"""
자동매매 메인 실행 파일
GitHub Actions에서 장중 5분마다 호출됨
"""
import sys
import traceback
from datetime import datetime
from io import StringIO
import pytz

from kis_api import KISApi
import strategy
import kakao_notify

# ── 감시 종목 리스트 ─────────────────────────────────────────────────────────
WATCHLIST = [
    {'code': '096350', 'name': '대창솔루션'},
]


def is_market_open() -> bool:
    """KST 기준 장중 시간 여부 (평일 09:00~15:30)"""
    kst  = pytz.timezone('Asia/Seoul')
    now  = datetime.now(kst)
    if now.weekday() >= 5:          # 토/일
        return False
    open_  = now.replace(hour=9,  minute=0,  second=0, microsecond=0)
    close_ = now.replace(hour=15, minute=30, second=0, microsecond=0)
    return open_ <= now <= close_


def main():
    kst = pytz.timezone('Asia/Seoul')
    now_str = datetime.now(kst).strftime('%Y-%m-%d %H:%M:%S KST')

    # ── stdout 캡처 시작 (카카오톡 전송용) ──────────────────────────────────
    _buf = StringIO()
    _tee = _TeeWriter(sys.stdout, _buf)
    sys.stdout = _tee

    print(f"\n{'='*60}")
    print(f"  StockWiki 자동매매  |  {now_str}")
    print(f"{'='*60}")

    if not is_market_open():
        print("⏸  장외 시간 → 종료")
        sys.stdout = sys.__stdout__
        sys.exit(0)

    # KIS API 인증
    api = KISApi()
    api.auth()

    # 종목별 전략 실행
    errors = []
    for stock in WATCHLIST:
        try:
            strategy.run(api, stock['code'], stock['name'])
        except Exception as e:
            msg = f"[{stock['name']}] {e}"
            print(f"\n❌ {msg}")
            traceback.print_exc()
            errors.append(msg)

    print(f"\n{'='*60}")
    if errors:
        print(f"⚠️  오류 {len(errors)}건 발생:")
        for e in errors:
            print(f"   - {e}")

    # ── stdout 복원 + 카카오톡 전송 ─────────────────────────────────────────
    sys.stdout = sys.__stdout__
    kakao_notify.send(_buf.getvalue())

    if errors:
        sys.exit(1)
    else:
        print("✅ 완료")


class _TeeWriter:
    """sys.stdout 을 원본 + 버퍼 양쪽에 동시 기록"""
    def __init__(self, original, buffer):
        self._orig = original
        self._buf  = buffer

    def write(self, data):
        self._orig.write(data)
        self._buf.write(data)

    def flush(self):
        self._orig.flush()
        self._buf.flush()


if __name__ == '__main__':
    main()
