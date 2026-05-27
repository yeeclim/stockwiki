"""
카카오톡 나에게 메시지 보내기
- KAKAO_REST_API_KEY  : 카카오 앱 REST API 키
- KAKAO_REFRESH_TOKEN : 최초 발급받은 리프레시 토큰 (60일 유효)
"""
import os
import json
import requests

_REST_KEY       = os.environ.get('KAKAO_REST_API_KEY', '').strip()
_REFRESH_TOKEN  = os.environ.get('KAKAO_REFRESH_TOKEN', '').strip()
_CLIENT_SECRET  = os.environ.get('KAKAO_CLIENT_SECRET', '').strip()


def _get_access_token() -> str | None:
    """리프레시 토큰 → 액세스 토큰 발급"""
    if not _REST_KEY or not _REFRESH_TOKEN:
        return None
    data = {
        'grant_type':    'refresh_token',
        'client_id':     _REST_KEY,
        'refresh_token': _REFRESH_TOKEN,
    }
    if _CLIENT_SECRET:
        data['client_secret'] = _CLIENT_SECRET
    r = requests.post(
        'https://kauth.kakao.com/oauth/token',
        data=data,
        timeout=10,
    )
    if r.status_code == 200:
        return r.json().get('access_token')
    print(f'⚠️  카카오 토큰 발급 실패: {r.status_code} {r.text}')
    return None


def send(text: str) -> bool:
    """카카오톡 나에게 텍스트 메시지 전송 (최대 1000자)"""
    access_token = _get_access_token()
    if not access_token:
        print('⚠️  카카오 알림 비활성 (토큰 없음)')
        return False

    r = requests.post(
        'https://kapi.kakao.com/v2/api/talk/memo/default/send',
        headers={'Authorization': f'Bearer {access_token}'},
        data={
            'template_object': json.dumps({
                'object_type': 'text',
                'text': text[:1000],
                'link': {
                    'web_url':        'https://stockwiki.vercel.app',
                    'mobile_web_url': 'https://stockwiki.vercel.app',
                },
            }, ensure_ascii=False),
        },
        timeout=10,
    )
    ok = r.status_code == 200
    if ok:
        print('📱 카카오톡 알림 전송 완료')
    else:
        print(f'⚠️  카카오톡 전송 실패: {r.status_code} {r.text}')
    return ok
