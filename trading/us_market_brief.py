"""
간밤 미국시장 브리핑 — 주요 지수/섹터 ETF 등락률 + Claude 기반 이슈 요약
국내 스크리닝 메일(screen.py) 상단에 삽입되는 용도.
news_sentiment.py 와 동일한 패턴(Google News RSS + Claude Haiku)을 재사용한다.
"""
import os
import re
import time
import html as html_lib
from datetime import datetime
from urllib.parse import quote
from xml.etree import ElementTree

import pytz
import requests

import us_market_data as umd
import kr_market_data as kmd

_ANTHROPIC_KEY = os.environ.get('ANTHROPIC_API_KEY', '').strip()

_INDICES = [
    ('^GSPC', 'S&P 500'),
    ('^IXIC', '나스닥'),
    ('^DJI',  '다우'),
    ('^VIX',  'VIX'),
]

# 유가·금리·환율·한국물은 지수와 단위가 달라(달러/배럴, %, 원, 달러) 따로 모아
# 별도 그리드로 렌더링한다.
#
# EWY(iShares MSCI South Korea ETF)는 KRX 야간선물의 대용이다. KRX 야간
# 파생상품시장 시세를 주는 무료 API가 없어서, 국내장이 닫힌 동안 글로벌 투자자가
# 한국 주식을 어떻게 사고팔았는지를 보여주는 지표로 EWY를 쓴다. 미국 정규장
# 마감(=05:00 KST 전후)에 확정되므로 06:30 발송 시점엔 1~2시간 된 신선한 값이다.
_MACRO = [
    ('CL=F',  '국제유가(WTI)'),
    ('^TNX',  '미 국채 10년'),
    ('KRW=X', '원/달러'),
    ('EWY',   '한국물 야간(EWY)'),
]

# 미국 시세가 이 시간보다 오래됐으면(장기 휴장 등) 신호로 쓰지 않는다.
# 주말을 낀 월요일 아침엔 금요일 종가라 약 50시간까지 벌어진다.
_STALE_HOURS = 60

_SECTORS = [
    ('SMH', '반도체'),
    ('XLK', '기술'),
    ('XLE', '에너지'),
    ('XLF', '금융'),
    ('XLV', '헬스케어'),
    ('XLY', '임의소비재'),
]

_URL_RE = re.compile(r'https?://\S+')


# ── 데이터 수집 ────────────────────────────────────────────────────────────────

def _fetch_rows(items: list[tuple[str, str]]) -> list[dict]:
    symbols = [s for s, _ in items]
    quotes = umd.get_quotes_batch(symbols)
    rows = []
    for symbol, label in items:
        q = quotes.get(symbol)
        if not q:
            continue
        price = q.get('regularMarketPrice')
        pct = q.get('regularMarketChangePercent')
        if price is None or pct is None:
            continue
        # change(절대 변화량)는 국채금리를 bp로 표시/판정하는 데 쓴다.
        # market_time(마지막 체결 epoch)은 스테일 데이터를 신호에서 빼는 데 쓴다.
        rows.append({'symbol': symbol, 'label': label, 'price': price, 'pct': pct,
                     'change': q.get('regularMarketChange'),
                     'market_time': q.get('regularMarketTime')})
    return rows


def _macro_display(row: dict) -> dict:
    """유가·금리는 '4.98 (+0.63%)'처럼 지수 포맷으로 찍으면 오해를 부른다
    (금리 0.63%는 절대 수준이 아니라 수익률의 변화율이다). 단위를 붙여 돌려준다."""
    out = dict(row)
    if row['symbol'] == '^TNX':
        bp = (row.get('change') or 0.0) * 100
        out['price_text'] = f"{row['price']:.3f}%"
        out['delta_text'] = f"{bp:+.1f}bp"
    elif row['symbol'] == 'KRW=X':
        out['price_text'] = f"{row['price']:,.2f}원"
        out['delta_text'] = f"{row['pct']:+.2f}%"
    else:
        out['price_text'] = f"${row['price']:,.2f}"
        out['delta_text'] = f"{row['pct']:+.2f}%"
    return out


def _is_fresh(row: dict, hours: int = _STALE_HOURS) -> bool:
    """미국 시세의 마지막 체결이 hours 안쪽인가. 시각을 못 받았으면 신선한 것으로 본다
    (신호를 통째로 잃는 것보다 낫다)."""
    ts = row.get('market_time')
    if not ts:
        return True
    age = time.time() - float(ts)
    return 0 <= age <= hours * 3600


def _traded_today_kst(traded_at: str | None) -> bool:
    """네이버 체결 시각(ISO, +09:00)이 오늘(KST)인가.

    장 시작 전에는 전일 종가가 그대로 내려온다. 그 값을 '오늘 신호'로 세면
    아침 메일에서 선물이 늘 의미 없는 한 칸을 차지하므로 걸러낸다."""
    if not traded_at:
        return False
    try:
        ts = datetime.fromisoformat(traded_at)
    except ValueError:
        return False
    kst = pytz.timezone('Asia/Seoul')
    if ts.tzinfo is None:
        ts = kst.localize(ts)
    return ts.astimezone(kst).date() == datetime.now(kst).date()


