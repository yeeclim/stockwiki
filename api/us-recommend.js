// api/us-recommend.js
// Yahoo Finance 비공식 API로 미국 주식 추천 (API 키 불필요)

const MAJOR_SYMBOLS = [
  'AAPL', 'MSFT', 'NVDA', 'GOOGL', 'AMZN', 'META', 'TSLA', 'AVGO',
  'LLY',  'JPM',  'UNH',  'V',    'XOM',  'MA',   'JNJ',  'PG',
  'HD',   'COST', 'MRK',  'ABBV', 'AMD',  'NFLX', 'CRM',  'BAC',
  'CVX',  'PEP',  'TMO',  'WMT',  'ORCL', 'ACN',
];

const MIN_MARKET_CAP = 50_000_000_000; // $500억 이상 대형주

let cache = null;
let cacheTime = 0;
const CACHE_TTL = 10 * 60 * 1000; // 10분

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  try {
    const now = Date.now();
    if (cache && now - cacheTime < CACHE_TTL) {
      return res.status(200).json({ success: true, data: cache, cached: true });
    }

    // Step 1: 쿠키 + 크럼 획득
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

    // Step 2: 시세 조회
    const symbols = MAJOR_SYMBOLS.join(',');
    const url = `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${symbols}&crumb=${encodeURIComponent(crumb)}&fields=shortName,regularMarketPrice,regularMarketChangePercent,regularMarketVolume,marketCap,fiftyDayAverage,twoHundredDayAverage,fiftyTwoWeekHigh,fiftyTwoWeekLow`;

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

    const recommendations = quotes
      .filter(q => q.regularMarketPrice && q.marketCap >= MIN_MARKET_CAP)
      .map(q => {
        const price   = q.regularMarketPrice ?? 0;
        const ma50    = q.fiftyDayAverage ?? 0;
        const ma200   = q.twoHundredDayAverage ?? 0;
        const chgPct  = q.regularMarketChangePercent ?? 0;
        const vol     = q.regularMarketVolume ?? 0;
        const hi52w   = q.fiftyTwoWeekHigh ?? 0;

        const score = calcScore(price, ma50, ma200, chgPct, vol, hi52w);
        const action = determineAction(price, ma50, ma200, score);
        const reasons = buildReasons(price, ma50, ma200, chgPct, vol, hi52w);

        return {
          symbol: q.symbol,
          name: q.shortName ?? q.symbol,
          price,
          changePercent: chgPct,
          volume: vol,
          marketCap: q.marketCap,
          ma50,
          ma200,
          yearHigh: hi52w,
          yearLow: q.fiftyTwoWeekLow ?? 0,
          score,
          action,
          reasons,
        };
      })
      .filter(s => s.action === 'Buy')
      .sort((a, b) => b.score - a.score)
      .slice(0, 20);

    cache = recommendations;
    cacheTime = now;

    return res.status(200).json({ success: true, data: recommendations, cached: false });

  } catch (error) {
    console.error('US 추천 API 오류:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
}

function calcScore(price, ma50, ma200, chgPct, vol, hi52w) {
  let score = 30;

  // 이평선 신호 (최대 50점)
  if (ma50 > 0 && ma200 > 0) {
    if (price > ma50 && price > ma200 && ma50 > ma200) score += 50; // 골든크로스
    else if (price > ma50 && price > ma200)             score += 38;
    else if (price > ma50 && ma50 > ma200)              score += 30;
    else if (price > ma50)                              score += 20;
    else if (price < ma50 && price < ma200)             score -= 15;
  } else if (ma50 > 0) {
    score += price > ma50 ? 20 : -10;
  }

  // 모멘텀 (최대 20점)
  if      (chgPct >= 3)  score += 20;
  else if (chgPct >= 1)  score += 12;
  else if (chgPct >= 0)  score += 5;
  else if (chgPct >= -2) score -= 5;
  else                   score -= 15;

  // 거래량 (최대 15점)
  if      (vol > 10000000) score += 15;
  else if (vol > 5000000)  score += 10;
  else if (vol > 1000000)  score += 5;

  // 52주 고가 근접 (최대 10점)
  if (hi52w > 0 && price > 0) {
    const ratio = price / hi52w;
    if      (ratio >= 0.95) score += 10;
    else if (ratio >= 0.85) score += 5;
  }

  return Math.min(100, Math.max(0, score));
}

function determineAction(price, ma50, ma200, score) {
  if (ma50 > 0 && price < ma50) return 'Hold'; // 단기 이평선 아래면 제외
  if (score >= 50) return 'Buy';
  return 'Hold';
}

function buildReasons(price, ma50, ma200, chgPct, vol, hi52w) {
  const reasons = [];

  if (ma50 > 0 && ma200 > 0) {
    if (price > ma50 && price > ma200 && ma50 > ma200)
      reasons.push(`골든크로스 + 현재가 MA50·MA200 상회 — 강한 상승 추세`);
    else if (price > ma50 && price > ma200)
      reasons.push(`현재가 MA50(${ma50.toFixed(1)})·MA200(${ma200.toFixed(1)}) 상회 — 중장기 상승 구간`);
    else if (price > ma50)
      reasons.push(`현재가 MA50(${ma50.toFixed(1)}) 상회 — 단기 상승 모멘텀`);
  }

  if      (chgPct >= 3) reasons.push(`오늘 +${chgPct.toFixed(2)}% 강한 상승 모멘텀`);
  else if (chgPct >= 1) reasons.push(`오늘 +${chgPct.toFixed(2)}% 안정적 상승`);

  if      (vol > 10000000) reasons.push(`거래량 ${(vol/1000000).toFixed(0)}M — 유동성 우수`);
  else if (vol > 5000000)  reasons.push(`거래량 ${(vol/1000000).toFixed(0)}M — 활발한 매수세`);

  if (hi52w > 0 && price / hi52w >= 0.95)
    reasons.push(`52주 고가($${hi52w.toFixed(0)}) 근접 — 강한 상승 흐름`);

  if (reasons.length === 0) reasons.push('시장 주도 대형주 — 이평선 기준 관심 종목');
  return reasons;
}
