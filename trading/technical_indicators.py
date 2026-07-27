"""
공용 기술적 "바닥 확인" 지표 — 국내(kis_api.py)·미국(us_market_data.py) 공통 재사용.
동일 조건을 두 시장에 똑같이 적용하기 위해 계산 로직을 한 곳에 모아둔다.

모든 함수는 종가/거래량 리스트를 과거→최근(오름차순) 순서로 받는다.
"""


def rsi_series(closes: list[float], period: int = 14) -> list[float]:
    if len(closes) < period + 1:
        return []
    out = []
    for i in range(period, len(closes)):
        window = closes[i - period:i + 1]
        deltas = [window[j + 1] - window[j] for j in range(period)]
        gains = [d for d in deltas if d > 0]
        losses = [-d for d in deltas if d < 0]
        avg_gain = sum(gains) / period
        avg_loss = sum(losses) / period
        if avg_loss == 0:
            out.append(100.0)
        else:
            rs = avg_gain / avg_loss
            out.append(100 - 100 / (1 + rs))
    return out


def rsi_oversold_rebound(closes: list[float], period: int = 14, lookback: int = 10,
                          rebound_ceiling: float = 50.0) -> tuple[bool, float | None]:
    """RSI가 최근 lookback거래일 내에 30 밑으로 내려갔다가 지금 막 30~rebound_ceiling
    구간으로 회복했는지. 상한을 두는 이유: 상한이 없으면 몇 주 전 과매도였다가 이미
    많이 반등해 RSI 70~80대까지 온 종목(더는 "바닥 확인" 구간이 아님)도 걸려버린다.
    반환: (회복 여부, 현재 RSI)
    """
    rsis = rsi_series(closes, period)
    if not rsis:
        return False, None
    now = rsis[-1]
    if len(rsis) < lookback + 1:
        return False, now
    recent_min = min(rsis[-(lookback + 1):-1])
    return bool(recent_min < 30 and 30 <= now <= rebound_ceiling), now


def basing_near_low(closes: list[float], window: int = 60, near_pct: float = 8.0,
                     no_new_low_days: int = 10) -> bool:
    """최근 window거래일 저점 대비 near_pct% 이내이고, 최근 no_new_low_days일간
    신저가 갱신이 없으면 '바닥을 다지는 중'으로 판단한다.
    """
    if len(closes) < window:
        return False
    recent_low = min(closes[-window:])
    price = closes[-1]
    near_low = price <= recent_low * (1 + near_pct / 100)
    if not near_low:
        return False

    if len(closes) < window + no_new_low_days:
        return True  # 저점 구간 이전 데이터가 부족하면 근접 여부만으로 판단

    last_low = min(closes[-no_new_low_days:])
    prior_low = min(closes[-window - no_new_low_days:-no_new_low_days])
    return bool(last_low >= prior_low)


def volume_declining(volumes: list[float], recent: int = 5, prior: int = 20) -> bool:
    """최근 recent거래일 평균 거래량이 직전 prior거래일 평균보다 낮으면 매도세 소진으로 본다."""
    if len(volumes) < recent + prior:
        return False
    recent_avg = sum(volumes[-recent:]) / recent
    prior_avg = sum(volumes[-(recent + prior):-recent]) / prior
    if prior_avg == 0:
        return False
    return recent_avg < prior_avg