def _get_market_headlines(limit: int = 6) -> list[str]:
    try:
        encoded = quote('Wall Street stock market')
        url = f'https://news.google.com/rss/search?q={encoded}&hl=en-US&gl=US&ceid=US:en'
        r = requests.get(
            url,
            headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
            timeout=8,
        )
        r.raise_for_status()
        root = ElementTree.fromstring(r.content)
        titles = []
        for item in root.iter('item'):
            title_el = item.find('title')
            if title_el is None or not title_el.text:
                continue
            full_title = title_el.text.strip()
            last_dash = full_title.rfind(' - ')
            title = full_title[:last_dash] if last_dash > 0 else full_title
            if title:
                titles.append(title)
        return titles[:limit]
    except Exception:
        return []


def _summarize_issues(headlines: list[str], index_rows: list[dict], sector_rows: list[dict],
                      macro_rows: list[dict] | None = None) -> str:
    if not _ANTHROPIC_KEY or not headlines:
        return ''
    idx_str = ', '.join(f"{r['label']} {r['pct']:+.2f}%" for r in index_rows) or '데이터 없음'
    sec_str = ', '.join(f"{r['label']} {r['pct']:+.2f}%" for r in sector_rows) or '데이터 없음'
    # 유가·금리는 단위가 달라 표시용 문자열(달러/bp)을 그대로 넘긴다.
    mac_str = ', '.join(
        f"{r['label']} {r.get('price_text', r['price'])} ({r.get('delta_text', '')})"
        for r in (macro_rows or [])) or '데이터 없음'
    prompt = (
        "다음은 간밤 미국 증시 관련 최신 뉴스 헤드라인과 실제 지수/섹터/유가·금리·환율 등락률입니다.\n\n"
        f"지수 등락률: {idx_str}\n섹터 ETF 등락률: {sec_str}\n"
        f"유가·금리·환율: {mac_str}\n\n헤드라인:\n"
        + '\n'.join(f'- {h}' for h in headlines)
        + "\n\n이 정보를 바탕으로 한국 투자자를 위한 '간밤 미국시장 브리핑'을 한국어로 3~5줄로 작성하세요. "
          "지수/섹터/유가·금리·환율 수치는 위에 주어진 값만 언급하고 새로운 수치를 지어내지 마세요. "
          "연준·실적발표·지정학 등 핵심 이슈를 중심으로 간결하게 서술하세요. "
          "설명 없이 브리핑 본문만 순수 텍스트로 응답하세요."
    )
    try:
        resp = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers={
                'x-api-key':         _ANTHROPIC_KEY,
                'anthropic-version': '2023-06-01',
                'content-type':      'application/json',
            },
            json={
                'model':      'claude-haiku-4-5-20251001',
                'max_tokens': 400,
                'messages':   [{'role': 'user', 'content': prompt}],
            },
            timeout=20,
        )
        resp.raise_for_status()
        return resp.json()['content'][0]['text'].strip()
    except Exception:
        return ''


def get_brief(kis_api=None) -> dict:
    """반환: {'indices', 'sectors', 'summary', 'kr_indices', 'kr_open_interest'}
    개별 단계가 실패해도 예외를 전파하지 않고 빈 값으로 안전하게 대체한다.
    kis_api(인증된 KISApi 인스턴스)를 넘기면 코스피200 선물 미결제약정도 함께 조회한다.
    """
    try:
        index_rows = _fetch_rows(_INDICES)
    except Exception as e:
        print(f"⚠️  미국 지수 조회 실패: {e}")
        index_rows = []
    try:
        sector_rows = _fetch_rows(_SECTORS)
    except Exception as e:
        print(f"⚠️  미국 섹터 ETF 조회 실패: {e}")
        sector_rows = []
    try:
        macro_rows = [_macro_display(r) for r in _fetch_rows(_MACRO)]
    except Exception as e:
        print(f"⚠️  유가/금리 조회 실패: {e}")
        macro_rows = []
    headlines = _get_market_headlines()
    summary = _summarize_issues(headlines, index_rows, sector_rows, macro_rows)

    try:
        kr_quotes = kmd.get_quotes()
    except Exception as e:
        print(f"⚠️  국내 지수 조회 실패: {e}")
        kr_quotes = {}
    kr_indices = [kr_quotes[c] for c in ('KOSPI', 'KOSDAQ', 'FUT') if c in kr_quotes]

    kr_open_interest = None
    kr_night_futures = None
    kr_investors: list[dict] = []
    if kis_api is not None:
        try:
            kr_night_futures = kis_api.get_night_futures_quote(kmd.kospi200_futures_code())
        except Exception as e:
            print(f"⚠️  야간선물 조회 실패: {e}")
        try:
            kr_open_interest = kis_api.get_futures_open_interest(kmd.kospi200_futures_code())
        except Exception as e:
            print(f"⚠️  선물 미결제약정 조회 실패: {e}")
        for label, code, mkt in (('코스피', '0001', 'KSP'), ('코스닥', '1001', 'KSQ')):
            try:
                trend = kis_api.get_investor_trend(code, mkt)
                if trend:
                    kr_investors.append({'label': label, **trend})
            except Exception as e:
                print(f"⚠️  {label} 투자자매매동향 조회 실패: {e}")

    brief = {
        'indices': index_rows, 'sectors': sector_rows, 'macro': macro_rows,
        'summary': summary,
        'kr_indices': kr_indices, 'kr_open_interest': kr_open_interest,
        'kr_night_futures': kr_night_futures,
        'kr_investors': kr_investors,
    }
    brief['signals'] = _compute_signals(brief)
    brief['generated_at'] = datetime.now(pytz.timezone('Asia/Seoul')).strftime(
        '%Y.%m.%d (%a) %H:%M KST')
    import blog_card_render
    brief['close_phase'] = blog_card_render.close_phase_now()
    brief['kr_verdict'] = _kr_verdict(brief)
    return brief


