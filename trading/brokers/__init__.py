from .base_api import BaseBrokerApi
from .kis_api import KISApi
from .kiwoom_api import KiwoomApi
from .nh_api import NHApi
from .samsung_api import SamsungApi


def create_api(broker_type: str, cfg: dict) -> BaseBrokerApi:
    """broker_type에 맞는 API 인스턴스 생성"""
    key    = cfg.get('kis_app_key')
    secret = cfg.get('kis_app_secret')
    acct   = cfg.get('kis_account_no')
    prod   = cfg.get('kis_account_prod_code', '01')

    match broker_type:
        case 'kiwoom':
            return KiwoomApi(key, secret, acct, prod)
        case 'nh':
            return NHApi(key, secret, acct, prod)
        case 'samsung':
            return SamsungApi(key, secret, acct, prod)
        case _:
            return KISApi(key, secret, acct, prod)
