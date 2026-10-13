import unittest

from kis_api import KISApi


class InvestorRowTest(unittest.TestCase):
    def test_uses_amount_not_quantity(self):
        # 수량은 순매수, 금액은 순매도 — 대형주를 팔고 저가주를 산 날
        row = {'stck_bsop_date': '20261013',
               'frgn_ntby_qty': '5000000', 'frgn_ntby_tr_pbmn': '-1971500',
               'orgn_ntby_qty': '100000', 'orgn_ntby_tr_pbmn': '518500',
               'prsn_ntby_qty': '-5100000', 'prsn_ntby_tr_pbmn': '1427100'}
        parsed = KISApi.parse_investor_row(row)

        self.assertLess(parsed['frgn_net'] + parsed['orgn_net'], 0)
        self.assertEqual(parsed['date'], '20261013')


if __name__ == '__main__':
    unittest.main()
