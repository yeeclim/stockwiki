"""
한국투자증권 KIS OpenAPI 래퍼
실전투자: https://openapi.koreainvestment.com:9443
"""
import os
import requests
from datetime import datetime, timedelta

BASE_URL = "https://openapi.koreainvestment.com:9443"


class KISApi:
    def __init__(self):
        self.app_key    = os.environ['KIS_APP_KEY']
        self.app_secret = os.environ['KIS_APP_SECRET']
        self.account_no = os.environ['KIS_ACCOUNT_NO']
        self.acnt_code  = os.environ.get('KIS_ACCOUNT_PROD_CODE', '01')
        self.token      = None

    # ── 인증 ──────────────────────────────────────────────────────────────────
    def auth(self):
        res = requests.post(
            f"{BASE_URL}/oauth2/tokenP",
            headers={"content-type": "application/json"},
            json={
                "grant_type": "client_credentials",
                "appkey":     self.app_key,
                "appsecret":  self.app_secret,
            },
        )
        res.raise_for_status()
        self.token = res.json()['access_token']
        print("✅ KIS 토큰 발급 완료")

    def _h(self, tr_id):
        return {
            "content-type": "application/json",
            "authorization": f"Bearer {self.token}",
            "appkey":   self.app_key,
            "appsecret": self.app_secret,
            "tr_id":    tr_id,
            "custtype": "P",
        }

    # ── 시세 조회 ──────────────────────────────────────────────────────────────
    def get_price(self, code) -> int:
        """현재가"""
        r = requests.get(
            f"{BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-price",
            headers=self._h("FHKST01010100"),
            params={"FID_COND_MRKT_DIV_CODE": "J", "FID_INPUT_ISCD": code},
        )
        r.raise_for_status()
        d = r.json()
        if d['rt_cd'] != '0':
            raise RuntimeError(f"현재가 오류: {d['msg1']}")
        return int(d['output']['stck_prpr'])

    def get_ma60(self, code) -> float | None:
        """60일 이동평균선"""
        end   = datetime.now().strftime('%Y%m%d')
        start = (datetime.now() - timedelta(days=120)).strftime('%Y%m%d')
        r = requests.get(
            f"{BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice",
            headers=self._h("FHKST03010100"),
            params={
                "FID_COND_MRKT_DIV_CODE": "J",
                "FID_INPUT_ISCD":         code,
                "FID_INPUT_DATE_1":       start,
                "FID_INPUT_DATE_2":       end,
                "FID_PERIOD_DIV_CODE":    "D",
                "FID_ORG_ADJ_PRC":        "0",
            },
        )
        r.raise_for_status()
        d = r.json()
        if d['rt_cd'] != '0':
            raise RuntimeError(f"이평선 오류: {d['msg1']}")
        prices = [int(x['stck_clpr']) for x in d.get('output2', []) if x.get('stck_clpr', '0') != '0']
        if len(prices) < 60:
            print(f"⚠️  데이터 부족: {len(prices)}일 (60일 필요)")
            return None
        return sum(prices[:60]) / 60

    # ── 잔고 조회 ──────────────────────────────────────────────────────────────
    def get_cash(self) -> int:
        """주문 가능 예수금"""
        r = requests.get(
            f"{BASE_URL}/uapi/domestic-stock/v1/trading/inquire-psbl-order",
            headers=self._h("TTTC8908R"),
            params={
                "CANO":              self.account_no,
                "ACNT_PRDT_CD":      self.acnt_code,
                "PDNO":              "005930",
                "ORD_UNPR":          "0",
                "ORD_DVSN":          "01",
                "CMA_EVLU_AMT_ICLD_YN": "N",
                "OVRS_ICLD_YN":      "N",
            },
        )
        r.raise_for_status()
        d = r.json()
        if d['rt_cd'] != '0':
            raise RuntimeError(f"예수금 오류: {d['msg1']}")
        return int(d['output']['ord_psbl_cash'])

    def get_holdings(self, code) -> dict:
        """보유 수량 + 평단가"""
        r = requests.get(
            f"{BASE_URL}/uapi/domestic-stock/v1/trading/inquire-balance",
            headers=self._h("TTTC8434R"),
            params={
                "CANO":                  self.account_no,
                "ACNT_PRDT_CD":          self.acnt_code,
                "AFHR_FLPR_YN":          "N",
                "OFL_YN":                "",
                "INQR_DVSN":             "02",
                "UNPR_DVSN":             "01",
                "FUND_STTL_ICLD_YN":     "N",
                "FNCG_AMT_AUTO_RDPT_YN": "N",
                "PRCS_DVSN":             "01",
                "CTX_AREA_FK100":        "",
                "CTX_AREA_NK100":        "",
            },
        )
        r.raise_for_status()
        d = r.json()
        for item in d.get('output1', []):
            if item['pdno'] == code:
                return {
                    'shares':    int(item['hldg_qty']),
                    'avg_price': float(item['pchs_avg_pric']),
                }
        return {'shares': 0, 'avg_price': 0.0}

    def get_fundamentals(self, code: str) -> dict:
        """현재가 + PER + PBR + 거래량 (FHKST01010100 재활용)"""
        r = requests.get(
            f"{BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-price",
            headers=self._h("FHKST01010100"),
            params={"FID_COND_MRKT_DIV_CODE": "J", "FID_INPUT_ISCD": code},
        )
        r.raise_for_status()
        d = r.json()
        if d['rt_cd'] != '0':
            raise RuntimeError(f"시세 오류: {d['msg1']}")
        out = d['output']

        def _f(v):
            try: return float(v) if v and str(v).strip() not in ('', '-') else 0.0
            except: return 0.0
        def _i(v):
            try: return int(v) if v else 0
            except: return 0

        return {
            'price':  _i(out.get('stck_prpr')),
            'per':    _f(out.get('per')),
            'pbr':    _f(out.get('pbr')),
            'volume': _i(out.get('acml_vol')),
        }

    def get_ma_data(self, code: str) -> dict:
        """MA5 / MA20 / MA60 / MA120 + 골든크로스 여부"""
        end   = datetime.now().strftime('%Y%m%d')
        start = (datetime.now() - timedelta(days=250)).strftime('%Y%m%d')
        r = requests.get(
            f"{BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice",
            headers=self._h("FHKST03010100"),
            params={
                "FID_COND_MRKT_DIV_CODE": "J",
                "FID_INPUT_ISCD":         code,
                "FID_INPUT_DATE_1":       start,
                "FID_INPUT_DATE_2":       end,
                "FID_PERIOD_DIV_CODE":    "D",
                "FID_ORG_ADJ_PRC":        "0",
            },
        )
        r.raise_for_status()
        d = r.json()
        if d['rt_cd'] != '0':
            raise RuntimeError(f"차트 오류: {d['msg1']}")

        prices = [int(x['stck_clpr']) for x in d.get('output2', [])
                  if x.get('stck_clpr', '0') not in ('0', '', None)]

        def ma(n):      return round(sum(prices[:n]) / n, 1) if len(prices) >= n else None
        def ma_prev(n): return round(sum(prices[1:n+1]) / n, 1) if len(prices) >= n + 1 else None

        ma5, ma20, ma60, ma120 = ma(5), ma(20), ma(60), ma(120)
        p5, p20 = ma_prev(5), ma_prev(20)

        return {
            'ma5':   ma5,  'ma20': ma20, 'ma60': ma60, 'ma120': ma120,
            'golden_cross': bool(ma5 and ma20 and p5 and p20
                                 and ma5 > ma20 and p5 <= p20),
            'above_ma20':   bool(ma5 and ma20 and ma5 > ma20),
        }

    def get_financial_ratios(self, code: str) -> dict | None:
        """부채비율, 유동비율, 현금비율 — FnGuide 스크래핑 (실패 시 None)"""
        try:
            from bs4 import BeautifulSoup
            r = requests.get(
                "https://comp.fnguide.com/SVO2/ASP/SVD_Finance.asp",
                params={"gicode": f"A{code}", "rptType": "1",
                        "fin_typ": "0", "MenuYn": "N"},
                headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
                timeout=10,
            )
            r.raise_for_status()
            soup = BeautifulSoup(r.content, 'lxml')

            TARGETS = {
                '부채비율': 'debt_ratio',
                '유동비율': 'current_ratio',
                '현금비율': 'cash_ratio',
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

            return result if result else None
        except Exception as e:
            print(f"⚠️  재무비율 조회 실패 ({code}): {e}")
            return None

    # ── 주문 ──────────────────────────────────────────────────────────────────
    def buy(self, code, amount: int) -> dict | None:
        """시장가 매수 (금액 → 수량 계산)"""
        price  = self.get_price(code)
        shares = amount // price
        if shares <= 0:
            print(f"⚠️  매수 불가 (금액 부족): {amount:,}원 / 현재가 {price:,}원")
            return None
        r = requests.post(
            f"{BASE_URL}/uapi/domestic-stock/v1/trading/order-cash",
            headers=self._h("TTTC0802U"),
            json={
                "CANO":         self.account_no,
                "ACNT_PRDT_CD": self.acnt_code,
                "PDNO":         code,
                "ORD_DVSN":     "01",
                "ORD_QTY":      str(shares),
                "ORD_UNPR":     "0",
            },
        )
        r.raise_for_status()
        d = r.json()
        if d['rt_cd'] != '0':
            raise RuntimeError(f"매수 오류: {d['msg1']}")
        print(f"📈 매수: {shares}주 × {price:,}원 = {shares*price:,}원")
        return {'shares': shares, 'price': price, 'amount': shares * price}

    def sell(self, code, shares: int) -> dict | None:
        """시장가 매도"""
        if shares <= 0:
            return None
        price = self.get_price(code)
        r = requests.post(
            f"{BASE_URL}/uapi/domestic-stock/v1/trading/order-cash",
            headers=self._h("TTTC0801U"),
            json={
                "CANO":         self.account_no,
                "ACNT_PRDT_CD": self.acnt_code,
                "PDNO":         code,
                "ORD_DVSN":     "01",
                "ORD_QTY":      str(shares),
                "ORD_UNPR":     "0",
            },
        )
        r.raise_for_status()
        d = r.json()
        if d['rt_cd'] != '0':
            raise RuntimeError(f"매도 오류: {d['msg1']}")
        print(f"📉 매도: {shares}주 × {price:,}원 = {shares*price:,}원")
        return {'shares': shares, 'price': price, 'amount': shares * price}
