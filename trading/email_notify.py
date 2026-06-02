"""
이메일 알림 — Gmail SMTP
환경변수:
  EMAIL_SENDER   : 발신 Gmail 주소 (예: stockwiki.kr@gmail.com)
  EMAIL_PASSWORD : Gmail 앱 비밀번호 (16자리)
"""
import os
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime
import pytz

_SENDER   = os.environ.get('EMAIL_SENDER', '').strip()
_PASSWORD = os.environ.get('EMAIL_PASSWORD', '').strip()
_SMTP_HOST = 'smtp.gmail.com'
_SMTP_PORT = 587


def send_to(text: str, recipients: list[str]) -> bool:
    """지정 수신자에게 이메일 발송"""
    if not (_SENDER and _PASSWORD):
        print('⚠️  이메일 발송 실패 (EMAIL_SENDER / EMAIL_PASSWORD 미설정)')
        return False
    if not recipients:
        return False
    return _send(text, recipients)


def send(text: str) -> bool:
    """관리자용"""
    if not (_SENDER and _PASSWORD):
        print('⚠️  이메일 발송 실패 (EMAIL_SENDER / EMAIL_PASSWORD 미설정)')
        return False
    return _send(text, [_SENDER])


def _send(text: str, recipients: list[str]) -> bool:
    kst = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y-%m-%d %H:%M KST')
    subject = f'StockWiki 알림 | {now_str}'

    html = f"""\
<html><body style="font-family:monospace;background:#111;color:#eee;padding:20px;">
<pre style="font-size:14px;line-height:1.7;">{_escape(text)}</pre>
<hr style="border-color:#333;margin-top:24px;">
<p style="font-size:12px;color:#888;">
  <a href="https://stockwiki.vercel.app" style="color:#4a9eff;">StockWiki</a>
</p>
</body></html>"""

    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From']    = f'StockWiki <{_SENDER}>'
    msg['To']      = ', '.join(recipients)
    msg.attach(MIMEText(text, 'plain', 'utf-8'))
    msg.attach(MIMEText(html, 'html', 'utf-8'))

    try:
        with smtplib.SMTP(_SMTP_HOST, _SMTP_PORT, timeout=15) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.login(_SENDER, _PASSWORD)
            smtp.sendmail(_SENDER, recipients, msg.as_string())
        print(f'📧 이메일 발송 완료 → {", ".join(recipients)}')
        return True
    except Exception as e:
        print(f'⚠️  이메일 발송 실패: {e}')
        return False


def _escape(text: str) -> str:
    return text.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
