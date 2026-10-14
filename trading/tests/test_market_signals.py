"""시장 신호 판정 회귀 테스트 — 극단일에 상식과 반대 판정이 나오지 않는지.

    cd trading && python -m unittest discover -s tests -t .
"""
import unittest
from datetime import datetime

import pytz

import market_signals
import us_market_brief as umb
from kis_api import KISApi


def _now_kst_iso() -> str:
    return datetime.now(pytz.timezone('Asia/Seoul')).isoformat()


def _brief(us_pct: float, vix_pct: float, oil_pct: float, ewy_pct: float, skhy_pct: float,
           krw_pct: float, fut_pct: float | None, flow_net: int) -> dict:
    kr_indices = []
    if fut_pct is not None:
        kr_indices.append({'label': '코스피200 선물', 'pct': fut_pct, 'traded_at': _now_kst_iso()})

    return {
        'indices': [
            {'symbol': '^GSPC', 'pct': us_pct},
            {'symbol': '^IXIC', 'pct': us_pct},
            {'symbol': '^DJI', 'pct': us_pct},
            {'symbol': '^VIX', 'pct': vix_pct},
        ],
        'macro': [
            {'symbol': 'CL=F', 'pct': oil_pct},
            {'symbol': '^TNX', 'pct': 0.0, 'change': 0.0},
            {'symbol': 'KRW=X', 'pct': krw_pct},
            {'symbol': 'EWY', 'pct': ewy_pct},
            {'symbol': 'SKHY', 'pct': skhy_pct},
        ],
        'kr_indices': kr_indices,
        'kr_investors': [
            {'label': '코스피', 'frgn_net': flow_net, 'orgn_net': 0},
            {'label': '코스닥', 'frgn_net': flow_net, 'orgn_net': 0},
        ],
    }


class ExtremeDayTest(unittest.TestCase):
    def test_2026_10_13_crash_is_bear(self):
        # 실제 10-13 값 + 국내 수급만 ▲ 로 둔 최악 조합 — 예전 로직은 2:2 '팽팽'
        brief = _brief(us_pct=-0.04, vix_pct=2.49, oil_pct=-1.06, ewy_pct=-4.02, skhy_pct=-4.02,
                       krw_pct=0.30, fut_pct=-6.43, flow_net=100)
        signals = umb._compute_signals(brief)

        self.assertEqual(market_signals.verdict(signals), 'bear')

    def test_premarket_crash_without_futures_is_bear(self):
        # 장전(정규 선물 체결 전) — EWY 환율보정 −3.7% 갭만 있는 경우
        brief = _brief(us_pct=-0.04, vix_pct=2.49, oil_pct=-1.06, ewy_pct=-4.02, skhy_pct=-4.02,
                       krw_pct=0.30, fut_pct=None, flow_net=100)
        signals = umb._compute_signals(brief)

        self.assertEqual(market_signals.verdict(signals), 'bear')

    def test_big_rally_is_bull(self):
        # 대칭 케이스 — 큰 갭 상승인데 유가 급등·수급 매도가 표를 상쇄하는 날
        brief = _brief(us_pct=0.2, vix_pct=-1.0, oil_pct=2.5, ewy_pct=3.5, skhy_pct=3.0,
                       krw_pct=0.5, fut_pct=4.0, flow_net=-100)
        signals = umb._compute_signals(brief)

        self.assertEqual(market_signals.verdict(signals), 'bull')

    def test_small_gap_keeps_vote_count(self):
        # 갭이 ±2% 미만이면 기존 그룹 투표 그대로
        brief = _brief(us_pct=0.5, vix_pct=-2.0, oil_pct=0.2, ewy_pct=-0.6, skhy_pct=-0.5,
                       krw_pct=0.0, fut_pct=-0.8, flow_net=100)
        signals = umb._compute_signals(brief)
        bull, bear, _ = market_signals.signal_counts(signals)

        self.assertEqual(market_signals.verdict(signals), market_signals.verdict_from_counts(bull, bear))
        self.assertEqual(market_signals.verdict_reason(signals), '')

    def test_oil_drop_on_risk_off_day_is_neutral(self):
        brief = _brief(us_pct=-1.5, vix_pct=8.0, oil_pct=-3.0, ewy_pct=0.0, skhy_pct=0.0,
                       krw_pct=0.0, fut_pct=None, flow_net=0)
        oil = next(s for s in umb._compute_signals(brief) if s['label'].startswith('국제유가'))

        self.assertEqual(oil['direction'], 0)

    def test_oil_drop_on_calm_day_is_bull(self):
        brief = _brief(us_pct=0.3, vix_pct=-2.0, oil_pct=-3.0, ewy_pct=0.0, skhy_pct=0.0,
                       krw_pct=0.0, fut_pct=None, flow_net=0)
        oil = next(s for s in umb._compute_signals(brief) if s['label'].startswith('국제유가'))

        self.assertEqual(oil['direction'], 1)

    def test_kospi_and_kosdaq_flows_vote_separately(self):
        # 10-13 실측(백만원): 코스피 −1,328,605 ▼, 코스닥 +129,642 ▲ — 상쇄해 중립 1표로 만들지 않는다
        signals = [{'label': '코스피 수급(외국인+기관)', 'direction': -1, 'value': -1328605},
                   {'label': '코스닥 수급(외국인+기관)', 'direction': 1, 'value': 129642}]
        votes = {v['name']: v['direction'] for v in market_signals.group_votes(signals)}

        self.assertEqual(votes, {'코스피 수급': -1, '코스닥 수급': 1})

    def test_archived_signals_without_value_still_count(self):
        # value 필드가 없던 옛 brief_json
        signals = [{'label': '코스피200 선물', 'direction': -1}, {'label': '국제유가(WTI)', 'direction': 1}]

        self.assertEqual(market_signals.verdict(signals), 'neutral')


