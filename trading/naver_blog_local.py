"""
네이버 블로그 로컬 자동 포스팅 — Supabase에 저장된 스크리닝 게시글을 그대로 옮긴다.

★ GitHub Actions(클라우드)가 아니라 "본인 Windows PC"에서만 실행하는 스크립트입니다.
   ID/비밀번호를 저장하지 않고, 이미 로그인해 둔 크롬 프로필의 세션을 그대로 재사용합니다.

────────────────────────────────────────────────────────────────────────────
1회만 하면 되는 사전 준비
────────────────────────────────────────────────────────────────────────────
1. 자동화 전용 크롬 데이터 폴더로 쓸, "크롬 기본 설치 경로가 아닌" 새 폴더를 하나 정한다.
   ⚠️ 평소 쓰는 크롬의 실제 기본 폴더(...\\Google\\Chrome\\User Data)를 그대로 쓰면
   최신 크롬의 보안 정책 때문에 자동화 실행 자체가 차단된다(DevToolsActivePort 에러).
   반드시 아래처럼 완전히 별도인 새 폴더를 지정할 것:
     C:\\Users\\<사용자명>\\AppData\\Local\\StockWikiNaverAutomation\\ChromeProfile
   (폴더가 없어도 됨 — 크롬이 처음 실행될 때 알아서 새로 만든다)
2. 패키지 설치 (trading 폴더에서):
     pip install -r requirements-naver-local.txt
3. 환경변수 설정 후 실행:
     $env:SUPABASE_URL = "https://xpiqctjidvrlmazslzyg.supabase.co"
     $env:SUPABASE_ANON_KEY = "본인 anon key"
     $env:NAVER_CHROME_USER_DATA_DIR = "C:\\Users\\사용자명\\AppData\\Local\\StockWikiNaverAutomation\\ChromeProfile"
     python naver_blog_local.py
4. 처음 실행하면 로그인 안 된 새 프로필이라 네이버 로그인 화면이 뜬다.
   그 크롬 창에서 직접 로그인 → 터미널에서 Enter → 이후로는 계속 로그인 상태 유지.

────────────────────────────────────────────────────────────────────────────
미리보기 (네이버에 올리지 않고 블로그에 실릴 모양만 확인)
────────────────────────────────────────────────────────────────────────────
  python naver_blog_local.py --preview                # 최신 메일 기준, _preview/index.html 생성
  python naver_blog_local.py --preview --sample       # 실데이터 없이 샘플 카드로 디자인만
  python naver_blog_local.py --preview --from-file mail.html   # 특정 메일 HTML을 입력으로
- _preview/index.html : 이미지(요약 카드·차트) + 본문이 합쳐진 전체 미리보기
- _preview/card.html  : 요약 카드 단독 (색상·레이아웃 확인용, selenium 없이도 열림)

────────────────────────────────────────────────────────────────────────────
동작 방식
────────────────────────────────────────────────────────────────────────────
- 이 스크립트를 실행하는 동안에는 해당 크롬 프로필이 다른 창에서 열려 있으면 안 됩니다
  (크롬이 프로필 폴더를 잠그기 때문). 자동화 전용 프로필이므로 평소 사용 중이 아니면 문제 없음.
- 기본값은 "임시저장까지만" 자동으로 하고, 발행 버튼은 직접 눌러 확인하도록 되어 있습니다
  (며칠 지켜보고 안정적이면 publish=True로 바꿔서 완전 자동 발행 전환).
- 네이버 에디터(SmartEditor ONE)는 내부 CSS 클래스명이 빌드마다 바뀔 수 있어, 아래 셀렉터가
  깨질 수 있습니다. 실패하면 오류 메시지와 함께 어느 단계에서 멈췄는지 출력하니, 그 내용을
  가지고 다시 요청하면 셀렉터를 갱신할 수 있습니다.
"""
import os
import sys
import time

_SUPABASE_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_SUPABASE_KEY = (
    os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()
    or os.environ.get('SUPABASE_ANON_KEY', '').strip()
)
_CHROME_USER_DATA_DIR = os.environ.get('NAVER_CHROME_USER_DATA_DIR', '').strip()
_CHROME_PROFILE = os.environ.get('NAVER_CHROME_PROFILE', 'Default').strip()

