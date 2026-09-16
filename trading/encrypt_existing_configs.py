"""
trading_configs 의 기존 평문 행을 암호화하는 1회성 마이그레이션.

암호화 도입 이전에 저장된 행은 KIS App Key/Secret·계좌번호·카카오 토큰이 평문이다.
Edge Function 은 새로 저장할 때만 암호화하므로, 기존 행은 이 스크립트로 한 번
올려줘야 한다. 이미 암호화된 값(enc:v1: 접두사)은 건너뛰므로 여러 번 돌려도 안전하다.

실행 (로컬):
    export SUPABASE_URL=...                  # 또는 $env:SUPABASE_URL (PowerShell)
    export SUPABASE_SERVICE_ROLE_KEY=...
    export TRADING_ENC_KEY=...               # Edge Function 과 동일한 base64 32바이트
    python trading/encrypt_existing_configs.py --dry-run   # 먼저 확인
    python trading/encrypt_existing_configs.py

새 키를 만들려면:
    python -c "import os,base64;print(base64.b64encode(os.urandom(32)).decode())"
그 값을 두 곳에 같은 값으로 등록한다.
    supabase secrets set TRADING_ENC_KEY=<값> --project-ref <ref>
    gh secret set TRADING_ENC_KEY --body "<값>"
"""
import os
import sys

import requests

import config_crypto

_URL = os.environ.get('SUPABASE_URL', '').rstrip('/')
_KEY = os.environ.get('SUPABASE_SERVICE_ROLE_KEY', '').strip()


def _headers(extra: dict | None = None) -> dict:
    return {
        'apikey':        _KEY,
        'Authorization': f'Bearer {_KEY}',
        'Content-Type':  'application/json',
        **(extra or {}),
    }


def main() -> int:
    dry_run = '--dry-run' in sys.argv

    if not (_URL and _KEY):
        print('❌ SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY 를 설정하세요')
        return 1
    try:
        config_crypto.encrypt('probe')          # 키 형식을 먼저 검증한다
    except Exception as e:
        print(f'❌ {e}')
        return 1

    r = requests.get(
        f'{_URL}/rest/v1/trading_configs?select=user_id,'
        + ','.join(config_crypto.SENSITIVE_FIELDS),
        headers=_headers(), timeout=15,
    )
    r.raise_for_status()
    rows = r.json()
    print(f'대상 행 {len(rows)}개\n')

    changed = 0
    for row in rows:
        uid = row.get('user_id')
        patch = {}
        for field in config_crypto.SENSITIVE_FIELDS:
            value = row.get(field)
            if not value or config_crypto.is_encrypted(value):
                continue
            patch[field] = config_crypto.encrypt(value)

        if not patch:
            print(f'  · {uid}  이미 암호화됨 — 건너뜀')
            continue

        # 평문 값 자체는 절대 출력하지 않는다. 어떤 필드가 바뀌는지만 남긴다.
        print(f'  ✱ {uid}  암호화: {", ".join(sorted(patch))}')
        changed += 1
        if dry_run:
            continue

        u = requests.patch(
            f'{_URL}/rest/v1/trading_configs?user_id=eq.{uid}',
            headers=_headers(), json=patch, timeout=15,
        )
        if not u.ok:
            print(f'    ❌ 실패: {u.status_code} {u.text[:150]}')
            return 1

    print()
    if dry_run:
        print(f'[DRY RUN] {changed}개 행이 암호화 대상입니다. --dry-run 없이 다시 실행하세요.')
    else:
        print(f'✅ {changed}개 행 암호화 완료')
        print('   복호화 확인: TRADING_ENC_KEY 를 그대로 둔 채 trading/main.py 를 DRY_RUN 으로 실행해보세요.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
