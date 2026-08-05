// api/us-recommend.js
// 미국 주식 AI 추천 — 하드코딩 30종목 대신 전체 NASDAQ/NYSE/AMEX 스크리닝 결과 사용
// trading/screen_us_broad.py가 매일 upsert하는 Supabase us_screening_results
// (국내 strategy._score_entry와 동일 10점 기준, BUY_THRESHOLD=6)를 그대로 읽고,
// 현재가/등락률만 Yahoo Finance에서 실시간으로 보강한다.

import { fetchLiveQuotes, scoreToAction, buildReasons } from './_us-recommend-shared.js';

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
// 8점 이상은 실제 일별 스캔에서 거의 나오지 않는 수준이라(대부분 6.5~7.5점대) 7점으로 설정
const MIN_DISPLAY_SCORE = 7; // 10점 만점

// screen_us_broad.py는 그날의 상위 60개만 upsert하고 순위 밖으로 밀린 종목은
// 갱신/삭제하지 않으므로, 표시 단계에서 오래된(3일 초과) 결과는 걸러낸다
const MAX_SCREENED_AGE_DAYS = 3;

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
    const cutoff = new Date(Date.now() - MAX_SCREENED_AGE_DAYS * 24 * 60 * 60 * 1000).toISOString();
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/us_screening_results?pass=eq.true&market_cap_usd=gte.${MIN_DISPLAY_MARKET_CAP_USD}&score=gte.${MIN_DISPLAY_SCORE}&screened_at=gte.${cutoff}&order=score.desc&limit=20`,
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