_DISCLAIMER = (
    '<p>스톡위키가 매일 자동으로 돌리는 스크리닝 결과를 그대로 옮긴 글입니다. '
    '투자 판단의 참고 자료일 뿐 투자 권유나 수익 보장이 아니며, '
    '최종 투자 결정과 그 책임은 본인에게 있습니다.</p>'
)
_OUTRO = '<p>더 많은 정보: <a href="https://stockwiki.vercel.app">https://stockwiki.vercel.app</a></p>'
_HASHTAGS = (
    '<p>#스톡위키 #주식스크리닝 #국내증시 #미국증시 #주식정보 '
    '#투자정보 #코스피 #코스닥 #AI주식추천 #오늘의증시</p>'
)


def fetch_latest_screening_post() -> dict | None:
    """Supabase email_archive에서 실제로 발송된 최신 스크리닝 메일 원본(HTML)을 가져온다.
    (board_posts는 게시판용으로 따로 단순화한 버전이라 메일과 내용이 다르다 — 쓰지 않는다)

    반환: {'title', 'content'(HTML), 'brief'(요약 지표 dict 또는 None)}
    """
    import requests

    if not (_SUPABASE_URL and _SUPABASE_KEY):
        print('❌ SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY(또는 ANON) 환경변수가 필요합니다.')
        return None
    try:
        r = requests.get(
            f'{_SUPABASE_URL}/rest/v1/email_archive',
            headers={
                'apikey':        _SUPABASE_KEY,
                'Authorization': f'Bearer {_SUPABASE_KEY}',
            },
            params={
                'select': '*',
                'order': 'created_at.desc',
                'limit': 1,
            },
            timeout=10,
        )
        r.raise_for_status()
        rows = r.json()
        if not rows:
            return None
        row = rows[0]
        return {
            'title': row['subject'],
            'content': row['html'],
            'brief': row.get('brief_json'),
        }
    except Exception as e:
        print(f'⚠️  메일 원본 조회 실패: {e}')
        return None


def _build_cf_html(html_fragment: str) -> bytes:
    """Windows 클립보드의 'HTML Format'(CF_HTML) 바이트를 만든다.
    바이트 오프셋 규격: https://learn.microsoft.com/globalization/encoding/html-clipboard-format
    """
    fragment_bytes = html_fragment.strip().encode('utf-8')
    header_template = (
        "Version:0.9\r\n"
        "StartHTML:{0:010d}\r\n"
        "EndHTML:{1:010d}\r\n"
        "StartFragment:{2:010d}\r\n"
        "EndFragment:{3:010d}\r\n"
    )
    pre_fragment = "<html><body>\r\n<!--StartFragment-->".encode('utf-8')
    post_fragment = "<!--EndFragment-->\r\n</body></html>".encode('utf-8')

    header_len = len(header_template.format(0, 0, 0, 0).encode('utf-8'))
    start_html = header_len
    start_fragment = start_html + len(pre_fragment)
    end_fragment = start_fragment + len(fragment_bytes)
    end_html = end_fragment + len(post_fragment)

    header = header_template.format(start_html, end_html, start_fragment, end_fragment).encode('utf-8')
    return header + pre_fragment + fragment_bytes + post_fragment


def set_clipboard_html(html: str):
    """클립보드에 서식 있는 HTML을 직접 심는다 (사람이 화면에서 드래그 복사한 것과 동일 효과)."""
    import win32clipboard

    cf_html_format = win32clipboard.RegisterClipboardFormat('HTML Format')
    win32clipboard.OpenClipboard()
    try:
        win32clipboard.EmptyClipboard()
        win32clipboard.SetClipboardData(cf_html_format, _build_cf_html(html))
    finally:
        win32clipboard.CloseClipboard()


