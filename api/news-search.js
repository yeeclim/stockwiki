// 외부 뉴스 API 프록시 — Yahoo Finance(무료) + 유료 API 키 있으면 병행 사용
import { checkRateLimit, getClientIp, validateString, validateInt, fail } from './shared.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!checkRateLimit(getClientIp(req), 30, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
  }

  const keyword = validateString(req.query.keyword, { minLen: 1, maxLen: 100 });
  if (!keyword) return fail(res, 400, '유효한 검색어가 필요합니다 (1~100자)');

  const lang = req.query.lang || 'en';
  const maxResults = validateInt(req.query.limit, { min: 1, max: 30 }) ?? 10;
  const sanitized = encodeURIComponent(keyword);

  const sources = [
    fetchYahooNews(keyword, maxResults),
    fetchNewsData(sanitized, lang, maxResults),
    fetchGNews(sanitized, lang, maxResults),
  ];

  const results = await Promise.allSettled(sources);

  const allNews = results
    .filter(r => r.status === 'fulfilled')
    .flatMap(r => r.value);

  const seen = new Set();
  const unique = allNews.filter(item => {
    if (!item.title || seen.has(item.title)) return false;
    seen.add(item.title);
    return true;
  });

  return res.status(200).json({
    success: true,
    results: unique.slice(0, maxResults),
  });
}

// Yahoo Finance 뉴스 검색 (API 키 불필요)
async function fetchYahooNews(keyword, limit) {
  try {
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Accept': 'application/json',
    };
    const url = `https://query1.finance.yahoo.com/v1/finance/search?q=${encodeURIComponent(keyword)}&quotesCount=0&newsCount=${limit}&enableFuzzyQuery=false`;
    const res = await fetch(url, { headers, signal: AbortSignal.timeout(6000) });
    if (!res.ok) return [];
    const data = await res.json();
    const news = data.news || [];
    return news.map(item => ({
      title: item.title || '',
      description: item.summary || '',
      link: item.link || '',
      source: item.publisher || 'Yahoo Finance',
      publishedAt: item.providerPublishTime
        ? new Date(item.providerPublishTime * 1000).toISOString()
        : '',
    }));
  } catch {
    return [];
  }
}

async function fetchNewsData(keyword, lang, limit) {
  const apiKey = process.env.NEWSDATA_API_KEY || '';
  if (!apiKey) return [];
  try {
    const url = `https://newsdata.io/api/1/news?apikey=${apiKey}&q=${keyword}&language=${lang}&size=${limit}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return [];
    const data = await res.json();
    return (data.results || []).map(item => ({
      title: item.title || '',
      description: item.description || '',
      link: item.link || '',
      source: item.source_id || 'NewsData.io',
      publishedAt: item.pubDate || '',
    }));
  } catch {
    return [];
  }
}

async function fetchGNews(keyword, lang, limit) {
  const apiKey = process.env.GNEWS_API_KEY || '';
  if (!apiKey) return [];
  try {
    const url = `https://gnews.io/api/v4/search?token=${apiKey}&q=${keyword}&lang=${lang}&max=${limit}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return [];
    const data = await res.json();
    return (data.articles || []).map(item => ({
      title: item.title || '',
      description: item.description || '',
      link: item.url || '',
      source: item.source?.name || 'GNews',
      publishedAt: item.publishedAt || '',
    }));
  } catch {
    return [];
  }
}
