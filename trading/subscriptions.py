"""
스크리닝 메일·카카오 알림 수신 동의 조회 (정보통신망법 제50조).

동의 기록은 email_subscriptions 테이블에 있다 (마이그레이션 20260917000002).
  - 메일 수신 동의(email_opt_in)가 있어야 보낸다
  - 21시~08시(KST) 발송이면 야간 수신 동의(night_opt_in)도 있어야 한다
  - 동의(또는 재확인) 후 2년이 지나면 보내지 않는다 (앱에서 재확인 요청)

조회에 실패하면 예외를 낸다. "동의 여부를 모르면 보내지 않는다" 가 원칙이다.
"""
import os
from datetime import datetime, timedelta, timezone

import requests

_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()
_KST = timezone(timedelta(hours=9))
CONSENT_VALID_DAYS = 730
UNSUBSCRIBE_BASE = 'https://stockwiki.vercel.app/api/utils?type=unsubscribe&token='


def _headers() -> dict:
    return {'apikey': _KEY, 'Authorization': f'Bearer {_KEY}'}


def is_night_kst(now: datetime | None = None) -> bool:
    """정보통신망법상 야간 전송 시간대(21:00~08:00 KST)인가."""
    hour = (now or datetime.now(_KST)).astimezone(_KST).hour
    return hour >= 21 or hour < 8


def consented_rows(night: bool, now: datetime | None = None) -> dict[str, str]:
    """{user_id: unsubscribe_token} — 지금 보내도 되는 사용자만."""
    now = now or datetime.now(timezone.utc)
    cutoff = (now - timedelta(days=CONSENT_VALID_DAYS)).astimezone(timezone.utc)
    query = (
        f"{_URL}/rest/v1/email_subscriptions?select=user_id,unsubscribe_token"
        f"&email_opt_in=eq.true&consented_at=gte.{cutoff.strftime('%Y-%m-%dT%H:%M:%SZ')}"
    )
    if night:
        query += "&night_opt_in=eq.true"
    r = requests.get(query, headers=_headers(), timeout=10)
    r.raise_for_status()
    return {row['user_id']: row['unsubscribe_token'] for row in r.json()}


def _user_emails() -> dict[str, str]:
    """{user_id: email} — GoTrue admin API 는 페이지 단위라 끝까지 읽는다."""
    per_page = 1000
    out: dict[str, str] = {}
    for page in range(1, 101):
        r = requests.get(
            f"{_URL}/auth/v1/admin/users?page={page}&per_page={per_page}",
            headers=_headers(), timeout=10,
        )
        r.raise_for_status()
        users = r.json().get('users', [])
        out.update({u['id']: u['email'] for u in users if u.get('email')})
        if len(users) < per_page:
            break
    return out


def email_recipients(night: bool) -> list[tuple[str, str]]:
    """[(이메일, 수신거부 URL)] — 동의한 사용자만."""
    if not (_URL and _KEY):
        return []
    consents = consented_rows(night)
    if not consents:
        return []
    emails = _user_emails()
    seen: set[str] = set()
    out = []
    for user_id, token in consents.items():
        email = emails.get(user_id)
        if email and email.lower() not in seen:
            seen.add(email.lower())
            out.append((email, UNSUBSCRIBE_BASE + token))
    return out