def set_clipboard_image(png_path: str) -> bool:
    """PNG 파일을 클립보드에 비트맵(CF_DIB)으로 심는다 — 에디터에 Ctrl+V 하면
    사람이 스크린샷 붙여넣기 한 것과 동일하게 이미지가 업로드된다.
    SmartEditor는 input[type=file]을 DOM에 상시 두지 않아, 이 방식이 가장 안정적이다.
    Pillow가 없으면 False를 반환한다 (이미지 없이 발행 계속)."""
    try:
        import io

        import win32clipboard
        from PIL import Image
    except Exception as e:
        print(f'⚠️  이미지 클립보드 변환 불가 (pip install pillow 필요): {e}')
        return False

    try:
        with Image.open(png_path) as im:
            im = im.convert('RGB')
            buf = io.BytesIO()
            im.save(buf, 'BMP')
        dib = buf.getvalue()[14:]  # BMP 파일 헤더(14바이트)를 떼면 DIB

        win32clipboard.OpenClipboard()
        try:
            win32clipboard.EmptyClipboard()
            win32clipboard.SetClipboardData(win32clipboard.CF_DIB, dib)
        finally:
            win32clipboard.CloseClipboard()
        return True
    except Exception as e:
        print(f'⚠️  이미지 클립보드 심기 실패 ({os.path.basename(png_path)}): {e}')
        return False


def _to_blog_friendly_html(html: str) -> str:
    """네이버 에디터는 붙여넣기 시 style="..." 를 전부 지워버려, 이 메일의 다크 네온 카드
    디자인(배경색·둥근 모서리·글자색)은 애초에 살릴 방법이 없다 (네이버 에디터 자체의 한계).
    이 함수는 블로그 포스팅 전용 가공이며 메일 자체(us_market_brief.py)는 건드리지 않는다.
    대신 구조는 최대한 보기 좋게 남긴다:
      - 메일 전체를 감싸는 <html>/<head>/<body>는 벗겨내고 본문만 취한다
      - 제목(STOCKWIKI)·날짜 줄은 <h2>/<h4>로 바꿔 글자 크기·굵기를 키운다
        (style이 지워져도 브라우저 기본 스타일로 큼직하게 유지됨)
      - 표는 전부 테두리·헤더 배경(border/bgcolor)을 입혀 실제 표 모양으로 보이게 한다
        (지수/섹터 카드 그리드도 포함 — 색 카드 대신 격자 표로)
      - 스크리닝 리포트의 "=====" 구분선은 고정폭 문자라 좁은 포스팅 폭에서 줄이 밀리므로
        포스팅 폭에 맞춰 늘어나는 <hr>로 바꾼다
      - <pre> 안의 개행은 태그가 풀리면 같이 사라지므로 <br>로 미리 바꿔 줄바꿈을 보존한다
      - 상승/하락 화살표(▲▼)는 색은 없어도 글자라 그대로 남는다
    """
    import re

    m = re.search(r'<body[^>]*>(.*)</body>', html, re.DOTALL | re.IGNORECASE)
    if m:
        html = m.group(1)
    # <style>...</style> 블록(애니메이션 등)은 본문에 그대로 보이면 안 되므로 제거
    html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL | re.IGNORECASE)

    # 메일 받은편지함 미리보기용 숨김 텍스트(display:none) 제거 — style이 지워지면서
    # 숨겨져 있던 게 그대로 드러나 버리는데, 애초에 사람이 보라고 만든 문장이 아니다.
    html = re.sub(
        r'<div[^>]*display:\s*none[^>]*>.*?</div>',
        '', html, flags=re.DOTALL | re.IGNORECASE,
    )

    # 제목(STOCKWIKI 로고) + 바로 다음 날짜 줄을 진짜 제목 태그로 승격 — style 없이도 크고 굵게 보임
    html = re.sub(
        r'<span class="swk-logo"[^>]*>(.*?)</span>\s*<div[^>]*>\s*(.*?)\s*</div>',
        r'<h2>\1</h2><h4>\2</h4>',
        html,
        flags=re.DOTALL,
    )

    # 고정폭 "=====" 구분선은 포스팅 폭에서 줄이 안 맞으므로, 폭에 맞춰 늘어나는 가로선으로 교체
    html = re.sub(r'={10,}', '<hr>', html)

    # <pre>의 줄바꿈은 원래 브라우저 기본 white-space:pre로 유지되지만, 네이버 에디터가
    # 붙여넣기 시 <pre>를 풀어헤치면서 줄바꿈이 같이 사라져 한 줄로 붙어버린다.
    # 그 안의 개행을 <br>로 미리 바꿔, 태그가 풀려도 줄바꿈만은 남게 한다.
    def _pre_repl(m):
        return f'<pre>{m.group(1).replace(chr(10), "<br>")}</pre>'

    html = re.sub(r'<pre[^>]*>(.*?)</pre>', _pre_repl, html, flags=re.DOTALL)

    def _table_repl(m):
        # 지수/섹터 카드 그리드(role="presentation")도 포함해 전부 테두리 있는 표로 통일 —
        # 카드 배경색이 사라지는 대신 격자 표로라도 구조가 보이게 한다
        return '<table border="1" cellpadding="8" cellspacing="0" width="100%">'

    html = re.sub(r'<table[^>]*>', _table_repl, html)

    # font-weight:700/800 인 <span>은 색상과 함께 style이 통째로 지워지기 전에
    # <b> 태그로 바꿔서 "굵은 글씨"만이라도 살린다 (중첩 <span>이 있는 복잡한 요소는 건드리지 않음)
    html = re.sub(
        r'<span[^>]*style="[^"]*font-weight:\s*(?:700|800)[^"]*"[^>]*>((?:(?!</?span)[\s\S])*?)</span>',
        r'<b>\1</b>',
        html,
    )

    html = re.sub(r"\s*style='[^']*'", '', html)
    html = re.sub(r'\s*style="[^"]*"', '', html)
    html = re.sub(r'<th(?=[ >])([^>]*)>', r'<th\1 bgcolor="#f0f0f0">', html)
    return html


