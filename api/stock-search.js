// Vercel API 핸들러
export default async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  const { keyword, limit = 10 } = req.query;

  if (!keyword) {
    return res.status(400).json({
      success: false,
      error: '검색어가 필요합니다'
    });
  }

  try {
    console.log(`종목 검색: ${keyword}`);
    
    // 종목 검색 실행
    const searchResults = await searchStocks(keyword, limit);
    
    if (searchResults.length > 0) {
      return res.status(200).json({
        success: true,
        keyword: keyword,
        count: searchResults.length,
        data: searchResults,
        timestamp: new Date().toISOString()
      });
    }

    return res.status(404).json({
      success: false,
      error: '검색 결과가 없습니다'
    });

  } catch (error) {
    console.error('종목 검색 실패:', error);
    return res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다'
    });
  }
}

async function searchStocks(keyword, limit) {
  try {
    console.log(`종목 검색 시작: ${keyword}`);
    
    // 주요 종목 목록
    const stocks = [
      { code: '005930', name: '삼성전자' },
      { code: '000660', name: 'SK하이닉스' },
      { code: '035420', name: 'NAVER' },
      { code: '035720', name: '카카오' },
      { code: '207940', name: '삼성바이오로직스' },
      { code: '006400', name: '삼성SDI' },
      { code: '051910', name: 'LG화학' },
      { code: '068270', name: '셀트리온' },
      { code: '323410', name: '카카오뱅크' },
      { code: '000270', name: '기아' },
      { code: '005490', name: 'POSCO홀딩스' },
      { code: '017670', name: 'SK텔레콤' },
      { code: '105560', name: 'KB금융' },
      { code: '055550', name: '신한지주' },
      { code: '096770', name: 'SK이노베이션' },
      { code: '066570', name: 'LG전자' },
      { code: '003550', name: 'LG' },
      { code: '018260', name: '삼성에스디에스' },
      { code: '015760', name: '한국전력' },
      { code: '012330', name: '현대모비스' },
      { code: '000810', name: '삼성화재' },
      { code: '086280', name: '현대글로비스' },
      { code: '028260', name: '삼성물산' },
      { code: '032830', name: '삼성생명' },
      { code: '003670', name: '포스코홀딩스' },
      { code: '024110', name: '기업은행' },
      { code: '030200', name: 'KT' },
      { code: '011200', name: 'HMM' },
      { code: '086790', name: '하나금융지주' },
      { code: '377300', name: '카카오페이' },
      { code: '161890', name: '한국항공우주' },
      { code: '034730', name: 'SK' },
      { code: '003490', name: '대한항공' },
      { code: '259960', name: '크래프톤' },
      { code: '035900', name: 'JYP Ent.' },
      { code: '251270', name: '넷마블' },
      { code: '091990', name: '셀트리온헬스케어' },
      { code: '078930', name: 'GS' },
      { code: '000720', name: '현대건설' },
      { code: '267250', name: 'HD현대중공업' },
      { code: '042700', name: '한미반도체' },
      { code: '047050', name: '포스코인터내셔널' },
    ];

    // 키워드와 일치하는 종목 찾기
    const matches = stocks.filter(stock => 
      stock.name.includes(keyword) || 
      stock.code.includes(keyword) ||
      keyword.includes(stock.name) ||
      keyword.includes(stock.code)
    ).slice(0, limit);

    console.log(`검색 결과: ${matches.length}개`);

    // 결과 반환 (실시간 데이터 없이 기본 정보만)
    const results = matches.map(stock => ({
      symbol: stock.code,
      name: stock.name,
      price: 0,
      change: 0,
      changePercent: 0,
      volume: 0,
      marketCap: 0,
      lastUpdate: new Date().toISOString(),
      source: 'stock-database',
      note: '종목 데이터베이스'
    }));

    return results;

  } catch (error) {
    console.error('종목 검색 오류:', error);
    return [];
  }
}