"""
한국투자증권 KIS OpenAPI 래퍼
실전투자: https://openapi.koreainvestment.com:9443
"""
import os
import requests
from datetime import datetime, timedelta
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import technical_indicators as ti

BASE_URL = "https://openapi.koreainvestment.com:9443"


class KISApi:
    def __init__(self):
        self.app_key    = os.environ.get('KIS_APP_KEY', '')
        self.app_secret = os.environ.get('KIS_APP_SECRET', '')
        self.account_no = os.environ.get('KIS_ACCOUNT_NO', '')
        self.acnt_code  = os.environ.get('KIS_ACCOUNT_PROD_CODE', '01')
        self.token      = None

        # session with retries
        self._session = requests.Session()
        retries = Retry(total=3, backoff_factor=0.5,
                        status_forcelist=[429, 500, 502, 503, 504],
                        allowed_methods=frozenset(['GET', 'POST']))
        adapter = HTTPAdapter(max_retries=retries)
        self._session.mount('https://', adapter)
        self._session.mount('http://', adapter)

        # timeouts: (connect, read)
        self._timeout = (5, 15)

    # ── 인증 ──────────────────────────────────────────────────────────────────
    def auth(self):
        try:
            res = self._session.post(
                f"{BASE_URL}/oauth2/tokenP",
                headers={"content-type": "application/json"},
                json={
                    "grant_type": "client_credentials",
                    "appkey":     self.app_key,
                    "appsecret":  self.app_secret,
                },
                timeout=self._timeout,
            )
            res.raise_for_status()
            data = res.json()
            self.token = data.get('access_token')
            if not self.token:
                raise RuntimeError('토큰 응답이 비어있습니다')
            print("✅ KIS 토큰 발급 완료")
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"KIS 토큰 발급 실패: {e}") from e

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
        try:
            r = self._session.get(
                f"{BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-price",
                headers=self._h("FHKST01010100"),
                params={"FID_COND_MRKT_DIV_CODE": "J", "FID_INPUT_ISCD": code},
                timeout=self._timeout,
            )
            r.raise_for_status()
            d = r.json()
            if d.get('rt_cd') != '0':
                raise RuntimeError(f"현재가 오류: {d.get('msg1')}")
            return int(d['output']['stck_prpr'])
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"현재가 조회 실패: {e}") from e

    def get_ma60(self, code) -> float | None:
        """60일 이동평균선"""
        end   = datetime.now().strftime('%Y%m%d')
        start = (datetime.now() - timedelta(days=120)).strftime('%Y%m%d')
        try:
            r = self._session.get(
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
                timeout=self._timeout,
            )
            r.raise_for_status()
            d = r.json()
            if d.get('rt_cd') != '0':
                raise RuntimeError(f"이평선 오류: {d.get('msg1')}")
            prices = [int(x['stck_clpr']) for x in d.get('output2', []) if x.get('stck_clpr', '0') != '0']
            if len(prices) < 60:
                print(f"⚠️  데이터 부족: {len(prices)}일 (60일 필요)")
                return None
            return sum(prices[:60]) / 60
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"이평선 조회 실패: {e}") from e

    # ── 잔고 조회 ──────────────────────────────────────────────────────────────
    def get_cash(self) -> int:
        """주문 가능 예수금"""
        try:
            r = self._session.get(
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
                timeout=self._timeout,
            )
            r.raise_for_status()
            d = r.json()
            if d.get('rt_cd') != '0':
                raise RuntimeError(f"예수금 오류: {d.get('msg1')}")
            return int(d['output']['ord_psbl_cash'])
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"예수금 조회 실패: {e}") from e

    def _fetch_all_holdings(self) -> dict:
        """전체 잔고를 한 번 조회하여 {종목코드: {shares, avg_price}} 캐시 반환"""
        if hasattr(self, '_holdings_cache'):
            return self._holdings_cache
        try:
            r = self._session.get(
                f"{BASE_URL}/uapi/domestic-stock/v1/trading/inquire-balance",
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
                timeout=self._timeout,
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
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"잔고 조회 실패: {e}") from e

    def get_holdings(self, code) -> dict:
        """보유 수량 + 평단가 (세션당 1회 조회 후 캐시 사용)"""
        return self._fetch_all_holdings().get(code, {'shares': 0, 'avg_price': 0.0})

    def get_fundamentals(self, code: str) -> dict:
        """현재가 + PER + PBR + 거래량 (FHKST01010100 재활용)"""
        try:
            r = self._session.get(
                f"{BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-price",
                headers=self._h("FHKST01010100"),
                params={"FID_COND_MRKT_DIV_CODE": "J", "FID_INPUT_ISCD": code},
                timeout=self._timeout,
            )
            r.raise_for_status()
            d = r.json()
            if d.get('rt_cd') != '0':
                raise RuntimeError(f"시세 오류: {d.get('msg1')}")
            out = d['output']

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
                'market_cap': _i(out.get('hts_avls')),  # 시가총액 (억원)
            }
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"시세 조회 실패: {e}") from e

    def get_ma_data(self, code: str) -> dict:
        """MA5 / MA20 / MA60 / MA120 + 골든크로스 여부"""
        end   = datetime.now().strftime('%Y%m%d')
        start = (datetime.now() - timedelta(days=250)).strftime('%Y%m%d')
        try:
            r = self._session.get(
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
                timeout=self._timeout,
            )
            r.raise_for_status()
            d = r.json()
            if d.get('rt_cd') != '0':
                raise RuntimeError(f"차트 오류: {d.get('msg1')}")

            rows = [x for x in d.get('output2', [])
                    if x.get('stck_clpr', '0') not in ('0', '', None)]
            prices = [int(x['stck_clpr']) for x in rows]

            def ma(n):      return round(sum(prices[:n]) / n, 1) if len(prices) >= n else None
            def ma_prev(n): return round(sum(prices[1:n+1]) / n, 1) if len(prices) >= n + 1 else None

            ma5, ma20, ma60, ma120 = ma(5), ma(20), ma(60), ma(120)
            p5, p20 = ma_prev(5), ma_prev(20)

            # rows/prices는 최신→과거 순서 — 지표 함수는 과거→최신(오름차순)을 기대하므로 뒤집는다
            closes_asc = list(reversed(prices))
            volumes_asc = [int(x.get('acml_vol', 0) or 0) for x in reversed(rows)]

            rsi_rebound, rsi_now = ti.rsi_oversold_rebound(closes_asc)
            basing = ti.basing_near_low(closes_asc)
            vol_declining = ti.volume_declining(volumes_asc)

            return {
                'ma5':   ma5,  'ma20': ma20, 'ma60': ma60, 'ma120': ma120,
                'golden_cross': bool(ma5 and ma20 and p5 and p20
                                     and ma5 > ma20 and p5 <= p20),
                'above_ma20':   bool(ma5 and ma20 and ma5 > ma20),
                'rsi':               rsi_now,
                'rsi_rebound':       rsi_rebound,
                'basing':            basing,
                'volume_declining':  vol_declining,
            }
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"MA 데이터 조회 실패: {e}") from e

    def get_financial_ratios(self, code: str) -> dict | None:
        """재무비율 4종 — DART API 우선, 실패 시 FnGuide 스크래핑 fallback"""
        import dart_api
        result = dart_api.get_financial_ratios(code)
        if result:
            return result

        # FnGuide fallback
        try:
            from bs4 import BeautifulSoup
            r = self._session.get(
                "https://comp.fnguide.com/SVO2/ASP/SVD_Finance.asp",
                params={"gicode": f"A{code}", "rptType": "1",
                        "fin_typ": "0", "MenuYn": "N"},
                headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"},
                timeout=10,
            )
            r.raise_for_status()
            soup = BeautifulSoup(r.content, 'lxml')
            TARGETS = ('부채비율', '유동비율', '현금비율', '이자보상배율')
            result = {}
            for row in soup.select('tr'):
                th = row.find('th')
                if not th:
                    continue
                label = th.get_text(strip=True)
                for keyword in TARGETS:
                    if keyword in label:
                        for td in reversed(row.find_all('td')):
                            txt = td.get_text(strip=True).replace(',', '').replace('%', '')
                            try:
                                result[keyword] = float(txt)
                                break
                            except ValueError:
                                continue
                        break
            return result or None
        except Exception as e:
            print(f"⚠️  재무비율 조회 실패 ({code}): {e}")
            return None

    # ── 선물 시세 ──────────────────────────────────────────────────────────────
    def get_futures_open_interest(self, code: str) -> dict | None:
        """국내선물옵션 시세 조회 — 미결제약정수량 및 전일대비 증감.
        계정에 '국내선물옵션' 서비스 권한이 승인되어 있어야 동작하며, tr_id·응답
        필드명·종목코드 형식은 실계좌로 검증되지 않았다. 실패 시 예외를 전파하지
        않고 None을 반환한다(권한 미승인/코드 오류 시에도 메일 발송은 계속됨).
        """
        try:
            r = self._session.get(
                f"{BASE_URL}/uapi/domestic-futureoption/v1/quotations/inquire-price",
                headers=self._h("FHMIF10000000"),
                params={"FID_COND_MRKT_DIV_CODE": "F", "FID_INPUT_ISCD": code},
                timeout=self._timeout,
            )
            r.raise_for_status()
            d = r.json()
            if d.get('rt_cd') != '0':
                print(f"⚠️  선물 미결제약정 조회 오류: {d.get('msg1')}")
                return None
            out = d['output']
            oi = out.get('hts_otst_stpl_qty')
            if oi in (None, ''):
                return None
            return {
                'open_interest':        int(oi),
                'open_interest_change': int(out.get('otst_stpl_qty_icdc') or 0),
            }
        except Exception as e:
            print(f"⚠️  선물 미결제약정 조회 실패: {e}")
            return None

    # ── 주문 ──────────────────────────────────────────────────────────────────
    def _ord_dvsn(self) -> str:
        """시간대에 따른 주문구분: 정규장 시장가(01) / NXT 시간외 최유리지정가(03)"""
        from datetime import time as _time
        import pytz
        kst = pytz.timezone('Asia/Seoul')
        t = datetime.now(kst).time()
        if _time(8, 0) <= t < _time(9, 0) or _time(15, 40) <= t < _time(20, 0):
            return "03"  # NXT 프리/포스트마켓 — 최유리지정가
        return "01"  # 정규장 — 시장가

    def buy(self, code, amount: int) -> dict | None:
        """시장가 매수 (금액 → 수량 계산)"""
        price  = self.get_price(code)
        shares = amount // price
        if shares <= 0:
            print(f"⚠️  매수 불가 (금액 부족): {amount:,}원 / 현재가 {price:,}원")
            return None
        try:
            r = self._session.post(
                f"{BASE_URL}/uapi/domestic-stock/v1/trading/order-cash",
                headers=self._h("TTTC0802U"),
                json={
                    "CANO":         self.account_no,
                    "ACNT_PRDT_CD": self.acnt_code,
                    "PDNO":         code,
                    "ORD_DVSN":     self._ord_dvsn(),
                    "ORD_QTY":      str(shares),
                    "ORD_UNPR":     "0",
                },
                timeout=self._timeout,
            )
            r.raise_for_status()
            d = r.json()
            if d.get('rt_cd') != '0':
                raise RuntimeError(f"매수 오류: {d.get('msg1')}")
            print(f"📈 매수: {shares}주 × {price:,}원 = {shares*price:,}원")
            return {'shares': shares, 'price': price, 'amount': shares * price}
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"매수 요청 실패: {e}") from e

    def sell(self, code, shares: int) -> dict | None:
        """시장가 매도"""
        if shares <= 0:
            return None
        price = self.get_price(code)
        try:
            r = self._session.post(
                f"{BASE_URL}/uapi/domestic-stock/v1/trading/order-cash",
                headers=self._h("TTTC0801U"),
                json={
                    "CANO":         self.account_no,
                    "ACNT_PRDT_CD": self.acnt_code,
                    "PDNO":         code,
                    "ORD_DVSN":     self._ord_dvsn(),
                    "ORD_QTY":      str(shares),
                    "ORD_UNPR":     "0",
                },
                timeout=self._timeout,
            )
            r.raise_for_status()
            d = r.json()
            if d.get('rt_cd') != '0':
                raise RuntimeError(f"매도 오류: {d.get('msg1')}")
            print(f"📉 매도: {shares}주 × {price:,}원 = {shares*price:,}원")
            return {'shares': shares, 'price': price, 'amount': shares * price}
        except requests.exceptions.RequestException as e:
            raise RuntimeError(f"매도 요청 실패: {e}") from e
