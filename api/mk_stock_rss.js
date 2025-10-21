// 📄 /api/mk_stock_rss.js
import Parser from 'rss-parser';

const parser = new Parser();

export default async function handler(req, res) {
  try {
    const feed = await parser.parseURL('https://www.mk.co.kr/rss/30100041/');

    const items = feed.items.map(item => ({
      title: item.title || '',
      link: item.link || '',
      pubDate: item.pubDate || '',
      summary: item.contentSnippet || '',
      language: detectLanguage(item.title + item.contentSnippet),
      source: '매일경제',
    }));

    // 한글 또는 영어 기사만 필터링
    const filteredItems = items.filter(item =>
      item.language === 'ko' || item.language === 'en'
    );

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', 'application/json');
    res.status(200).json({
      source: 'mk_rss',
      category: '증권/시황',
      count: filteredItems.length,
      results: filteredItems,
    });
  } catch (error) {
    res.status(500).json({
      error: 'RSS 파싱 실패',
      message: error.message,
    });
  }
}

// 간단한 언어 감지 함수
function detectLanguage(text) {
  const korean = /[ㄱ-ㅎ|ㅏ-ㅣ|가-힣]/;
  const english = /[a-zA-Z]/;

  if (korean.test(text)) return 'ko';
  if (english.test(text)) return 'en';
  return 'other';
}