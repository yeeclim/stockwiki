"""
시장 신호 적중률 추적 — 판정을 기록하고, 장 마감 뒤 실제 결과를 붙여 채점한다.

왜 필요한가
-----------
매일 아침 메일이 "강세 N : 약세 M (약세 우세)" 를 내보내지만, 그 판정이 동전던지기보다
나은지 확인할 데이터가 어디에도 없었다. 판정도 결과도 남지 않았으니 검증이 불가능했다.

채점 기준을 두 개로 나눈다.
  - gap   : 시가 / 전일종가 - 1.  신호 입력이 전부 개장 전 데이터(미국 종가, 야간선물,
            환율...)이므로, 이 모델이 실제로 예측할 수 있는 구간은 여기까지다.
  - close : 종가 / 전일종가 - 1.  하루 전체. 장중 재료는 모델에 입력조차 없으므로
            여기서 맞으면 상당 부분 운이다. 그래도 같이 본다.

그리고 반드시 기준선(base rate)과 같이 본다. 표본에서 상승일이 60% 인데 강세 판정
적중률이 60% 라면 그 모델은 아무 정보도 더하지 않은 것이다. 적중률 숫자만 보면
이걸 놓친다.

장중 체크포인트 (INTRADAY_SIGNAL_PLAN.md)
-----------------------------------------
장전 판정('pre')과 별도로, 장중(11시경)에 같은 신호 로직을 다시 돌린 판정('mid')을
같은 거래일의 다른 행으로 남긴다. 장중 판정은 이미 오전 움직임을 보고 낸 것이라
전일종가 대비 종가로 채점하면 공짜 적중이 섞인다. 그래서 판정 시점 지수 레벨을 같이
남기고 '체크포인트 → 종가' 잔여 구간(rest)으로 따로 채점한다.

사용법
------
  python forecast_log.py record      # (screen.py 가 자동 호출) 오늘 장전 판정 기록
                                     #  장 시작(09:00 KST) 후에는 건너뛴다. --force 로 강제 가능
  python forecast_log.py checkpoint  # 장중 재판정 기록 (forecast_checkpoint.yml 이 11시경 호출)
  python forecast_log.py fill        # 결과 미기입 행에 실제 시가/종가 채우기
  python forecast_log.py report      # 적중률 집계 출력
"""
import os
import sys
from datetime import datetime, timedelta, timezone

import requests

import market_signals

_SUPABASE_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_SUPABASE_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()
_TABLE = 'market_forecast_log'
_KST = timezone(timedelta(hours=9))

# 코스피 / 코스닥 — 네이버 지수 코드와 Yahoo 심볼(폴백)
_INDEX_CODES = {'kospi': ('KOSPI', '^KS11'), 'kosdaq': ('KOSDAQ', '^KQ11')}


def _headers(extra: dict | None = None) -> dict:
    return {
        'apikey':        _SUPABASE_KEY,
        'Authorization': f'Bearer {_SUPABASE_KEY}',
        'Content-Type':  'application/json',
        **(extra or {}),
    }


def _configured() -> bool:
    if _SUPABASE_URL and _SUPABASE_KEY:
        return True
    print('⚠️  SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 미설정 — 적중률 로그를 건너뜁니다')
    return False


# ── 1. 판정 기록 ─────────────────────────────────────────────────────────────
# 장 시작(09:00 KST) 전에 낸 판정만 기록한다.
#
# screen.py 는 하루 두 번 돈다 — 06:30(장전 메일)과 15:00(마감 정리). 15:00 실행분의
# 신호에는 이미 당일 장중 데이터가 섞여 있어서 '예측'이 아니라 '사후 관찰'이다.
# 그걸 같은 trade_date 에 덮어쓰면 적중률 로그 전체가 무의미해진다(결과를 보고
# 찍은 판정을 채점하는 꼴). 그래서 장 시작 이후 호출은 기록하지 않는다.
_MARKET_OPEN_HOUR = 9
# 장중 체크포인트는 정규장(09:00~15:30) 안에서만 의미가 있다. 15시 이후면 남은 구간이
# 너무 짧아 잔여 구간 채점이 잡음뿐이다 (Actions 지연이 길어진 날은 그냥 버린다).
_CHECKPOINT_LAST_HOUR = 15

CHECKPOINTS = ('pre', 'mid')


def _today_index_levels(brief: dict) -> dict | None:
    """장중 체크포인트 시점의 코스피/코스닥 현재가. 오늘 체결값이 아니면(휴장일 등) None."""
    import us_market_brief
    by_label = {r['label']: r for r in (brief.get('kr_indices') or [])}
    out = {}
    for name, label in (('kospi', '코스피'), ('kosdaq', '코스닥')):
        row = by_label.get(label)
        if not row or not us_market_brief._traded_today_kst(row.get('traded_at')):
            return None
        out[f'{name}_at_check'] = round(float(row['price']), 2)
    return out


