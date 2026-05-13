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
  if (!q || q.length < 1) return res.json({ success: true, data: [] });

  try {
    // Naver Finance autocomplete — target: stock, etf (ETN은 etf로 분류됨)
    const target = type === 'stock' ? 'stock' : type === 'etf' ? 'etf' : 'stock,etf';
    const encoded = encodeURIComponent(q);
    const acUrl = `https://ac.finance.naver.com/ac?q=${encoded}&q_enc=UTF-8&target=${target}&st=111&frm=thstock`;

    const acRes = await fetch(acUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://finance.naver.com/',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(8000),
    });

    if (!acRes.ok) return res.json({ success: true, data: [] });

    const acData = await acRes.json();
    // Naver autocomplete 응답 형식: { r: [[code, name, typeCode, displayName, marketCode, marketName], ...] }
    const rawItems = (acData.r || acData.items || []).slice(0, 15);

    // 가격 병렬 조회
    const results = await Promise.allSettled(rawItems.map(async (item) => {
      const code = Array.isArray(item) ? item[0] : item.code;
      const name = Array.isArray(item) ? item[1] : item.name;
      const typeCode = Array.isArray(item) ? item[2] : '';
      const marketCode = Array.isArray(item) ? (item[4] || '') : '';

      if (!code || !name) return null;

      // ETF/ETN 판별: typeCode '4' 또는 코드가 ETN 범위(5xxxxx)
      const isEtf = typeCode === '4' || (code.length === 6 && code.startsWith('5'));
      const marketLabel = marketCode === 'KQ11' ? 'KOSDAQ' : marketCode === 'KS11' ? 'KOSPI' : '기타';

      let price = null, changePercent = null;
      try {
        const priceUrl = `https://fchart.stock.naver.com/sise.nhn?symbol=${code}&timeframe=day&count=2&requestType=0`;
        const priceRes = await fetch(priceUrl, {
          headers: { 'User-Agent': 'Mozilla/5.0', 'Referer': 'https://finance.naver.com/' },
          signal: AbortSignal.timeout(5000),
        });
        const text = await priceRes.text();
        const matches = [...text.matchAll(/data="[^|"]+\|[^|"]+\|[^|"]+\|[^|"]+\|([^|"]+)\|/g)];
        const closes = matches.map(m => parseFloat(m[1])).filter(v => !isNaN(v) && v > 0);
        if (closes.length >= 1) price = closes[closes.length - 1];
        if (closes.length >= 2) {
          const prev = closes[closes.length - 2];
          if (prev > 0) changePercent = (price - prev) / prev * 100;
        }
      } catch (_) {}

      return { code, name, isEtf, market: marketLabel, price, changePercent };
    }));

    const data = results
      .filter(r => r.status === 'fulfilled' && r.value !== null)
      .map(r => r.value);

    res.setHeader('Cache-Control', 's-maxage=30');
    res.json({ success: true, data });
  } catch (e) {
    console.error('kr-stock-search error:', e);
    res.status(500).json({ success: false, error: e.message });
  }
}
