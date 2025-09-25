const https = require('https');

module.exports = async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const { symbol } = req.query;

  if (!symbol) {
    return res.status(400).json({
      success: false,
      error: '종목 코드가 필요합니다'
    });
  }

  try {
    console.log(`종목 ${symbol} 차트 이미지 프록시 시작...`);
    
    // 네이버 증권 차트 이미지 URL
    const chartUrl = `https://ssl.pstatic.net/imgfinance/chart/item/candle/day/${symbol}.png`;
    
    // https 모듈을 사용하여 이미지 다운로드
    const imageData = await new Promise((resolve, reject) => {
      const request = https.get(chartUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Referer': 'https://finance.naver.com/',
          'Accept': 'image/webp,image/apng,image/*,*/*;q=0.8'
        }
      }, (response) => {
        if (response.statusCode !== 200) {
          reject(new Error(`이미지 로드 실패: ${response.statusCode}`));
          return;
        }
        
        const chunks = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () => {
          resolve({
            data: Buffer.concat(chunks),
            contentType: response.headers['content-type'] || 'image/png'
          });
        });
      });
      
      request.on('error', reject);
      request.setTimeout(10000, () => {
        request.destroy();
        reject(new Error('요청 시간 초과'));
      });
    });

    // 이미지 헤더 설정
    res.setHeader('Content-Type', imageData.contentType);
    res.setHeader('Cache-Control', 'public, max-age=300'); // 5분 캐시
    res.setHeader('Content-Length', imageData.data.length);

    // 이미지 데이터 전송
    res.status(200).send(imageData.data);

  } catch (error) {
    console.error('차트 이미지 프록시 실패:', error);
    
    // 에러 시 기본 이미지 반환
    res.setHeader('Content-Type', 'image/svg+xml');
    res.status(200).send(`
      <svg width="400" height="200" xmlns="http://www.w3.org/2000/svg">
        <rect width="100%" height="100%" fill="#2a2a2a"/>
        <text x="50%" y="50%" text-anchor="middle" fill="#666" font-family="Arial" font-size="14">
          차트를 불러올 수 없습니다
        </text>
      </svg>
    `);
  }
}
