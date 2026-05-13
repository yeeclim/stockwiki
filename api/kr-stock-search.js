import { checkRateLimit, getClientIp, fail } from './shared.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Content-Type', 'application/json');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!checkRateLimit(getClientIp(req), 30, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다.');
  }

  const { query = '', type = 'all' } = req.query;
  const q = query.trim();
  if (!q) return res.json({ success: true, data: [] });

  try {
    // 1차: Naver 자동완성 (짧은 키워드에 강함)
    let rawItems = await naverAcSearch(q, type);

    // 2차: Naver 모바일 검색 API (긴 ETF 이름에 강함) — fallback
    if (rawItems.length < 3) {
      const mobileItems = await naverMobileSearch(q, type);
      // 자동완성 결과에 없는 것만 추가
      const acCodes = new Set(rawItems.map(r => r.code));
      for (const item of mobileItems) {
        if (!acCodes.has(item.code)) rawItems.push(item);
      }
    }

    rawItems = rawItems.slice(0, 15);

    if (rawItems.length === 0) {
      return res.json({ success: true, data: [] });
    }

    // 가격 병렬 조회
    const settled = await Promise.allSettled(rawItems.map(item => fetchPrice(item)));
    const data = settled
      .filter(r => r.status === 'fulfilled' && r.value)
      .map(r => r.value);

    res.setHeader('Cache-Control', 's-maxage=30');
    res.json({ success: true, data });
  } catch (e) {
    console.error('kr-stock-search error:', e.message);
    res.status(500).json({ success: false, error: '검색 중 오류: ' + e.message });
  }
}

// ── Naver 자동완성 API ────────────────────────────────────────────────────────
async function naverAcSearch(q, type) {
  const targets = type === 'stock' ? ['stock']
                : type === 'etf'   ? ['etf']
                : ['stock', 'etf'];

  const allItems = [];
  const seen = new Set();

  for (const target of targets) {
    try {
      const encoded = encodeURIComponent(q);
      const url = `https://ac.finance.naver.com/ac?q=${encoded}&q_enc=UTF-8&target=${encodeURIComponent(target)}&st=111&frm=thstock`;
      const text = await fetchText(url, 6000);
      if (!text) continue;

      const data = parseJson(text);
      if (!data) continue;

      for (const item of (data.r || data.items || [])) {
        const code = Array.isArray(item) ? item[0] : item.code;
        if (!code || seen.has(code)) continue;
        seen.add(code);
        allItems.push(normalizeAcItem(item));
      }
    } catch (e) {
      console.error(`[naverAcSearch] target=${target}:`, e.message);
    }
  }
  return allItems;
}

// ── Naver 모바일 검색 API (긴 이름 검색에 적합) ───────────────────────────────
async function naverMobileSearch(q, type) {
  try {
    const encoded = encodeURIComponent(q);
    const url = `https://m.stock.naver.com/api/search/all?query=${encoded}&target=stock,etf`;
    const text = await fetchText(url, 8000, {
      'Referer': 'https://m.stock.naver.com/',
    });
    if (!text) return [];

    const data = parseJson(text);
    if (!data) return [];

    const results = [];
    const seen = new Set();

    // 가능한 필드명 목록 처리
    const sections = [
      ...(data.stocks || data.stockItems || []),
      ...(data.etfs || data.etfItems || []),
      ...(data.funds || []),
    ];

    for (const item of sections) {
      const code = item.itemCode || item.stockCode || item.code || '';
      const name = item.itemName || item.stockName || item.name || '';
      const isEtf = !!(item.etfTabCode || item.etfType || item.isEtf
                     || (code.length === 6 && code.startsWith('5')));
      const market = item.stockExchangeType?.name
                  || item.market
                  || (item.stockExchangeType?.code === 'KOSDAQ' ? 'KOSDAQ' : 'KOSPI');

      if (!code || !name || seen.has(code)) continue;

      // type 필터 적용
      if (type === 'stock' && isEtf) continue;
      if (type === 'etf' && !isEtf) continue;

      seen.add(code);
      results.push({ code, name, isEtf, market });
    }
    return results;
  } catch (e) {
    console.error('[naverMobileSearch]:', e.message);
    return [];
  }
}

// ── 가격 조회 ─────────────────────────────────────────────────────────────────
async function fetchPrice(item) {
  const { code, name, isEtf, market } = item;
  if (!code || !name) return null;

  let price = null, changePercent = null;
  try {
    const url = `https://fchart.stock.naver.com/sise.nhn?symbol=${code}&timeframe=day&count=2&requestType=0`;
    const text = await fetchText(url, 5000);
    if (text) {
      const matches = [...text.matchAll(/data="[^|"]+\|[^|"]+\|[^|"]+\|[^|"]+\|([^|"]+)\|/g)];
      const closes = matches.map(m => parseFloat(m[1])).filter(v => !isNaN(v) && v > 0);
      if (closes.length >= 1) price = closes[closes.length - 1];
      if (closes.length >= 2) {
        const prev = closes[closes.length - 2];
        if (prev > 0) changePercent = (price - prev) / prev * 100;
      }
    }
  } catch (_) {}

  return { code, name, isEtf, market, price, changePercent };
}

// ── 공통 유틸 ─────────────────────────────────────────────────────────────────
async function fetchText(url, timeoutMs = 8000, extraHeaders = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://finance.naver.com/',
        'Accept': '*/*',
        ...extraHeaders,
      },
      signal: controller.signal,
    });
    if (!res.ok) return null;
    return await res.text();
  } catch (e) {
    if (e.name !== 'AbortError') console.error('[fetchText]', url, e.message);
    return null;
  } finally {
    clearTimeout(timer);
  }
}

function parseJson(text) {
  try { return JSON.parse(text); } catch (_) {}
  // JSONP 래퍼 제거
  const m = text.match(/\(([\s\S]+)\)\s*;?\s*$/);
  if (m) { try { return JSON.parse(m[1]); } catch (_) {} }
  return null;
}

function normalizeAcItem(item) {
  const code      = Array.isArray(item) ? item[0] : item.code;
  const name      = Array.isArray(item) ? item[1] : item.name;
  const typeCode  = Array.isArray(item) ? (item[2] ?? '') : '';
  const marketCode = Array.isArray(item) ? (item[4] ?? '') : '';
  const isEtf = typeCode === '4' || (code?.length === 6 && code.startsWith('5'));
  const market = marketCode === 'KQ11' ? 'KOSDAQ' : marketCode === 'KS11' ? 'KOSPI' : '';
  return { code, name, isEtf, market };
}
