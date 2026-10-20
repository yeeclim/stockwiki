"""
시장 신호 집계 — 상관 그룹 단위 투표.

왜 그룹으로 묶는가
------------------
_compute_signals 는 지표 하나당 신호 하나(±1)를 만들고, 예전엔 그걸 그대로 세어
"강세 N : 약세 M" 을 뽑았다. 문제는 지표들이 서로 독립이 아니라는 점이다.

    "간밤 미국 위험선호 개선" 이라는 사건 하나가
      → 미국 증시 ▲ (강세 1표)
      → VIX ▼      (강세 1표)
      → 미 국채 10년 ▼ (강세 1표)
    로 3표가 된다. 실제로 관측한 독립 정보는 1개인데 3:0 처럼 보인다.

이러면 서로 다른 재료가 부딪히는 날(예: 미국은 좋은데 국내 수급이 나쁜 날)에
표차가 실제보다 크게 벌어져, 신호 개수가 "얼마나 많은 근거가 같은 방향인가" 가
아니라 "어느 진영에 상관된 지표가 더 많이 편성돼 있나" 를 재게 된다.

그래서 상관이 높은 지표들을 한 그룹으로 묶고, 그룹당 정확히 1표만 행사한다.
그룹 안에서 방향이 갈리면(합이 0) 그 그룹은 중립 — 실제로 판단이 안 서는 상태를
숫자로도 그대로 드러낸다.

화면에 찍히는 개별 칩(라벨 ▲ 강세)은 그대로 둔다. 근거는 다 보여주되
집계만 그룹 단위로 한다.

판정은 투표가 아니라 예상 시가 갭으로 한다 (2026-10-20)
------------------------------------------------------
같은 203거래일(2025-12-11~2026-10-16) 백테스트에서 코스피200 야간선물 하나가 상관 0.81,
갭 방향 84%였고 SOX(0.59)·EWY보정(0.52)을 더해도 검증 구간 성적이 나아지지 않았다.
유가·금리·환율은 3년 표본에서 방향 49~53% — 동전 던지기인데 투표에선 1표씩이었다.
그래서 판정 = 회귀식으로 낸 예상 갭의 부호, 투표 집계는 적중률 로그 비교용으로만 남긴다.
"""

# 그룹 정의 — (키, 표시명, 라벨 매칭 함수)
# 순서가 곧 표시 순서다.
_GROUP_DEFS = [
    ('us_risk', '미국 위험선호',
     lambda l: l in ('미국 증시', '미국 지수선물(마감 후)', 'VIX(변동성)', '미 국채 10년', '미국 반도체(SOX)')),
    # 원/달러는 달러인덱스를 타고 us_risk 와 상관되지만, 외국인 자금 유출입이라는
    # 국내 고유 정보도 담고 있어 별도 그룹으로 둔다. 완전히 독립은 아니라는 점은
    # 알고 쓰는 타협이다.
    ('fx', '원화',
     lambda l: l.startswith('원/달러')),
    # 야간선물 / EWY보정 / 정규장선물 / 미결제약정 — 전부 "국내장이 닫힌 동안의
    # 한국 주식 방향" 하나를 다른 창으로 본 것이다.
    ('kr_overnight', '국내 야간·선물',
     lambda l: ('야간' in l) or ('선물' in l)),
    ('commodity', '원자재',
     lambda l: l.startswith('국제유가')),
    # 코스피·코스닥 수급은 시장별로 따로 1표. 한 그룹으로 묶으면 방향이 갈리는 날
    # 서로 상쇄돼 중립이 된다(2026-10-13 코스피 −1.33조 ▼ / 코스닥 +0.13조 ▲ → 중립).
    # 같은 방향인 날엔 2표가 되는 점은 감수한다.
    ('kr_flow_kospi', '코스피 수급',
     lambda l: l.startswith('코스피 수급')),
    ('kr_flow_kosdaq', '코스닥 수급',
     lambda l: l.startswith('코스닥 수급')),
]

VERDICT_TEXT = {'bull': '강세 출발', 'bear': '약세 출발', 'neutral': '보합 출발', 'unknown': '판정 보류'}

# 예상 시가 갭(%) 회귀 계수 — 2026-10-20 백테스트, 전체 표본으로 적합.
#   야간선물: 203일, 뒤 30% 검증 방향 87%·R² 0.63
#   SOX·EWY보정: 야간선물이 없을 때만. 723일(3년), 검증 방향 72%·R² 0.38
NIGHT_LABEL = '코스피200 야간선물'
EWY_LABEL = '야간 한국물(EWY·환율보정)'
SOX_LABEL = '미국 반도체(SOX)'
NIGHT_GAP = (0.042, 0.703)            # 갭 ≈ a + b × 야간선물
FALLBACK_GAP = (0.136, 0.165, 0.218)  # 갭 ≈ a + b × EWY보정 + c × SOX
GAP_BAND = 0.3                         # 예상 갭이 이 안쪽이면 보합