def _kr_verdict(brief: dict) -> str:
    """국내 마감 시황 '그래서 결과가 뭔데' 한 줄 해설.
    규칙 기반 문장을 기본으로 하고, ANTHROPIC_API_KEY가 있으면 Haiku로 자연스럽게 다듬는다
    (수치는 새로 지어내지 않도록 제약). 실패하면 규칙 문장 그대로 반환한다."""
    import blog_card_render
    base = blog_card_render.verdict_line(brief)
    if not _ANTHROPIC_KEY or base.startswith('오늘 시장 데이터'):
        return base
    try:
        resp = requests.post(
            'https://api.anthropic.com/v1/messages',
            headers={
                'x-api-key':         _ANTHROPIC_KEY,
                'anthropic-version': '2023-06-01',
                'content-type':      'application/json',
            },
            json={
                'model':      'claude-haiku-4-5-20251001',
                'max_tokens': 200,
                'messages':   [{'role': 'user', 'content': (
                    "아래는 국내 증시 마감 요약(규칙으로 조립한 문장)입니다. 같은 사실만 유지한 채 "
                    "주식을 모르는 사람도 이해할 수 있게 1~2문장으로 자연스럽게 다듬어 주세요. "
                    "새로운 수치·종목·전망을 추가하지 말고, 존댓말로, 설명 없이 문장만 답하세요.\n\n"
                    f"{base}"
                )}],
            },
            timeout=15,
        )
        resp.raise_for_status()
        out = resp.json()['content'][0]['text'].strip()
        return out or base
    except Exception:
        return base


# ── 강세/약세 신호 스코어 ────────────────────────────────────────────────────
# 통계적으로 검증된 확률이 아니라, 이미 수집한 지표들을 단순히 방향(상승/하락)
# 으로 환산해 개수를 세는 규칙 기반 요약이다. "N% 확률" 같은 정밀한 수치로
# 표현하면 실제 검증된 예측 모델처럼 오해될 수 있어 신호 개수로만 보여준다.
def _dir(value: float) -> int:
    if value > 0:
        return 1
    if value < 0:
        return -1
    return 0


def _dir_band(value: float, band: float) -> int:
    """|value| 가 band 이하면 중립(0). 유가·금리처럼 하루 등락이 대부분 잡음인
    지표를 부호만으로 세면 신호 개수가 잡음에 따라 흔들려서 완충구간을 둔다."""
    if value > band:
        return 1
    if value < -band:
        return -1
    return 0


def _signal(label: str, direction: int, move: int | None = None) -> dict:
    """신호 하나. 두 값을 분리해 담는다.

    - move      : 지표 자체가 어느 쪽으로 움직였는가 (화면의 ▲/▼ 표시용)
    - direction : 그 움직임이 시장에 강세(+1)/약세(-1)인가 (강세·약세 개수 집계용)

    대부분은 둘이 같지만 VIX는 반대다(VIX 하락 = 위험선호 = 강세). 예전엔 화살표를
    direction으로 그려서 'VIX -11%'인 날에도 요약에 'VIX ▲'가 찍혀, 본문 시황과
    어긋나 보였다. 그래서 화살표는 move, 강세/약세 판정은 direction으로 분리한다.
    """
    return {'label': label, 'direction': direction,
            'move': direction if move is None else move}


