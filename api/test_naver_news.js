// 📄 /api/test_naver_news.js
// 테스트용 네이버 뉴스 API

export default async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // POST 요청만 허용
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { keyword, max_results = 20 } = req.body;

    if (!keyword || keyword.trim() === '') {
      res.status(400).json({ 
        success: false,
        error: '키워드가 필요합니다' 
      });
      return;
    }

    // 테스트용 더미 데이터
    const dummyNews = [
      {
        title: `[${keyword}] 관련 뉴스 1`,
        description: `${keyword}에 대한 최신 뉴스입니다. 주가 동향과 관련 정보를 제공합니다.`,
        link: 'https://example.com/news1',
        source: '테스트뉴스',
        date: '2024-01-15',
        crawled_at: new Date().toISOString()
      },
      {
        title: `[${keyword}] 관련 뉴스 2`,
        description: `${keyword}의 실적 발표와 투자 전망에 대한 분석입니다.`,
        link: 'https://example.com/news2',
        source: '테스트뉴스',
        date: '2024-01-14',
        crawled_at: new Date().toISOString()
      },
      {
        title: `[${keyword}] 관련 뉴스 3`,
        description: `${keyword}의 시장 동향과 전문가 의견을 정리했습니다.`,
        link: 'https://example.com/news3',
        source: '테스트뉴스',
        date: '2024-01-13',
        crawled_at: new Date().toISOString()
      }
    ];

    const result = {
      success: true,
      keyword: keyword.trim(),
      count: dummyNews.length,
      results: dummyNews,
      crawled_at: new Date().toISOString()
    };

    res.status(200).json(result);

  } catch (error) {
    console.error('테스트 API 오류:', error);
    res.status(500).json({
      success: false,
      error: '서버 오류',
      details: error.message
    });
  }
}