class PreopenEmptyDataTest(unittest.TestCase):
    """2026-10-14 08:05 KST 아침 메일(런 38481504047) 로그 값 그대로.
    선물·미결제약정·수급이 개장 전 빈 값(+0.00, asof=당일)인데 '중립'으로 집계됐다."""

    NOW = pytz.timezone('Asia/Seoul').localize(datetime(2026, 10, 14, 8, 5))

    def _brief(self, investors: list[dict]) -> dict:
        return {
            'indices': [
                {'symbol': '^GSPC', 'pct': -0.17},
                {'symbol': '^IXIC', 'pct': -0.17},
                {'symbol': '^DJI', 'pct': -0.17},
                {'symbol': '^VIX', 'pct': 0.39},
            ],
            'macro': [
                {'symbol': 'CL=F', 'pct': 0.54},
                {'symbol': '^TNX', 'pct': 0.0, 'change': -0.023},
                {'symbol': 'KRW=X', 'pct': 0.39},
                # SKHY 환율보정치 −2.79 = SKHY + 원/달러
                {'symbol': 'SKHY', 'pct': -3.18},
            ],
            'kr_night_futures': {'pct': 1.71},
            'kr_indices': [{'label': '코스피200 선물', 'pct': 0.0,
                            'traded_at': '2026-10-14T08:00:00+09:00'}],
            'kr_open_interest': {'open_interest': 0, 'open_interest_change': 0},
            'kr_investors': investors,
        }

    def test_preopen_skips_today_investor_row(self):
        rows = [{'stck_bsop_date': '20261014', 'frgn_ntby_tr_pbmn': '0', 'orgn_ntby_tr_pbmn': '0'},
                {'stck_bsop_date': '20261013', 'frgn_ntby_tr_pbmn': '-1968528', 'orgn_ntby_tr_pbmn': '639923'}]

        self.assertEqual(KISApi.pick_investor_row(rows, '20261014', before_open=True)['stck_bsop_date'], '20261013')
        self.assertEqual(KISApi.pick_investor_row(rows, '20261014', before_open=False)['stck_bsop_date'], '20261014')

    def test_preopen_zero_futures_excluded(self):
        labels = [s['label'] for s in umb._compute_signals(self._brief([]), now=self.NOW)]

        self.assertNotIn('코스피200 선물', labels)
        self.assertNotIn('선물 미결제약정', labels)

    def test_zero_futures_after_open_still_counts(self):
        after_open = pytz.timezone('Asia/Seoul').localize(datetime(2026, 10, 14, 9, 30))
        labels = [s['label'] for s in umb._compute_signals(self._brief([]), now=after_open)]

        self.assertIn('코스피200 선물', labels)

    def test_small_us_and_vix_moves_are_neutral(self):
        by_label = {s['label']: s for s in umb._compute_signals(self._brief([]), now=self.NOW)}

        self.assertEqual(by_label['미국 증시']['direction'], 0)
        self.assertEqual(by_label['VIX(변동성)']['direction'], 0)

    def test_night_futures_outranks_skhy(self):
        signals = umb._compute_signals(self._brief([]), now=self.NOW)

        self.assertEqual(market_signals.group_direction(signals, 'kr_overnight'), 1)
        self.assertEqual(market_signals.excluded_labels(signals), {'SK하이닉스 ADR 야간(환율보정)'})

    def test_skhy_counts_without_night_futures(self):
        brief = self._brief([])
        brief['kr_night_futures'] = None
        signals = umb._compute_signals(brief, now=self.NOW)

        self.assertEqual(market_signals.group_direction(signals, 'kr_overnight'), -1)

    def test_2026_10_14_verdict_uses_prior_day_flows(self):
        # 전일(10-13) 수급 — 10:45 KIS 원본 실측(백만원). 코스피 −1.33조 ▼, 코스닥 +0.13조 ▲
        investors = [{'label': '코스피', 'frgn_net': -1968528, 'orgn_net': 639923, 'date': '20261013'},
                     {'label': '코스닥', 'frgn_net': 101049, 'orgn_net': 28593, 'date': '20261013'}]
        signals = umb._compute_signals(self._brief(investors), now=self.NOW)
        votes = {v['key']: v['direction'] for v in market_signals.group_votes(signals)}

        self.assertEqual(votes, {'us_risk': 0, 'kr_overnight': 1, 'fx': 0, 'commodity': 0,
                                 'kr_flow_kospi': -1, 'kr_flow_kosdaq': 1})
        self.assertEqual(market_signals.verdict(signals), 'bull')


if __name__ == '__main__':
    unittest.main()