def _compute_signals(brief: dict) -> list[dict]:
    signals = []
    us_by_symbol = {r['symbol']: r for r in (brief.get('indices') or [])}

    us_core_pct = [us_by_symbol[s]['pct'] for s in ('^GSPC', '^IXIC', '^DJI') if s in us_by_symbol]
    if us_core_pct:
        signals.append(_signal('미국 증시', _dir(sum(us_core_pct) / len(us_core_pct))))
    if '^VIX' in us_by_symbol:
        # VIX 상승 = 시장 불안 심화(약세 신호)이므로 부호를 반대로 해석한다.
        vix_move = _dir(us_by_symbol['^VIX']['pct'])
        signals.append(_signal('VIX(변동성)', -vix_move, move=vix_move))

    macro_by_symbol = {r['symbol']: r for r in (brief.get('macro') or [])}
    krw = macro_by_symbol.get('KRW=X')
    ewy = macro_by_symbol.get('EWY')
    # 야간 국내물은 '야간선물 → EWY' 순으로 하나만 센다. 둘 다 같은 것(국내장이
    # 닫힌 동안의 한국 주식 방향)을 재므로 함께 세면 중복 계산이 된다.
    night = brief.get('kr_night_futures')
    if night:
        # 코스피200 야간선물 — 원화 표시라 보정이 필요 없는 직접 관측치다.
        signals.append(_signal('코스피200 야간선물', _dir_band(night['pct'], 0.3)))
    elif ewy and krw and _is_fresh(ewy):
        # 폴백. EWY 는 달러 표시라 원화 기준 코스피 등락률로 환산해야 갭 추정이 된다.
        #   EWY(USD) = 코스피(KRW) / 원달러  ⇒  %코스피 ≈ %EWY + %원달러
        # 이렇게 보정해두면 아래 '원/달러' 신호와 환율 부분이 중복 계산되지 않는다.
        #
        # 월요일 아침엔 금요일 미국장 값이라 주말 재료를 못 담는다. 야간선물도
        # 같은 한계가 있지만 EWY 는 이틀이 밀려서 더 심하다.
        implied = ewy['pct'] + krw['pct']
        signals.append(_signal('야간 한국물(EWY·환율보정)', _dir_band(implied, 0.5)))
    if krw:
        # 원화 약세(환율 상승)는 외국인 자금 유출 압력이라 약세 신호.
        krw_move = _dir_band(krw['pct'], 0.4)
        signals.append(_signal('원/달러', -krw_move, move=krw_move))

    oil = macro_by_symbol.get('CL=F')
    if oil:
        # 한국은 원유 전량 수입국이라 유가 상승은 교역조건 악화·원가 부담(약세 신호)이다.
        # 일간 ±1% 안쪽은 잡음으로 보고 중립 처리.
        oil_move = _dir_band(oil['pct'], 1.0)
        signals.append(_signal('국제유가(WTI)', -oil_move, move=oil_move))
    tnx = macro_by_symbol.get('^TNX')
    if tnx:
        # 금리 상승 = 할인율 상승 + 달러 강세 → 성장주 비중 큰 국내 증시엔 약세 신호.
        # ^TNX 의 change 는 수익률 자체의 변화(%p)라 100을 곱해 bp 로 본다. ±3bp 완충.
        tnx_move = _dir_band((tnx.get('change') or 0.0) * 100, 3.0)
        signals.append(_signal('미 국채 10년', -tnx_move, move=tnx_move))

    kr_by_label = {r['label']: r for r in (brief.get('kr_indices') or [])}
    fut = kr_by_label.get('코스피200 선물')
    # 정규장 선물은 06:30 발송 시점엔 전일 종가라 오버나이트 정보가 없다.
    # 오늘 체결된 값일 때만 신호로 센다 (없으면 위의 EWY 보정치가 그 자리를 맡는다).
    if fut and not _traded_today_kst(fut.get('traded_at')):
        fut = None
    if fut:
        signals.append(_signal('코스피200 선물', _dir(fut['pct'])))

    kr_oi = brief.get('kr_open_interest')
    if fut and kr_oi:
        price_up = fut['pct'] > 0
        oi_up = kr_oi['open_interest_change'] > 0
        # 가격↑+OI↑=신규매수 유입(강세), 가격↓+OI↑=신규매도 유입(약세),
        # OI가 줄었으면(청산 위주) 방향성이 약하므로 중립 처리.
        d = 1 if (price_up and oi_up) else (-1 if (not price_up and oi_up) else 0)
        signals.append(_signal('선물 미결제약정', d, move=_dir(kr_oi['open_interest_change'])))

    for inv in brief.get('kr_investors') or []:
        net = inv['frgn_net'] + inv['orgn_net']
        signals.append(_signal(f"{inv['label']} 수급(외국인+기관)", _dir(net)))

    return signals


# 화살표는 지표의 실제 방향(move), 옆의 글자는 시장 해석(direction).
SIGNAL_ARROW = {1: '▲', -1: '▼', 0: '－'}
SIGNAL_WORD = {1: '강세', -1: '약세', 0: '중립'}


def signal_move(s: dict) -> int:
    """move가 없는 옛 brief_json(아카이브)도 읽을 수 있도록 direction으로 폴백."""
    return int(s.get('move', s.get('direction', 0)) or 0)


def signal_chip_text(s: dict) -> str:
    return f"{s['label']} {SIGNAL_ARROW[signal_move(s)]} {SIGNAL_WORD[s.get('direction', 0)]}"


def _signal_counts(signals: list[dict]) -> tuple[int, int, int]:
    bull = sum(1 for s in signals if s['direction'] > 0)
    bear = sum(1 for s in signals if s['direction'] < 0)
    return bull, bear, len(signals) - bull - bear


