// 📄 /api/stock-price-updater.js
// 하루에 한번씩 네이버 금융에서 주가 데이터를 가져와서 업데이트

import { JSDOM } from 'jsdom';

// 주식 데이터 캐시 (실제로는 데이터베이스나 파일에 저장)
let stockDataCache = {};

// 네이버 금융에서 주가 데이터 스크래핑
async function fetchStockPriceFromNaver(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.nhn?code=${symbol}`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.8,en-US;q=0.5,en;q=0.3',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
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

// 주요 종목들의 주가 업데이트
async function updateAllStockPrices() {
  const symbols = [
    '005930', // 삼성전자
    '000660', // SK하이닉스
    '035420', // NAVER
    '131390', // 대창솔루션
    '035720', // 카카오
    '207940', // 삼성바이오로직스
  ];

  console.log('주가 업데이트 시작...');
  
  for (const symbol of symbols) {
    try {
      const stockData = await fetchStockPriceFromNaver(symbol);
      if (stockData) {
        stockDataCache[symbol] = stockData;
        console.log(`${symbol} 업데이트 완료: ${stockData.price}원`);
      }
      
      // 요청 간격 조절 (너무 빠르게 요청하지 않도록)
      await new Promise(resolve => setTimeout(resolve, 1000));
    } catch (error) {
      console.error(`${symbol} 업데이트 실패:`, error);
    }
  }
  
  console.log('주가 업데이트 완료');
  return stockDataCache;
}

// API 엔드포인트
export default async function handler(req, res) {
  try {
    if (req.method === 'GET') {
      // 특정 종목 조회
      const { symbol } = req.query;
      
      if (symbol) {
        const stockData = stockDataCache[symbol];
        if (stockData) {
          res.setHeader('Access-Control-Allow-Origin', '*');
          return res.status(200).json({
            success: true,
            data: stockData,
          });
        } else {
          return res.status(404).json({
            success: false,
            error: '해당 종목 데이터를 찾을 수 없습니다',
          });
        }
      } else {
        // 전체 종목 조회
        res.setHeader('Access-Control-Allow-Origin', '*');
        return res.status(200).json({
          success: true,
          data: stockDataCache,
        });
      }
    } else if (req.method === 'POST') {
      // 수동 업데이트 트리거
      const updatedData = await updateAllStockPrices();
      
      res.setHeader('Access-Control-Allow-Origin', '*');
      return res.status(200).json({
        success: true,
        message: '주가 업데이트 완료',
        data: updatedData,
      });
    }
  } catch (error) {
    console.error('API 오류:', error);
    
    res.setHeader('Access-Control-Allow-Origin', '*');
    return res.status(500).json({
      success: false,
      error: error.message,
    });
  }
}
