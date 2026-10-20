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
           krw_pct: float, fut_pct: float | None, flow_net: int, sox_pct: float = 0.0) -> dict:
    kr_indices = []
    if fut_pct is not None:
        kr_indices.append({'label': '코스피200 선물', 'pct': fut_pct, 'traded_at': _now_kst_iso()})

    return {
        'indices': [
            {'symbol': '^GSPC', 'pct': us_pct},
            {'symbol': '^IXIC', 'pct': us_pct},
            {'symbol': '^DJI', 'pct': us_pct},
            {'symbol': '^VIX', 'pct': vix_pct},
            {'symbol': '^SOX', 'pct': sox_pct},
        ],
        'macro': [
            {'symbol': 'CL=F', 'pct': oil_pct},
            {'symbol': '^TNX', 'pct': 0.0, 'change': 0.0},
            {'symbol': 'KRW=X', 'pct': krw_pct},
            {'symbol': 'EWY', 'pct': ewy_pct},
            {'symbol': 'SKHY', 'pct': skhy_pct},
        ],
        'kr_indices': kr_indices,
        # 합성 극단값 케이스 — EWY·SKHY 등락을 그대로 갭으로 보도록 전일 국내 등락 0
        'kr_last_session': {'KOSPI': 0.0, '000660': 0.0},
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
        # 장전·야간선물 없음 — EWY 환율보정 −3.7%, SOX −3% 로 예상 갭 계산
        brief = _brief(us_pct=-0.04, vix_pct=2.49, oil_pct=-1.06, ewy_pct=-4.02, skhy_pct=-4.02,
                       krw_pct=0.30, fut_pct=None, flow_net=100, sox_pct=-3.0)
        signals = umb._compute_signals(brief)

        self.assertEqual(market_signals.verdict(signals), 'bear')

    def test_big_rally_is_bull(self):
        # 대칭 케이스 — 큰 갭 상승인데 유가 급등·수급 매도가 표를 상쇄하는 날
        brief = _brief(us_pct=0.2, vix_pct=-1.0, oil_pct=2.5, ewy_pct=3.5, skhy_pct=3.0,
                       krw_pct=0.5, fut_pct=4.0, flow_net=-100, sox_pct=2.0)
        signals = umb._compute_signals(brief)

        self.assertEqual(market_signals.verdict(signals), 'bull')

    def test_small_expected_gap_is_neutral_despite_votes(self):
        # 미국·VIX·수급이 전부 강세 표여도 예상 갭이 ±0.3% 안쪽이면 보합
        brief = _brief(us_pct=0.5, vix_pct=-5.0, oil_pct=-2.0, ewy_pct=-0.6, skhy_pct=-0.5,
                       krw_pct=0.0, fut_pct=None, flow_net=100, sox_pct=0.0)
        signals = umb._compute_signals(brief)

        self.assertGreater(market_signals.signal_counts(signals)[0], 2)
        self.assertEqual(market_signals.verdict(signals), 'neutral')
        self.assertTrue(market_signals.verdict_reason(signals).startswith('예상 시가 갭'))

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

    def test_archived_signals_without_value_are_unknown(self):
        # value 필드가 없던 옛 brief_json — 예상 갭을 못 내면 중립이 아니라 보류
        signals = [{'label': '코스피200 선물', 'direction': -1}, {'label': '국제유가(WTI)', 'direction': 1}]

        self.assertEqual(market_signals.verdict(signals), 'unknown')


class ExpectedGapTest(unittest.TestCase):
    """예상 시가 갭 = 0.042 + 0.703 × 야간선물 (2026-10-20 백테스트). 다른 지표 표는 무시한다."""

    def _signals(self, night: float | None, **others: float) -> list[dict]:
        signals = [{'label': label, 'direction': 1 if v > 0 else -1, 'value': v} for label, v in others.items()]
        if night is not None:
            signals.append({'label': '코스피200 야간선물', 'direction': 0, 'value': night})

        return signals

    def test_2026_10_19_night_crash_overrides_bullish_votes(self):
        # 실측 야간 −3.50%. 미국·수급이 전부 강세여도 약세
        signals = self._signals(-3.50, **{'미국 증시': 1.2, 'VIX(변동성)': -8.0, '코스피 수급(외국인+기관)': 900000})

        self.assertEqual(market_signals.verdict(signals), 'bear')
        self.assertAlmostEqual(market_signals.expected_gap(signals)['value'], 0.042 - 0.703 * 3.50, places=3)

    def test_extreme_night_rally_is_bull(self):
        signals = self._signals(6.0, **{'미국 증시': -1.5, '국제유가(WTI)': 4.0})

        self.assertEqual(market_signals.verdict(signals), 'bull')

    def test_2026_10_20_small_night_move_is_neutral(self):
        # 실측 야간 −0.13% → 예상 −0.05% 보합 (실제 시가 −0.60%)
        signals = self._signals(-0.13, **{'미국 증시': 0.48})

        self.assertEqual(market_signals.verdict(signals), 'neutral')
        self.assertEqual(market_signals.headline(signals), '예상 시가 갭 -0.05% (보합)')

    def test_fallback_uses_ewy_and_sox(self):
        signals = self._signals(None, **{'야간 한국물(EWY·환율보정)': -3.0, '미국 반도체(SOX)': -4.0})
        gap = market_signals.expected_gap(signals)

        self.assertAlmostEqual(gap['value'], 0.136 - 0.165 * 3.0 - 0.218 * 4.0, places=3)
        self.assertEqual(market_signals.verdict(signals), 'bear')

    def test_night_futures_outranks_fallback(self):
        signals = self._signals(1.0, **{'야간 한국물(EWY·환율보정)': -3.0, '미국 반도체(SOX)': -4.0})

        self.assertEqual(market_signals.verdict(signals), 'bull')

    def test_no_gap_inputs_is_unknown_not_neutral(self):
        signals = self._signals(None, **{'미국 증시': 1.5, '국제유가(WTI)': -2.0})

        self.assertEqual(market_signals.verdict(signals), 'unknown')
        self.assertEqual(market_signals.verdict_label(signals), '판정 보류')

    def test_sox_signal_from_brief(self):
        brief = {'indices': [{'symbol': '^SOX', 'pct': -4.2}]}
        sox = next(s for s in umb._compute_signals(brief) if s['label'] == '미국 반도체(SOX)')

        self.assertEqual((sox['direction'], sox['value']), (-1, -4.2))


class IntradayVerdictTest(unittest.TestCase):
    """장이 열리면 당일 코스피200 선물 방향이 판정 — 간접 지표 투표로 뒤집지 않는다."""

    def test_2026_10_14_1035_is_bull(self):
        # 실측(런 38496472489): 선물 +1.04%·야간 +1.71% 인데 WTI +1.15%·장중 수급 ▼▼ 로 '약세 우세'가 나왔다
        signals = [
            {'label': '코스피200 야간선물', 'direction': 1, 'value': 1.71},
            {'label': '국제유가(WTI)', 'direction': -1, 'value': 1.15},
            {'label': '코스피200 선물', 'direction': 1, 'value': 1.04},
            {'label': '선물 미결제약정', 'direction': 1, 'value': 127},
            {'label': '코스피 수급(외국인+기관)', 'direction': -1, 'value': -57451},
            {'label': '코스닥 수급(외국인+기관)', 'direction': -1, 'value': -356518},
        ]

        self.assertEqual(market_signals.signal_counts(signals)[:2], (1, 3))
        self.assertEqual(market_signals.verdict(signals), 'bull')

    def test_small_intraday_move_is_neutral(self):
        signals = [{'label': '코스피200 선물', 'direction': 1, 'value': 0.2},
                   {'label': '국제유가(WTI)', 'direction': -1, 'value': 1.5}]

        self.assertEqual(market_signals.verdict(signals), 'neutral')

    def test_intraday_drop_is_bear(self):
        signals = [{'label': '코스피200 선물', 'direction': -1, 'value': -0.9},
                   {'label': '코스피200 야간선물', 'direction': 1, 'value': 1.2}]

        self.assertEqual(market_signals.verdict(signals), 'bear')


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
            # 10-13 국내 정규장: 코스피 −5.46%, SK하이닉스 −9.28% (네이버 일별 시세)
            'kr_last_session': {'KOSPI': -5.46, '000660': -9.28},
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
        # SKHY −3.18% 에서 전일 국내 −9.28% 를 빼면 밤사이 +6.49% ▲ — 실제 하이닉스 상승 출발
        brief = self._brief([])
        brief['kr_night_futures'] = None
        signals = umb._compute_signals(brief, now=self.NOW)
        skhy = next(s for s in signals if s['label'].startswith('SK하이닉스'))

        self.assertAlmostEqual(skhy['value'], -3.18 + 0.39 + 9.28, places=2)
        self.assertEqual(market_signals.group_direction(signals, 'kr_overnight'), 1)

    def test_ewy_gap_excludes_prior_korean_session(self):
        # 10-14 실측: EWY 정규장 −2.09%, 원/달러 +0.39%, 전일 코스피 −5.46% → +3.76% ▲
        brief = self._brief([])
        brief['kr_night_futures'] = None
        brief['macro'].append({'symbol': 'EWY', 'pct': -2.09})
        ewy = next(s for s in umb._compute_signals(brief, now=self.NOW) if s['label'].startswith('야간 한국물'))

        self.assertAlmostEqual(ewy['value'], 3.76, places=2)
        self.assertEqual(ewy['direction'], 1)

    def test_ewy_skipped_without_prior_session(self):
        brief = self._brief([])
        brief['kr_night_futures'] = None
        brief['kr_last_session'] = {}
        brief['macro'].append({'symbol': 'EWY', 'pct': -2.09})
        labels = [s['label'] for s in umb._compute_signals(brief, now=self.NOW)]

        self.assertNotIn('야간 한국물(EWY·환율보정)', labels)
        self.assertNotIn('SK하이닉스 ADR 야간(환율보정)', labels)

    def test_2026_10_14_verdict_uses_prior_day_flows(self):
        # 전일(10-13) 수급 — 10:45 KIS 원본 실측(백만원). 코스피 −1.33조 ▼, 코스닥 +0.13조 ▲
        investors = [{'label': '코스피', 'frgn_net': -1968528, 'orgn_net': 639923, 'date': '20261013'},
                     {'label': '코스닥', 'frgn_net': 101049, 'orgn_net': 28593, 'date': '20261013'}]
        signals = umb._compute_signals(self._brief(investors), now=self.NOW)
        votes = {v['key']: v['direction'] for v in market_signals.group_votes(signals)}

        self.assertEqual(votes, {'us_risk': 0, 'kr_overnight': 1, 'fx': 0, 'commodity': 0,
                                 'kr_flow_kospi': -1, 'kr_flow_kosdaq': 1})
        self.assertEqual(market_signals.verdict(signals), 'bull')


class AfterHoursTest(unittest.TestCase):
    """08:00 발송 — 미국 현물 마감(05:00 KST) 이후 정보: 지수선물·애프터마켓."""

    def test_us_futures_vote_in_us_risk(self):
        brief = {'indices': [{'symbol': '^GSPC', 'pct': 0.0}, {'symbol': 'ES=F', 'pct': -0.8},
                             {'symbol': 'NQ=F', 'pct': -1.2}]}
        signals = umb._compute_signals(brief)

        self.assertEqual(market_signals.group_direction(signals, 'us_risk'), -1)

    def test_small_us_futures_move_is_neutral(self):
        brief = {'indices': [{'symbol': 'ES=F', 'pct': 0.03}, {'symbol': 'NQ=F', 'pct': 0.08}]}
        fut = next(s for s in umb._compute_signals(brief) if s['label'] == '미국 지수선물(마감 후)')

        self.assertEqual(fut['direction'], 0)

    def test_skhy_includes_after_hours(self):
        # 2026-10-14 원본: SKHY 정규장 −3.19%, 애프터 −0.73%
        brief = {'macro': [{'symbol': 'SKHY', 'pct': -3.19, 'post_pct': -0.73},
                           {'symbol': 'KRW=X', 'pct': 0.0}],
                 'kr_last_session': {'000660': 0.0}}
        skhy = next(s for s in umb._compute_signals(brief) if s['label'].startswith('SK하이닉스'))

        self.assertAlmostEqual(skhy['value'], -3.897, places=2)

    def test_after_hours_shown_in_mail_delta(self):
        row = umb._macro_display({'symbol': 'EWY', 'price': 165.2, 'pct': -2.09, 'post_pct': -0.82})

        self.assertEqual(row['delta_text'], '-2.09% · 애프터 -0.82%')


if __name__ == '__main__':
    unittest.main()
