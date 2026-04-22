import Parser from 'rss-parser';
import { checkRateLimit, getClientIp, validateString, validateInt, fail } from './shared.js';

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

  if (!keyword) {
    return fail(res, 400, '유효한 키워드가 필요합니다 (1~100자)');
  }

  const encodedKeyword = encodeURIComponent(keyword);
  const rssUrl = `https://news.naver.com/main/rss/section.naver?sid=101&query=${encodedKeyword}`;

  const response = await fetch(rssUrl, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
    timeout: 10000
  });

  if (!response.ok) return res.status(200).json({ success: true, count: 0, results: [] });

  const xmlText = await response.text();
  const newsList = [];
  const itemPattern = /<item[^>]*>(.*?)<\/item>/gs;
  const items = xmlText.match(itemPattern) || [];

  for (let i = 0; i < Math.min(items.length, max_results); i++) {
    const itemXml = items[i];
    const titleMatch = itemXml.match(/<title[^>]*><!\[CDATA\[(.*?)\]\]><\/title>/) || itemXml.match(/<title[^>]*>(.*?)<\/title>/);
    const title = titleMatch ? cleanText(titleMatch[1]) : '';
    const linkMatch = itemXml.match(/<link[^>]*><!\[CDATA\[(.*?)\]\]><\/link>/) || itemXml.match(/<link[^>]*>(.*?)<\/link>/);
    const link = linkMatch ? linkMatch[1] : '';
    const descMatch = itemXml.match(/<description[^>]*><!\[CDATA\[(.*?)\]\]><\/description>/) || itemXml.match(/<description[^>]*>(.*?)<\/description>/);
    const description = descMatch ? cleanText(descMatch[1]) : '';
    const pubDateMatch = itemXml.match(/<pubDate[^>]*>(.*?)<\/pubDate>/);

    if (title && link) {
      newsList.push({
        title: title,
        description: description,
        link: link,
        source: title.match(/\[(.*?)\]/)?.[1] || '네이버뉴스',
        published_at: pubDateMatch ? pubDateMatch[1] : '',
        crawled_at: new Date().toISOString()
      });
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