def screening_blog_content(email_html: str) -> str:
    return _to_blog_friendly_html(email_html) + _DISCLAIMER + _OUTRO + _HASHTAGS


def _launch_driver():
    from selenium import webdriver

    options = webdriver.ChromeOptions()
    if _CHROME_USER_DATA_DIR:
        options.add_argument(f'--user-data-dir={_CHROME_USER_DATA_DIR}')
        options.add_argument(f'--profile-directory={_CHROME_PROFILE}')
    else:
        print('⚠️  NAVER_CHROME_USER_DATA_DIR 미설정 — 로그인 안 된 새 프로필로 열립니다.')
    options.add_argument('--start-maximized')
    return webdriver.Chrome(options=options)


def _find_in_any_frame(driver, by, selector, timeout=10):
    """최상위 문서 + 모든 iframe(중첩 포함, 1단계)을 순서대로 뒤져서 보이는 요소를 찾는다.
    네이버 에디터는 팝업/버튼이 어느 프레임에 있는지 예측하기 어려워, 위치를 가정하지 않고
    직접 찾아다니는 방식으로 안정성을 높인다."""
    end = time.time() + timeout
    while time.time() < end:
        driver.switch_to.default_content()
        try:
            el = driver.find_element(by, selector)
            if el.is_displayed():
                return el
        except Exception:
            pass
        for frame in driver.find_elements('tag name', 'iframe'):
            try:
                driver.switch_to.default_content()
                driver.switch_to.frame(frame)
                el = driver.find_element(by, selector)
                if el.is_displayed():
                    return el
            except Exception:
                continue
        time.sleep(0.3)
    driver.switch_to.default_content()
    return None


def _focus_body(driver):
    """본문 편집영역에 포커스를 준다. 다른 요소가 클릭을 가로채면 JS 클릭으로 우회한다.
    포커스한 요소를 반환(없으면 None)."""
    from selenium.webdriver.common.by import By

    els = (driver.find_elements(By.CSS_SELECTOR, '.se-section-text .se-text-paragraph')
           or driver.find_elements(By.CSS_SELECTOR, '.se-section-text')
           or driver.find_elements(By.CSS_SELECTOR, '.se-content'))
    if not els:
        return None
    el = els[0]
    try:
        el.click()
    except Exception:
        try:
            driver.execute_script('arguments[0].scrollIntoView({block:"center"});'
                                  'arguments[0].click(); arguments[0].focus();', el)
        except Exception:
            return None
    return el


