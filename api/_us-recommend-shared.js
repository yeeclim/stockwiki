// api/_us-recommend-shared.js
// us-recommend.js / us-sector-recommend.js가 공유하는 Yahoo Finance 실시간 시세 조회 +
// 점수→액션/추천사유 변환 헬퍼. Naver 쪽의 api/_naver-stock.js와 동일한 내부 공용 모듈 컨벤션.

// ── Yahoo Finance 실시간 시세 (표시용 보강) ─────────────────────────────────
export async function fetchLiveQuotes(symbols) {
  if (!symbols.length) return {};
  try {
    const cookieRes = await fetch('https://fc.yahoo.com', {
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36' }
    });
    const rawCookie = cookieRes.headers.get('set-cookie') ?? '';
    const cookie = rawCookie.split(',').map(c => c.split(';')[0].trim()).join('; ');

    const crumbRes = await fetch('https://query1.finance.yahoo.com/v1/test/getcrumb', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36',
        'Cookie': cookie,
      }
    });
    const crumb = await crumbRes.text();

    const url = `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${symbols.join(',')}&crumb=${encodeURIComponent(crumb)}&fields=shortName,regularMarketPrice,regularMarketChangePercent,regularMarketVolume,marketCap,fiftyDayAverage,twoHundredDayAverage,fiftyTwoWeekHigh,fiftyTwoWeekLow`;

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36',
        'Accept': 'application/json',
        'Cookie': cookie,
      }
    });
    if (!response.ok) throw new Error(`Yahoo Finance API 오류: ${response.status}`);

    const data = await response.json();
    const quotes = data?.quoteResponse?.result ?? [];
    const map = {};
    for (const q of quotes) map[q.symbol] = q;
    return map;
  } catch (e) {
    console.error('Yahoo 실시간 시세 조회 실패:', e);
    return {};
  }
}

// screen_us_broad.py 기준 — 10점 만점, BUY_THRESHOLD(6점) 이상만 us_screening_results.pass=true로 저장됨
export function scoreToAction(score) {
  if (score >= 8) return 'Buy';
  if (score >= 6) return 'Watch';
  return 'Hold';
}

export function buildReasons(row, q) {
  const reasons = [];
  reasons.push(`전체 NASDAQ/NYSE/AMEX 스크리닝 점수 ${row.score}/10점 통과 — 재무비율·이동평균·바닥지표 진입 조건 충족`);

  const cp = q?.regularMarketChangePercent ?? 0;
  if (cp >= 3) reasons.push(`오늘 +${cp.toFixed(2)}% 강한 상승 모멘텀`);
  else if (cp >= 0) reasons.push(`오늘 +${cp.toFixed(2)}% 보합~상승`);
  else reasons.push(`오늘 ${cp.toFixed(2)}% 하락 중 — 진입 타이밍 유의`);

  if (row.sector) reasons.push(`${row.sector} 상장`);
  if (row.screened_at) {
    const d = new Date(row.screened_at);
    reasons.push(`최근 스크리닝: ${d.toLocaleDateString('ko-KR')} 기준`);
  }
  return reasons;
}
