import { fetchStockDataDirect } from './_naver-stock.js';
import { checkRateLimit, getClientIp, validateInt, fail } from './_shared.js';

const SUPABASE_URL = process.env.SUPABASE_URL?.trim();
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.replace(/\s+/g, '');

// ── 캐시 ────────────────────────────────────────────────────────
let cache = null;
let cacheTime = 0;
const CACHE_TTL = 5 * 60 * 1000; // 5분

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'GET') return fail(res, 405, 'Method not allowed');

  if (!checkRateLimit(getClientIp(req), 20, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
  }

  try {
    const forceRefresh = req.query.refresh === 'true';
    const limit = validateInt(req.query.limit, { min: 1, max: 50 }) ?? 20;
    const now = Date.now();

    if (!forceRefresh && cache && (now - cacheTime) < CACHE_TTL) {
      return res.status(200).json({
        success: true,
        total: cache.length,
        count: cache.length,
        data: cache.slice(0, limit),
        lastUpdated: new Date(cacheTime).toISOString(),
        cached: true,
      });
    }

    const recommendations = await buildFromScreening(limit);

    if (recommendations.length > 0) {
      cache = recommendations;
      cacheTime = now;
    }

    return res.status(200).json({
      success: true,
      total: recommendations.length,
      count: recommendations.length,
      data: recommendations,
      lastUpdated: new Date().toISOString(),
      cached: false,
    });

  } catch (err) {
    console.error('ai-recommend-list error:', err);
    return fail(res, 500, '서버 오류가 발생했습니다.');
  }
}

// ── 스크리닝 결과 조회 (전종목 스캔 → screen_broad.py → screen.py 파이프라인 결과) ──
// screening_results는 stock_code가 PK라 종목당 최신 스크리닝 1건만 남아있고,
// screen.py가 매일 08:50 KST에 upsert하므로 이 테이블을 그대로 읽으면 항상 최신이다.
async function fetchScreeningResults(limit) {
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    console.error('ai-recommend-list: Supabase 환경변수 없음');
    return [];
  }
  try {
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/screening_results?pass=eq.true&order=score.desc&limit=${limit}`,
      {
        headers: {
          apikey: SUPABASE_KEY,
          Authorization: `Bearer ${SUPABASE_KEY}`,
        },
      }
    );
    if (!res.ok) {
      console.error(`screening_results 조회 실패: ${res.status}`);
      return [];
    }
    return await res.json();
  } catch (e) {
    console.error('screening_results 조회 오류:', e);
    return [];
  }
}

// ── 스크리닝 결과 + 실시간 시세 결합 ─────────────────────────────
async function buildFromScreening(limit) {
  const rows = await fetchScreeningResults(limit);
  if (!rows.length) return [];

  const enriched = await Promise.allSettled(
    rows.map(async row => {
      const data = await fetchStockDataDirect(row.stock_code);
      return { row, data };
    })
  );

  return enriched
    .filter(r => r.status === 'fulfilled' && r.value.data && r.value.data.price)
    .map(r => buildItem(r.value.row, r.value.data));
}

// screen.py 기준 — 13점 만점, BUY_THRESHOLD(8점) 이상만 screening_results.pass=true로 저장됨
function scoreToAction(score) {
  if (score >= 11) return 'Buy';
  if (score >= 8) return 'Watch';
  return 'Hold';
}

function targetMultiplier(action) {
  if (action === 'Buy')   return 1.15;
  if (action === 'Watch') return 1.08;
  return 1.05;
}

function buildItem(row, data) {
  const cp = data.changePercent ?? 0;
  const price = data.price ?? row.price ?? 0;
  const action = scoreToAction(row.score);

  return {
    stockName: row.stock_name,
    stockCode: row.stock_code,
    currentPrice: price,
    changePercent: cp,
    changeAmount: data.change ?? 0,
    previousClose: data.previousClose ?? null,
    priceSource: data.source ?? 'naver-finance',
    action,
    reasons: buildReasons(row, data),
    targetPrice: Math.round(price * targetMultiplier(action)),
    postedAt: row.screened_at || new Date().toISOString(),
    likes: 0,
    comments: 0,
    shares: 0,
    score: row.score,
    sector: row.sector,
    dayTrading:   tradingStrategy(price, 'day'),
    swingTrading: tradingStrategy(price, 'swing'),
    longTerm:     tradingStrategy(price, 'long'),
  };
}

// ── 이유 생성 (스크리닝 결과 기반) ────────────────────────────────
function buildReasons(row, data) {
  const cp = data.changePercent ?? 0;
  const reasons = [];

  reasons.push(`전종목 스크리닝 점수 ${row.score}/13점 통과 — 재무비율·이동평균·바닥지표 진입 조건 충족`);

  if (cp >= 3) {
    reasons.push(`오늘 +${cp.toFixed(2)}% 강한 상승 모멘텀`);
  } else if (cp >= 0) {
    reasons.push(`오늘 +${cp.toFixed(2)}% 보합~상승`);
  } else {
    reasons.push(`오늘 ${cp.toFixed(2)}% 하락 중 — 진입 타이밍 유의`);
  }

  if (row.sector) {
    reasons.push(`${row.sector} 섹터`);
  }

  if (row.screened_at) {
    const d = new Date(row.screened_at);
    reasons.push(`최근 스크리닝: ${d.toLocaleDateString('ko-KR')} 기준`);
  }

  return reasons;
}

// ── 투자 전략 ────────────────────────────────────────────────────
function tradingStrategy(price, type) {
  const configs = {
    day:   { buy: 0.995, sell: 1.030, stop: 0.980, period: '1~3일',     ret: 3.0 },
    swing: { buy: 0.985, sell: 1.080, stop: 0.960, period: '1주~1개월', ret: 8.5 },
    long:  { buy: 1.000, sell: 1.200, stop: 0.930, period: '3개월~1년', ret: 20.0 },
  };
  const c = configs[type];
  return {
    buyPrice:       Math.round(price * c.buy),
    sellPrice:      Math.round(price * c.sell),
    stopLoss:       Math.round(price * c.stop),
    period:         c.period,
    expectedReturn: c.ret,
  };
}
