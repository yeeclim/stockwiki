// 📄 /api/cron-update-prices.js
// Vercel Cron Job으로 하루에 한번씩 주가 업데이트

import { JSDOM } from 'jsdom';

// 네이버 금융에서 주가 데이터 스크래핑
async function fetchStockPriceFromNaver(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.nhn?code=${symbol}`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.8,en-US;q=0.5,en;q=0.3',
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }

    const html = await response.text();
    const dom = new JSDOM(html);
    const document = dom.window.document;

    // 주가 정보 추출
    const priceElement = document.querySelector('.no_today .blind');
    const changeElement = document.querySelector('.no_exday .blind');
    const changePercentElement = document.querySelector('.no_exday .blind + .blind');
    const volumeElement = document.querySelector('.no_info .blind');
    const nameElement = document.querySelector('.wrap_company h2 a');

    if (!priceElement) {
      throw new Error('주가 정보를 찾을 수 없습니다');
    }

    const price = parseInt(priceElement.textContent.replace(/,/g, ''));
    const change = changeElement ? parseInt(changeElement.textContent.replace(/,/g, '')) : 0;
    const changePercent = changePercentElement ? parseFloat(changePercentElement.textContent.replace('%', '')) : 0;
    const volume = volumeElement ? parseInt(volumeElement.textContent.replace(/,/g, '')) : 0;
    const name = nameElement ? nameElement.textContent.trim() : '';

    return {
      symbol,
      name,
      price,
      change,
      changePercent,
      volume,
      lastUpdate: new Date().toISOString(),
    };

  } catch (error) {
    console.error(`네이버 금융 스크래핑 실패 (${symbol}):`, error);
    return null;
  }
}

export default async function handler(req, res) {
  // Vercel Cron Job에서만 실행되도록 보안
  if (req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    const symbols = [
      '005930', // 삼성전자
      '000660', // SK하이닉스
      '035420', // NAVER
      '131390', // 대창솔루션
      '035720', // 카카오
      '207940', // 삼성바이오로직스
    ];

    console.log('Cron Job: 주가 업데이트 시작...');
    
    const updatedStocks = {};
    
    for (const symbol of symbols) {
      try {
        const stockData = await fetchStockPriceFromNaver(symbol);
        if (stockData) {
          updatedStocks[symbol] = stockData;
          console.log(`${symbol} 업데이트 완료: ${stockData.price}원`);
        }
        
        // 요청 간격 조절
        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (error) {
        console.error(`${symbol} 업데이트 실패:`, error);
      }
    }
    
    // 여기서 실제로는 데이터베이스나 파일에 저장
    // 예: await saveStockData(updatedStocks);
    
    console.log('Cron Job: 주가 업데이트 완료');
    
    return res.status(200).json({
      success: true,
      message: '주가 업데이트 완료',
      updatedCount: Object.keys(updatedStocks).length,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('Cron Job 오류:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}
