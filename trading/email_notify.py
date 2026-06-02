"""
이메일 알림 — Resend API 사용
환경변수:
  RESEND_API_KEY : Resend에서 발급받은 API 키
"""
import os
import requests

_API_KEY   = os.environ.get('RESEND_API_KEY', '').strip()
_FROM      = 'StockWiki <noreply@stockwiki.vercel.app>'
_RESEND_URL = 'https://api.resend.com/emails'


def send_to(text: str, recipients: list[str]) -> bool:
    """지정 수신자에게 이메일 발송 (사용자별 알림용)"""
    if not _API_KEY or not recipients:
        print('⚠️  이메일 발송 실패 (RESEND_API_KEY 미설정)')
        return False
    return _send(text, recipients)


def send(text: str) -> bool:
    """관리자 알림용 — 현재는 send_to와 동일"""
    if not _API_KEY:
        print('⚠️  이메일 발송 실패 (RESEND_API_KEY 미설정)')
        return False
    return _send(text, [])


def _send(text: str, recipients: list[str]) -> bool:
    if not recipients:
        return False

    kst_str = _now_kst()
    subject = f'StockWiki 알림 | {kst_str}'

    html = f"""\
<html><body style="font-family:monospace;background:#111;color:#eee;padding:20px;">
<pre style="font-size:14px;line-height:1.7;">{_escape(text)}</pre>
<hr style="border-color:#333;margin-top:24px;">
<p style="font-size:12px;color:#888;">
  <a href="https://stockwiki.vercel.app" style="color:#4a9eff;">StockWiki</a>
</p>
</body></html>"""

    try:
        r = requests.post(
            _RESEND_URL,
            headers={
                'Authorization': f'Bearer {_API_KEY}',
                'Content-Type':  'application/json',
            },
            json={
                'from':    _FROM,
                'to':      recipients,
                'subject': subject,
                'text':    text,
                'html':    html,
            },
            timeout=15,
        )
        if r.ok:
            print(f'📧 이메일 발송 완료 → {", ".join(recipients)}')
            return True
        else:
            print(f'⚠️  이메일 발송 실패: {r.status_code} {r.text}')
            return False
    except Exception as e:
        print(f'⚠️  이메일 발송 오류: {e}')
        return False


def _now_kst() -> str:
    from datetime import datetime
    import pytz
    return datetime.now(pytz.timezone('Asia/Seoul')).strftime('%Y-%m-%d %H:%M KST')


def _escape(text: str) -> str:
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