def _paste_images(driver, image_paths: list[str]) -> int:
    """이미지를 클립보드(비트맵)로 하나씩 심어 본문에 Ctrl+V로 붙여넣는다.

    ※ SmartEditor ONE은 input[type=file]을 DOM에 상시 두지 않고 '사진' 버튼이 OS 파일
       대화상자를 띄우는 구조라(무인 실행에서 멈춤), 사람이 스크린샷 붙여넣듯 하는 이 방식이
       가장 안정적이다. 절대 예외를 던지지 않고 붙여넣은 장수를 반환한다."""
    from selenium.webdriver.common.action_chains import ActionChains
    from selenium.webdriver.common.keys import Keys

    existing = [p for p in image_paths if p and os.path.exists(p)]
    if not existing:
        return 0

    done = 0
    for path in existing:
        try:
            if not set_clipboard_image(path):
                continue
            if _focus_body(driver) is None:
                print('⚠️  본문 편집영역을 찾지 못해 이미지 붙여넣기를 건너뜁니다.')
                break
            ActionChains(driver).key_down(Keys.CONTROL).send_keys('v').key_up(Keys.CONTROL).perform()
            time.sleep(5.0)  # 네이버 이미지 서버 업로드 완료 대기
            done += 1
            print(f'🖼️  이미지 붙여넣기 {done}/{len(existing)} — {os.path.basename(path)}')
        except Exception as e:
            print(f'⚠️  이미지 붙여넣기 실패 ({os.path.basename(path)}): {e}')
    return done


