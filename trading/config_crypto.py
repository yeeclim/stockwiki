"""
trading_configs 민감 필드 복호화 (AES-256-GCM).

Edge Function(supabase/functions/_shared/crypto.ts)이 암호화한 값을 여기서 푼다.
형식과 키는 반드시 양쪽이 같아야 한다:

    enc:v1:<base64(iv 12B)>:<base64(ciphertext||tag)>
    TRADING_ENC_KEY = base64 로 인코딩한 32바이트

WebCrypto 의 AES-GCM 출력은 태그 16바이트가 뒤에 붙어 있고, cryptography 의
AESGCM.decrypt 도 같은 배치를 기대하므로 추가 가공 없이 맞물린다.

접두사가 없는 값은 아직 암호화 전 평문으로 보고 그대로 돌려준다. 그래야
기존 행을 마이그레이션하는 동안 매매가 멈추지 않는다.
"""
import base64
import os

_PREFIX = 'enc:v1:'

# 암호화해서 저장하는 필드 — DB 조회 결과에 이 키들이 있으면 풀어준다.
SENSITIVE_FIELDS = (
    'kis_app_key',
    'kis_app_secret',
    'kis_account_no',
    'notify_kakao_refresh_token',
)


def _key() -> bytes:
    raw = os.environ.get('TRADING_ENC_KEY', '').strip()
    if not raw:
        raise RuntimeError(
            'TRADING_ENC_KEY 미설정 — GitHub Secrets 에 base64 32바이트로 등록하세요'
        )
    key = base64.b64decode(raw)
    if len(key) != 32:
        raise RuntimeError(f'TRADING_ENC_KEY 길이 오류: {len(key)}바이트 (32 필요)')
    return key


def is_encrypted(value) -> bool:
    return isinstance(value, str) and value.startswith(_PREFIX)


def encrypt(plain: str | None) -> str | None:
    """평문 → 암호문. 기존 행 마이그레이션(encrypt_existing_configs.py)에서만 쓴다.
    평상시 암호화는 Edge Function 쪽에서 일어난다."""
    if not plain:
        return None
    if is_encrypted(plain):
        return plain
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    iv = os.urandom(12)
    ct = AESGCM(_key()).encrypt(iv, plain.encode('utf-8'), None)
    return f"{_PREFIX}{base64.b64encode(iv).decode()}:{base64.b64encode(ct).decode()}"


def decrypt(value: str | None) -> str | None:
    """암호문 → 평문. 접두사가 없으면 평문으로 보고 그대로 반환."""
    if not value:
        return value
    if not is_encrypted(value):
        return value
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    parts = value.split(':')
    if len(parts) != 4:
        raise ValueError('암호문 형식 오류')
    iv = base64.b64decode(parts[2])
    ct = base64.b64decode(parts[3])
    return AESGCM(_key()).decrypt(iv, ct, None).decode('utf-8')


def decrypt_config(cfg: dict) -> dict:
    """trading_configs 행 하나의 민감 필드를 전부 복호화한 사본을 돌려준다.

    복호화 실패는 삼키지 않는다. 키가 틀렸는데 조용히 평문 취급하고 넘어가면
    깨진 자격증명으로 증권사 인증을 시도하게 되고, 원인도 안 보인다.
    """
    out = dict(cfg)
    for field in SENSITIVE_FIELDS:
        if field in out:
            out[field] = decrypt(out[field])
    return out
