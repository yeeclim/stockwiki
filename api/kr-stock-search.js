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
    // 1차: Yahoo Finance (한국 주식 .KS/.KQ 지원, 서버에서 접근 가능)
    let items = await yahooSearch(q, type);

    // 2차: Naver 모바일 검색 API
    if (items.length < 3) {
      const naverItems = await naverMobileSearch(q, type);
      const seen = new Set(items.map(i => i.code));
      for (const item of naverItems) {
        if (!seen.has(item.code)) { seen.add(item.code); items.push(item); }
      }
    }

    if (items.length === 0) return res.json({ success: true, data: [] });

    items = items.slice(0, 15);

    // 가격 병렬 조회 (Naver fchart)
    const settled = await Promise.allSettled(items.map(fetchPrice));
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

// ── Yahoo Finance 검색 ─────────────────────────────────────────────────────────
// 한국 종목은 symbol이 "466930.KS" (KOSPI) 또는 "466930.KQ" (KOSDAQ) 형식
async function yahooSearch(q, type) {
  try {
    const seen = new Map(); // code → item

    // 1차: 전체 쿼리로 검색
    await yahooSearchQuery(q, type, seen);

    // 2차: 한글이 포함된 긴 쿼리면 영문/숫자 prefix로 추가 검색
    // 예) "SOL 200타겟위클리커버드콜" → "SOL 200"으로도 검색
    const asciiPrefix = q.match(/^[A-Za-z0-9\s\-\.]+/)?.[0]?.trim() ?? '';
    if (asciiPrefix && asciiPrefix.length >= 2 && asciiPrefix !== q) {
      await yahooSearchQuery(asciiPrefix, type, seen);
    }

    return [...seen.values()];
  } catch (e) {
    console.error('[yahooSearch]:', e.message);
    return [];
  }
}

async function yahooSearchQuery(q, type, seen) {
  const encoded = encodeURIComponent(q);
  const url = `https://query1.finance.yahoo.com/v1/finance/search?q=${encoded}&quotesCount=20&newsCount=0&enableFuzzyQuery=false`;
  const text = await fetchText(url, 8000, { 'Accept': 'application/json' });
  if (!text) return;

  let data;
  try { data = JSON.parse(text); } catch { return; }

  for (const quote of (data?.quotes || [])) {
    const symbol = quote.symbol || '';
    if (!/\.(KS|KQ)$/.test(symbol)) continue;

    const code = symbol.replace(/\.(KS|KQ)$/, '');
    if (!/^\d{6}$/.test(code) || seen.has(code)) continue;

    const name = quote.shortname || quote.longname || '';
    if (!name) continue;

    const isEtf = quote.quoteType === 'ETF'
               || quote.quoteType === 'ETF-ETN'
               || code.startsWith('5');
    const market = symbol.endsWith('.KQ') ? 'KOSDAQ' : 'KOSPI';

    if (type === 'stock' && isEtf) continue;
    if (type === 'etf' && !isEtf) continue;

    seen.set(code, { code, name, isEtf, market });
  }
}

// ── Naver 모바일 검색 API ─────────────────────────────────────────────────────
async function naverMobileSearch(q, type) {
  // 여러 endpoint 시도
  const endpoints = [
    `https://m.stock.naver.com/api/search/searchWord?searchWord=${encodeURIComponent(q)}&pageSize=20`,
    `https://m.stock.naver.com/api/stocks/search?keyword=${encodeURIComponent(q)}&page=1&pageSize=20`,
  ];

  for (const url of endpoints) {
    try {
      const text = await fetchText(url, 8000, { 'Referer': 'https://m.stock.naver.com/' });
      if (!text) continue;

      let data;
      try { data = JSON.parse(text); } catch { continue; }

      // 가능한 필드명들
      const list = data?.stockList || data?.stocks || data?.items
                || data?.result?.stockList || data?.data?.stockList || [];
      if (!Array.isArray(list) || list.length === 0) continue;

      const results = [];
      for (const item of list) {
        const code = item.itemCode || item.stockCode || item.code || '';
        const name = item.itemName || item.stockName || item.name || '';
        if (!code || !name || !/^\d{6}$/.test(code)) continue;

        const isEtf = item.quoteType === 'ETF'
                   || !!(item.etfType)
                   || code.startsWith('5');
        const market = item.stockExchangeType?.name
                    || item.stockExchangeType?.code
                    || item.market || '';

        if (type === 'stock' && isEtf) continue;
        if (type === 'etf' && !isEtf) continue;

        results.push({ code, name, isEtf, market });
      }

      if (results.length > 0) return results;
    } catch (e) {
      console.error('[naverMobileSearch]', url, e.message);
    }
  }
  return [];
}

// ── Naver fchart 가격 조회 ────────────────────────────────────────────────────
async function fetchPrice(item) {
  const { code, name, isEtf, market } = item;
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

// ── 공통 fetch 유틸 ───────────────────────────────────────────────────────────
async function fetchText(url, timeoutMs = 8000, extraHeaders = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://finance.naver.com/',
        ...extraHeaders,
      },
      signal: controller.signal,
    });
    if (!res.ok) {
      console.error('[fetchText] HTTP', res.status, url);
      return null;
    }
    return await res.text();
  } catch (e) {
    if (e.name !== 'AbortError') console.error('[fetchText]', e.message, url);
    return null;
  } finally {
    clearTimeout(timer);
  }
}
