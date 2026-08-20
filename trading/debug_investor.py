"""
일회성 디버그 스크립트 — 시장별 투자자매매동향(일별) API 응답 필드를 이메일 발송 없이 확인한다.
확인이 끝나면 이 파일과 .github/workflows/debug_investor.yml 은 삭제할 것.
"""
import json
from datetime import datetime
from kis_api import KISApi, BASE_URL

TODAY = datetime.now().strftime('%Y%m%d')

CANDIDATES = [
    ("0001", "KSP"),  # 코스피
    ("1001", "KSQ"),  # 코스닥
]


def main():
    api = KISApi()
    api.auth()

    for code, mkt in CANDIDATES:
        try:
            r = api._session.get(
                f"{BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-investor-daily-by-market",
                headers=api._h("FHPTJ04040000"),
                params={
                    "FID_COND_MRKT_DIV_CODE": "U",
                    "FID_INPUT_ISCD": code,
                    "FID_INPUT_DATE_1": TODAY,
                    "FID_INPUT_ISCD_1": mkt,
                    "FID_INPUT_DATE_2": TODAY,
                    "FID_INPUT_ISCD_2": code,
                },
                timeout=api._timeout,
            )
            d = r.json()
            out = d.get('output')
            print(f"=== code={code} mkt={mkt} rt_cd={d.get('rt_cd')} msg1={d.get('msg1')} "
                  f"output type={type(out).__name__} ===")
            print(json.dumps(out, ensure_ascii=False)[:1500])
        except Exception as e:
            print(f"=== code={code} mkt={mkt} 오류: {e} ===")


if __name__ == '__main__':
    main()
