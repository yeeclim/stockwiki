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
import requests

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


def fetch_latest_screening_post() -> dict | None:
    """Supabase email_archive에서 실제로 발송된 최신 스크리닝 메일 원본(HTML)을 가져온다.
    (board_posts는 게시판용으로 따로 단순화한 버전이라 메일과 내용이 다르다 — 쓰지 않는다)"""
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
        return {'title': row['subject'], 'content': row['html']}
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
      - 상승/하락 화살표(▲▼)는 색은 없어도 글자라 그대로 남는다
    """
    import re

    m = re.search(r'<body[^>]*>(.*)</body>', html, re.DOTALL | re.IGNORECASE)
    if m:
        html = m.group(1)
    # <style>...</style> 블록(애니메이션 등)은 본문에 그대로 보이면 안 되므로 제거
    html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL | re.IGNORECASE)

    # 제목(STOCKWIKI 로고) + 바로 다음 날짜 줄을 진짜 제목 태그로 승격 — style 없이도 크고 굵게 보임
    html = re.sub(
        r'<span class="swk-logo"[^>]*>(.*?)</span>\s*<div[^>]*>\s*(.*?)\s*</div>',
        r'<h2>\1</h2><h4>\2</h4>',
        html,
        flags=re.DOTALL,
    )

    # 고정폭 "=====" 구분선은 포스팅 폭에서 줄이 안 맞으므로, 폭에 맞춰 늘어나는 가로선으로 교체
    html = re.sub(r'={10,}', '<hr>', html)

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
    return _DISCLAIMER + _to_blog_friendly_html(email_html) + _OUTRO


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


def post_to_naver_blog(title: str, html_content: str, publish: bool = True) -> bool:
    """네이버 블로그 글쓰기 화면에 제목+본문을 채워 넣는다.
    publish=True(기본)면 발행 버튼까지 자동으로 누른다.
    publish=False로 부르면 임시저장 상태로 두고 사람이 화면에서 직접 확인 후 발행하도록 멈춘다
    (터미널이 있는 상태로 수동 테스트할 때만 사용 — 무인 실행에서는 의미 없음).
    """
    from selenium.webdriver.common.by import By
    from selenium.webdriver.common.action_chains import ActionChains
    from selenium.webdriver.common.keys import Keys
    from selenium.webdriver.support.ui import WebDriverWait
    from selenium.webdriver.support import expected_conditions as EC

    set_clipboard_html(html_content)

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

        body_el = driver.find_element(By.CSS_SELECTOR, '.se-section-text')
        body_el.click()
        time.sleep(0.3)
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


if __name__ == '__main__':
    post = fetch_latest_screening_post()
    if not post:
        raise SystemExit('가져올 게시글이 없습니다.')
    content = screening_blog_content(post['content'])
    ok = post_to_naver_blog(post['title'], content, publish=True)
    sys.exit(0 if ok else 1)
