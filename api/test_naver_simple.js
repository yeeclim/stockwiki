// 간단한 네이버 뉴스 테스트 API
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

  try {
    const { keyword = '대창솔루션' } = req.method === 'POST' ? req.body : req.query;
    
    console.log('테스트 키워드:', keyword);

    // 간단한 테스트 뉴스 데이터
    const testNews = [
      {
        title: `${keyword} 관련 최신 뉴스 1`,
        description: `${keyword}에 대한 최신 동향과 분석 내용입니다.`,
        link: 'https://finance.naver.com/item/main.naver?code=027360',
        published_at: new Date().toISOString(),
      },
      {
        title: `${keyword} 투자 전망 뉴스`,
        description: `${keyword}의 투자 전망과 시장 분석에 대한 전문가 의견입니다.`,
        link: 'https://finance.naver.com/item/main.naver?code=027360',
        published_at: new Date(Date.now() - 3600000).toISOString(), // 1시간 전
      },
      {
        title: `${keyword} 실적 발표 관련 뉴스`,
        description: `${keyword}의 최근 실적 발표와 시장 반응에 대한 분석입니다.`,
        link: 'https://finance.naver.com/item/main.naver?code=027360',
        published_at: new Date(Date.now() - 7200000).toISOString(), // 2시간 전
      }
    ];

    const result = {
      success: true,
      keyword: keyword,
      count: testNews.length,
      results: testNews,
      test_mode: true,
      crawled_at: new Date().toISOString()
    };

    console.log('테스트 뉴스 반환:', result);
    res.status(200).json(result);

  } catch (error) {
    console.error('테스트 API 오류:', error);
    res.status(500).json({
      success: false,
      error: '테스트 API 오류',
      details: error.message
    });
  }
}