def record(brief: dict | None, trade_date: str | None = None,
           force: bool = False, checkpoint: str = 'pre') -> bool:
    """신호 판정을 저장. 같은 날·같은 체크포인트 재실행은 덮어쓴다(upsert).

    checkpoint='pre' : 장전 판정. 장 시작 후 호출은 건너뛴다.
    checkpoint='mid' : 장중 재판정. 정규장 중에만, 그 시점 지수 레벨과 함께 남긴다."""
    if checkpoint not in CHECKPOINTS:
        raise ValueError(f'unknown checkpoint: {checkpoint}')
    if not _configured():
        return False

    now = datetime.now(_KST)
    extra: dict = {}
    if checkpoint == 'pre':
        if not force and now.hour >= _MARKET_OPEN_HOUR:
            print(f'⏭  적중률 로그 생략 — 장 시작 후 실행({now:%H:%M} KST)이라 예측이 아닙니다')
            return False
    else:
        if not force and not (_MARKET_OPEN_HOUR <= now.hour < _CHECKPOINT_LAST_HOUR):
            print(f'⏭  장중 체크포인트 생략 — 정규장 시간대가 아닙니다({now:%H:%M} KST)')
            return False
        levels = _today_index_levels(brief or {})
        if levels is None:
            print('⏭  장중 체크포인트 생략 — 오늘 지수 체결값이 없습니다(휴장일?)')
            return False
        extra = levels

    signals = (brief or {}).get('signals') or []
    if not signals:
        print('⚠️  신호가 없어 적중률 로그를 남기지 않습니다')
        return False

    trade_date = trade_date or now.strftime('%Y-%m-%d')
    bull, bear, neutral = market_signals.signal_counts(signals)
    raw_bull, raw_bear, _ = market_signals.raw_counts(signals)

    row = {
        'trade_date':   trade_date,
        'checkpoint':   checkpoint,
        'recorded_at':  datetime.now(timezone.utc).isoformat(),
        'verdict':      market_signals.verdict_from_counts(bull, bear),
        'bull':         bull,
        'bear':         bear,
        'neutral':      neutral,
        'raw_verdict':  market_signals.verdict_from_counts(raw_bull, raw_bear),
        'raw_bull':     raw_bull,
        'raw_bear':     raw_bear,
        'signals_json': signals,
        **extra,
    }
    try:
        r = requests.post(
            f'{_SUPABASE_URL}/rest/v1/{_TABLE}?on_conflict=trade_date,checkpoint',
            headers=_headers({'Prefer': 'resolution=merge-duplicates'}),
            json=row, timeout=10,
        )
        if r.ok:
            print(f"📈 적중률 로그 기록: {trade_date} [{checkpoint}] {row['verdict']} "
                  f"(강세 {bull} · 약세 {bear} · 중립 {neutral})")
            return True
        print(f'⚠️  적중률 로그 기록 실패: {r.status_code} {r.text[:200]}')
    except Exception as e:
        print(f'⚠️  적중률 로그 기록 오류: {e}')
    return False


# ── 2. 실제 결과 채우기 ──────────────────────────────────────────────────────
def _naver_daily(code: str) -> dict[str, dict]:
    """네이버 지수 일봉 → {'YYYY-MM-DD': {'open', 'close'}}.

    국내 지수는 네이버를 1순위로 쓴다. Yahoo(^KS11)는 거래일이 통째로 빠지는 일이
    있는데(예: 2026-09-15 누락), 그러면 직전 봉을 전일종가로 잘못 집어 갭이 하루치
    통째로 틀어진다. 네이버는 국내 지수 원천에 가깝고 누락이 없었다."""
    r = requests.get(
        f'https://api.stock.naver.com/chart/domestic/index/{code}',
        params={'periodType': 'dayCandle'},
        headers={'User-Agent': 'Mozilla/5.0'}, timeout=20,
    )
    r.raise_for_status()
    out: dict[str, dict] = {}
    for row in r.json().get('priceInfos') or []:
        d = str(row.get('localDate') or '')
        o, c = row.get('openPrice'), row.get('closePrice')
        if len(d) != 8 or o is None or c is None:
            continue
        out[f'{d[:4]}-{d[4:6]}-{d[6:]}'] = {'open': float(o), 'close': float(c)}
    return out


