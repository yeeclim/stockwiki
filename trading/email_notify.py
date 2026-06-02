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
    return _send(text, recipients)


def send(text: str) -> bool:
    if not (_SENDER and _PASSWORD):
        print('⚠️  이메일 발송 실패 (EMAIL_SENDER / EMAIL_PASSWORD 미설정)')
        return False
    return _send(text, [_SENDER])


def _send(text: str, recipients: list[str]) -> bool:
    kst     = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y-%m-%d %H:%M KST')

    msg = EmailMessage(policy=email.policy.SMTP)
    msg['Subject'] = f'StockWiki | {now_str}'   # ASCII only
    msg['From']    = f'StockWiki <{_SENDER}>'
    msg['To']      = ', '.join(recipients)
    msg.set_content(text, charset='utf-8')

    try:
        with smtplib.SMTP(_SMTP_HOST, _SMTP_PORT, timeout=15) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.login(_SENDER, _PASSWORD)
            smtp.send_message(msg)
        print(f'📧 이메일 발송 완료 → {", ".join(recipients)}')
        return True
    except Exception as e:
        print(f'⚠️  이메일 발송 실패: {e}')
        return False
