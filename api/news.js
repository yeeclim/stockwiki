import Parser from 'rss-parser';
import { checkRateLimit, getClientIp, validateString, validateInt, fail } from './_shared.js';

const parser = new Parser();

export default async function handler(req, res) {
  const fetch = globalThis.fetch || (await import('node-fetch')).default;
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!checkRateLimit(getClientIp(req), 60, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
  }

  const { source } = req.query;
  const bodySource = req.body?.source;
  const activeSource = source || bodySource || 'naver';

  try {
    if (activeSource === 'mk_rss') {
      return await handleMkRss(req, res);
    } else if (activeSource === 'daum') {
      return await handleDaumNews(req, res);
    } else if (activeSource === 'naver') {
      return await handleNaverNews(req, res);
    } else {
      res.status(400).json({ error: '유효하지 않은 뉴스 소스입니다.' });
    }
  } catch (error) {
    console.error('News API 오류:', error);
    res.status(500).json({
      success: false,
      error: '뉴스 처리 오류',
      details: error.message
    });
  }
}

async function handleMkRss(req, res) {
  const feed = await parser.parseURL('https://www.mk.co.kr/rss/30100041/');
  const items = feed.items.map(item => ({
    title: item.title || '',
    link: item.link || '',
    pubDate: item.pubDate || '',
    summary: item.contentSnippet || '',
    language: detectLanguage(item.title + item.contentSnippet),
    source: '매일경제',
  }));

  const filteredItems = items.filter(item =>
    item.language === 'ko' || item.language === 'en'
  );

  res.status(200).json({
    source: 'mk_rss',
    category: '증권/시황',
    count: filteredItems.length,
    results: filteredItems,
  });
}

async function handleDaumNews(req, res) {
  const raw = req.method === 'POST' ? req.body : req.query;
  const keyword = validateString(raw.keyword, { minLen: 1, maxLen: 100 });
  const max_results = validateInt(raw.max_results, { min: 1, max: 30 }) ?? 10;

  if (!keyword) {
    return fail(res, 400, '유효한 키워드가 필요합니다 (1~100자)');
  }

  const encodedKeyword = encodeURIComponent(keyword);
  const searchUrl = `https://search.daum.net/search?w=news&q=${encodedKeyword}&sort=recency`;

  const response = await fetch(searchUrl, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
    timeout: 10000
  });

  if (!response.ok) {
    return res.status(200).json({
      success: true,
      keyword: keyword.trim(),
      count: 0,
      results: [],
      error: '다음 뉴스 요청 실패'
    });
  }

  const htmlText = await response.text();
  const newsList = [];
  const itemPattern = /<div[^>]*class="item-title"[^>]*>(.*?)<\/div>/gs;
  const items = htmlText.match(itemPattern) || [];

  for (let i = 0; i < Math.min(items.length, max_results); i++) {
    const itemHtml = items[i];
    const linkPattern = /<a[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/g;
    let linkMatch;

    while ((linkMatch = linkPattern.exec(itemHtml)) !== null) {
      const link = linkMatch[1];
      const title = cleanText(linkMatch[2]);
      if (title && link) {
        newsList.push({
          title: title,
          description: '',
          link: link,
          source: '다음뉴스',
          published_at: new Date().toISOString(),
          crawled_at: new Date().toISOString()
        });
        break;
      }
    }
  }

  res.status(200).json({
    success: true,
    keyword: keyword.trim(),
    count: newsList.length,
    results: newsList,
    crawled_at: new Date().toISOString()
  });
}

async function handleNaverNews(req, res) {
  const raw = req.method === 'POST' ? req.body : req.query;
  const keyword = validateString(raw.keyword, { minLen: 1, maxLen: 100 });
  const max_results = validateInt(raw.max_results, { min: 1, max: 50 }) ?? 20;

  if (!keyword) return fail(res, 400, '유효한 키워드가 필요합니다 (1~100자)');

  // 네이버 뉴스 검색 스크래핑 — <mark> 태그가 붙은 항목이 키워드 매칭 기사
  const encodedKeyword = encodeURIComponent(keyword);
  const searchUrl = `https://search.naver.com/search.naver?where=news&query=${encodedKeyword}&sort=1&nso=so:dd,p:all`;

  try {
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
        'Accept-Language': 'ko-KR,ko;q=0.9',
      },
      signal: AbortSignal.timeout(8000),
    });

    if (!response.ok) return res.status(200).json({ success: true, count: 0, results: [] });

    const html = await response.text();

    // 1. 키워드 매칭 기사 타이틀 (<mark> 포함된 것만 추출)
    const allTitleMatches = [...html.matchAll(/"title":"([^"]{3,})"/g)];
    const markedTitles = allTitleMatches
      .map(m => m[1])
      .filter(t => t.includes('<mark>') || t.includes('<strong>'));

    // 2. 네이버 뉴스 기사 링크 (중복 제거)
    const rawLinks = html.match(/https?:\/\/n\.news\.naver\.com\/mnews\/article\/[^\\"&]+/g) || [];
    const uniqueLinks = [...new Set(rawLinks)];

    // 3. 소스명: <mark> 타이틀 바로 앞의 짧은 타이틀
    const results = [];
    let linkIdx = 0;

    for (let i = 0; i < allTitleMatches.length && results.length < max_results; i++) {
      const raw = allTitleMatches[i][1];
      if (!raw.includes('<mark>') && !raw.includes('<strong>')) continue;

      const title = cleanNaverText(raw);
      if (!title || title.length < 5) continue;

      const prevRaw = i > 0 ? allTitleMatches[i - 1][1] : '';
      const source = (prevRaw.length < 25 && !prevRaw.includes('<mark>'))
        ? cleanNaverText(prevRaw)
        : '네이버뉴스';

      const link = uniqueLinks[linkIdx]
        ? (uniqueLinks[linkIdx].startsWith('http') ? uniqueLinks[linkIdx] : 'https://' + uniqueLinks[linkIdx])
        : `https://search.naver.com/search.naver?where=news&query=${encodedKeyword}`;
      linkIdx++;

      results.push({
        title,
        description: '',
        link,
        source,
        published_at: new Date().toISOString(),
        crawled_at: new Date().toISOString(),
      });
    }

    return res.status(200).json({
      success: true,
      keyword: keyword.trim(),
      count: results.length,
      results,
      crawled_at: new Date().toISOString(),
    });
  } catch (e) {
    console.error('handleNaverNews error:', e.message);
    return res.status(200).json({ success: true, count: 0, results: [] });
  }
}

function cleanNaverText(raw) {
  return raw
    .replace(/<\/?mark>/g, '').replace(/<\/?strong>/g, '')
    .replace(/&quot;/g, '"').replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ').trim();
}

function cleanText(text) {
  if (!text) return "";
  return text.replace(/<[^>]*>/g, '')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ').trim();
}

function detectLanguage(text) {
  if (/[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]/.test(text)) return 'ko';
  if (/[a-zA-Z]/.test(text)) return 'en';
  return 'other';
}
