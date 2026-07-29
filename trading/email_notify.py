"""
이메일 알림 — Gmail SMTP (EmailMessage API)
환경변수:
  EMAIL_SENDER   : 발신 Gmail (예: stockwiki.kr@gmail.com)
  EMAIL_PASSWORD : Gmail 앱 비밀번호 (16자리, 공백 무관)
"""
import os
import smtplib
from email.message import EmailMessage
import email.policy
from datetime import datetime
import pytz

# 공백·비표준 스페이스(\xa0) 모두 제거 — Gmail 앱 비밀번호 16자리만 사용
_SENDER   = os.environ.get('EMAIL_SENDER', '').strip()
_PASSWORD = (os.environ.get('EMAIL_PASSWORD', '')
             .replace('\xa0', '').replace(' ', '').strip())

_SMTP_HOST = 'smtp.gmail.com'
_SMTP_PORT = 587


def send_to(text: str, recipients: list[str]) -> bool:
    if not (_SENDER and _PASSWORD):
        print('⚠️  이메일 발송 실패 (EMAIL_SENDER / EMAIL_PASSWORD 미설정)')
        return False
    if not recipients:
        return False
    return _send(_build_message(recipients, plain_text=text), recipients)


def send(text: str) -> bool:
    if not (_SENDER and _PASSWORD):
        print('⚠️  이메일 발송 실패 (EMAIL_SENDER / EMAIL_PASSWORD 미설정)')
        return False
    return _send(_build_message([_SENDER], plain_text=text), [_SENDER])


def send_html_to(html: str, plain_text: str, recipients: list[str]) -> bool:
    """HTML 본문(+ 텍스트 폴백)을 multipart/alternative 로 발송."""
    if not (_SENDER and _PASSWORD):
        print('⚠️  이메일 발송 실패 (EMAIL_SENDER / EMAIL_PASSWORD 미설정)')
        return False
    if not recipients:
        return False
    return _send(_build_message(recipients, plain_text=plain_text, html=html), recipients)


def _build_message(recipients: list[str], plain_text: str, html: str | None = None) -> EmailMessage:
    kst     = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y-%m-%d %H:%M KST')

    msg = EmailMessage(policy=email.policy.SMTP)
    msg['Subject'] = f'StockWiki | {now_str}'   # ASCII only
    msg['From']    = f'StockWiki <{_SENDER}>'
    # If sending to multiple recipients, hide them using Bcc
    if len(recipients) == 1:
        msg['To'] = recipients[0]
    else:
        msg['To'] = f'Undisclosed recipients <{_SENDER}>'
        msg['Bcc'] = ', '.join(recipients)
    msg.set_content(plain_text, charset='utf-8')
    if html:
        msg.add_alternative(html, subtype='html', charset='utf-8')
    return msg


def _send(msg: EmailMessage, recipients: list[str]) -> bool:
    try:
        with smtplib.SMTP(_SMTP_HOST, _SMTP_PORT, timeout=15) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.login(_SENDER, _PASSWORD)
            smtp.send_message(msg)
        # Avoid printing the full recipient list for privacy
        if len(recipients) == 1:
            print(f'📧 이메일 발송 완료 → {recipients[0]}')
        else:
            print(f'📧 이메일 발송 완료 → {len(recipients)} recipients (hidden)')
        return True
    except Exception as e:
        print(f'⚠️  이메일 발송 실패: {e}')
        return False
