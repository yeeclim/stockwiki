"""
블로그용 "오늘의 국내 증시 요약 카드" 이미지 생성.

네이버 블로그 에디터(SmartEditor ONE)는 붙여넣기 시 style(=색상·배경·둥근 모서리)을
전부 지워버린다. 그래서 "+빨강/-파랑" 색과 "확 눈에 들어오는" 시각적 강조는
이미지 안에 넣어야만 살아남는다. 이 모듈이 그 역할을 한다.

- build_card_html(brief) : 순수 함수. selenium 없이도 import 되며, 카드 HTML 문자열만 만든다.
- render_html_to_png()   : 헤드리스 Chrome으로 #card 요소만 스크린샷 (selenium은 이 함수 안에서만 import).
- make_market_card()     : 위 둘을 묶어 PNG 파일 하나를 만든다.

단독 실행:  python blog_card_render.py           → SAMPLE_BRIEF로 _preview/card.(html|png) 생성
"""
import html as html_lib
import os
import time

# ── StockWiki 블랙+네온 테마 (us_market_brief.py 와 동일값, 색상 관행: 상승=빨강 / 하락=파랑) ──
_BG           = '#050706'
_SURFACE      = '#0B0F0C'
_SURFACE_SOFT = '#0F1C15'
_LINE         = '#182620'
_INK          = '#EEF4EF'
_MUTED        = '#8A9990'
_ACCENT       = '#39FF8C'
_UP           = '#FF4550'   # 상승 = 빨강 (국내 관행)
_DOWN         = '#3B82F6'   # 하락 = 파랑
_AMBER        = '#FFC94D'

_CARD_WIDTH = 720


def _pct_color(pct: float) -> str:
    return _UP if pct >= 0 else _DOWN


def _arrow(pct: float) -> str:
    return '▲' if pct > 0 else ('▼' if pct < 0 else '－')


def _fmt_volume(vol) -> str:
    """지수 거래량(주식 수)을 사람이 읽기 좋은 단위로."""
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


def _signal_counts(signals: list[dict]) -> tuple[int, int, int]:
    bull = sum(1 for s in signals if s.get('direction', 0) > 0)
    bear = sum(1 for s in signals if s.get('direction', 0) < 0)
    return bull, bear, len(signals) - bull - bear


def verdict_line(brief: dict) -> str:
    """'그래서 오늘 결과가 뭔데' 한 줄 해설 — 규칙 기반 조립.

    screen.py(=ANTHROPIC_API_KEY 보유 환경)에서 미리 다듬어 brief['kr_verdict']에
    넣어두면 그 값을 그대로 쓰고, 없으면 여기서 규칙 문장을 만든다.
    """
    pre = (brief.get('kr_verdict') or '').strip()
    if pre:
        return pre

    kr = {r['label']: r for r in (brief.get('kr_indices') or [])}
    kospi, kosdaq = kr.get('코스피'), kr.get('코스닥')
    parts: list[str] = []

    def _word(p: float) -> str:
        if p >= 1.0:
            return '강세'
        if p > 0.2:
            return '상승'
        if p >= -0.2:
            return '보합'
        if p > -1.0:
            return '약세'
        return '급락' if p <= -2.0 else '하락'

    if kospi and kosdaq:
        kp, kq = kospi['pct'], kosdaq['pct']
        nums = f'코스피 {kp:+.2f}%·코스닥 {kq:+.2f}%'
        if (kp > 0) == (kq > 0) and min(abs(kp), abs(kq)) > 0.2:
            parts.append(f'{nums} ' + ('동반 상승' if kp > 0 else '동반 하락') + ' 마감')
        elif kp > 0 >= kq:
            parts.append(f'{nums} — 대형주 강세·중소형주 약세로 엇갈림')
        elif kq > 0 >= kp:
            parts.append(f'{nums} — 중소형주 강세·대형주 약세로 엇갈림')
        else:
            parts.append(f'{nums} 혼조 마감')
    elif kospi:
        parts.append(f'코스피 {kospi["pct"]:+.2f}% {_word(kospi["pct"])} 마감')
    elif kosdaq:
        parts.append(f'코스닥 {kosdaq["pct"]:+.2f}% {_word(kosdaq["pct"])} 마감')

    kospi_inv = next(
        (i for i in (brief.get('kr_investors') or []) if i.get('label') == '코스피'), None
    )
    if kospi_inv:
        f, o = kospi_inv.get('frgn_net', 0), kospi_inv.get('orgn_net', 0)
        if f > 0 and o > 0:
            parts.append('외국인·기관 동반 순매수')
        elif f < 0 and o < 0:
            parts.append('외국인·기관 순매도')
        elif f > 0:
            parts.append('외국인 순매수')
        elif o > 0:
            parts.append('기관 순매수')

    signals = brief.get('signals') or []
    if signals:
        bull, bear, _ = _signal_counts(signals)
        if bull > bear:
            parts.append(f'오늘 강세 신호 우세({bull}:{bear})')
        elif bear > bull:
            parts.append(f'오늘 약세 신호 우세({bear}:{bull})')
        else:
            parts.append('오늘 신호 팽팽')

    if not parts:
        return ''
    return ', '.join(parts) + '.'


