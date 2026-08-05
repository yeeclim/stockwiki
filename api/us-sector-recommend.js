// api/us-sector-recommend.js
// Sector별 추천 종목 (미국 주식) — 기존 하드코딩 종목 리스트 대신 us_screening_results를
// 실제 GICS 대분류 섹터(screen_us_broad.py stage4가 채워 넣는 gics_sector)로 그룹핑해 노출.

import { fetchLiveQuotes, scoreToAction, buildReasons } from './_us-recommend-shared.js';

const SUPABASE_URL = process.env.SUPABASE_URL?.trim();
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY?.replace(/\s+/g, '');

let cache = null;
let cacheTime = 0;
const CACHE_TTL = 10 * 60 * 1000; // 10분

// screen_us_broad.py는 top-60만 upsert하므로 오래된 결과는 걸러낸다 (us-recommend.js와 동일 패턴)
const MAX_SCREENED_AGE_DAYS = 3;

// 섹터 브라우즈 뷰는 "top 20 elite" 피드보다 관대한 기준: pass=true(score>=6)만 사용,
// 별도 점수/시총 하한 없음 (한국 테마 페이지 MIN_THEME_SCORE=55/100 "분할매수검토" 등급과 같은 철학)
const SECTOR_CAP = 8; // 섹터당 최대 노출 종목 수

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  try {
    const now = Date.now();
    if (cache && now - cacheTime < CACHE_TTL) {
      return res.status(200).json({ success: true, data: cache, cached: true, timestamp: new Date().toISOString() });
    }

    const grouped = await buildSectorGroups();

    if (Object.keys(grouped).length > 0) {
      cache = grouped;
      cacheTime = now;
    }

    return res.status(200).json({ success: true, data: grouped, cached: false, timestamp: new Date().toISOString() });

  } catch (error) {
    console.error('US 섹터 추천 API 오류:', error);
    return res.status(500).json({ success: false, error: '서버 오류가 발생했습니다' });
  }
}

// ── 스크리닝 결과 조회 ───────────────────────────────────────────────────────
async function fetchScreeningRows() {
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    console.error('us-sector-recommend: Supabase 환경변수 없음');
    return [];
  }
  try {
    const cutoff = new Date(Date.now() - MAX_SCREENED_AGE_DAYS * 24 * 60 * 60 * 1000).toISOString();
    const res = await fetch(
      `${SUPABASE_URL}/rest/v1/us_screening_results?pass=eq.true&gics_sector=not.is.null&screened_at=gte.${cutoff}&order=score.desc&limit=500`,
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

// ── 스크리닝 결과를 GICS 섹터별로 그룹핑 + 실시간 시세 결합 ────────────────────
async function buildSectorGroups() {
  const rows = await fetchScreeningRows();
  if (!rows.length) return {};

  const quotes = await fetchLiveQuotes(rows.map(r => r.stock_code));
  const grouped = {};

  for (const row of rows) { // rows는 이미 score.desc 정렬됨
    const q = quotes[row.stock_code];
    const price = q?.regularMarketPrice ?? row.price ?? 0;
    if (!price) continue;

    const key = row.gics_sector;
    if (!grouped[key]) grouped[key] = [];
    if (grouped[key].length >= SECTOR_CAP) continue; // 섹터당 상위 SECTOR_CAP개만

    grouped[key].push({
      symbol: row.stock_code,
      name: q?.shortName ?? row.stock_name,
      price,
      changePercent: q?.regularMarketChangePercent ?? 0,
      volume: q?.regularMarketVolume ?? 0,
      marketCap: q?.marketCap ?? row.market_cap_usd ?? 0,
      score: row.score,
      action: scoreToAction(row.score),
      reasons: buildReasons(row, q),
      exchange: row.sector,
      gicsSector: row.gics_sector,
    });
  }
  return grouped;
}