def post_to_naver_blog(title: str, html_content: str, publish: bool = True,
                       image_paths: list[str] | None = None) -> bool:
    """네이버 블로그 글쓰기 화면에 제목+본문을 채워 넣는다.
    publish=True(기본)면 발행 버튼까지 자동으로 누른다.
    publish=False로 부르면 임시저장 상태로 두고 사람이 화면에서 직접 확인 후 발행하도록 멈춘다
    (터미널이 있는 상태로 수동 테스트할 때만 사용 — 무인 실행에서는 의미 없음).
    image_paths를 주면 본문 맨 위에 그 이미지들을 먼저 삽입한다 (요약 카드/차트 스냅샷).
    """
    from selenium.webdriver.common.by import By
    from selenium.webdriver.common.action_chains import ActionChains
    from selenium.webdriver.common.keys import Keys
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC

    driver = _launch_driver()
    try:
        driver.get('https://blog.naver.com/GoBlogWrite.naver')
        time.sleep(2)
        if 'nidlogin' in driver.current_url or 'login' in driver.current_url.lower():
            if sys.stdin.isatty():
                print('🔐 로그인이 안 되어 있습니다. 방금 뜬 크롬 창에서 네이버에 직접 로그인해주세요.')
                print('   (이 자동화 전용 프로필에 처음 한 번만 로그인하면, 이후엔 계속 로그인 상태가 유지됩니다)')
                input('로그인 완료 후 Enter를 누르면 계속 진행합니다... ')
                driver.get('https://blog.naver.com/GoBlogWrite.naver')
            else:
                # 작업 스케줄러 등 무인 실행 중엔 기다려줄 사람이 없으므로 곧바로 포기한다
                print('⚠️  네이버 로그인 세션이 끊겼습니다. 무인 실행이라 대기하지 않고 중단합니다 — '
                      '터미널에서 한 번 python naver_blog_local.py를 직접 실행해 재로그인해주세요.')
                return False

        wait = WebDriverWait(driver, 20)
        wait.until(EC.frame_to_be_available_and_switch_to_it((By.ID, 'mainFrame')))

        # "작성 중인 글이 있습니다" 팝업 — 뜨는 데 약간 시간이 걸리므로 짧게 기다렸다가 "취소"(새 글로 시작)를 누른다
        try:
            cancel_btn = WebDriverWait(driver, 4).until(
                EC.element_to_be_clickable((By.CSS_SELECTOR, '.se-popup-button-cancel'))
            )
            cancel_btn.click()
            time.sleep(0.5)
        except Exception:
            pass

        for selector in ['.se-help-panel-close-button']:
            try:
                driver.find_element(By.CSS_SELECTOR, selector).click()
                time.sleep(0.3)
            except Exception:
                pass

        title_el = wait.until(
            EC.element_to_be_clickable((By.CSS_SELECTOR, '.se-section-documentTitle'))
        )
        title_el.click()
        ActionChains(driver).send_keys(title).perform()
        print('✏️  제목 입력 완료')

        # 본문 편집영역 포커스 (에디터가 비어 있는 지금이 오버레이 간섭 없이 가장 안전)
        _focus_body(driver)
        time.sleep(0.3)

        # 1) 이미지 먼저 — 비어 있는 본문 맨 위에 [요약 카드][차트] 순서로 들어간다.
        #    이미지 단계에서 무슨 일이 있어도 발행까지는 반드시 진행되도록 방어한다.
        if image_paths:
            try:
                _paste_images(driver, image_paths)
            except Exception as e:
                print(f'⚠️  이미지 삽입 건너뜀(발행은 계속): {e}')

        # 2) HTML 본문 붙여넣기 — 이미지 뒤에 이어 붙는다
        set_clipboard_html(html_content)
        _focus_body(driver)
        time.sleep(0.3)
        ActionChains(driver).key_down(Keys.CONTROL).send_keys(Keys.END).key_up(Keys.CONTROL).perform()
        ActionChains(driver).key_down(Keys.CONTROL).send_keys('v').key_up(Keys.CONTROL).perform()
        time.sleep(1.5)
        print('📋 본문 붙여넣기 완료 (표 서식이 살아있는지 화면에서 확인하세요)')

        if publish:
            # 1단계: 상단 "발행" 버튼(#mainFrame 안, data-click-area로 식별) → 공개설정 팝업이 뜬다
            driver.find_element(By.CSS_SELECTOR, 'button[data-click-area="tpb.publish"]').click()
            time.sleep(1)
            # 2단계: 팝업 안의 최종 "발행" 확인 버튼 — data-testid는 CSS 해시 클래스보다 안정적이다.
            # 프레임 위치도 가정하지 않고 찾는다 (직전에 겪은 취소/임시저장 버튼 오클릭 방지)
            confirm_btn = _find_in_any_frame(
                driver, By.CSS_SELECTOR, 'button[data-testid="seOnePublishBtn"]', timeout=10
            )
            if not confirm_btn:
                raise Exception('발행 확인 버튼(seOnePublishBtn)을 어느 프레임에서도 찾지 못했습니다')
            confirm_btn.click()
            time.sleep(2)
            print('📝 네이버 블로그 발행 완료')
        elif sys.stdin.isatty():
            print('💾 자동 발행은 꺼져 있습니다 — 브라우저 창에서 표/내용을 확인한 뒤 직접 발행 버튼을 눌러주세요.')
            input('확인 후 Enter를 누르면 이 창을 닫습니다 (발행 전이면 먼저 발행부터) ... ')
        return True
    except Exception as e:
        print(f'⚠️  네이버 블로그 포스팅 실패: {e}')
        print('   → 어느 단계에서 멈췄는지(제목 입력 전/후, 본문 클릭 전/후 등) 알려주시면 셀렉터를 다시 맞춰드릴 수 있습니다.')
        return False
    finally:
        if publish or not sys.stdin.isatty():
            driver.quit()


def _prepare_images(brief: dict | None, work_dir: str) -> list[dict]:
    """요약 카드 PNG + 네이버 지수 차트 PNG를 만들어 [{'label','path'}, ...] 로 반환.
    개별 실패는 건너뛴다 (이미지 없이도 글은 발행)."""
    os.makedirs(work_dir, exist_ok=True)
    images: list[dict] = []

    if brief:
        try:
            import blog_card_render
            card = blog_card_render.make_market_card(brief, os.path.join(work_dir, 'card.png'))
            if card:
                images.append({'label': '오늘의 국내 증시 요약', 'path': card})
        except Exception as e:
            print(f'⚠️  요약 카드 생성 건너뜀: {e}')

    try:
        import naver_finance_chart
        images.extend(naver_finance_chart.download_index_charts(work_dir))
    except Exception as e:
        print(f'⚠️  지수 차트 이미지 건너뜀: {e}')

    return images