def _quote_cell(row: dict) -> str:
    color = _pct_color(row['pct'])
    vol = _fmt_volume(row.get('volume'))
    vol_html = (
        f'<div style="color:{_MUTED};font-size:12px;margin-top:6px;">거래량 {vol}</div>'
        if vol else
        '<div style="font-size:12px;margin-top:6px;">&nbsp;</div>'
    )
    return (
        f'<td width="33%" style="padding:6px;vertical-align:top;">'
        f'<div style="background:{_SURFACE_SOFT};border:1px solid {_LINE};border-radius:14px;'
        f'padding:16px 12px;text-align:center;">'
        f'<div style="color:{_MUTED};font-size:13px;letter-spacing:.3px;">{html_lib.escape(row["label"])}</div>'
        f'<div style="color:{_INK};font-size:24px;font-weight:800;margin-top:6px;'
        f'font-family:Consolas,Menlo,monospace;">{row["price"]:,.2f}</div>'
        f'<div style="color:{color};font-size:16px;font-weight:800;margin-top:4px;'
        f'font-family:Consolas,Menlo,monospace;">{_arrow(row["pct"])} {row["pct"]:+.2f}%</div>'
        f'{vol_html}'
        f'</div></td>'
    )


def build_card_html(brief: dict) -> str:
    """카드 HTML 문서. #card 요소만 스크린샷하면 된다."""
    now_str = (brief.get('generated_at') or '').strip()

    kr_rows = list(brief.get('kr_indices') or [])
    # 정확히 3칸(코스피/코스닥/선물)으로 맞춘다
    order = {'코스피': 0, '코스닥': 1, '코스피200 선물': 2}
    kr_rows.sort(key=lambda r: order.get(r['label'], 9))
    cells = ''.join(_quote_cell(r) for r in kr_rows[:3])
    while cells.count('<td') < 3:
        cells += '<td width="33%"></td>'
    quote_grid = (
        f'<table role="presentation" width="100%" cellpadding="0" cellspacing="0" '
        f'style="margin-top:4px;"><tr>{cells}</tr></table>'
        if kr_rows else ''
    )

    signals = brief.get('signals') or []
    signal_block = ''
    if signals:
        bull, bear, neutral = _signal_counts(signals)
        if bull > bear:
            verdict, vcolor = '강세 우세', _UP
        elif bear > bull:
            verdict, vcolor = '약세 우세', _DOWN
        else:
            verdict, vcolor = '팽팽', _AMBER
        signal_block = (
            f'<div style="margin-top:18px;padding:16px 18px;background:{_SURFACE_SOFT};'
            f'border:1px solid {_LINE};border-radius:14px;">'
            f'<span style="color:{_ACCENT};font-size:15px;font-weight:800;letter-spacing:.3px;">'
            f'📊 오늘의 시장 신호 📍</span>'
            f'<div style="margin-top:8px;">'
            f'<span style="color:{_INK};font-size:22px;font-weight:800;">강세 {bull}</span>'
            f'<span style="color:{_MUTED};font-size:16px;"> · </span>'
            f'<span style="color:{_INK};font-size:22px;font-weight:800;">약세 {bear}</span>'
            f'<span style="color:{_MUTED};font-size:16px;"> · </span>'
            f'<span style="color:{_INK};font-size:22px;font-weight:800;">중립 {neutral}</span>'
            f'<span style="display:inline-block;margin-left:10px;padding:3px 12px;border-radius:999px;'
            f'background:{vcolor};color:{_BG};font-size:13px;font-weight:800;vertical-align:middle;">'
            f'{verdict}</span>'
            f'</div></div>'
        )

    verdict_txt = verdict_line(brief)
    verdict_block = ''
    if verdict_txt:
        verdict_block = (
            f'<div style="margin-top:14px;padding:16px 18px;background:{_SURFACE};'
            f'border-left:4px solid {_ACCENT};border-radius:8px;color:{_INK};'
            f'font-size:16px;font-weight:600;line-height:1.7;">💬 {html_lib.escape(verdict_txt)}</div>'
        )

    return f"""<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8"><style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{ background:{_BG}; padding:0; }}
  #card {{
    width:{_CARD_WIDTH}px; background:{_BG};
    border:1px solid {_LINE}; border-radius:22px; padding:28px 30px;
    font-family:'Malgun Gothic','Apple SD Gothic Neo','Noto Sans KR',sans-serif;
  }}
</style></head><body>
<div id="card">
  <table role="presentation" width="100%"><tr>
    <td style="color:{_ACCENT};font-family:Consolas,Menlo,monospace;font-size:16px;
               font-weight:800;letter-spacing:2px;">STOCKWIKI</td>
    <td style="text-align:right;color:{_MUTED};font-size:13px;
               font-family:Consolas,Menlo,monospace;">{html_lib.escape(now_str)}</td>
  </tr></table>
  <div style="color:{_INK};font-size:22px;font-weight:800;margin-top:14px;">
    📊 오늘의 국내 증시, 한눈에
  </div>
  {quote_grid}
  {signal_block}
  {verdict_block}
</div>
</body></html>"""


