from .base_api import BaseBrokerApi
from .kis_api import KISApi
import os


class DryRunWrapper(BaseBrokerApi):
    """Wrap a real broker API to simulate buy/sell while allowing real data calls."""
    def __init__(self, inner: BaseBrokerApi):
        self._inner = inner

    def auth(self):
        return self._inner.auth()

    def get_price(self, code: str) -> int:
        return self._inner.get_price(code)

    def get_fundamentals(self, code: str) -> dict:
        return self._inner.get_fundamentals(code)

    def get_ma_data(self, code: str) -> dict:
        return self._inner.get_ma_data(code)

    def get_holdings(self, code: str) -> dict:
        return self._inner.get_holdings(code)

    def get_cash(self) -> int:
        return self._inner.get_cash()

    def buy(self, code: str, amount: int) -> dict | None:
        price = self.get_price(code)
        shares = amount // price
        if shares <= 0:
            print(f"⚠️  [DRY RUN] 매수 불가: {amount:,}원 / 현재가 {price:,}원")
            return None
        print(f"[DRY RUN] 매수 시뮬레이션: {shares}주 × {price:,}원 = {shares*price:,}원")
        return {'shares': shares, 'price': price, 'amount': shares * price}

    def sell(self, code: str, shares: int) -> dict | None:
        price = self.get_price(code)
        if shares <= 0:
            return None
        print(f"[DRY RUN] 매도 시뮬레이션: {shares}주 × {price:,}원 = {shares*price:,}원")
        return {'shares': shares, 'price': price, 'amount': shares * price}


def create_api(broker_type: str, cfg: dict) -> BaseBrokerApi:
    """broker_type에 맞는 API 인스턴스 생성. DRY_RUN 환경변수가 설정되면 주문은 시뮬레이션됩니다."""
    key    = cfg.get('kis_app_key')
    secret = cfg.get('kis_app_secret')
    acct   = cfg.get('kis_account_no')
    prod   = cfg.get('kis_account_prod_code', '01')

    # 키움/NH/삼성 래퍼는 KIS 의 TR ID·경로를 다른 도메인에 복사해 둔 것이라 실제로
    # 동작하지 않는다. 조용히 엉뚱한 서버로 인증·주문을 보내지 않도록 명시적으로 막는다.
    if broker_type not in (None, '', 'kis'):
        raise NotImplementedError(f"'{broker_type}' 증권사는 아직 지원하지 않습니다 (KIS 만 지원)")
    api = KISApi(key, secret, acct, prod)

    dry = os.environ.get('DRY_RUN')
    if dry and str(dry).lower() in ('1', 'true', 'yes'):
        return DryRunWrapper(api)
    return api