# 장중 우선 — '코스피200 선물' 신호는 오늘 체결된 값일 때만 만들어진다(us_market_brief).
# 장이 열려 실제 방향이 나와 있으면 유가·수급 같은 간접 지표로 투표하지 않는다.
# 10-14 10:35: 선물 +1.04%·코스피 상승 중인데 유가 +1.15%·장중 수급 ▼ 3표에 밀려 '약세 우세'.
INTRADAY_LABEL = '코스피200 선물'
INTRADAY_BAND = 0.3


def group_of(label: str) -> tuple[str, str]:
    """라벨 → (그룹키, 표시명). 어디에도 안 걸리면 그 신호만의 단독 그룹으로 만든다
    (새 지표를 추가했을 때 조용히 집계에서 빠지는 일이 없도록)."""
    label = (label or '').strip()
    for key, name, match in _GROUP_DEFS:
        if match(label):
            return key, name
    return f'etc:{label}', label


# 야간선물이 있으면 SK하이닉스 ADR 은 집계에서 뺀다(칩·로그엔 남김). 지수를 직접 보는
# 야간선물 +1.71% 가 종목 하나 −2.79% 와 1:1 로 상쇄돼 그룹이 중립이 됐다(2026-10-14).
_NIGHT_FUTURES_LABEL = '코스피200 야간선물'
_SKHY_PREFIX = 'SK하이닉스 ADR'


def excluded_labels(signals: list[dict]) -> set[str]:
    """칩엔 보이지만 그룹 집계에서 빠지는 신호 라벨."""
    labels = [s.get('label', '') for s in signals or []]
    if _NIGHT_FUTURES_LABEL not in labels:
        return set()

    return {l for l in labels if l.startswith(_SKHY_PREFIX)}


def group_votes(signals: list[dict]) -> list[dict]:
    """신호 목록 → 그룹당 1표. [{'key','name','direction','members':[라벨...]}]

    그룹 표 = sign(그룹 내 direction 합). 합이 0이면 중립(서로 상쇄).
    """
    excluded = excluded_labels(signals)
    order: list[str] = []
    buckets: dict[str, dict] = {}
    for s in signals or []:
        key, name = group_of(s.get('label', ''))
        if key not in buckets:
            buckets[key] = {'key': key, 'name': name, 'net': 0, 'members': []}
            order.append(key)
        b = buckets[key]
        if s.get('label', '') not in excluded:
            b['net'] += int(s.get('direction', 0) or 0)
        b['members'].append(s.get('label', ''))

    votes = []
    for key in order:
        b = buckets[key]
        net = b['net']
        votes.append({
            'key':       b['key'],
            'name':      b['name'],
            'direction': 1 if net > 0 else (-1 if net < 0 else 0),
            'members':   b['members'],
        })
    return votes


def group_direction(signals: list[dict], key: str) -> int:
    """그룹 하나의 표(+1/-1/0). 그룹 신호가 없으면 0."""
    for v in group_votes(signals):
        if v['key'] == key:
            return v['direction']

    return 0


def _values(signals: list[dict]) -> dict[str, float]:
    """라벨 → value. value 가 없는 신호(옛 아카이브)는 뺀다."""
    return {s['label']: s['value'] for s in signals or [] if s.get('label') and s.get('value') is not None}


def intraday_signal(signals: list[dict]) -> dict | None:
    """장중이면 당일 코스피200 선물 신호, 아니면 None."""
    for s in signals or []:
        if s.get('label') == INTRADAY_LABEL and s.get('value') is not None:
            return s

    return None


def expected_gap(signals: list[dict]) -> dict | None:
    """{'value': 예상 시가 갭 %, 'basis': 근거 문구} — 야간선물, 없으면 EWY보정+SOX.
    둘 다 없으면 None (중립으로 세지 않는다)."""
    values = _values(signals)
    if NIGHT_LABEL in values:
        a, b = NIGHT_GAP
        night = values[NIGHT_LABEL]

        return {'value': a + b * night, 'basis': f'{NIGHT_LABEL} {night:+.2f}%'}

    if EWY_LABEL in values and SOX_LABEL in values:
        a, b, c = FALLBACK_GAP
        ewy, sox = values[EWY_LABEL], values[SOX_LABEL]

        return {'value': a + b * ewy + c * sox, 'basis': f'EWY보정 {ewy:+.2f}% · SOX {sox:+.2f}%'}

    return None


