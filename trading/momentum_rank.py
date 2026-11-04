"""
모멘텀 상위 종목 — 매일 게시판에 기록만 한다 (메일·앱·자동매매 미노출).
기존 바닥 매수 점수와 2~3개월 실제 성과를 비교하기 위한 전진 검증용.

근거: 2022-07~2026-11 전 종목 백테스트(신호 시점 시총 필터)에서
  12개월 모멘텀(최근 1개월 제외)·52주 최고가 근접도 상위 20% 가 전·후반 모두 20일 초과수익 +.
  두 순위 평균 상위 20종목, 비중첩 20일: 전반 +3.48%p · 후반 +0.94%p (후반 t 0.7 — 미확정).

선정: 시총 4천억↑ 보통주 · 종가 1천~80만 · 직전 세션 거래량 5만주↑ · 251거래일 이력 보유
      → mom12_1 = 종가[t-20]/종가[t-250]−1, high52 = 종가[t]/최근 250일 최고 종가
      → 각 백분위 순위 평균 상위 20
데이터: FinanceDataReader 일봉 (KIS 일봉 조회는 달력 250일 ≈ 170거래일이라 12개월 계산 불가)
GitHub Actions 광역 스캔(06:00 KST) 다음 단계로 실행.
"""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone

import pandas as pd
import FinanceDataReader as fdr

import board_post
from exclusions import get_excluded_codes

KST = timezone(timedelta(hours=9))
MIN_CAP_EOK = 4_000
TOP_N = 20
LOOKBACK = 250   # 52주 ≈ 250거래일
SKIP = 20        # 최근 1개월 제외 (단기 반전 회피)


def features(closes: list[float]) -> dict | None:
    """종가(과거→최신)로 모멘텀 지표 계산. 이력이 부족하면 None — 0 으로 채워 순위에 넣지 않는다."""
    if len(closes) < LOOKBACK + 1 or closes[-LOOKBACK - 1] <= 0:
        return None

    return {
        'mom12_1': closes[-SKIP - 1] / closes[-LOOKBACK - 1] - 1,
        'high52': closes[-1] / max(closes[-LOOKBACK:]),
    }


def rank(feats: dict[str, dict], top_n: int = TOP_N) -> list[tuple[str, float]]:
    """{code: features} → 두 지표 백분위 순위 평균 상위 top_n [(code, 평균순위)]."""
    df = pd.DataFrame.from_dict(feats, orient='index')
    df['score'] = (df['mom12_1'].rank(pct=True) + df['high52'].rank(pct=True)) / 2

    top = df['score'].sort_values(ascending=False).head(top_n)

    return list(top.items())


def _completed_rows(df: pd.DataFrame, now: datetime) -> pd.DataFrame:
    """15:30 전이면 오늘 행(진행 중 세션)을 뺀다."""
    if (now.hour, now.minute) < (15, 30):
        return df[df.index.normalize() < pd.Timestamp(now.date())]

    return df


def _universe() -> pd.DataFrame:
    frames = [fdr.StockListing(m).assign(Market=m) for m in ('KOSPI', 'KOSDAQ')]
    df = pd.concat(frames)
    df['Code'] = df['Code'].astype(str).str.zfill(6)
    df = df[df['Code'].str.endswith('0') & ~df['Name'].str.contains('스팩')]

    return df[df['Marcap'] >= MIN_CAP_EOK * 1e8]


def _content(rows: list[dict], base_date: str, n_ranked: int) -> str:
    th = "padding:6px;border-bottom:2px solid rgba(128,128,128,0.6);text-align:left"
    body = ''.join(
        f"<tr><td>{i}</td><td>{r['name']}({r['code']})</td><td>{r['close']:,.0f}원</td>"
        f"<td>{r['mom12_1'] * 100:+.1f}%</td><td>{r['high52'] * 100:.1f}%</td></tr>"
        for i, r in enumerate(rows, 1)
    )

    return (
        f"<p><b>기준일:</b> {base_date} 종가 | <b>순위 대상:</b> {n_ranked}종목</p>"
        f"<p>선정: 12개월 수익률(최근 1개월 제외)과 52주 최고가 대비 위치의 순위 평균 상위 {TOP_N} "
        f"(시총 {MIN_CAP_EOK:,}억 이상, 직전 거래량 5만주 이상)</p>"
        f"<table cellpadding='6' cellspacing='0' style='border-collapse:collapse;width:100%'>"
        f"<thead><tr><th style='{th}'>순위</th><th style='{th}'>종목</th><th style='{th}'>종가</th>"
        f"<th style='{th}'>12개월(−1개월)</th><th style='{th}'>52주 최고가 대비</th></tr></thead>"
        f"<tbody>{body}</tbody></table>"
    )


def main():
    now = datetime.now(KST)
    if now.weekday() >= 5:
        print('주말 — 기록 생략')
        return

    uni = _universe()
    try:
        excluded = get_excluded_codes()
    except Exception as e:
        print(f'❌ 제외 종목 조회 실패 — 기록 생략: {e}')
        return
    uni = uni[~uni['Code'].isin(excluded)]
    names = dict(zip(uni['Code'], uni['Name']))
    start = (now - timedelta(days=400)).strftime('%Y-%m-%d')

    def fetch(code):
        try:
            return code, _completed_rows(fdr.DataReader(code, start), now)
        except Exception as e:
            return code, e

    feats, last, skipped = {}, {}, {'조회 실패': 0, '이력 부족': 0, '가격 범위': 0, '거래량': 0}
    with ThreadPoolExecutor(8) as ex:
        for code, df in ex.map(fetch, uni['Code']):
            if isinstance(df, Exception) or df.empty:
                skipped['조회 실패'] += 1
                continue

            close, vol = float(df['Close'].iloc[-1]), float(df['Volume'].iloc[-1])
            if not 1_000 <= close <= 800_000:
                skipped['가격 범위'] += 1
                continue

            if vol < 50_000:
                skipped['거래량'] += 1
                continue

            f = features(df['Close'].astype(float).tolist())
            if f is None:
                skipped['이력 부족'] += 1
                continue

            feats[code] = f
            last[code] = (df.index[-1], close)

    print(f'대상 {len(uni)}종목 · 순위 산정 {len(feats)} · 제외 ' + ', '.join(f'{k} {v}' for k, v in skipped.items()))
    if skipped['조회 실패'] > len(uni) * 0.2:
        print('❌ 조회 실패 20% 초과 — 기록 생략')
        return

    base = max(d for d, _ in last.values())
    rows = [{'code': c, 'name': names[c], 'close': last[c][1], **feats[c]} for c, _ in rank(feats)]
    for i, r in enumerate(rows, 1):
        print(f"  {i:>2}. {r['name']}({r['code']}) {r['close']:,.0f}원  "
              f"mom12_1 {r['mom12_1'] * 100:+.1f}%  high52 {r['high52'] * 100:.1f}%")

    base_str = f'{base:%Y년 %m월 %d일}'
    post_id = board_post.post(f'{base_str} 종가 기준 모멘텀 상위 {TOP_N}종목', _content(rows, base_str, len(feats)))
    print(f'📝 게시판 등록: {board_post.post_url(post_id)}' if post_id else '⚠️  게시판 등록 실패')


if __name__ == '__main__':
    main()
