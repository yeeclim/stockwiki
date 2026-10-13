"""시장 신호 판정 회귀 테스트 — 극단일에 상식과 반대 판정이 나오지 않는지.

    cd trading && python -m unittest discover -s tests -t .
"""
import unittest
from datetime import datetime

import pytz

import market_signals
import us_market_brief as umb


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

    def test_archived_signals_without_value_still_count(self):
        # value 필드가 없던 옛 brief_json
        signals = [{'label': '코스피200 선물', 'direction': -1}, {'label': '국제유가(WTI)', 'direction': 1}]

        self.assertEqual(market_signals.verdict(signals), 'neutral')


if __name__ == '__main__':
    unittest.main()
