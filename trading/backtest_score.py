"""
스크리닝 점수 백테스트 — "점수가 높을수록 이후 수익률이 높은가"를 과거 일봉으로 검증.

재현 범위: strategy._score_entry 중 일봉으로 과거 재계산이 가능한 기술적 7점
  필수: 현재가<MA60(+1), MA5>MA20(+1) / 골든크로스(+1) / 거래량≥10만(+1)
        RSI 과매도 반등(+2) / 거래량 감소(+1)
  바닥 다지기(basing)는 2026-11-04 채점에서 제거됐다 — 항목별 효과 비교용으로만 계산한다.
재현 불가(과거 시점 값 없음): PER·PBR(각 0.5) · 재무비율 4종(각 0.5) — 3점

진입: 신호일(t) 종가로 채점 → 다음 거래일(t+1) 시가 매수 (08:00 스크리닝과 동일 시점)
청산: t+5 / t+20 거래일 종가
초과수익: 같은 날 유니버스 전체 종목 평균 수익률을 뺀 값
통계: 같은 날 표본끼리는 독립이 아니므로 "일별 평균 → 날짜 간 평균·t값"으로 집계

한계: 현재 상장 종목만 대상(상장폐지 종목 누락 = 생존 편향), 시총 필터는 현재 시총 기준.

    python backtest_score.py [--start 2022-01-01] [--workers 8]
"""
import argparse
import os
import pickle
from concurrent.futures import ThreadPoolExecutor

import numpy as np
import pandas as pd

import FinanceDataReader as fdr

CACHE = os.path.join(os.path.dirname(os.path.abspath(__file__)), '_backtest_cache.pkl')
HORIZONS = (5, 20)


def _universe() -> pd.DataFrame:
    """screen_broad 와 같은 기준: 보통주·스팩 제외·시총 4천억 이상(현재 시총)."""
    frames = []
    for market in ('KOSPI', 'KOSDAQ'):
        df = fdr.StockListing(market)
        df['Market'] = market
        frames.append(df)

    df = pd.concat(frames)
    df['Code'] = df['Code'].astype(str).str.zfill(6)
    df = df[df['Code'].str.endswith('0') & ~df['Name'].str.contains('스팩')]

    return df[df['Marcap'] >= 4000 * 1e8][['Code', 'Name', 'Market', 'Marcap']]


def _load_prices(codes: list[str], start: str, workers: int) -> dict[str, pd.DataFrame]:
    if os.path.exists(CACHE):
        with open(CACHE, 'rb') as f:
            cached = pickle.load(f)
        if cached['start'] == start and set(codes) <= set(cached['prices']):
            return cached['prices']

    def fetch(code):
        try:
            return code, fdr.DataReader(code, start)
        except Exception:
            return code, None

    with ThreadPoolExecutor(workers) as ex:
        prices = {c: df for c, df in ex.map(fetch, codes) if df is not None and len(df) > 120}

    with open(CACHE, 'wb') as f:
        pickle.dump({'start': start, 'prices': prices}, f)

    return prices


def signals(df: pd.DataFrame) -> pd.DataFrame:
    """technical_indicators / kis_api.get_ma_data 와 같은 정의를 벡터로 계산."""
    c, v = df['Close'].astype(float), df['Volume'].astype(float)
    ma5, ma20, ma60 = c.rolling(5).mean(), c.rolling(20).mean(), c.rolling(60).mean()

    # rsi_series: 단순평균(와일더 아님) 14일
    d = c.diff()
    avg_gain = d.clip(lower=0).rolling(14).sum() / 14
    avg_loss = (-d.clip(upper=0)).rolling(14).sum() / 14
    rsi = (100 - 100 / (1 + avg_gain / avg_loss)).where(avg_loss != 0, 100.0)
    rsi_prev_min = rsi.shift(1).rolling(10).min()

    low60 = c.rolling(60).min()
    prior_low = c.shift(10).rolling(60).min()
    recent_vol, prior_vol = v.rolling(5).mean(), v.shift(5).rolling(20).mean()

    out = pd.DataFrame(index=df.index)
    out['below_ma60'] = c < ma60
    out['ma5_gt_ma20'] = ma5 > ma20
    out['golden_cross'] = (ma5 > ma20) & (ma5.shift(1) <= ma20.shift(1))
    out['volume_100k'] = v >= 100_000
    out['rsi_rebound'] = (rsi_prev_min < 30) & (rsi >= 30) & (rsi <= 50)
    # 옛 technical_indicators.basing_near_low (60일 저점 8% 이내 + 최근 10일 신저가 없음)
    out['basing'] = (c <= low60 * 1.08) & (c.rolling(10).min() >= prior_low)
    out['volume_declining'] = (recent_vol < prior_vol) & (prior_vol > 0)
    out['gate'] = out['below_ma60'] & out['ma5_gt_ma20']
    out['score'] = (out[['below_ma60', 'ma5_gt_ma20', 'golden_cross', 'volume_100k',
                         'volume_declining']].sum(axis=1)
                    + 2 * out['rsi_rebound']).where(out['gate'], 0)
    # screen_broad 기초 필터: 가격 1천~80만, 직전 세션 거래량 5만 이상, MA60 계산 가능
    out['eligible'] = c.between(1_000, 800_000) & (v >= 50_000) & ma60.notna()

    entry = df['Open'].shift(-1).astype(float)
    for h in HORIZONS:
        out[f'ret{h}'] = (c.shift(-h) / entry - 1) * 100
    out.loc[entry <= 0, [f'ret{h}' for h in HORIZONS]] = np.nan

    return out


