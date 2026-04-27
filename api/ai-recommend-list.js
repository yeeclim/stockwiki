import { fetchStockDataDirect } from './naver-stock.js';
import { checkRateLimit, getClientIp, fail } from './shared.js';

// ── 캐시 ────────────────────────────────────────────────────────
let cache = null;
let cacheTime = 0;
const CACHE_TTL = 5 * 60 * 1000; // 5분

// ── 스크리닝 대상 종목 (섹터별 분산 50선) ───────────────────────
const UNIVERSE = [
  // 반도체·IT
  { code: '005930', name: '삼성전자',         sector: '반도체' },
  { code: '000660', name: 'SK하이닉스',        sector: '반도체' },
  { code: '066570', name: 'LG전자',            sector: '전자' },
  { code: '009150', name: '삼성전기',          sector: '전자부품' },
  { code: '035420', name: 'NAVER',             sector: 'IT·플랫폼' },
  { code: '035720', name: '카카오',            sector: 'IT·플랫폼' },
  { code: '047810', name: '한국항공우주',      sector: '방산' },
  // 자동차·이차전지
  { code: '005380', name: '현대차',            sector: '자동차' },
  { code: '000270', name: '기아',              sector: '자동차' },
  { code: '012330', name: '현대모비스',        sector: '자동차부품' },
  { code: '051910', name: 'LG화학',            sector: '이차전지' },
  { code: '006400', name: '삼성SDI',           sector: '이차전지' },
  { code: '373220', name: 'LG에너지솔루션',    sector: '이차전지' },
  { code: '096770', name: 'SK이노베이션',      sector: '이차전지' },
  { code: '247540', name: '에코프로비엠',      sector: '이차전지' },
  // 바이오·헬스
  { code: '068270', name: '셀트리온',          sector: '바이오' },
  { code: '207940', name: '삼성바이오로직스',  sector: '바이오' },
  { code: '128940', name: '한미약품',          sector: '제약' },
  { code: '326030', name: '에이비엘바이오',    sector: '바이오' },
  { code: '196170', name: '알테오젠',          sector: '바이오' },
  // 금융·증권
  { code: '105560', name: 'KB금융',            sector: '금융' },
  { code: '055550', name: '신한지주',          sector: '금융' },
  { code: '086790', name: '하나금융지주',      sector: '금융' },
  { code: '316140', name: '우리금융지주',      sector: '금융' },
  { code: '006800', name: '미래에셋증권',      sector: '증권' },
  // 통신·미디어
  { code: '017670', name: 'SK텔레콤',          sector: '통신' },
  { code: '030200', name: 'KT',                sector: '통신' },
  { code: '032640', name: 'LG유플러스',        sector: '통신' },
  // 에너지·화학
  { code: '034730', name: 'SK',                sector: '지주' },
  { code: '003550', name: 'LG',                sector: '지주' },
  { code: '028260', name: '삼성물산',          sector: '건설·지주' },
  { code: '000720', name: '현대건설',          sector: '건설' },
  { code: '010140', name: '삼성중공업',        sector: '조선' },
  { code: '009540', name: 'HD한국조선해양',    sector: '조선' },
  { code: '042660', name: 'HD현대중공업',      sector: '조선' },
  // 소비재·유통
  { code: '139480', name: '이마트',            sector: '유통' },
  { code: '004990', name: '롯데지주',          sector: '유통' },
  { code: '011170', name: '롯데케미칼',        sector: '화학' },
  { code: '010950', name: 'S-Oil',             sector: '정유' },
  { code: '078930', name: 'GS',                sector: '정유·지주' },
  // 철강·소재
  { code: '005490', name: 'POSCO홀딩스',       sector: '철강' },
  { code: '004020', name: '현대제철',          sector: '철강' },
  { code: '010130', name: '고려아연',          sector: '비철금속' },
  // 게임·엔터
  { code: '036570', name: 'NCsoft',            sector: '게임' },
  { code: '263750', name: '펄어비스',          sector: '게임' },
  { code: '041510', name: 'SM엔터테인먼트',    sector: '엔터' },
  { code: '035900', name: 'JYP Ent.',          sector: '엔터' },
  // 방산·항공
  { code: '012450', name: '한화에어로스페이스',sector: '방산' },
  { code: '003490', name: '대한항공',          sector: '항공' },
  { code: '020560', name: '아시아나항공',      sector: '항공' },
];

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

    const recommendations = await screenAndRank();

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

// ── 스크리닝 & 랭킹 ──────────────────────────────────────────────
async function screenAndRank() {
  // 전 종목 병렬 조회 (실패한 종목은 제외)
  const results = await Promise.allSettled(
    UNIVERSE.map(async stock => {
      const data = await fetchStockDataDirect(stock.code);
      if (!data || !data.price) return null;
      return { stock, data };
    })
  );

  const fetched = results
    .filter(r => r.status === 'fulfilled' && r.value !== null)
    .map(r => r.value);

  // 각 종목 점수 계산
  const scored = fetched
    .map(({ stock, data }) => ({
      stock,
      data,
      score: calcScore(data),
    }))
    .filter(item => item.score > 0);

  // 점수 내림차순 정렬 → 상위 10개
  scored.sort((a, b) => b.score - a.score);
  const top = scored.slice(0, 10);

  return top.map(({ stock, data, score }) => buildItem(stock, data, score));
}