def _yahoo_daily(symbol: str, range_: str = '1y') -> dict[str, dict]:
    """폴백. 네이버가 막혔을 때만 쓴다 (위 주석의 누락 위험을 안고 가는 경로)."""
    r = requests.get(
        f'https://query1.finance.yahoo.com/v8/finance/chart/{symbol}',
        params={'interval': '1d', 'range': range_},
        headers={'User-Agent': 'Mozilla/5.0'}, timeout=20,
    )
    r.raise_for_status()
    res = r.json()['chart']['result'][0]
    stamps = res.get('timestamp') or []
    quote = (res.get('indicators', {}).get('quote') or [{}])[0]
    opens, closes = quote.get('open') or [], quote.get('close') or []
    out: dict[str, dict] = {}
    for i, ts in enumerate(stamps):
        day = datetime.fromtimestamp(ts, _KST).strftime('%Y-%m-%d')
        o = opens[i] if i < len(opens) else None
        c = closes[i] if i < len(closes) else None
        if o is None or c is None:
            continue
        out[day] = {'open': float(o), 'close': float(c)}
    return out


def _daily_bars(index_key: str) -> dict[str, dict]:
    """일봉 시계열. 진행 중인 당일 봉은 종가가 확정되지 않았으므로 버린다."""
    naver_code, yahoo_symbol = _INDEX_CODES[index_key]
    try:
        bars = _naver_daily(naver_code)
    except Exception as e:
        print(f'⚠️  네이버 {naver_code} 일봉 실패({e}) — Yahoo로 폴백합니다')
        bars = _yahoo_daily(yahoo_symbol)
    today = datetime.now(_KST).strftime('%Y-%m-%d')
    return {d: v for d, v in bars.items() if d < today}


def _pct(now: float, base: float) -> float | None:
    if not base:
        return None
    return round((now / base - 1) * 100, 3)


def fill_outcomes(lookback_days: int = 180) -> int:
    """결과가 비어 있는 행에 시가/종가/등락률을 채운다. 채운 행 수를 반환."""
    if not _configured():
        return 0
    since = (datetime.now(_KST) - timedelta(days=lookback_days)).strftime('%Y-%m-%d')
    try:
        r = requests.get(
            f'{_SUPABASE_URL}/rest/v1/{_TABLE}'
            f'?outcome_filled_at=is.null&trade_date=gte.{since}'
            f'&select=trade_date,checkpoint,kospi_at_check,kosdaq_at_check'
            f'&order=trade_date.asc',
            headers=_headers(), timeout=15,
        )
        r.raise_for_status()
        pending = r.json()
    except Exception as e:
        print(f'⚠️  미기입 행 조회 실패: {e}')
        return 0

    if not pending:
        print('✅ 채울 결과가 없습니다')
        return 0

    try:
        bars = {name: _daily_bars(name) for name in _INDEX_CODES}
    except Exception as e:
        print(f'⚠️  지수 일봉 조회 실패: {e}')
        return 0

    # 전일 종가는 "그 지수의 직전 거래일 종가" — 일봉 시계열에서 직접 찾는다.
    sorted_days = {name: sorted(b) for name, b in bars.items()}

    filled = 0
    for prow in pending:
        day, checkpoint = prow['trade_date'], prow.get('checkpoint') or 'pre'
        patch: dict = {}
        ok = False
        for name in _INDEX_CODES:
            series, days = bars[name], sorted_days[name]
            if day not in series:
                continue  # 휴장일이거나 아직 일봉이 안 올라온 날
            idx = days.index(day)
            if idx == 0:
                continue  # 직전 거래일이 조회 범위 밖 — 갭 계산 불가
            prev_close = series[days[idx - 1]]['close']
            bar = series[day]
            patch[f'{name}_prev_close'] = round(prev_close, 2)
            patch[f'{name}_open']       = round(bar['open'], 2)
            patch[f'{name}_close']      = round(bar['close'], 2)
            patch[f'{name}_gap_pct']    = _pct(bar['open'], prev_close)
            patch[f'{name}_close_pct']  = _pct(bar['close'], prev_close)
            at_check = prow.get(f'{name}_at_check')
            if at_check is not None:
                patch[f'{name}_rest_pct'] = _pct(bar['close'], float(at_check))
            ok = True

        if not ok:
            continue
        patch['outcome_filled_at'] = datetime.now(timezone.utc).isoformat()
        try:
            u = requests.patch(
                f'{_SUPABASE_URL}/rest/v1/{_TABLE}'
                f'?trade_date=eq.{day}&checkpoint=eq.{checkpoint}',
                headers=_headers(), json=patch, timeout=10,
            )
            if u.ok:
                filled += 1
            else:
                print(f'⚠️  {day} [{checkpoint}] 결과 기입 실패: {u.status_code} {u.text[:150]}')
        except Exception as e:
            print(f'⚠️  {day} [{checkpoint}] 결과 기입 오류: {e}')

    print(f'✅ 결과 기입 완료: {filled}/{len(pending)}행'
          + ('' if filled == len(pending) else ' (나머지는 휴장일이거나 일봉 미반영)'))
    return filled


