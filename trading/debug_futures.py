"""
일회성 디버그 스크립트 — 코스피200 선물 종목코드를 이메일 발송 없이 확인한다.
확인이 끝나면 이 파일과 .github/workflows/debug_futures.yml 은 삭제할 것.
"""
import json
from kis_api import KISApi, BASE_URL

# "101" + F(선물) + MM(만기월, 분기월물) + "000"(옵션 행사가 자리, 선물은 000)
CANDIDATES = [
    "101F09000", "101F12000", "101F06000", "101F03000",
    "101F0900", "101F1200",
]


def main():
    api = KISApi()
    api.auth()

    for code in CANDIDATES:
        try:
            r = api._session.get(
                f"{BASE_URL}/uapi/domestic-futureoption/v1/quotations/inquire-price",
                headers=api._h("FHMIF10000000"),
                params={"FID_COND_MRKT_DIV_CODE": "F", "FID_INPUT_ISCD": code},
                timeout=api._timeout,
            )
            d = r.json()
            out1 = d.get('output1') or {}
            print(f"=== code={code!r} rt_cd={d.get('rt_cd')} msg1={d.get('msg1')} "
                  f"output1 keys={list(out1.keys())} ===")
            if out1:
                print(json.dumps(out1, ensure_ascii=False)[:1200])
        except Exception as e:
            print(f"=== code={code!r} 오류: {e} ===")


if __name__ == '__main__':
    main()
