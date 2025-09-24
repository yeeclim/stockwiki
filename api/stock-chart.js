module.exports = async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  const { symbol } = req.query;

  if (!symbol) {
    return res.status(400).json({
      success: false,
      error: '종목 코드가 필요합니다'
    });
  }

  try {
    console.log(`종목 ${symbol} 차트 스냅샷 생성 시작...`);
    
    // 네이버 증권 차트 이미지 URL 생성
    const chartUrls = generateChartUrls(symbol);
    
    return res.status(200).json({
      success: true,
      data: {
        symbol: symbol,
        chartUrls: chartUrls,
        note: '차트 스냅샷 URL 제공'
      },
      source: 'naver-chart',
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('차트 스냅샷 생성 실패:', error);
    return res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다'
    });
  }
}

function generateChartUrls(symbol) {
  // 네이버 증권 일봉 캔들 차트만 제공
  const baseUrl = 'https://ssl.pstatic.net/imgfinance/chart';
  
  return {
    // 일봉 캔들 차트만
    candle: `${baseUrl}/item/candle/day/${symbol}.png`
  };
}
