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
    console.log(`전체 종목 검색 시작: ${keyword}`);
    
    // KRX JSON 파일에서 전체 종목 검색
    const fs = require('fs');
    const path = require('path');
    
    const krxDataPath = path.join(process.cwd(), 'assets', 'data', 'krx_basic_info.json');
    const krxData = JSON.parse(fs.readFileSync(krxDataPath, 'utf8'));
    
    console.log(`KRX 데이터 로드: ${krxData.stocks?.length || 0}개 종목`);
    
    // 키워드와 일치하는 종목 찾기 (대소문자 구분 없이)
    const searchKeyword = keyword.toLowerCase();
    const matches = krxData.stocks.filter(stock => {
      const name = (stock.name || '').toLowerCase();
      const code = (stock.code || '').toLowerCase();
      const market = (stock.market || '').toLowerCase();
      const sector = (stock.sector || '').toLowerCase();
      
      return name.includes(searchKeyword) || 
             code.includes(searchKeyword) ||
             market.includes(searchKeyword) ||
             sector.includes(searchKeyword) ||
             searchKeyword.includes(name) ||
             searchKeyword.includes(code);
    }).slice(0, limit);

    console.log(`검색 결과: ${matches.length}개`);

    // 결과 반환
    const results = matches.map(stock => ({
      symbol: stock.code,
      name: stock.name,
      market: stock.market || 'KOSPI',
      sector: stock.sector || '기타',
      price: stock.current_price || 0,
      change: stock.change || 0,
      changePercent: stock.change_rate || 0,
      volume: stock.volume || 0,
      marketCap: stock.market_cap || 0,
      lastUpdate: stock.updated_at || new Date().toISOString(),
      source: 'krx-database',
      note: 'KRX 전체 데이터베이스'
    }));

    return results;

  } catch (error) {
    console.error('종목 검색 오류:', error);
    return [];
  }
}