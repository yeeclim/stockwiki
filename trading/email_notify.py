"""
이메일 알림 — 자동매매 결과를 수신자 목록에 발송
환경변수:
  EMAIL_SENDER     : 발신 Gmail 주소
  EMAIL_PASSWORD   : Gmail 앱 비밀번호 (2단계 인증 후 발급)
  EMAIL_RECIPIENTS : 관리자 수신자, 쉼표로 구분 (예: a@b.com,c@d.com)
"""
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime
import pytz

_SENDER     = os.environ.get('EMAIL_SENDER', '').strip()
_PASSWORD   = os.environ.get('EMAIL_PASSWORD', '').strip()
_RECIPIENTS = [r.strip() for r in os.environ.get('EMAIL_RECIPIENTS', '').split(',') if r.strip()]

_SMTP_HOST = 'smtp.gmail.com'
_SMTP_PORT = 587


def send_to(text: str, recipients: list[str]) -> bool:
    """지정 수신자에게 이메일 발송 (사용자별 알림용)"""
    if not (_SENDER and _PASSWORD) or not recipients:
        return False
    return _send_mail(text, recipients)


def send(text: str) -> bool:
    """환경변수 EMAIL_RECIPIENTS 전체에게 이메일 발송 (관리자 알림용)"""
    if not (_SENDER and _PASSWORD and _RECIPIENTS):
        print('⚠️  이메일 알림 비활성 (환경변수 미설정)')
        return False
    return _send_mail(text, _RECIPIENTS)


def _send_mail(text: str, recipients: list[str]) -> bool:
    kst = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y-%m-%d %H:%M KST')
    subject = f'StockWiki 자동매매 | {now_str}'

    html = f"""\
<html><body style="font-family:monospace; background:#111; color:#eee; padding:20px;">
<pre style="font-size:14px; line-height:1.6;">{_escape(text)}</pre>
<hr style="border-color:#333; margin-top:24px;">
<p style="font-size:12px; color:#888;">
  <a href="https://stockwiki.vercel.app" style="color:#4a9eff;">StockWiki</a>에서 더 자세한 정보를 확인하세요.
</p>
</body></html>"""

    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From']    = _SENDER
    msg['To']      = ', '.join(recipients)
    msg.attach(MIMEText(text, 'plain', 'utf-8'))
    msg.attach(MIMEText(html, 'html', 'utf-8'))

    try:
        with smtplib.SMTP(_SMTP_HOST, _SMTP_PORT, timeout=15) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.login(_SENDER, _PASSWORD)
            smtp.sendmail(_SENDER, recipients, msg.as_string())
        print(f'📧 이메일 전송 완료 → {", ".join(recipients)}')
        return True
    except Exception as e:
        print(f'⚠️  이메일 전송 실패: {e}')
        return False


def _escape(text: str) -> str:
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
