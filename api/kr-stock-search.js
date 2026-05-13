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
    const seen = new Map(); // code → item

    // 검색어 준비: 전체 + ASCII prefix
    const queries = [q];
    const asciiPrefix = q.match(/^[A-Za-z0-9\s\-\.]+/)?.[0]?.trim() ?? '';
    if (asciiPrefix && asciiPrefix.length >= 2 && asciiPrefix !== q) {
      queries.push(asciiPrefix);
    }

    // 1차: Yahoo Finance (KR locale — 한국 ETF 결과 개선)
    for (const qry of queries) {
      await yahooQuery(qry, type, seen);
    }
    console.log(`[yahoo] ${seen.size} results for "${q}"`);

    // 2차: Naver Finance HTML 검색 (finance.naver.com 본체는 Vercel에서 접근 가능)
    if (seen.size < 8) {
      for (const qry of queries) {
        await naverFinanceHtmlQuery(qry, type, seen);
      }
      console.log(`[naver-html] total ${seen.size} results`);
    }

    // 3차: Daum Finance (카카오 금융, 한국 ETF 커버 보완)
    if (seen.size < 5) {
      for (const qry of queries) {
        await daumQuery(qry, type, seen);
      }
      console.log(`[daum] total ${seen.size} results`);
    }

    // 4차: Naver 모바일 검색 (fallback)
    if (seen.size < 3) {
      for (const qry of queries) {
        await naverMobileQuery(qry, type, seen);
      }
      console.log(`[naver-mobile] total ${seen.size} results`);
    }

    const items = [...seen.values()].slice(0, 15);
    if (items.length === 0) return res.json({ success: true, data: [] });

    // 가격 병렬 조회
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

// ── Yahoo Finance (KR locale) ──────────────────────────────────────────────────
async function yahooQuery(q, type, seen) {
  try {
    const url = `https://query1.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(q)}&quotesCount=40&newsCount=0&enableFuzzyQuery=true&lang=ko-KR&region=KR`;
    const text = await fetchText(url, 8000, { 'Accept': 'application/json' });
    if (!text) return;
    let data; try { data = JSON.parse(text); } catch { return; }

    for (const quote of (data?.quotes ?? [])) {
      const symbol = quote.symbol ?? '';
      if (!/\.(KS|KQ)$/.test(symbol)) continue;
      const code = symbol.replace(/\.(KS|KQ)$/, '');
      if (!/^\d{6}$/.test(code) || seen.has(code)) continue;
      const name = quote.shortname || quote.longname || '';
      if (!name) continue;
      const isEtf = /^ETF/.test(quote.quoteType ?? '') || code.startsWith('5');
      const market = symbol.endsWith('.KQ') ? 'KOSDAQ' : 'KOSPI';
      if (type === 'stock' && isEtf) continue;
      if (type === 'etf' && !isEtf) continue;
      seen.set(code, { code, name, isEtf, market });
    }
  } catch (e) { console.error('[yahoo]', e.message); }
}

// ── Naver Finance HTML 검색 ────────────────────────────────────────────────────
async function naverFinanceHtmlQuery(q, type, seen) {
  try {
    const url = `https://finance.naver.com/search/searchList.nhn?query=${encodeURIComponent(q)}&searchType=quant`;
    const text = await fetchText(url, 8000, {
      'Referer': 'https://finance.naver.com/',
      'Accept': 'text/html,application/xhtml+xml',
      'Accept-Language': 'ko-KR,ko;q=0.9',
    });
    if (!text) return;

    // href="/item/main.naver?code=466930" 또는 main.nhn?code= 두 패턴 모두 캡처
    const codeRe = /href="\/item\/main\.n(?:aver|hn)\?code=(\d{6})"/g;
    const nameRe = /<td class="tit">\s*<a[^>]+>([^<]+)<\/a>/g;

    const codes = [...text.matchAll(codeRe)].map(m => m[1]);
    const names = [...text.matchAll(nameRe)].map(m => m[1].trim());

    for (let i = 0; i < codes.length; i++) {
      const code = codes[i];
      const name = names[i] ?? '';
      if (!code || !name || seen.has(code)) continue;
      const isEtf = name.includes('ETF') || name.includes('ETN') || code.startsWith('5');
      const market = '';
      if (type === 'stock' && isEtf) continue;
      if (type === 'etf' && !isEtf) continue;
      seen.set(code, { code, name, isEtf, market });
    }
  } catch (e) { console.error('[naver-html]', e.message); }
}

