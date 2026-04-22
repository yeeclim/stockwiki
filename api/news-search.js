// 외부 뉴스 API 프록시 (NewsData.io, GNews, MediaStack)
// API 키는 서버 환경변수에서만 읽음 — 클라이언트에 노출되지 않음

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
  if (!keyword) {
    return fail(res, 400, '유효한 검색어가 필요합니다 (1~100자)');
  }
  const lang = req.query.lang || 'ko,en';
  const maxResults = validateInt(req.query.limit, { min: 1, max: 30 }) ?? 10;
  const sanitized = encodeURIComponent(keyword);

  const results = await Promise.allSettled([
    fetchNewsData(sanitized, lang, maxResults),
    fetchGNews(sanitized, lang, maxResults),
    fetchMediaStack(sanitized, lang, maxResults),
  ]);

  const allNews = results
    .filter(r => r.status === 'fulfilled')
    .flatMap(r => r.value);

  // 제목 기준 중복 제거
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

async function fetchMediaStack(keyword, lang, limit) {
  const apiKey = process.env.MEDIASTACK_API_KEY || '';
  if (!apiKey) return [];
  try {
    const url = `http://api.mediastack.com/v1/news?access_key=${apiKey}&keywords=${keyword}&languages=${lang}&limit=${limit}`;
    const res = await fetch(url, { signal: AbortSignal.timeout(5000) });
    if (!res.ok) return [];
    const data = await res.json();
    return (data.data || []).map(item => ({
      title: item.title || '',
      description: item.description || '',
      link: item.url || '',
      source: item.source || 'MediaStack',
      publishedAt: item.published_at || '',
    }));
  } catch {
    return [];
  }
}