def render_html_to_png(doc_html: str, out_path: str, elem_id: str = 'card',
                       scale: int = 2, label: str = '이미지') -> bool:
    """헤드리스 Chrome으로 #<elem_id> 요소만 PNG로 저장. selenium은 여기서만 필요."""
    import tempfile

    from selenium import webdriver
    from selenium.webdriver.common.by import By

    tmp_path = None
    driver = None
    try:
        with tempfile.NamedTemporaryFile('w', suffix='.html', delete=False, encoding='utf-8') as fh:
            fh.write(doc_html)
            tmp_path = fh.name

        opts = webdriver.ChromeOptions()
        opts.add_argument('--headless=new')
        opts.add_argument('--hide-scrollbars')
        opts.add_argument('--disable-gpu')
        opts.add_argument(f'--force-device-scale-factor={scale}')
        opts.add_argument(f'--window-size={_CARD_WIDTH + 80},3200')
        driver = webdriver.Chrome(options=opts)
        driver.get('file:///' + tmp_path.replace('\\', '/'))
        time.sleep(0.4)  # 이미지(data URI) 디코딩 여유
        el = driver.find_element(By.ID, elem_id)
        ok = el.screenshot(out_path)
        if ok:
            print(f'🖼️  {label} 생성: {out_path}')
        return bool(ok)
    except Exception as e:
        print(f'⚠️  {label} 생성 실패: {e}')
        return False
    finally:
        if driver is not None:
            driver.quit()
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except OSError:
                pass


def make_market_card(brief: dict, out_path: str) -> str | None:
    """brief로 요약 카드 PNG를 만들고 경로를 반환. 실패 시 None."""
    if not brief or not (brief.get('kr_indices') or brief.get('signals')):
        print('ℹ️  요약 카드용 데이터(brief)가 없어 카드 생성을 건너뜁니다.')
        return None
    html_doc = build_card_html(brief)
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    return out_path if render_html_to_png(html_doc, out_path, label='요약 카드') else None


# ── 지수 흐름 패널 (네이버 차트 이미지 + 제목·등락·관전포인트를 우리 디자인으로 감싼다) ──

def _img_data_uri(path: str) -> str:
    import base64
    with open(path, 'rb') as fh:
        b64 = base64.b64encode(fh.read()).decode('ascii')
    return f'data:image/png;base64,{b64}'


def _chart_flow_hint(pct) -> str:
    try:
        p = float(pct)
    except (TypeError, ValueError):
        return ''
    if p >= 1.0:
        return '강세 마감'
    if p > 0.2:
        return '소폭 상승'
    if p >= -0.2:
        return '보합'
    if p > -1.0:
        return '소폭 하락'
    return '약세 마감'


