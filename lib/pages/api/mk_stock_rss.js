export default async function handler(req, res) {
  if (req.method === 'OPTIONS') {
    // CORS preflight 요청 처리
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    res.status(200).end();
    return;
  }

  try {
    const feed = await parser.parseURL('https://www.mk.co.kr/rss/30100041/');

    const items = feed.items.map(item => ({
      title: item.title,
      link: item.link,
      pubDate: item.pubDate,
      summary: item.contentSnippet || '',
      source: '매일경제',
    }));

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.status(200).json({
      source: 'mk_rss',
      category: '증권/시황',
      count: items.length,
      results: items,
    });
  } catch (error) {
    res.status(500).json({
      error: 'RSS 파싱 실패',
      message: error.message,
    });
  }
}