def signal_counts(signals: list[dict]) -> tuple[int, int, int]:
    """(강세, 약세, 중립) — 그룹 단위 집계. 표시·판정에 쓰는 공식 카운트."""
    votes = group_votes(signals)
    bull = sum(1 for v in votes if v['direction'] > 0)
    bear = sum(1 for v in votes if v['direction'] < 0)
    return bull, bear, len(votes) - bull - bear


def raw_counts(signals: list[dict]) -> tuple[int, int, int]:
    """그룹화 전 개별 지표 카운트. 표시엔 쓰지 않고, 적중률 로그에서
    '그룹화가 실제로 판정을 개선했는가' 를 비교할 때만 쓴다."""
    bull = sum(1 for s in (signals or []) if (s.get('direction', 0) or 0) > 0)
    bear = sum(1 for s in (signals or []) if (s.get('direction', 0) or 0) < 0)
    return bull, bear, len(signals or []) - bull - bear


def _sign_with_band(value: float, band: float) -> str:
    if value > band:
        return 'bull'

    return 'bear' if value < -band else 'neutral'


def verdict(signals: list[dict]) -> str:
    """'bull' | 'bear' | 'neutral' | 'unknown' — 장중엔 당일 선물, 장전엔 예상 시가 갭."""
    intraday = intraday_signal(signals)
    if intraday is not None:
        return _sign_with_band(intraday['value'], INTRADAY_BAND)

    gap = expected_gap(signals)
    if gap is None:
        return 'unknown'

    return _sign_with_band(gap['value'], GAP_BAND)


def verdict_reason(signals: list[dict]) -> str:
    """판정 근거 한 줄. 근거 지표가 없으면 그 사실을 적는다."""
    intraday = intraday_signal(signals)
    if intraday is not None:
        return f"{INTRADAY_LABEL} 당일 {intraday['value']:+.2f}% (±{INTRADAY_BAND:g}% 이내 보합)"

    gap = expected_gap(signals)
    if gap is None:
        return '야간선물·SOX·EWY 모두 없음'

    return f"예상 시가 갭 {gap['value']:+.2f}% ({gap['basis']})"


def basis(signals: list[dict]) -> str:
    """화면용 근거 — 판정에 실제로 들어간 입력값만."""
    intraday = intraday_signal(signals)
    if intraday is not None:
        return f"장중 — 당일 선물 방향 우선 (±{INTRADAY_BAND:g}% 이내 보합)"

    gap = expected_gap(signals)

    return '야간선물·SOX·EWY 모두 없음' if gap is None else gap['basis']


def verdict_label(signals: list[dict]) -> str:
    """화면 표시용 판정 문구 ('약세 출발' 등)."""
    return VERDICT_TEXT[verdict(signals)]


def headline(signals: list[dict]) -> str:
    """메일·게시판 머리줄 — '예상 시가 갭 −2.42% (약세 출발)' 등."""
    intraday = intraday_signal(signals)
    if intraday is not None:
        return f"코스피200 선물 당일 {intraday['value']:+.2f}% ({verdict_label(signals)})"

    gap = expected_gap(signals)
    if gap is None:
        return VERDICT_TEXT['unknown']

    return f"예상 시가 갭 {gap['value']:+.2f}% ({verdict_label(signals)})"


def log_lines(signals: list[dict]) -> list[str]:
    """런 로그용 판정 근거. 사후에 '왜 이 판정인가'를 이 출력만으로 답할 수 있어야 한다."""
    bull, bear, neutral = signal_counts(signals)
    lines = [f'📊 시장 신호 판정: {verdict_label(signals)} · {verdict_reason(signals)}',
             f'   (참고: 그룹 투표 강세 {bull} · 약세 {bear} · 중립 {neutral} — 판정엔 미사용)',
             f'   집계(그룹): {votes_line(signals)}']
    excluded = excluded_labels(signals)
    for s in signals or []:
        value = s.get('value')
        value_text = '-' if value is None else f'{value:+.2f}'
        asof = f" asof={s['asof']}" if s.get('asof') else ''
        note = ' (집계 제외: 야간선물 우선)' if s.get('label') in excluded else ''
        lines.append(f"   - {s.get('label')}: value={value_text} move={s.get('move')} "
                     f"direction={s.get('direction')}{asof}{note}")

    return lines


def verdict_from_counts(bull: int, bear: int) -> str:
    return 'bull' if bull > bear else ('bear' if bear > bull else 'neutral')


def votes_line(signals: list[dict]) -> str:
    """그룹 투표를 한 줄로. 개별 칩만 보면 '왜 강세 3개인데 카운트는 1이지?' 가
    되므로, 집계 근거를 같이 보여준다."""
    arrow = {1: '▲', -1: '▼', 0: '－'}
    votes = group_votes(signals)
    return ' · '.join(f"{v['name']} {arrow[v['direction']]}" for v in votes)