def build_chart_panel_html(chart_items: list[dict], brief: dict) -> str:
    """chart_items = [{'label','path','code'}]. 각 지수의 종가/등락률(brief)과 함께
    네이버 차트 이미지를 우리 카드 디자인 안에 넣는다."""
    by_label = {r['label']: r for r in (brief.get('kr_indices') or [])}
    code_to_label = {'KOSPI': '코스피', 'KOSDAQ': '코스닥'}

    blocks = []
    for it in chart_items:
        if not os.path.exists(it['path']):
            continue
        name = code_to_label.get(it.get('code', ''), it['label'].replace(' 일간 차트', ''))
        row = by_label.get(name)
        head = f'<span style="color:{_INK};font-size:16px;font-weight:800;">{html_lib.escape(name)}</span>'
        if row:
            color = _pct_color(row['pct'])
            vol = _fmt_volume(row.get('volume'))
            head += (
                f'<span style="color:{_INK};font-size:15px;font-weight:800;margin-left:10px;'
                f'font-family:Consolas,Menlo,monospace;">{row["price"]:,.2f}</span>'
                f'<span style="color:{color};font-size:14px;font-weight:800;margin-left:8px;'
                f'font-family:Consolas,Menlo,monospace;">{_arrow(row["pct"])} {row["pct"]:+.2f}%</span>'
            )
            sub = _chart_flow_hint(row['pct'])
            if vol:
                sub = f'거래량 {vol} · {sub}' if sub else f'거래량 {vol}'
        else:
            sub = ''
        sub_html = (f'<div style="color:{_MUTED};font-size:12px;margin-top:6px;">{html_lib.escape(sub)}</div>'
                    if sub else '')
        blocks.append(
            f'<div style="margin-top:16px;">'
            f'<div style="margin-bottom:8px;">{head}</div>'
            f'<img src="{_img_data_uri(it["path"])}" alt="{html_lib.escape(name)} 차트" '
            f'style="display:block;width:100%;border:1px solid {_LINE};border-radius:10px;background:#fff;">'
            f'{sub_html}</div>'
        )

    if not blocks:
        return ''

    now_str = (brief.get('generated_at') or '').strip()
    return f"""<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8"><style>
  * {{ margin:0; padding:0; box-sizing:border-box; }}
  body {{ background:{_BG}; }}
  #panel {{
    width:{_CARD_WIDTH}px; background:{_BG};
    border:1px solid {_LINE}; border-radius:22px; padding:26px 28px;
    font-family:'Malgun Gothic','Apple SD Gothic Neo','Noto Sans KR',sans-serif;
  }}
</style></head><body>
<div id="panel">
  <table role="presentation" width="100%"><tr>
    <td style="color:{_ACCENT};font-family:Consolas,Menlo,monospace;font-size:16px;
               font-weight:800;letter-spacing:2px;">STOCKWIKI</td>
    <td style="text-align:right;color:{_MUTED};font-size:13px;
               font-family:Consolas,Menlo,monospace;">{html_lib.escape(now_str)}</td>
  </tr></table>
  <div style="color:{_INK};font-size:21px;font-weight:800;margin-top:14px;">📈 지수 흐름</div>
  {''.join(blocks)}
</div>
</body></html>"""


def make_chart_panel(chart_items: list[dict], brief: dict, out_path: str) -> str | None:
    doc = build_chart_panel_html(chart_items, brief or {})
    if not doc:
        return None
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    return out_path if render_html_to_png(doc, out_path, elem_id='panel', label='지수 흐름 패널') else None


# ── 단독 실행용 샘플 ──────────────────────────────────────────────────────────

SAMPLE_BRIEF = {
    'generated_at': '2026.09.04 (목) 15:40 KST',
    'kr_indices': [
        {'label': '코스피', 'price': 3201.55, 'pct': 0.82, 'volume': 520_000_000},
        {'label': '코스닥', 'price': 1045.22, 'pct': -0.31, 'volume': 810_000_000},
        {'label': '코스피200 선물', 'price': 438.90, 'pct': 0.75, 'volume': 0},
    ],
    'kr_investors': [
        {'label': '코스피', 'frgn_net': 3421, 'orgn_net': 1180, 'prsn_net': -4600},
        {'label': '코스닥', 'frgn_net': -210, 'orgn_net': -540, 'prsn_net': 760},
    ],
    'kr_open_interest': {'open_interest': 412_305, 'open_interest_change': 3120},
    'signals': [
        {'label': '미국 증시', 'direction': 1},
        {'label': 'VIX(변동성)', 'direction': 1},
        {'label': '코스피200 선물', 'direction': 1},
        {'label': '선물 미결제약정', 'direction': 1},
        {'label': '코스피 수급(외국인+기관)', 'direction': 1},
        {'label': '코스닥 수급(외국인+기관)', 'direction': -1},
        {'label': '지수 방향', 'direction': 0},
    ],
}


if __name__ == '__main__':
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.join(here, '_preview')
    os.makedirs(out_dir, exist_ok=True)

    doc = build_card_html(SAMPLE_BRIEF)
    html_path = os.path.join(out_dir, 'card.html')
    with open(html_path, 'w', encoding='utf-8') as fh:
        fh.write(doc)
    print(f'📝 카드 HTML: {html_path}')
    print(f'💬 해설 문구: {verdict_line(SAMPLE_BRIEF)}')

    try:
        render_html_to_png(doc, os.path.join(out_dir, 'card.png'))
    except Exception as e:  # selenium 미설치 등 — HTML만 확인
        print(f'ℹ️  PNG 렌더는 건너뜀 (selenium/Chrome 필요): {e}')