# ── 3. 집계 ──────────────────────────────────────────────────────────────────
def _score(rows: list[dict], verdict_key: str, pct_key: str) -> dict:
    """방향 판정이 실제 등락 부호와 맞았는지. 중립 판정과 결측은 제외."""
    hit = miss = 0
    for row in rows:
        v = row.get(verdict_key)
        pct = row.get(pct_key)
        if v not in ('bull', 'bear') or pct is None:
            continue
        actual = float(pct)
        if actual == 0:
            continue
        if (v == 'bull') == (actual > 0):
            hit += 1
        else:
            miss += 1
    n = hit + miss
    return {'n': n, 'hit': hit, 'rate': (hit / n * 100) if n else None}


def _base_rate(rows: list[dict], pct_key: str) -> dict:
    """기준선 — 표본에서 그냥 상승한 날의 비율. '항상 강세' 라고 찍는 전략의 성적이다.
    모델 적중률이 이 숫자를 못 넘으면 정보값이 0이다."""
    vals = [float(r[pct_key]) for r in rows
            if r.get(pct_key) is not None and float(r[pct_key]) != 0]
    up = sum(1 for v in vals if v > 0)
    return {'n': len(vals), 'up': up, 'rate': (up / len(vals) * 100) if vals else None}


def _fmt(d: dict) -> str:
    return '표본 부족' if not d['n'] else f"{d['rate']:5.1f}%  ({d['hit']}/{d['n']})"


def _print_horizon(rows: list[dict], pct_key: str, title: str) -> None:
    """한 채점 구간에 대해 기준선 / 그룹 판정 / 개별 판정(대조군) 을 찍는다."""
    base = _base_rate(rows, pct_key)
    grouped = _score(rows, 'verdict', pct_key)
    raw = _score(rows, 'raw_verdict', pct_key)
    base_txt = ('표본 부족' if not base['n']
                else f"{base['rate']:5.1f}%  ({base['up']}/{base['n']})")
    print(f'  {title}')
    print(f"    기준선(항상 강세) : {base_txt}")
    print(f"    그룹 집계 판정    : {_fmt(grouped)}")
    print(f"    개별 집계(대조군) : {_fmt(raw)}")
    if grouped['n'] and base['rate'] is not None:
        edge = grouped['rate'] - base['rate']
        note = ('기준선 초과' if edge > 0 else
                ('기준선 이하 — 정보값 없음' if edge < 0 else '기준선과 동일'))
        print(f"    → 기준선 대비 {edge:+.1f}%p  ({note})")


def _hit(verdict: str | None, pct) -> bool | None:
    if verdict not in ('bull', 'bear') or pct is None or float(pct) == 0:
        return None
    return (verdict == 'bull') == (float(pct) > 0)


def _print_paired(pre_rows: list[dict], mid_rows: list[dict], idx_name: str) -> None:
    """장전·장중 판정이 둘 다 있는 날만 골라 같은 표본에서 비교한다.
    표본이 다르면 적중률 차이가 판정 차이인지 날짜 차이인지 구분이 안 된다."""
    pre_by_day = {r['trade_date']: r for r in pre_rows}
    pairs = [(pre_by_day[m['trade_date']], m) for m in mid_rows if m['trade_date'] in pre_by_day]
    if not pairs:
        print('  같은 날 장전·장중 판정이 모두 있는 표본이 아직 없습니다')
        return

    close_key, rest_key = f'{idx_name}_close_pct', f'{idx_name}_rest_pct'
    pre_hits = [h for h in (_hit(p['verdict'], p.get(close_key)) for p, _ in pairs) if h is not None]
    mid_hits = [h for h in (_hit(m['verdict'], m.get(rest_key)) for _, m in pairs) if h is not None]

    def _rate(hits: list[bool]) -> str:
        return '표본 부족' if not hits else f'{sum(hits) / len(hits) * 100:5.1f}%  ({sum(hits)}/{len(hits)})'

    print(f'  3단 비교 (같은 {len(pairs)}일)')
    print(f'    장전 판정 → 종가          : {_rate(pre_hits)}')
    print(f'    장중 재판정 → 잔여 구간   : {_rate(mid_hits)}')

    # 장중에 판정이 뒤집힌 날 — 체크포인트의 존재 이유는 결국 여기서 드러난다.
    flips = [(p, m) for p, m in pairs
             if p['verdict'] in ('bull', 'bear') and m['verdict'] in ('bull', 'bear')
             and p['verdict'] != m['verdict']]
    if flips:
        right = [h for h in (_hit(m['verdict'], m.get(rest_key)) for _, m in flips) if h is not None]
        print(f'    판정 반전 {len(flips)}일 → 장중 쪽이 잔여 구간을 맞힌 날 {_rate(right).strip()}')
    else:
        print('    판정 반전: 없음')