def render_text(brief: dict) -> str:
    """브리핑의 텍스트(plain) 버전. HTML을 못 받는 메일 클라이언트를 위한
    multipart/alternative 의 text/plain 파트에도 동일한 내용을 담기 위해 사용한다."""
    indices = brief.get('indices') or []
    sectors = brief.get('sectors') or []
    macro = brief.get('macro') or []
    summary = (brief.get('summary') or '').strip()
    kr_indices = brief.get('kr_indices') or []
    kr_oi = brief.get('kr_open_interest')
    kr_investors = brief.get('kr_investors') or []
    signals = brief.get('signals') or []
    if not (indices or sectors or macro or summary or kr_indices or kr_oi or kr_investors):
        return ''

    lines = []
    if signals:
        bull, bear, neutral = _signal_counts(signals)
        verdict = '강세 우세' if bull > bear else ('약세 우세' if bear > bull else '팽팽')
        lines.append(f"📊 오늘의 시장 신호: 강세 {bull} · 약세 {bear} · 중립 {neutral} ({verdict})")
        lines.append('   ' + '  '.join(f"[{signal_chip_text(s)}]" for s in signals))
        lines.append('   ※ ▲▼는 지표 자체의 방향, 강세/약세는 그 움직임의 시장 해석입니다'
                     ' (예: VIX ▼ = 강세)')
        lines.append('   ※ 통계적 확률이 아닌 단순 신호 조합입니다')
        lines.append('')

    lines.append('🌙 간밤 미국시장 브리핑')
    lines.append('-' * 55)
    if indices:
        lines.append('[주요 지수] ' + '  '.join(
            f"{r['label']} {r['price']:,.2f} ({r['pct']:+.2f}%)" for r in indices))
    if sectors:
        lines.append('[섹터 ETF] ' + '  '.join(
            f"{r['label']} {r['pct']:+.2f}%" for r in sectors))
    if macro:
        lines.append('[유가·금리·환율] ' + '  '.join(
            f"{r['label']} {r.get('price_text', r['price'])} ({r.get('delta_text', '')})"
            for r in macro))
    if summary:
        lines.append('')
        lines.append(summary)
    if kr_indices or kr_oi:
        lines.append('')
        _krt = {'prev': '[전일 국내 증시 마감]', 'intraday': '[국내 증시 (장중)]',
                'today': '[국내 증시 마감]'}.get(brief.get('close_phase', 'prev'), '[전일 국내 증시 마감]')
        lines.append(_krt)
        kr_verdict = (brief.get('kr_verdict') or '').strip()
        if kr_verdict:
            lines.append(f'  💬 {kr_verdict}')
        if kr_indices:
            lines.append('  ' + '  '.join(
                f"{r['label']} {r['price']:,.2f} ({r['pct']:+.2f}%)" for r in kr_indices))
        if kr_oi:
            chg = kr_oi['open_interest_change']
            arrow = '▲' if chg > 0 else ('▼' if chg < 0 else '－')
            lines.append(f"  코스피200 선물 미결제약정 {kr_oi['open_interest']:,}계약"
                          f" (전일대비 {arrow}{abs(chg):,})")
        for inv in kr_investors:
            def _s(v):
                return f"{'+' if v > 0 else ''}{v:,}"
            lines.append(f"  {inv['label']} 외국인 {_s(inv['frgn_net'])}  "
                         f"기관 {_s(inv['orgn_net'])}  개인 {_s(inv['prsn_net'])}")
    lines.append('=' * 55)
    return '\n'.join(lines)


# ── HTML 렌더링 — StockWiki 앱과 동일한 블랙+네온 테마 (lib/theme/app_theme.dart 참고) ──

_BG           = '#050706'
_SURFACE      = '#0B0F0C'
_SURFACE_SOFT = '#0F1C15'
_LINE         = '#182620'
_INK          = '#EEF4EF'
_MUTED        = '#6C7A71'
_ACCENT       = '#39FF8C'   # 네온 그린
_UP           = '#FF4550'   # 상승 = 빨강 (국내 관행)
_DOWN         = '#3B82F6'   # 하락 = 파랑
_AMBER        = '#FFC94D'   # 중립/주의


def _chunk(seq: list, n: int) -> list[list]:
    return [seq[i:i + n] for i in range(0, len(seq), n)]


def _pct_color(pct: float) -> str:
    return _UP if pct >= 0 else _DOWN


def _fmt_index_volume(vol) -> str:
    try:
        v = float(vol)
    except (TypeError, ValueError):
        return ''
    if v <= 0:
        return ''
    if v >= 1e8:
        return f'{v / 1e8:.1f}억주'
    if v >= 1e4:
        return f'{v / 1e4:.0f}만주'
    return f'{v:,.0f}주'


def _chip_grid_html(title: str, rows: list[dict], cols: int) -> str:
    """지수/섹터 등락률을 네온 카드 그리드로 렌더링."""
    if not rows:
        return ''
    cell_w = f'{100 // cols}%'
    body = []
    for chunk in _chunk(rows, cols):
        cells = []
        for r in chunk:
            color = _pct_color(r['pct'])
            # 유가·금리처럼 단위가 붙는 행은 미리 만들어둔 문자열을 쓴다.
            # (f-string 중첩은 CI의 Python 3.11에서 문법 오류라 여기서 풀어둔다)
            price_text = r.get('price_text') or f"{r['price']:,.2f}"
            delta_text = r.get('delta_text') or f"{r['pct']:+.2f}%"
            vol_html = ''
            vol = _fmt_index_volume(r.get('volume'))
            if vol:
                vol_html = (f'<div style="color:{_MUTED};font-size:10px;margin-top:2px;">'
                            f'거래량 {vol}</div>')
            cells.append(
                f'<td width="{cell_w}" style="padding:5px;">'
                f'<div style="background:{_SURFACE_SOFT};border:1px solid {_LINE};'
                f'border-radius:10px;padding:10px 6px;text-align:center;">'
                f'<div style="color:{_MUTED};font-size:11px;letter-spacing:.2px;">{html_lib.escape(r["label"])}</div>'
                f'<div style="color:{_INK};font-size:14px;font-weight:700;margin-top:3px;font-family:Consolas,Menlo,monospace;">{price_text}</div>'
                f'<div style="color:{color};font-size:12px;font-weight:700;margin-top:2px;font-family:Consolas,Menlo,monospace;">{delta_text}</div>'
                f'{vol_html}'
                '</div></td>'
            )
        # 마지막 줄 셀 개수가 모자라면 빈 셀로 채워 정렬 유지
        while len(cells) < cols:
            cells.append(f'<td width="{cell_w}"></td>')
        body.append(f'<tr>{"".join(cells)}</tr>')
    return (
        f'<div style="color:{_MUTED};font-size:11px;font-weight:700;letter-spacing:.5px;'
        f'text-transform:uppercase;margin:14px 0 6px;">{html_lib.escape(title)}</div>'
        f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0">{"".join(body)}</table>'
    )


