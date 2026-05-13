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
    let rawItems = [];

    // type별로 target 결정
    const targets = type === 'stock' ? ['stock']
                  : type === 'etf'   ? ['etf']
                  : ['stock', 'etf'];

    for (const target of targets) {
      const items = await naverAcSearch(q, target);
      rawItems.push(...items);
    }

    // 중복 제거 (code 기준)
    const seen = new Set();
    rawItems = rawItems.filter(item => {
      const code = Array.isArray(item) ? item[0] : item.code;
      if (!code || seen.has(code)) return false;
      seen.add(code);
      return true;
    }).slice(0, 15);

    if (rawItems.length === 0) {
      return res.json({ success: true, data: [] });
    }

    // 가격 병렬 조회
    const settled = await Promise.allSettled(rawItems.map(item => fetchItem(item)));
    const data = settled
      .filter(r => r.status === 'fulfilled' && r.value)
      .map(r => r.value);

    res.setHeader('Cache-Control', 's-maxage=30');
    res.json({ success: true, data });
  } catch (e) {
    console.error('kr-stock-search error:', e.message);
    res.status(500).json({ success: false, error: '검색 중 오류가 발생했습니다: ' + e.message });
  }
}

async function naverAcSearch(q, target) {
  try {
    const encoded = encodeURIComponent(q);
    // target 파라미터를 따로 인코딩
    const url = `https://ac.finance.naver.com/ac?q=${encoded}&q_enc=UTF-8&target=${encodeURIComponent(target)}&st=111&frm=thstock`;

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);

    let text = '';
    try {
      const acRes = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://finance.naver.com/',
          'Accept': '*/*',
        },
        signal: controller.signal,
      });
      text = await acRes.text();
    } finally {
      clearTimeout(timer);
    }

    // JSON 파싱 — JSONP 래퍼도 처리
    let data = null;
    try {
      data = JSON.parse(text);
    } catch {
      const m = text.match(/\(([\s\S]+)\)\s*;?\s*$/);
      if (m) {
        try { data = JSON.parse(m[1]); } catch (_) {}
      }
    }

    if (!data) {
      console.error(`[naverAcSearch] parse failed for target=${target}, response snippet:`, text.slice(0, 200));
      return [];
    }

    return (data.r || data.items || []);
  } catch (e) {
    console.error(`[naverAcSearch] fetch error target=${target}:`, e.message);
    return [];
  }
}

async function fetchItem(item) {
  const code = Array.isArray(item) ? item[0] : item.code;
  const name = Array.isArray(item) ? item[1] : item.name;
  const typeCode = Array.isArray(item) ? (item[2] ?? '') : '';
  const marketCode = Array.isArray(item) ? (item[4] ?? '') : '';

  if (!code || !name) return null;

  const isEtf = typeCode === '4' || (code.length === 6 && code.startsWith('5'));
  const marketLabel = marketCode === 'KQ11' ? 'KOSDAQ'
                    : marketCode === 'KS11' ? 'KOSPI'
                    : '';

  let price = null, changePercent = null;
  try {
    const priceUrl = `https://fchart.stock.naver.com/sise.nhn?symbol=${code}&timeframe=day&count=2&requestType=0`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 5000);
    let priceText = '';
    try {
      const priceRes = await fetch(priceUrl, {
        headers: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://finance.naver.com/' },
        signal: controller.signal,
      });
      priceText = await priceRes.text();
    } finally {
      clearTimeout(timer);
    }
    const matches = [...priceText.matchAll(/data="[^|"]+\|[^|"]+\|[^|"]+\|[^|"]+\|([^|"]+)\|/g)];
    const closes = matches.map(m => parseFloat(m[1])).filter(v => !isNaN(v) && v > 0);
    if (closes.length >= 1) price = closes[closes.length - 1];
    if (closes.length >= 2) {
      const prev = closes[closes.length - 2];
      if (prev > 0) changePercent = (price - prev) / prev * 100;
    }
  } catch (_) {}

  return { code, name, isEtf, market: marketLabel, price, changePercent };
}
