// api/us-recommend.js
// 미국 주식 AI 추천 — 하드코딩 30종목 대신 전체 NASDAQ/NYSE/AMEX 스크리닝 결과 사용
// trading/screen_us_broad.py가 매일 upsert하는 Supabase us_screening_results
// (국내 strategy._score_entry와 동일 10점 기준, BUY_THRESHOLD=6)를 그대로 읽고,
// 현재가/등락률만 Yahoo Finance에서 실시간으로 보강한다.

const SUPABASE_URL = process.env.SUPABASE_URL?.trim();
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.replace(/\s+/g, '');

let cache = null;
let cacheTime = 0;
const CACHE_TTL = 10 * 60 * 1000; // 10분

// AI 미국주식 추천 화면 전용 시총 하한선 — screen_us_broad.py의 스크리닝 통과 기준(4천억원, 약 $3억)보다
// 높게 잡아 대형주 위주로만 노출 (스크리닝 자체 기준은 건드리지 않음)
const MIN_DISPLAY_MARKET_CAP_USD = 1_000_000_000; // $10억(1B)

// AI 미국주식 추천 화면 전용 점수 하한선 — strategy.py BUY_THRESHOLD(6점)보다 높게 잡아
// 상위권 종목만 노출 (스크리닝 자체 통과 기준은 건드리지 않음)
const MIN_DISPLAY_SCORE = 8; // 10점 만점

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

    const recommendations = await buildFromScreening();

    if (recommendations.length > 0) {
      cache = recommendations;
      cacheTime = now;
    }

    return res.status(200).json({ success: true, data: recommendations, cached: false });

  } catch (error) {
    console.error('US 추천 API 오류:', error);
    return res.status(500).json({ success: false, error: '서버 오류가 발생했습니다' });
  }
}

// ── 스크리닝 결과 조회 ───────────────────────────────────────────────────────
async function fetchScreeningResults() {
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    console.error('us-recommend: Supabase 환경변수 없음');
    return [];
  }
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/us_screening_results?pass=eq.true&market_cap_usd=gte.${MIN_DISPLAY_MARKET_CAP_USD}&score=gte.${MIN_DISPLAY_SCORE}&order=score.desc&limit=20`,
      { headers: { apikey: SUPABASE_KEY, Authorization: `Bearer ${SUPABASE_KEY}` } }
    );
    if (!res.ok) {
      console.error(`us_screening_results 조회 실패: ${res.status}`);
      return [];
    }
    return await res.json();
  } catch (e) {
    console.error('us_screening_results 조회 오류:', e);
    return [];
  }
}

// ── Yahoo Finance 실시간 시세 (표시용 보강) ─────────────────────────────────
async function fetchLiveQuotes(symbols) {
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

// ── 스크리닝 결과 + 실시간 시세 결합 ─────────────────────────────────────────
async function buildFromScreening() {
  const rows = await fetchScreeningResults();
  if (!rows.length) return [];

  const quotes = await fetchLiveQuotes(rows.map(r => r.stock_code));

  return rows
    .map(row => {
      const q = quotes[row.stock_code];
      const price = q?.regularMarketPrice ?? row.price ?? 0;
      if (!price) return null;

      return {
        symbol: row.stock_code,
        name: q?.shortName ?? row.stock_name,
        price,
        changePercent: q?.regularMarketChangePercent ?? 0,
        volume: q?.regularMarketVolume ?? 0,
        marketCap: q?.marketCap ?? row.market_cap_usd ?? 0,
        ma50: q?.fiftyDayAverage ?? null,
        ma200: q?.twoHundredDayAverage ?? null,
        yearHigh: q?.fiftyTwoWeekHigh ?? 0,
        yearLow: q?.fiftyTwoWeekLow ?? 0,
        score: row.score,
        action: scoreToAction(row.score),
        reasons: buildReasons(row, q),
        exchange: row.sector,
      };
    })
    .filter(Boolean)
    .sort((a, b) => b.score - a.score);
}

// screen_us_broad.py 기준 — 10점 만점, BUY_THRESHOLD(6점) 이상만 us_screening_results.pass=true로 저장됨
function scoreToAction(score) {
  if (score >= 8) return 'Buy';
  if (score >= 6) return 'Watch';
  return 'Hold';
}

function buildReasons(row, q) {
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