def _write_preview(work_dir: str, title: str, body_html: str,
                   images: list[dict], brief: dict | None):
    """네이버에 올리지 않고, 블로그에 실릴 모양을 로컬 HTML로 확인할 수 있게 저장한다."""
    os.makedirs(work_dir, exist_ok=True)

    if brief:
        try:
            import blog_card_render
            with open(os.path.join(work_dir, 'card.html'), 'w', encoding='utf-8') as fh:
                fh.write(blog_card_render.build_card_html(brief))
        except Exception as e:
            print(f'ℹ️  card.html 생략: {e}')

    img_tags = '\n'.join(
        f'<figure><img src="{os.path.basename(i["path"])}" alt="{i["label"]}">'
        f'<figcaption>{i["label"]}</figcaption></figure>'
        for i in images if os.path.exists(i['path'])
    )
    placeholder = ''
    if not img_tags:
        placeholder = (
            '<div class="note">※ 이미지(요약 카드·차트)는 selenium/Chrome/requests가 있는 '
            '환경(회사 노트북)에서 생성됩니다. 여기서는 아래 card.html 을 직접 열어 디자인만 확인하세요.</div>'
        )

    doc = f"""<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8">
<title>블로그 미리보기 — {title}</title>
<style>
  body {{ background:#e9ecef; margin:0; padding:32px 12px;
         font-family:'Malgun Gothic','Apple SD Gothic Neo',sans-serif; }}
  .post {{ max-width:760px; margin:0 auto; background:#fff; border-radius:12px;
          padding:36px 40px; box-shadow:0 4px 24px rgba(0,0,0,.12); }}
  h1 {{ font-size:24px; margin:0 0 24px; }}
  figure {{ margin:0 0 20px; }}
  figure img {{ width:100%; border-radius:10px; display:block; }}
  figcaption {{ color:#868e96; font-size:13px; margin-top:6px; text-align:center; }}
  .note {{ background:#fff3bf; border:1px solid #ffe066; border-radius:8px;
          padding:12px 14px; font-size:13px; color:#664d03; margin-bottom:20px; }}
  .body {{ line-height:1.8; word-break:break-word; }}
  .body table {{ border-collapse:collapse; }}
</style></head><body>
<div class="post">
  <h1>{title}</h1>
  {placeholder}
  {img_tags}
  <div class="body">{body_html}</div>
</div>
</body></html>"""
    out = os.path.join(work_dir, 'index.html')
    with open(out, 'w', encoding='utf-8') as fh:
        fh.write(doc)
    print(f'\n✅ 미리보기 생성: {out}')
    print('   → 브라우저로 열어 확인하세요 (card.html 은 요약 카드 단독 미리보기).')


def main(argv: list[str]) -> int:
    preview = '--preview' in argv
    sample = '--sample' in argv
    from_file = None
    if '--from-file' in argv:
        from_file = argv[argv.index('--from-file') + 1]

    here = os.path.dirname(os.path.abspath(__file__))

    # ── 입력(제목/본문 HTML/brief) 확보 ──
    if sample:
        import blog_card_render
        brief = blog_card_render.SAMPLE_BRIEF
        title = '[샘플] 오늘의 국내 증시 스크리닝'
    else:
        post = fetch_latest_screening_post()
        if not post:
            raise SystemExit('가져올 게시글이 없습니다.')
        title, brief = post['title'], post.get('brief')

    if from_file:
        with open(from_file, encoding='utf-8') as fh:
            email_html = fh.read()
    elif sample:
        email_html = '<body><h2>STOCKWIKI</h2><p>샘플 본문 — 실제 메일 HTML을 --from-file 로 주면 그대로 변환됩니다.</p></body>'
    else:
        email_html = post['content']

    body_html = screening_blog_content(email_html)

    # ── 미리보기 모드: 네이버 접속·발행 없이 로컬 HTML만 ──
    if preview:
        work_dir = os.path.join(here, '_preview')
        images = _prepare_images(brief, work_dir)
        _write_preview(work_dir, title, body_html, images, brief)
        return 0

    # ── 실제 발행 ──
    import shutil
    import tempfile
    work_dir = tempfile.mkdtemp(prefix='swk_blog_')
    try:
        images = _prepare_images(brief, work_dir)
        ok = post_to_naver_blog(
            title, body_html, publish=True,
            image_paths=[i['path'] for i in images],
        )
        return 0 if ok else 1
    finally:
        shutil.rmtree(work_dir, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
