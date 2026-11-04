"""모멘텀 순위 — 지표 정의·결측 처리·극단 케이스.

    cd trading && python -m unittest discover -s tests -t .
"""
import unittest
from datetime import datetime

import pandas as pd

import momentum_rank as mr


def _series(start: float, end: float, n: int = 260) -> list[float]:
    return [start + (end - start) * i / (n - 1) for i in range(n)]


class FeaturesTest(unittest.TestCase):
    def test_definitions(self):
        closes = _series(100, 200)
        f = mr.features(closes)

        self.assertAlmostEqual(f['mom12_1'], closes[-21] / closes[-251] - 1)
        self.assertAlmostEqual(f['high52'], 1.0)   # 꾸준한 상승 = 지금이 최고가

    def test_short_history_is_excluded_not_zero(self):
        # 신규 상장 등 이력 부족은 0%(중립)으로 순위에 넣지 않는다
        self.assertIsNone(mr.features(_series(100, 200, n=250)))

    def test_crash_has_low_high52(self):
        closes = _series(100, 200, n=240) + _series(200, 100, n=20)

        self.assertAlmostEqual(mr.features(closes)['high52'], 0.5)


class RankTest(unittest.TestCase):
    def test_extreme_riser_first_crash_last(self):
        feats = {
            'UP': mr.features(_series(100, 400)),
            'FLAT': mr.features(_series(100, 100)),
            'CRASH': mr.features(_series(100, 300, n=200) + _series(300, 60, n=60)),
        }
        order = [c for c, _ in mr.rank(feats, top_n=3)]

        self.assertEqual(order[0], 'UP')
        self.assertEqual(order[-1], 'CRASH')

    def test_top_n_limit(self):
        feats = {f'{i:06d}': {'mom12_1': i / 100, 'high52': 0.5 + i / 400} for i in range(50)}

        self.assertEqual(len(mr.rank(feats, top_n=20)), 20)


class CompletedRowsTest(unittest.TestCase):
    DF = pd.DataFrame({'Close': [1, 2]}, index=pd.to_datetime(['2026-11-04', '2026-11-05']))

    def test_preopen_drops_today_row(self):
        out = mr._completed_rows(self.DF, datetime(2026, 11, 5, 6, 0, tzinfo=mr.KST))

        self.assertEqual(len(out), 1)

    def test_after_close_keeps_today_row(self):
        out = mr._completed_rows(self.DF, datetime(2026, 11, 5, 16, 0, tzinfo=mr.KST))

        self.assertEqual(len(out), 2)


if __name__ == '__main__':
    unittest.main()
