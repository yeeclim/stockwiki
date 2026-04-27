import { fetchStockDataDirect } from './naver-stock.js';
import { checkRateLimit, getClientIp, fail } from './shared.js';

// ── 캐시 ────────────────────────────────────────────────────────
let cache = null;
let cacheTime = 0;
const CACHE_TTL = 5 * 60 * 1000; // 5분

// ── 분석 대상 종목 (인기 KOSPI/KOSDAQ 20선) ─────────────────────
const SEED_STOCKS = [
  { code: '005930', name: '삼성전자' },
  { code: '000660', name: 'SK하이닉스' },
  { code: '035420', name: 'NAVER' },
  { code: '005380', name: '현대차' },
  { code: '000270', name: '기아' },
  { code: '051910', name: 'LG화학' },
  { code: '006400', name: '삼성SDI' },
  { code: '035720', name: '카카오' },
  { code: '068270', name: '셀트리온' },
  { code: '207940', name: '삼성바이오로직스' },
  { code: '096770', name: 'SK이노베이션' },
  { code: '003550', name: 'LG' },
  { code: '034730', name: 'SK' },
  { code: '028260', name: '삼성물산' },
  { code: '105560', name: 'KB금융' },
  { code: '055550', name: '신한지주' },
  { code: '066570', name: 'LG전자' },
  { code: '012330', name: '현대모비스' },
  { code: '017670', name: 'SK텔레콤' },
  { code: '030200', name: 'KT' },
];

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'GET') return fail(res, 405, 'Method not allowed');

  if (!checkRateLimit(getClientIp(req), 30, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
  }

  try {
    const forceRefresh = req.query.refresh === 'true';
    const now = Date.now();

    if (!forceRefresh && cache && (now - cacheTime) < CACHE_TTL) {
      return res.status(200).json({
        success: true,
        total: cache.length,
        count: cache.length,
        data: cache,
        lastUpdated: new Date(cacheTime).toISOString(),
        cached: true,
      });
    }

    const recommendations = await buildRecommendations();

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

// ── 추천 목록 생성 ───────────────────────────────────────────────
async function buildRecommendations() {
  // 20개 중 랜덤 10개 추출 → 매번 다른 종목 노출
  const shuffled = [...SEED_STOCKS].sort(() => Math.random() - 0.5).slice(0, 10);

  const results = await Promise.allSettled(
    shuffled.map(stock => buildOneRecommendation(stock))
  );

  return results
    .filter(r => r.status === 'fulfilled' && r.value !== null)
    .map(r => r.value);
}

async function buildOneRecommendation(stock) {
  try {
    const data = await fetchStockDataDirect(stock.code);
    if (!data || !data.price) return null;

    const price = data.price;
    const changePercent = data.changePercent ?? 0;

    // OpenAI가 설정돼 있으면 AI 분석, 없으면 룰 기반 분석
    let action = ruleBasedAction(changePercent, data);
    let reasons = ruleBasedReasons(stock.name, data);

    const apiKey = process.env.OPENAI_API_KEY;
    if (apiKey) {
      try {
        const ai = await askChatGPT(apiKey, stock.name, price, changePercent);
        if (ai.action) action = ai.action;
        if (ai.reasons?.length) reasons = ai.reasons;
      } catch (e) {
        // AI 실패 시 룰 기반으로 폴백
      }
    }

    return {
      stockName: data.name || stock.name,
      stockCode: stock.code,
      currentPrice: price,
      changePercent,
      changeAmount: data.change ?? 0,
      previousClose: data.previousClose ?? null,
      priceSource: data.source ?? 'naver-finance',
      action,
      reasons,
      targetPrice: Math.round(price * 1.15),
      postedAt: new Date().toISOString(),
      likes: 0,
      comments: 0,
      shares: 0,
      dayTrading: tradingStrategy(price, 'day'),
      swingTrading: tradingStrategy(price, 'swing'),
      longTerm: tradingStrategy(price, 'long'),
    };
  } catch (e) {
    return null;
  }
}

// ── 룰 기반 추천 ─────────────────────────────────────────────────
function ruleBasedAction(changePercent, data) {
  if (changePercent >= 3) return 'Buy';
  if (changePercent <= -3) return 'Watch';
  if (changePercent >= 1) return 'Buy';
  if (changePercent <= -1) return 'Hold';
  return 'Hold';
}

function ruleBasedReasons(name, data) {
  const cp = data.changePercent ?? 0;
  const trend = cp >= 0 ? '상승' : '하락';
  return [
    `${name} 당일 ${Math.abs(cp).toFixed(2)}% ${trend} 중`,
    `거래량: ${(data.volume ?? 0).toLocaleString()}주`,
    'AI 분석 키가 설정되면 심층 분석이 제공됩니다',
  ];
}

// ── OpenAI 분석 ──────────────────────────────────────────────────
async function askChatGPT(apiKey, name, price, changePercent) {
  const prompt = `${name} 주식 현재가 ₩${price.toLocaleString()}, 등락률 ${changePercent.toFixed(2)}%.
투자 의견을 Buy/Hold/Watch/Sell 중 하나로 첫 단어에 쓰고, 이유를 2문장 이내로 답하세요.`;

  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'gpt-3.5-turbo',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 200,
    }),
  });

  if (!res.ok) throw new Error(`OpenAI ${res.status}`);

  const json = await res.json();
  const text = json.choices?.[0]?.message?.content ?? '';

  const actionMap = { buy: 'Buy', hold: 'Hold', watch: 'Watch', sell: 'Sell' };
  const firstWord = text.trim().split(/\s+/)[0].toLowerCase().replace(/[^a-z]/g, '');
  const action = actionMap[firstWord] ?? 'Watch';
  const sentences = text.split(/(?<=[.?!])\s+/).filter(s => s.length > 5).slice(0, 3);

  return { action, reasons: sentences.length ? sentences : null };
}

// ── 투자 전략 ────────────────────────────────────────────────────
function tradingStrategy(price, type) {
  const configs = {
    day:   { buy: 0.995, sell: 1.030, stop: 0.980, period: '1~3일',      ret: 3.0 },
    swing: { buy: 0.985, sell: 1.080, stop: 0.960, period: '1주~1개월',  ret: 8.5 },
    long:  { buy: 1.000, sell: 1.200, stop: 0.930, period: '3개월~1년',  ret: 20.0 },
  };
  const c = configs[type];
  return {
    buyPrice: Math.round(price * c.buy),
    sellPrice: Math.round(price * c.sell),
    stopLoss: Math.round(price * c.stop),
    period: c.period,
    expectedReturn: c.ret,
  };
}
