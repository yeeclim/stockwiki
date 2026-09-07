"""
한국투자증권 KIS OpenAPI 래퍼 (공통 베이스)
실전투자: https://openapi.koreainvestment.com:9443

main.py(실매매)는 이 베이스를 그대로 사용한다.
trading/kis_api.py 가 이 클래스를 상속해 세션/재시도·기술적 지표·시간외
주문구분·투자자동향/선물 등 스크리닝 전용 확장을 덧붙인다.
"""
import os
import requests
from datetime import datetime, timedelta
from .base_api import BaseBrokerApi

BASE_URL = "https://openapi.koreainvestment.com:9443"
_TIMEOUT = 15  # seconds


class KISApi(BaseBrokerApi):
    def __init__(self, app_key=None, app_secret=None, account_no=None, acnt_code=None):
        self.app_key    = app_key    or os.environ['KIS_APP_KEY']
        self.app_secret = app_secret or os.environ['KIS_APP_SECRET']
        self.account_no = account_no or os.environ['KIS_ACCOUNT_NO']
        self.acnt_code  = acnt_code  or os.environ.get('KIS_ACCOUNT_PROD_CODE', '01')
        self.token      = None

    # ── HTTP (서브클래스에서 세션/타임아웃으로 교체 가능) ────────────────────────
    def _get(self, path, **kw):
        kw.setdefault('timeout', _TIMEOUT)
        return requests.get(f"{BASE_URL}{path}", **kw)

    def _post(self, path, **kw):
        kw.setdefault('timeout', _TIMEOUT)
        return requests.post(f"{BASE_URL}{path}", **kw)

    def _h(self, tr_id):
        return {
            "content-type":  "application/json",
            "authorization": f"Bearer {self.token}",
            "appkey":        self.app_key,
            "appsecret":     self.app_secret,
            "tr_id":         tr_id,
            "custtype":      "P",
        }

    def auth(self):
        res = self._post(
            "/oauth2/tokenP",
            headers={"content-type": "application/json"},
            json={"grant_type": "client_credentials",
                  "appkey": self.app_key, "appsecret": self.app_secret},
        )
        res.raise_for_status()
        self.token = res.json()['access_token']
        print("✅ KIS 토큰 발급 완료")

    # ── 시세 조회 (raw 헬퍼는 서브클래스와 공유) ────────────────────────────────
    def _inquire_price_output(self, code: str, err_label: str = '시세 오류') -> dict:
        """inquire-price(FHKST01010100)의 output 딕셔너리 반환."""
        r = self._get(
            "/uapi/domestic-stock/v1/quotations/inquire-price",
            headers=self._h("FHKST01010100"),
            params={"FID_COND_MRKT_DIV_CODE": "J", "FID_INPUT_ISCD": code},
        )
        r.raise_for_status()
        d = r.json()
        if d['rt_cd'] != '0':
            raise RuntimeError(f"{err_label}: {d['msg1']}")
        return d['output']

    def _inquire_daily_rows(self, code: str, days: int) -> list:
        """inquire-daily-itemchartprice(FHKST03010100)의 output2 행 리스트(최신→과거)."""
        end   = datetime.now().strftime('%Y%m%d')
        start = (datetime.now() - timedelta(days=days)).strftime('%Y%m%d')
        r = self._get(
            "/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice",
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
        return [x for x in d.get('output2', [])
                if x.get('stck_clpr', '0') not in ('0', '', None)]

    def get_price(self, code: str) -> int:
        return int(self._inquire_price_output(code, '현재가 오류')['stck_prpr'])

    def get_fundamentals(self, code: str) -> dict:
        out = self._inquire_price_output(code)

        def _f(v):
            try: return float(v) if v and str(v).strip() not in ('', '-') else 0.0
            except: return 0.0
        def _i(v):
            try: return int(v) if v else 0
            except: return 0

        return {
            'price':      _i(out.get('stck_prpr')),
            'per':        _f(out.get('per')),
            'pbr':        _f(out.get('pbr')),
            'volume':     _i(out.get('acml_vol')),
            'prdy_ctrt':  _f(out.get('prdy_ctrt')),
            'open':       _i(out.get('stck_oprc')),
            'prdy_clpr':  _i(out.get('stck_prdy_clpr') or 0),
        }

    def get_ma_data(self, code: str) -> dict:
        prices = [int(x['stck_clpr']) for x in self._inquire_daily_rows(code, 250)]

        def ma(n):      return round(sum(prices[:n]) / n, 1) if len(prices) >= n else None
        def ma_prev(n): return round(sum(prices[1:n+1]) / n, 1) if len(prices) >= n + 1 else None

        ma5, ma20, ma60, ma120 = ma(5), ma(20), ma(60), ma(120)
        p5, p20 = ma_prev(5), ma_prev(20)

        return {
            'ma5': ma5, 'ma20': ma20, 'ma60': ma60, 'ma120': ma120,
            'golden_cross': bool(ma5 and ma20 and p5 and p20 and ma5 > ma20 and p5 <= p20),
            'above_ma20':   bool(ma5 and ma20 and ma5 > ma20),
        }

    # ── 잔고 조회 ──────────────────────────────────────────────────────────────
    def _fetch_all_holdings(self) -> dict:
        if hasattr(self, '_holdings_cache'):
            return self._holdings_cache
        r = self._get(
            "/uapi/domestic-stock/v1/trading/inquire-balance",
            headers=self._h("TTTC8434R"),
            params={
                "CANO":                  self.account_no,
                "ACNT_PRDT_CD":          self.acnt_code,
                "AFHR_FLPR_YN":          "N",
                "OFL_YN":                "N",
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
        self._holdings_cache = {
            item['pdno']: {
                'shares':    int(item['hldg_qty']),
                'avg_price': float(item['pchs_avg_pric']),
            }
            for item in d.get('output1', [])
            if item.get('pdno')
        }
        return self._holdings_cache

    def get_holdings(self, code: str) -> dict:
        return self._fetch_all_holdings().get(code, {'shares': 0, 'avg_price': 0.0})

    def get_cash(self) -> int:
        r = self._get(
            "/uapi/domestic-stock/v1/trading/inquire-psbl-order",
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

    # ── 주문 ──────────────────────────────────────────────────────────────────
    def _ord_dvsn(self) -> str:
        """주문구분. 베이스는 정규장 시장가(01) 고정. 서브클래스가 시간외 대응."""
        return "01"

    def buy(self, code: str, amount: int) -> dict | None:
        price  = self.get_price(code)
        shares = amount // price
        if shares <= 0:
            print(f"⚠️  매수 불가: {amount:,}원 / 현재가 {price:,}원")
            return None
        r = self._post(
            "/uapi/domestic-stock/v1/trading/order-cash",
            headers=self._h("TTTC0802U"),
            json={
                "CANO":         self.account_no,
                "ACNT_PRDT_CD": self.acnt_code,
                "PDNO":         code,
                "ORD_DVSN":     self._ord_dvsn(),
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

    def sell(self, code: str, shares: int) -> dict | None:
        if shares <= 0:
            return None
        price = self.get_price(code)
        r = self._post(
            "/uapi/domestic-stock/v1/trading/order-cash",
            headers=self._h("TTTC0801U"),
            json={
                "CANO":         self.account_no,
                "ACNT_PRDT_CD": self.acnt_code,
                "PDNO":         code,
                "ORD_DVSN":     self._ord_dvsn(),
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