def _day_clustered(df: pd.DataFrame, col: str) -> tuple[float, float, int]:
    """일별 평균의 날짜 간 평균·t값·일수."""
    daily = df.groupby(level='Date')[col].mean().dropna()
    if len(daily) < 2:
        return float('nan'), float('nan'), len(daily)

    return daily.mean(), daily.mean() / (daily.std(ddof=1) / np.sqrt(len(daily))), len(daily)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--start', default='2022-01-01')
    ap.add_argument('--signal-from', default='2022-07-01', help='지표 워밍업 이후부터 신호 집계')
    ap.add_argument('--workers', type=int, default=8)
    args = ap.parse_args()

    uni = _universe()
    print(f'유니버스: {len(uni)}종목 (시총 4천억↑ 보통주, 현재 기준)')
    prices = _load_prices(uni['Code'].tolist(), args.start, args.workers)
    print(f'일봉 확보: {len(prices)}종목')

    frames = []
    for code, df in prices.items():
        s = signals(df)
        s['code'] = code
        frames.append(s)

    allsig = pd.concat(frames)
    allsig.index.name = 'Date'
    allsig = allsig[(allsig.index >= args.signal_from) & allsig['eligible']]

    # 초과수익 = 종목 수익률 - 같은 날 유니버스 평균
    for h in HORIZONS:
        allsig[f'ex{h}'] = allsig[f'ret{h}'] - allsig.groupby(level='Date')[f'ret{h}'].transform('mean')

    period = f'{allsig.index.min():%Y-%m-%d} ~ {allsig.index.max():%Y-%m-%d}'
    print(f'신호 기간: {period}  표본(종목·일): {len(allsig):,}')

    gated = allsig[allsig['gate']]
    print(f'필수 조건(MA60 아래 + MA5>MA20) 통과: {len(gated):,} ({len(gated) / len(allsig):.1%})\n')

    print('■ 기술점수(7점 만점)별 초과수익 — 일별 평균 후 날짜 간 평균, 단위 %p')
    print(f"{'점수':>4} {'표본':>8} {'일수':>5} | " + ' | '.join(
        f'{h}일 초과 (t)   승률' for h in HORIZONS))
    for sc in range(2, 8):
        sub = gated[gated['score'] == sc]
        if sub.empty:
            continue

        cells = []
        for h in HORIZONS:
            m, t, _ = _day_clustered(sub, f'ex{h}')
            win = (sub[f'ex{h}'] > 0).mean()
            cells.append(f'{m:+6.2f} ({t:+5.1f}) {win:5.1%}')
        print(f'{sc:>4} {len(sub):>8,} {sub.index.nunique():>5} | ' + ' | '.join(cells))

    print('\n■ 필수 조건 통과 종목 안에서 항목별 효과 (해당=1 평균 − 해당=0 평균, 20일 초과 %p)')
    for item in ('golden_cross', 'volume_100k', 'rsi_rebound', 'basing', 'volume_declining'):
        on, off = gated[gated[item]], gated[~gated[item]]
        m_on, t_on, _ = _day_clustered(on, 'ex20')
        m_off, _, _ = _day_clustered(off, 'ex20')
        print(f'  {item:<17} 해당 {len(on):>7,}건 {m_on:+6.2f} (t {t_on:+5.1f}) vs 미해당 {m_off:+6.2f}'
              f'  → 차이 {m_on - m_off:+6.2f}')

    m, t, _ = _day_clustered(allsig[~allsig['gate']], 'ex20')
    print(f'\n참고: 필수 조건 탈락 종목 20일 초과 {m:+.2f}%p (t {t:+.1f})')


if __name__ == '__main__':
    main()