// ── Daum Finance (카카오) ─────────────────────────────────────────────────────
async function daumQuery(q, type, seen) {
  try {
    const url = `https://finance.daum.net/api/search/stocks?q=${encodeURIComponent(q)}&includeEtf=true&includeFund=false&limit=20`;
    const text = await fetchText(url, 8000, {
      'Referer': 'https://finance.daum.net/',
      'Origin': 'https://finance.daum.net',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'ko-KR,ko;q=0.9',
    });
    if (!text) return;
    let data; try { data = JSON.parse(text); } catch { return; }

    const list = data?.data ?? data?.result ?? [];
    for (const item of list) {
      const rawCode = item.shortCode || item.code || item.symbolCode?.replace(/^[A-Z]/, '') || '';
      const code = rawCode.replace(/\D/g, '').slice(0, 6);
      if (!code || !/^\d{6}$/.test(code) || seen.has(code)) continue;
      const name = item.name || item.stockName || '';
      if (!name) continue;
      const isEtf = (item.type ?? '').toUpperCase().includes('ETF')
                 || (item.securityType ?? '').toUpperCase().includes('ETF')
                 || code.startsWith('5');
      const market = item.market?.name || item.marketName || '';
      if (type === 'stock' && isEtf) continue;
      if (type === 'etf' && !isEtf) continue;
      seen.set(code, { code, name, isEtf, market });
    }
  } catch (e) { console.error('[daum]', e.message); }
}

// ── Naver 모바일 ───────────────────────────────────────────────────────────────
async function naverMobileQuery(q, type, seen) {
  const endpoints = [
    `https://m.stock.naver.com/api/search/searchWord?searchWord=${encodeURIComponent(q)}&pageSize=20`,
    `https://m.stock.naver.com/api/stocks/search?keyword=${encodeURIComponent(q)}&page=1&pageSize=20`,
  ];
  for (const url of endpoints) {
    try {
      const text = await fetchText(url, 8000, { 'Referer': 'https://m.stock.naver.com/' });
      if (!text) continue;
      let data; try { data = JSON.parse(text); } catch { continue; }
      const list = data?.stockList || data?.stocks || data?.items || data?.result?.stockList || [];
      if (!Array.isArray(list) || list.length === 0) continue;
      for (const item of list) {
        const code = item.itemCode || item.stockCode || item.code || '';
        const name = item.itemName || item.stockName || item.name || '';
        if (!code || !name || !/^\d{6}$/.test(code) || seen.has(code)) continue;
        const isEtf = !!(item.etfType) || code.startsWith('5');
        const market = item.stockExchangeType?.name || item.market || '';
        if (type === 'stock' && isEtf) continue;
        if (type === 'etf' && !isEtf) continue;
        seen.set(code, { code, name, isEtf, market });
      }
      if (seen.size > 0) break;
    } catch (e) { console.error('[naver-mobile]', url, e.message); }
  }
}

// ── Naver fchart 가격 ─────────────────────────────────────────────────────────
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

// ── 공통 fetch ────────────────────────────────────────────────────────────────
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
    if (!res.ok) { console.error('[fetchText] HTTP', res.status, url); return null; }
    return await res.text();
  } catch (e) {
    if (e.name !== 'AbortError') console.error('[fetchText]', e.message, url);
    return null;
  } finally {
    clearTimeout(timer);
  }
}
