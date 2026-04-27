// 미국 주식 검색 API (Yahoo Finance, API 키 불필요)
import { checkRateLimit, getClientIp, fail } from './shared.js';

export default async function handler(req, res) {
  const fetch = globalThis.fetch || (await import('node-fetch')).default;
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!checkRateLimit(getClientIp(req), 30, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
  }

  const keyword = (req.query.keyword || '').trim();
  if (!keyword || keyword.length < 1) return fail(res, 400, '검색어가 필요합니다');

  try {
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json',
      'Accept-Language': 'en-US,en;q=0.9',
    };

    // 1. Yahoo Finance 검색
    const searchUrl = `https://query1.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(keyword)}&quotesCount=5&newsCount=0&enableFuzzyQuery=false`;
    const searchRes = await fetch(searchUrl, { headers });

    if (!searchRes.ok) {
      return fail(res, 502, `Yahoo Finance 검색 실패: ${searchRes.status}`);
    }

    const searchData = await searchRes.json();
    const quotes = (searchData.quotes || []).filter(q =>
      q.quoteType === 'EQUITY' &&
      !q.symbol.includes('.') // 해외 거래소 제외 (.T, .HK 등)
    );

    if (quotes.length === 0) {
      return res.status(404).json({ success: false, error: '검색 결과가 없습니다' });
    }

    // 2. 상위 3개 실시간 시세 조회
    const symbols = quotes.slice(0, 3).map(q => q.symbol).join(',');
    const quoteUrl = `https://query2.finance.yahoo.com/v7/finance/quote?symbols=${symbols}`;
    const quoteRes = await fetch(quoteUrl, { headers });

    if (!quoteRes.ok) {
      // 시세 실패해도 검색 결과는 반환
      return res.status(200).json({
        success: true,
        data: quotes.slice(0, 3).map(q => ({
          symbol: q.symbol,
          name: q.longname || q.shortname || q.symbol,
          price: null,
          change: null,
          changePercent: null,
          exchange: q.exchange,
        })),
      });
    }

    const quoteData = await quoteRes.json();
    const results = (quoteData.quoteResponse?.result || []).map(q => ({
      symbol: q.symbol,
      name: q.longName || q.shortName || q.symbol,
      price: q.regularMarketPrice ?? null,
      change: q.regularMarketChange ?? null,
      changePercent: q.regularMarketChangePercent ?? null,
      volume: q.regularMarketVolume ?? null,
      marketCap: q.marketCap ?? null,
      exchange: q.fullExchangeName || q.exchange || 'US',
    }));

    return res.status(200).json({ success: true, data: results });

  } catch (error) {
    console.error('us-stock-search error:', error);
    return fail(res, 500, `검색 오류: ${error.message}`);
  }
}
