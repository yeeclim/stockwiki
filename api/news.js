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

// 공시/계약/투자 관련 고우선순위 키워드
const HIGH_PRIORITY_KEYWORDS = [
  '공시', '수주', '계약', 'MOU', '협약', '상장', 'IPO',
  '실적', '영업이익', '매출', '흑자', '적자', '어닝',
  '투자', '유상증자', '자사주', '배당', '분할',
  'FDA', '임상', '허가', '특허', '승인',
  '목표주가', '매수', '매도', '투자의견', '증권사', '애널리스트',
];

function scoreNewsItem(title, description, pubDate) {
  const text = (title + ' ' + description).toLowerCase();
  let score = 0;

  // 날짜 점수: 최근일수록 높음
  const now = Date.now();
  const age = now - new Date(pubDate).getTime();
  const days = age / (1000 * 60 * 60 * 24);
  if (days <= 1)       score += 10;
  else if (days <= 3)  score += 7;
  else if (days <= 7)  score += 5;
  else if (days <= 14) score += 2;
  else if (days <= 30) score += 1;

  // 키워드 적합성 점수
  for (const kw of HIGH_PRIORITY_KEYWORDS) {
    if (text.includes(kw.toLowerCase())) score += 5;
  }

  return score;
}

async function handleNaverNews(req, res) {
  const raw = req.method === 'POST' ? req.body : req.query;
  const keyword = validateString(raw.keyword, { minLen: 1, maxLen: 100 });

  if (!keyword) return fail(res, 400, '유효한 키워드가 필요합니다 (1~100자)');

  const encodedKeyword = encodeURIComponent(keyword);
  const feedUrl = `https://news.google.com/rss/search?q=${encodedKeyword}&hl=ko&gl=KR&ceid=KR:ko`;

  try {
    const feed = await parser.parseURL(feedUrl);

    const scored = feed.items.map(item => {
      // Google 뉴스 타이틀 형식: "기사 제목 - 언론사명"
      const fullTitle = item.title || '';
      const lastDash = fullTitle.lastIndexOf(' - ');
      const title = lastDash > 0 ? fullTitle.substring(0, lastDash) : fullTitle;
      const source = lastDash > 0 ? fullTitle.substring(lastDash + 3) : '구글뉴스';
      const pubDate = item.pubDate ? new Date(item.pubDate).toISOString() : new Date().toISOString();

      return {
        title,
        description: item.contentSnippet || '',
        link: item.link || '',
        source,
        published_at: pubDate,
        _score: scoreNewsItem(title, item.contentSnippet || '', pubDate),
      };
    });

    // 점수 내림차순 정렬 후 상위 5개
    scored.sort((a, b) => b._score - a._score);
    const results = scored.slice(0, 5).map(({ _score, ...item }) => item);

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
