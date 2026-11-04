"""스크리닝 파이프라인 회귀 테스트 — 뉴스 게이트·판정 저장·광역 스캔 상태 집계.

    cd trading && python -m unittest discover -s tests -t .
"""
import unittest
from datetime import datetime, timedelta, timezone

import screen
import screen_broad
from brokers.kis_api import last_session_volume
from strategy import _score_entry


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


class ScoreEntryTest(unittest.TestCase):
    """채점 극단 케이스 — 전 항목 충족 = 정확히 10점, 바닥 다지기는 점수에 없음."""
    FUND = {'price': 9_000, 'market_cap': 10_000, 'per': 5.0, 'pbr': 0.5}
    MA_ALL = {'ma60': 10_000, 'ma5': 9_100, 'ma20': 9_000, 'golden_cross': True,
              'last_session_volume': 500_000, 'rsi': 35, 'rsi_rebound': True,
              'volume_declining': True}
    RATIOS_ALL = {'부채비율': 50, '유동비율': 200, '현금비율': 50, '이자보상배율': 1000}

    def test_every_item_met_is_exactly_ten(self):
        score, max_score, _ = _score_entry(self.FUND, self.MA_ALL, self.RATIOS_ALL)

        self.assertEqual((score, max_score), (10, 10))

    def test_basing_flag_no_longer_scores(self):
        # 백테스트상 역신호라 2026-11-04 제거 — 키가 남아 들어와도 점수에 영향 없어야 한다
        base, _, _ = _score_entry(self.FUND, self.MA_ALL, self.RATIOS_ALL)
        with_basing, _, _ = _score_entry(self.FUND, {**self.MA_ALL, 'basing': True}, self.RATIOS_ALL)

        self.assertEqual(base, with_basing)

    def test_rsi_rebound_is_two_points(self):
        on, _, _ = _score_entry(self.FUND, self.MA_ALL, self.RATIOS_ALL)
        off, _, _ = _score_entry(self.FUND, {**self.MA_ALL, 'rsi_rebound': False}, self.RATIOS_ALL)

        self.assertEqual(on - off, 2)

    def test_gate_fail_stops_at_ma60(self):
        # 극단 상승 종목(현재가 ≥ MA60)은 나머지 항목이 다 좋아도 1점도 못 받는다
        score, _, _ = _score_entry({**self.FUND, 'price': 20_000}, self.MA_ALL, self.RATIOS_ALL)

        self.assertEqual(score, 0)

    def test_nothing_met_but_gates_is_two(self):
        # 극단 약세 반등 직전: 필수 2개만 충족, 나머지 결측/미달 → 2점 (결측을 점수로 세지 않음)
        ma = {'ma60': 10_000, 'ma5': 9_100, 'ma20': 9_000, 'last_session_volume': 0}
        score, _, _ = _score_entry({'price': 9_000, 'market_cap': 10_000}, ma, None)

        self.assertEqual(score, 2)


if __name__ == '__main__':
    unittest.main()