# ── 스크리닝 리포트 텍스트 하이라이팅 (터미널 스타일 <pre> 안에서 사용할 인라인 span만 삽입) ──

_SECTION_RE    = re.compile(r'^(✅|🔴|❌|⏸).*$', re.MULTILINE)
_SCORE_RE      = re.compile(r'\[(\d+(?:\.\d+)?)/(\d+)점\]')
_STOCK_RE      = re.compile(r'([^\s(]+)\(([\d*]{4,8})\)')
_CHANGE_RE     = re.compile(r'전일([+-]\d+\.\d+)%')
_SENTIMENT_RE  = re.compile(r'(📰 뉴스: )(🟢|🔴|🟡) (긍정|부정|중립)')


def _style_section_header(m: re.Match) -> str:
    line = m.group(0)
    color = {'✅': _ACCENT, '🔴': _UP, '❌': _MUTED, '⏸': _AMBER}.get(line[0], _INK)
    return f'<span style="color:{color};font-weight:700;">{line}</span>'


def _score_badge(m: re.Match) -> str:
    return (f'<span style="color:{_BG};background:{_ACCENT};font-weight:700;'
            f'padding:1px 6px;border-radius:4px;">{m.group(0)}</span>')


def _stock_name_code(m: re.Match) -> str:
    return (f'<b style="color:{_INK};">{m.group(1)}</b>'
            f'<span style="color:{_MUTED};">({m.group(2)})</span>')


def _change_pct(m: re.Match) -> str:
    val = m.group(1)
    color = _UP if val.startswith('+') else _DOWN
    return f'전일<span style="color:{color};font-weight:700;">{val}%</span>'


def _sentiment_word(m: re.Match) -> str:
    prefix, emoji, word = m.group(1), m.group(2), m.group(3)
    color = {'긍정': _ACCENT, '부정': _UP, '중립': _AMBER}.get(word, _INK)
    return f'{prefix}{emoji} <span style="color:{color};font-weight:700;">{word}</span>'


def _linkify(m: re.Match) -> str:
    url = m.group(0)
    return f'<a href="{url}" style="color:{_ACCENT};">{url}</a>'


def _highlight_report(report_text: str) -> str:
    """플레인 텍스트 리포트를 이스케이프 후, 알려진 패턴만 골라 인라인 색상을 입힌다."""
    text = html_lib.escape(report_text)
    text = _SECTION_RE.sub(_style_section_header, text)
    text = _SCORE_RE.sub(_score_badge, text)
    text = _STOCK_RE.sub(_stock_name_code, text)
    text = _CHANGE_RE.sub(_change_pct, text)
    text = _SENTIMENT_RE.sub(_sentiment_word, text)
    text = _URL_RE.sub(_linkify, text)
    return text


_STYLE_BLOCK = f"""
<style>
  @keyframes swkPulse {{ 0%, 100% {{ opacity: 1; }} 50% {{ opacity: .35; }} }}
  @keyframes swkGlow {{
    0%, 100% {{ text-shadow: 0 0 8px rgba(57,255,140,.55), 0 0 18px rgba(57,255,140,.25); }}
    50%      {{ text-shadow: 0 0 14px rgba(57,255,140,.85), 0 0 28px rgba(57,255,140,.4); }}
  }}
  .swk-dot  {{ animation: swkPulse 1.6s ease-in-out infinite; }}
  .swk-logo {{ animation: swkGlow 3s ease-in-out infinite; }}
  a {{ text-decoration: none; }}
  @media (max-width: 480px) {{
    .swk-container {{ width: 100% !important; }}
  }}
</style>
"""


