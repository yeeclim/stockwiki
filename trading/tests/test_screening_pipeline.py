"""스크리닝 파이프라인 회귀 테스트 — 뉴스 게이트·판정 저장·광역 스캔 상태 집계.

    cd trading && python -m unittest discover -s tests -t .
"""
import unittest
from datetime import datetime, timedelta, timezone

import screen
import screen_broad
from brokers.kis_api import last_session_volume


def _passed() -> dict:
    return {'code': '002350', 'name': '넥센타이어', 'score': 6.0, 'pass': True}


class SentimentGateTest(unittest.TestCase):
    def test_negative_news_excludes(self):
        r = _passed()
        screen._apply_sentiment(r, '부정', '🔴 부정 — 실적 부진')

        self.assertFalse(r['pass'])
        self.assertEqual(screen._verdict(r), 'news_negative')

    def test_timeout_is_held_not_passed(self):
        # 예전엔 시간 초과로 분석 못 한 종목을 통과시켰다
        r = _passed()
        screen._apply_sentiment(r, None, '시간 초과로 미분석')

        self.assertFalse(r['pass'])
        self.assertEqual(screen._verdict(r), 'news_unanalyzed')

    def test_analysis_failure_is_held(self):
        r = _passed()
        screen._apply_sentiment(r, None, '분석 실패')

        self.assertEqual(screen._verdict(r), 'news_unanalyzed')

    def test_no_news_keeps_pass(self):
        r = _passed()
        screen._apply_sentiment(r, None, '뉴스 없음')

        self.assertTrue(r['pass'])
        self.assertEqual(screen._verdict(r), 'pass')

    def test_below_score_verdict(self):
        self.assertEqual(screen._verdict({'pass': False}), 'below_score')


class _FakeApi:
    """KIS 대역 — 종목코드별로 시세를 돌려주거나 예외를 던진다."""

    def __init__(self, fund: dict, ma: dict, fail: bool = False):
        self.fund, self.ma, self.fail = fund, ma, fail

    def get_fundamentals(self, code):
        if self.fail:
            raise TimeoutError('KIS 응답 없음')

        return self.fund

    def get_ma_data(self, code):
        return self.ma


class BroadScanStatusTest(unittest.TestCase):
    STOCK = {'code': '011200', 'name': 'HMM', 'sector': 'KOSPI'}
    FUND = {'price': 25000, 'volume': 3_000_000, 'market_cap': 200_000, 'per': 5.0, 'pbr': 0.6}

    def setUp(self):
        self._orig_api, self._orig_delay = screen_broad._api, screen_broad.CALL_DELAY
        screen_broad.CALL_DELAY = 0

    def tearDown(self):
        screen_broad._api, screen_broad.CALL_DELAY = self._orig_api, self._orig_delay

    def test_api_error_is_counted_as_failed(self):
        # 예전엔 예외를 None 으로 삼켜 '조건 미달'과 구분이 안 됐다
        screen_broad._api = _FakeApi(self.FUND, {}, fail=True)
        result = screen_broad._score_stock(self.STOCK)

        self.assertEqual(result['status'], 'failed')
        self.assertIn('TimeoutError', result['error'])

    def test_above_ma60_records_gate(self):
        # 2026-10-14 HMM: 60일선 +10.5% — 필수 조건(현재가 < 60일선) 탈락 사유가 남아야 한다
        screen_broad._api = _FakeApi(self.FUND, {'ma60': 22_600, 'ma5': 25_000, 'ma20': 24_000,
                                                 'last_session_volume': 3_000_000})
        result = screen_broad._score_stock(self.STOCK)

        self.assertEqual(result['status'], 'scored')
        self.assertIn('MA60', result['gate'])

    def test_low_last_session_volume_is_filtered(self):
        screen_broad._api = _FakeApi(self.FUND, {'last_session_volume': 10_000})

        self.assertEqual(screen_broad._score_stock(self.STOCK)['status'], 'filtered')

    def test_preopen_zero_volume_not_filtered(self):
        # 장전엔 당일 누적 거래량이 0 — 그걸로 거르면 전 종목이 탈락한다
        screen_broad._api = _FakeApi({**self.FUND, 'volume': 0},
                                     {'ma60': 30_000, 'ma5': 25_000, 'ma20': 24_000,
                                      'last_session_volume': 3_000_000})

        self.assertEqual(screen_broad._score_stock(self.STOCK)['status'], 'scored')


class LastSessionVolumeTest(unittest.TestCase):
    KST = timezone(timedelta(hours=9))
    ROWS = [{'stck_bsop_date': '20261014', 'acml_vol': '21884'},
            {'stck_bsop_date': '20261013', 'acml_vol': '412000'}]

    def test_intraday_skips_today_partial(self):
        now = datetime(2026, 10, 14, 10, 19, tzinfo=self.KST)

        self.assertEqual(last_session_volume(self.ROWS, now), 412_000)

    def test_after_close_uses_today(self):
        now = datetime(2026, 10, 14, 15, 40, tzinfo=self.KST)

        self.assertEqual(last_session_volume(self.ROWS, now), 21_884)

    def test_preopen_without_today_row(self):
        now = datetime(2026, 10, 15, 6, 0, tzinfo=self.KST)

        self.assertEqual(last_session_volume(self.ROWS, now), 21_884)


if __name__ == '__main__':
    unittest.main()