def report(days: int = 180) -> None:
    if not _configured():
        return
    since = (datetime.now(_KST) - timedelta(days=days)).strftime('%Y-%m-%d')
    try:
        r = requests.get(
            f'{_SUPABASE_URL}/rest/v1/{_TABLE}'
            f'?trade_date=gte.{since}&outcome_filled_at=not.is.null'
            f'&order=trade_date.asc',
            headers=_headers(), timeout=15,
        )
        r.raise_for_status()
        rows = r.json()
    except Exception as e:
        print(f'⚠️  집계 조회 실패: {e}')
        return

    pre_rows = [r for r in rows if (r.get('checkpoint') or 'pre') == 'pre']
    mid_rows = [r for r in rows if r.get('checkpoint') == 'mid']
    if not pre_rows:
        print('집계할 데이터가 없습니다. 먼저 record / fill 을 돌리세요.')
        return

    bar = '=' * 64
    print(f'\n{bar}')
    print(f"  시장 신호 적중률 — 장전 판정  "
          f"({pre_rows[0]['trade_date']} ~ {pre_rows[-1]['trade_date']}, {len(pre_rows)}일)")
    print(bar)
    for idx_name, idx_label in (('kospi', '코스피'), ('kosdaq', '코스닥')):
        print(f'\n[{idx_label}]')
        _print_horizon(pre_rows, f'{idx_name}_gap_pct', '시가 갭 (모델이 실제로 예측하는 구간)')
        _print_horizon(pre_rows, f'{idx_name}_close_pct', '종가 (하루 전체)')

    if mid_rows:
        print(f'\n{bar}')
        print(f"  장중 재판정  ({mid_rows[0]['trade_date']} ~ {mid_rows[-1]['trade_date']}, "
              f"{len(mid_rows)}일)")
        print(bar)
        for idx_name, idx_label in (('kospi', '코스피'), ('kosdaq', '코스닥')):
            print(f'\n[{idx_label}]')
            # 잔여 구간이 정직한 채점이다. 전일종가 대비 종가는 오전 움직임을 이미 보고
            # 낸 판정이라 공짜 적중이 섞인다 — 참고로만 같이 찍는다.
            _print_horizon(mid_rows, f'{idx_name}_rest_pct', '체크포인트 → 종가 (장중 판정의 실제 성적)')
            _print_horizon(mid_rows, f'{idx_name}_close_pct', '전일종가 → 종가 (오전 움직임 포함, 참고용)')
            _print_paired(pre_rows, mid_rows, idx_name)

    n_scored = _score(pre_rows, 'verdict', 'kospi_gap_pct')['n']
    n_mid = _score(mid_rows, 'verdict', 'kospi_rest_pct')['n']
    if n_scored < 30 or (mid_rows and n_mid < 30):
        print(f'\n⚠️  방향 판정 표본: 장전 {n_scored}일 · 장중 {n_mid}일. 30일 미만에서는 적중률'
              '\n    차이가 대부분 우연이니 숫자를 믿지 마세요 (참고용으로만).')
    print()


def _brief_with_auth(with_summary: bool = True) -> dict:
    import us_market_brief
    from kis_api import KISApi
    api = KISApi()
    try:
        api.auth()
    except Exception as e:
        # 인증이 안 돼도 미국·네이버 지표로 신호는 나온다 (KIS 지표만 빠짐)
        print(f'⚠️  KIS 인증 실패 — KIS 지표 없이 진행: {e}')
        api = None
    return us_market_brief.get_brief(api, with_summary=with_summary)


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'report'
    force = '--force' in sys.argv
    if cmd == 'fill':
        fill_outcomes()
    elif cmd == 'report':
        fill_outcomes()   # 집계 전에 항상 최신 결과부터 채운다
        report()
    elif cmd == 'record':
        record(_brief_with_auth(), force=force)
    elif cmd == 'checkpoint':
        record(_brief_with_auth(with_summary=False), force=force, checkpoint='mid')
    else:
        print(__doc__)


if __name__ == '__main__':
    main()