def render_email_html(brief: dict, report_text: str) -> str:
    """브리핑 + 기존 텍스트 리포트를 StockWiki 블랙+네온 테마의 완성된 HTML 문서로 반환한다."""
    kst = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y.%m.%d (%a) %H:%M KST')

    signals = brief.get('signals') or []
    signal_html = ''
    if signals:
        bull, bear, neutral = _signal_counts(signals)
        verdict = '강세 우세' if bull > bear else ('약세 우세' if bear > bull else '팽팽')
        verdict_color = _UP if bull > bear else (_DOWN if bear > bull else _AMBER)
        chip_color = {1: _UP, -1: _DOWN, 0: _MUTED}
        chips = ''.join(
            f'<span style="display:inline-block;margin:3px 6px 3px 0;padding:3px 9px;'
            f'border-radius:999px;background:{_SURFACE_SOFT};border:1px solid {_LINE};'
            f'font-size:11px;color:{_INK};white-space:nowrap;">{html_lib.escape(s["label"])} '
            f'<span style="color:{chip_color[signal_move(s)]};font-weight:700;">'
            f'{SIGNAL_ARROW[signal_move(s)]}</span> '
            f'<span style="color:{chip_color[s.get("direction", 0)]};font-weight:700;">'
            f'{SIGNAL_WORD[s.get("direction", 0)]}</span></span>'
            for s in signals
        )
        signal_html = f"""
<tr><td style="padding-bottom:16px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background:{_SURFACE};border:1px solid {_LINE};border-radius:12px;">
    <tr><td style="padding:16px 20px;">
      <span style="color:{_ACCENT};font-size:16px;font-weight:800;letter-spacing:.3px;">
        📊 오늘의 시장 신호 📍
      </span>
      <div style="margin-top:8px;">
        <span style="color:{_INK};font-weight:800;font-size:20px;">강세 {bull}</span>
        <span style="color:{_MUTED};font-size:15px;"> · </span>
        <span style="color:{_INK};font-weight:800;font-size:20px;">약세 {bear}</span>
        <span style="color:{_MUTED};font-size:15px;"> · </span>
        <span style="color:{_INK};font-weight:800;font-size:20px;">중립 {neutral}</span>
        <span style="color:{verdict_color};font-weight:800;font-size:14px;margin-left:8px;">({verdict})</span>
      </div>
      <div style="margin-top:10px;">{chips}</div>
      <div style="margin-top:8px;color:{_MUTED};font-size:10.5px;">
        ※ ▲▼는 지표 자체의 방향, 옆의 강세/약세는 그 움직임의 시장 해석입니다 (예: VIX ▼ = 위험선호 = 강세).<br>
        ※ 통계적으로 검증된 확률이 아니라, 이미 수집한 지표들을 방향(상승/하락)으로만 환산해 개수를 센 단순 신호 조합입니다.
      </div>
    </td></tr>
  </table>
</td></tr>"""

    indices_html = _chip_grid_html('주요 지수', brief.get('indices') or [], cols=2)
    sectors_html = _chip_grid_html('섹터 ETF', brief.get('sectors') or [], cols=3)
    macro_html = _chip_grid_html('유가 · 금리 · 환율 · 한국물', brief.get('macro') or [], cols=2)
    summary = (brief.get('summary') or '').strip()
    summary_html = ''
    if summary:
        summary_html = (
            f'<div style="margin-top:14px;padding:12px 14px;background:{_SURFACE_SOFT};'
            f'border-left:3px solid {_ACCENT};border-radius:6px;color:{_INK};'
            f'font-size:13px;line-height:1.75;white-space:pre-wrap;">{html_lib.escape(summary)}</div>'
        )

    brief_section = ''
    if indices_html or sectors_html or macro_html or summary_html:
        brief_section = f"""
<tr><td style="padding-bottom:16px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background:{_SURFACE};border:1px solid {_LINE};border-radius:12px;">
    <tr><td style="padding:18px 20px;">
      <span class="swk-dot" style="display:inline-block;width:8px;height:8px;border-radius:50%;
            background:{_ACCENT};box-shadow:0 0 6px {_ACCENT};vertical-align:middle;"></span>
      <span style="color:{_INK};font-weight:700;font-size:14px;vertical-align:middle;margin-left:8px;">
        🌙 간밤 미국시장 브리핑
      </span>
      {indices_html}
      {sectors_html}
      {macro_html}
      {summary_html}
    </td></tr>
  </table>
</td></tr>"""

    kr_indices_html = _chip_grid_html('지수 · 선물', brief.get('kr_indices') or [], cols=3)
    kr_oi = brief.get('kr_open_interest')
    kr_oi_html = ''
    if kr_oi:
        chg = kr_oi['open_interest_change']
        oi_color = _UP if chg > 0 else (_DOWN if chg < 0 else _MUTED)
        arrow = '▲' if chg > 0 else ('▼' if chg < 0 else '－')
        kr_oi_html = (
            f'<div style="margin-top:10px;color:{_MUTED};font-size:12px;">'
            f'코스피200 선물 미결제약정 '
            f'<span style="color:{_INK};font-weight:700;font-family:Consolas,Menlo,monospace;">{kr_oi["open_interest"]:,}</span>계약'
            f'&nbsp; <span style="color:{oi_color};font-weight:700;font-family:Consolas,Menlo,monospace;">{arrow}{abs(chg):,}</span>'
            f'</div>'
        )

    kr_investors = brief.get('kr_investors') or []
    kr_investors_html = ''
    if kr_investors:
        def _inv_cell(v: int) -> str:
            color = _UP if v > 0 else (_DOWN if v < 0 else _MUTED)
            sign = '+' if v > 0 else ''
            return f'<span style="color:{color};font-weight:700;">{sign}{v:,}</span>'

        inv_rows = []
        for inv in kr_investors:
            inv_rows.append(
                '<tr>'
                f'<td style="padding:3px 10px 3px 0;color:{_MUTED};white-space:nowrap;">{html_lib.escape(inv["label"])}</td>'
                f'<td style="padding:3px 10px;white-space:nowrap;">외국인 {_inv_cell(inv["frgn_net"])}</td>'
                f'<td style="padding:3px 10px;white-space:nowrap;">기관 {_inv_cell(inv["orgn_net"])}</td>'
                f'<td style="padding:3px 0;white-space:nowrap;">개인 {_inv_cell(inv["prsn_net"])}</td>'
                '</tr>'
            )
        kr_investors_html = (
            f'<div style="color:{_MUTED};font-size:11px;font-weight:700;letter-spacing:.5px;'
            f'text-transform:uppercase;margin:14px 0 6px;">외국인·기관·개인 순매수(현물)</div>'
            '<table role="presentation" cellpadding="0" cellspacing="0" '
            f'style="font-size:12px;font-family:Consolas,Menlo,monospace;color:{_INK};">'
            + ''.join(inv_rows) + '</table>'
        )

    kr_section_title = {
        'prev': '🇰🇷 전일 국내 증시 마감', 'intraday': '🇰🇷 국내 증시 (장중)',
        'today': '🇰🇷 국내 증시 마감',
    }.get(brief.get('close_phase', 'prev'), '🇰🇷 전일 국내 증시 마감')

    kr_verdict = (brief.get('kr_verdict') or '').strip()
    kr_verdict_html = ''
    if kr_verdict:
        kr_verdict_html = (
            f'<div style="margin-top:12px;padding:12px 14px;background:{_SURFACE_SOFT};'
            f'border-left:3px solid {_ACCENT};border-radius:6px;color:{_INK};'
            f'font-size:13.5px;font-weight:600;line-height:1.7;">💬 {html_lib.escape(kr_verdict)}</div>'
        )

    kr_section = ''
    if kr_indices_html or kr_oi_html or kr_investors_html or kr_verdict_html:
        kr_section = f"""
<tr><td style="padding-bottom:16px;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background:{_SURFACE};border:1px solid {_LINE};border-radius:12px;">
    <tr><td style="padding:18px 20px;">
      <span class="swk-dot" style="display:inline-block;width:8px;height:8px;border-radius:50%;
            background:{_ACCENT};box-shadow:0 0 6px {_ACCENT};vertical-align:middle;"></span>
      <span style="color:{_INK};font-weight:700;font-size:14px;vertical-align:middle;margin-left:8px;">
        {kr_section_title}
      </span>
      {kr_verdict_html}
      {kr_indices_html}
      {kr_oi_html}
      {kr_investors_html}
    </td></tr>
  </table>
</td></tr>"""

    report_html = f"""
<tr><td>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
         style="background:{_SURFACE};border:1px solid {_LINE};border-radius:12px;">
    <tr><td style="background:{_SURFACE_SOFT};border-bottom:1px solid {_LINE};
                   border-radius:12px 12px 0 0;padding:10px 16px;">
      <span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:#FF5F56;margin-right:5px;"></span>
      <span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:#FFBD2E;margin-right:5px;"></span>
      <span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:#27C93F;margin-right:8px;"></span>
      <span style="color:{_MUTED};font-size:11px;font-family:Consolas,Menlo,monospace;">screening_result.log</span>
    </td></tr>
    <tr><td style="padding:16px;">
      <pre style="margin:0;white-space:pre-wrap;word-break:break-word;
                  font-family:Consolas,Menlo,monospace;font-size:12.5px;line-height:1.6;
                  color:{_INK};">{_highlight_report(report_text)}</pre>
    </td></tr>
  </table>
</td></tr>"""

    return f"""<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark">
<meta name="supported-color-schemes" content="dark">
<title>StockWiki</title>
{_STYLE_BLOCK}
</head>
<body style="margin:0;padding:0;background-color:{_BG};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">
  오늘의 종목 스크리닝 결과, 오늘의 시장 신호, 국내 마감 시황, 간밤 미국시장 브리핑
</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:{_BG};">
<tr><td align="center" style="padding:28px 12px;">
<table role="presentation" width="640" class="swk-container" cellpadding="0" cellspacing="0" style="width:640px;max-width:100%;">
  <tr><td style="text-align:center;padding-bottom:22px;">
    <span class="swk-logo" style="font-family:Consolas,Menlo,monospace;font-size:22px;
          font-weight:800;color:{_ACCENT};letter-spacing:3px;">STOCKWIKI</span>
    <div style="color:{_MUTED};font-size:12px;margin-top:6px;font-family:Consolas,Menlo,monospace;">
      {now_str} · 종목 스크리닝
    </div>
  </td></tr>
  {signal_html}
  {kr_section}
  {brief_section}
  {report_html}
  <tr><td style="text-align:center;padding-top:22px;color:{_MUTED};font-size:11px;">
    이 메일은 StockWiki 자동 스크리닝 시스템이 발송했습니다.
  </td></tr>
</table>
</td></tr>
</table>
</body>
</html>"""
