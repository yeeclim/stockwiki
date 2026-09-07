// 미국 주식 검색 API (Yahoo Finance)
import { checkRateLimit, getClientIp, fail, applyCors } from './_shared.js';

const YF_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Accept': 'application/json, text/plain, */*',
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept-Encoding': 'gzip, deflate, br',
  'Referer': 'https://finance.yahoo.com/',
  'Origin': 'https://finance.yahoo.com',
};

export default async function handler(req, res) {
  if (applyCors(req, res)) return;

  if (!checkRateLimit(getClientIp(req), 30, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
  }

  const keyword = (req.query.keyword || '').trim().toUpperCase();
  if (!keyword || keyword.length < 1) return fail(res, 400, '검색어가 필요합니다');

  try {
    // 1. 티커처럼 생긴 경우 직접 조회 우선 (DDOG, AAPL 등)
    const looksLikeTicker = /^[A-Z]{1,5}$/.test(keyword);
    if (looksLikeTicker) {
      const direct = await fetchQuotes([keyword]);
      if (direct.length > 0) {
        return res.status(200).json({ success: true, data: direct });
      }
    }

    // 2. Yahoo Finance 검색
    const searchUrl = `https://query1.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(keyword)}&quotesCount=6&newsCount=0&enableFuzzyQuery=false`;
    const searchRes = await fetch(searchUrl, { headers: YF_HEADERS });

    if (!searchRes.ok) {
      // 검색 실패 시 티커 직접 조회로 fallback
      const direct = await fetchQuotes([keyword]);
      if (direct.length > 0) return res.status(200).json({ success: true, data: direct });
      return fail(res, 502, `검색 실패 (${searchRes.status})`);
    }

    const searchData = await searchRes.json();
    const quotes = (searchData.quotes || []).filter(q =>
      (q.quoteType === 'EQUITY' || q.quoteType === 'ETF') &&
      !q.symbol.includes('.')
    );

    if (quotes.length === 0) {
      // 검색 결과 없으면 직접 조회 시도
      const direct = await fetchQuotes([keyword]);
      if (direct.length > 0) return res.status(200).json({ success: true, data: direct });
      return res.status(404).json({ success: false, error: '검색 결과가 없습니다' });
    }

    // 3. 실시간 시세 조회
    const symbols = quotes.slice(0, 5).map(q => q.symbol);
    const withPrice = await fetchQuotes(symbols);

    if (withPrice.length > 0) {
      return res.status(200).json({ success: true, data: withPrice });
    }

    // 시세 실패 시 기본 정보만 반환
    return res.status(200).json({
      success: true,
      data: quotes.slice(0, 5).map(q => ({
        symbol: q.symbol,
        name: q.longname || q.shortname || q.symbol,
        price: null, change: null, changePercent: null,
        exchange: q.exchange,
      })),
    });

  } catch (error) {
    console.error('us-stock-search error:', error);
    return fail(res, 500, `검색 오류: ${error.message}`);
  }
}

async function fetchQuotes(symbols) {
  try {
    const url = `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${symbols.join(',')}&fields=symbol,longName,shortName,regularMarketPrice,regularMarketChange,regularMarketChangePercent,regularMarketVolume,marketCap,fullExchangeName`;
    const r = await fetch(url, { headers: YF_HEADERS });
    if (!r.ok) return [];
    const data = await r.json();
    return (data.quoteResponse?.result || [])
      .filter(q => q.regularMarketPrice != null)
      .map(q => ({
        symbol: q.symbol,
        name: q.longName || q.shortName || q.symbol,
        price: q.regularMarketPrice ?? null,
        change: q.regularMarketChange ?? null,
        changePercent: q.regularMarketChangePercent ?? null,
        volume: q.regularMarketVolume ?? null,
        marketCap: q.marketCap ?? null,
        exchange: q.fullExchangeName || q.exchange || 'US',
      }));
  } catch {
    return [];
  }
}
