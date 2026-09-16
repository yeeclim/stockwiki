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
"""

# 그룹 정의 — (키, 표시명, 라벨 매칭 함수)
# 순서가 곧 표시 순서다.
_GROUP_DEFS = [
    ('us_risk', '미국 위험선호',
     lambda l: l in ('미국 증시', 'VIX(변동성)', '미 국채 10년')),
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
    # 코스피 수급과 코스닥 수급은 같은 날 같은 주체의 매매라 방향이 거의 붙어 다닌다.
    ('kr_flow', '국내 수급',
     lambda l: '수급' in l),
]

VERDICT_TEXT = {'bull': '강세 우세', 'bear': '약세 우세', 'neutral': '팽팽'}


def group_of(label: str) -> tuple[str, str]:
    """라벨 → (그룹키, 표시명). 어디에도 안 걸리면 그 신호만의 단독 그룹으로 만든다
    (새 지표를 추가했을 때 조용히 집계에서 빠지는 일이 없도록)."""
    label = (label or '').strip()
    for key, name, match in _GROUP_DEFS:
        if match(label):
            return key, name
    return f'etc:{label}', label


def group_votes(signals: list[dict]) -> list[dict]:
    """신호 목록 → 그룹당 1표. [{'key','name','direction','members':[라벨...]}]

    그룹 표 = sign(그룹 내 direction 합). 합이 0이면 중립(서로 상쇄).
    """
    order: list[str] = []
    buckets: dict[str, dict] = {}
    for s in signals or []:
        key, name = group_of(s.get('label', ''))
        if key not in buckets:
            buckets[key] = {'key': key, 'name': name, 'net': 0, 'members': []}
            order.append(key)
        b = buckets[key]
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


def verdict(signals: list[dict]) -> str:
    """'bull' | 'bear' | 'neutral'"""
    bull, bear, _ = signal_counts(signals)
    return 'bull' if bull > bear else ('bear' if bear > bull else 'neutral')


def verdict_from_counts(bull: int, bear: int) -> str:
    return 'bull' if bull > bear else ('bear' if bear > bull else 'neutral')


def votes_line(signals: list[dict]) -> str:
    """그룹 투표를 한 줄로. 개별 칩만 보면 '왜 강세 3개인데 카운트는 1이지?' 가
    되므로, 집계 근거를 같이 보여준다."""
    arrow = {1: '▲', -1: '▼', 0: '－'}
    votes = group_votes(signals)
    return ' · '.join(f"{v['name']} {arrow[v['direction']]}" for v in votes)
