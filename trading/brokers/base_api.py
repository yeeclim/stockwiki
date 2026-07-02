"""
브로커 API 추상 기반 클래스
모든 증권사 API 래퍼는 이 클래스를 상속하여 구현합니다.
"""
from abc import ABC, abstractmethod


class BaseBrokerApi(ABC):

    @abstractmethod
    def auth(self):
        """인증 토큰 발급"""

    @abstractmethod
    def get_price(self, code: str) -> int:
        """현재가 (원)"""

    @abstractmethod
    def get_fundamentals(self, code: str) -> dict:
        """price, per, pbr, volume, prdy_ctrt, open, prdy_clpr"""

    @abstractmethod
    def get_ma_data(self, code: str) -> dict:
        """ma5, ma20, ma60, ma120, golden_cross, above_ma20"""

    @abstractmethod
    def get_holdings(self, code: str) -> dict:
        """shares, avg_price"""

    @abstractmethod
    def get_cash(self) -> int:
        """주문 가능 예수금 (원)"""

    @abstractmethod
    def buy(self, code: str, amount: int) -> dict | None:
        """시장가 매수. 반환: {shares, price, amount} or None"""

    @abstractmethod
    def sell(self, code: str, shares: int) -> dict | None:
        """시장가 매도. 반환: {shares, price, amount} or None"""

    def get_financial_ratios(self, code: str) -> dict | None:
        """재무비율 4종 — DART API 우선, 실패 시 FnGuide 스크래핑 fallback"""
        import sys, os
        sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
        import dart_api
        result = dart_api.get_financial_ratios(code)
        if result:
            return result

        # FnGuide fallback
        try:
            import requests
            from bs4 import BeautifulSoup
            r = requests.get(
                "https://comp.fnguide.com/SVO2/ASP/SVD_Finance.asp",
                params={"gicode": f"A{code}", "rptType": "1",
                        "fin_typ": "0", "MenuYn": "N"},
                headers={"User-Agent": "Mozilla/5.0"},
                timeout=10,
            )
            r.raise_for_status()
            soup = BeautifulSoup(r.content, 'lxml')
            TARGETS = {
                '부채비율':    'debt_ratio',
                '유동비율':    'current_ratio',
                '현금비율':    'cash_ratio',
                '이자보상배율': 'interest_coverage',
            }
            result = {}
            for row in soup.select('tr'):
                th = row.find('th')
                if not th:
                    continue
                label = th.get_text(strip=True)
                for keyword, key in TARGETS.items():
                    if keyword in label:
                        for td in reversed(row.find_all('td')):
                            txt = td.get_text(strip=True).replace(',', '').replace('%', '')
                            try:
                                result[key] = float(txt)
                                break
                            except ValueError:
                                continue
                        break
            return result or None
        except Exception as e:
            print(f"⚠️  재무비율 조회 실패 ({code}): {e}")
            return None