// ── 점수 산정 (100점 만점) ───────────────────────────────────────
// · 모멘텀  50점: 오늘 등락률 기반 (상승 폭이 클수록 고점수)
// · 거래량  30점: 거래량이 많을수록 매수세 신뢰도 증가
// · 안정성  20점: 과도한 급등락 없이 건전한 상승
function calcScore(data) {
  const cp = data.changePercent ?? 0;
  const vol = data.volume ?? 0;

  // ① 모멘텀 점수 (상승일 때만 추천 가치 있음)
  let momentumScore;
  if (cp >= 5)       momentumScore = 50;   // 급등 (다소 오버슈팅 위험 있지만 모멘텀 최고)
  else if (cp >= 3)  momentumScore = 47;   // 강한 상승 (가장 이상적)
  else if (cp >= 2)  momentumScore = 40;
  else if (cp >= 1)  momentumScore = 30;
  else if (cp >= 0)  momentumScore = 18;   // 보합
  else if (cp >= -1) momentumScore = 8;    // 소폭 하락
  else               momentumScore = 0;    // 하락 중 → 추천 제외

  // 하락 중인 종목은 점수 자체를 0으로 (필터링용)
  if (cp < -1) return 0;

  // ② 거래량 점수
  let volScore;
  if (vol >= 3_000_000)      volScore = 30;
  else if (vol >= 1_000_000) volScore = 25;
  else if (vol >= 300_000)   volScore = 18;
  else if (vol >= 100_000)   volScore = 12;
  else if (vol >= 30_000)    volScore = 6;
  else                       volScore = 2;

  // ③ 안정성 점수 (1~5% 상승이 가장 이상적, 급등·보합은 감점)
  let stabilityScore;
  const abscp = Math.abs(cp);
  if (abscp >= 1 && abscp <= 5)  stabilityScore = 20;
  else if (abscp < 1)            stabilityScore = 12;  // 너무 평탄
  else if (abscp <= 8)           stabilityScore = 10;  // 다소 급등
  else                           stabilityScore = 4;   // 과급등

  return momentumScore + volScore + stabilityScore;
}

// ── 추천 아이템 생성 ─────────────────────────────────────────────
function buildItem(stock, data, score) {
  const cp = data.changePercent ?? 0;
  const vol = data.volume ?? 0;
  const price = data.price;

  const action = scoreToAction(score, cp);
  const reasons = buildReasons(stock, data, score);

  return {
    stockName: data.name || stock.name,
    stockCode: stock.code,
    currentPrice: price,
    changePercent: cp,
    changeAmount: data.change ?? 0,
    previousClose: data.previousClose ?? null,
    priceSource: data.source ?? 'naver-finance',
    action,
    reasons,
    targetPrice: Math.round(price * targetMultiplier(action)),
    postedAt: new Date().toISOString(),
    likes: 0,
    comments: 0,
    shares: 0,
    score,                          // 디버그용 점수 포함
    sector: stock.sector,
    dayTrading:   tradingStrategy(price, 'day'),
    swingTrading: tradingStrategy(price, 'swing'),
    longTerm:     tradingStrategy(price, 'long'),
  };
}

function scoreToAction(score, cp) {
  if (score >= 75) return 'Buy';
  if (score >= 55) return 'Buy';
  if (score >= 35) return 'Watch';
  return 'Hold';
}

function targetMultiplier(action) {
  if (action === 'Buy')   return 1.15;
  if (action === 'Watch') return 1.08;
  return 1.05;
}

// ── 이유 생성 (데이터 기반) ──────────────────────────────────────
function buildReasons(stock, data, score) {
  const cp = data.changePercent ?? 0;
  const vol = data.volume ?? 0;
  const reasons = [];

  // 모멘텀 근거
  if (cp >= 3) {
    reasons.push(`오늘 +${cp.toFixed(2)}% 강한 상승 모멘텀 — 매수세 우위 확인`);
  } else if (cp >= 1) {
    reasons.push(`오늘 +${cp.toFixed(2)}% 안정적 상승 — 단계적 매수 유효 구간`);
  } else {
    reasons.push(`오늘 ${cp.toFixed(2)}% 보합권 — 추가 모멘텀 확인 후 진입 권장`);
  }

  // 거래량 근거
  if (vol >= 1_000_000) {
    reasons.push(`거래량 ${vol.toLocaleString()}주 — 시장 관심 집중, 수급 긍정적`);
  } else if (vol >= 300_000) {
    reasons.push(`거래량 ${vol.toLocaleString()}주 — 평균 이상 거래 활발`);
  } else {
    reasons.push(`거래량 ${vol.toLocaleString()}주 — 거래 비교적 한산, 변동성 주의`);
  }

  // 섹터 근거
  reasons.push(`${stock.sector} 섹터 — 종합 스크리닝 점수 ${score}점 / 100점`);

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
