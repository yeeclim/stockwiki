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


def send_newsletter(html: str, plain_text: str,
                    recipients: list[tuple[str, str]]) -> tuple[int, int]:
    """동의한 수신자에게 1인 1통으로 발송한다. 반환: (성공 수, 시도 수).

    수신거부 링크가 사람마다 달라서 Bcc 일괄 발송을 쓸 수 없다. 각 메일에는
      - 제목 앞 "(광고)" 표기
      - 본문 하단 전송자 명칭·연락처·수신거부 방법
      - List-Unsubscribe / List-Unsubscribe-Post 헤더 (메일 앱의 원클릭 구독 취소)
    를 넣는다 (정보통신망법 제50조 광고성 정보 전송 기준을 보수적으로 적용).
    SMTP 연결은 한 번만 연다.
    """
    if not (_SENDER and _PASSWORD):
        print('⚠️  이메일 발송 실패 (EMAIL_SENDER / EMAIL_PASSWORD 미설정)')
        return 0, len(recipients)
    if not recipients:
        return 0, 0

    kst = pytz.timezone('Asia/Seoul')
    subject = f"(광고) StockWiki 스크리닝 | {datetime.now(kst).strftime('%Y-%m-%d %H:%M KST')}"
    sent = 0
    try:
        with smtplib.SMTP(_SMTP_HOST, _SMTP_PORT, timeout=15) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.login(_SENDER, _PASSWORD)
            for addr, unsubscribe_url in recipients:
                msg = EmailMessage(policy=email.policy.SMTP)
                msg['Subject'] = subject
                msg['From'] = f'StockWiki <{_SENDER}>'
                msg['To'] = addr
                msg['List-Unsubscribe'] = f'<{unsubscribe_url}>'
                msg['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'
                msg.set_content(plain_text + _footer_text(unsubscribe_url), charset='utf-8')
                msg.add_alternative(_with_footer_html(html, unsubscribe_url),
                                    subtype='html', charset='utf-8')
                try:
                    smtp.send_message(msg)
                    sent += 1
                except smtplib.SMTPException as e:
                    print(f'⚠️  개별 발송 실패: {e}')
    except Exception as e:
        print(f'⚠️  이메일 발송 실패: {e}')
    print(f'📧 뉴스레터 발송 {sent}/{len(recipients)}명')
    return sent, len(recipients)


def _footer_text(unsubscribe_url: str) -> str:
    return (
        "\n\n────────\n"
        "본 메일은 StockWiki 스크리닝 메일 수신에 동의하신 분께 발송됩니다.\n"
        f"전송자: StockWiki ({_SENDER})\n"
        f"수신거부: {unsubscribe_url}\n"
        "(앱 마이페이지에서도 수신 설정을 바꿀 수 있습니다)\n"
    )


def _with_footer_html(html: str, unsubscribe_url: str) -> str:
    from html import escape
    footer = (
        '<hr style="border:none;border-top:1px solid #ddd;margin:24px 0 12px">'
        '<p style="font-size:12px;color:#888;line-height:1.6">'
        '본 메일은 StockWiki 스크리닝 메일 수신에 동의하신 분께 발송됩니다.<br>'
        f'전송자: StockWiki ({escape(_SENDER)})<br>'
        f'<a href="{escape(unsubscribe_url)}" style="color:#888">수신거부</a>'
        ' · 앱 마이페이지에서도 수신 설정을 바꿀 수 있습니다.</p>'
    )
    lower = html.lower()
    idx = lower.rfind('</body>')
    return html[:idx] + footer + html[idx:] if idx >= 0 else html + footer


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
