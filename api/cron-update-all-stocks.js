// 📄 /api/cron-update-all-stocks.js
// 전체 종목 업데이트를 위한 Cron Job

import { JSDOM } from 'jsdom';

// 간단한 종목 리스트 (실제로는 더 많은 종목)
const MAJOR_STOCKS = [
  // KOSPI 주요 종목
  { symbol: '005930', name: '삼성전자', market: 'KOSPI' },
  { symbol: '000660', name: 'SK하이닉스', market: 'KOSPI' },
  { symbol: '035420', name: 'NAVER', market: 'KOSPI' },
  { symbol: '035720', name: '카카오', market: 'KOSPI' },
  { symbol: '207940', name: '삼성바이오로직스', market: 'KOSPI' },
  { symbol: '006400', name: '삼성SDI', market: 'KOSPI' },
  { symbol: '051910', name: 'LG화학', market: 'KOSPI' },
  { symbol: '068270', name: '셀트리온', market: 'KOSPI' },
  { symbol: '323410', name: '카카오뱅크', market: 'KOSPI' },
  { symbol: '000270', name: '기아', market: 'KOSPI' },
  
  // KOSDAQ 주요 종목
  { symbol: '131390', name: '대창솔루션', market: 'KOSDAQ' },
  { symbol: '086520', name: '에코프로', market: 'KOSDAQ' },
  { symbol: '247540', name: '에코프로비엠', market: 'KOSDAQ' },
  { symbol: '196170', name: '알테오젠', market: 'KOSDAQ' },
  { symbol: '066970', name: '엘앤에프', market: 'KOSDAQ' },
  { symbol: '091990', name: '셀트리온헬스케어', market: 'KOSDAQ' },
  { symbol: '196300', name: '에이치엘비', market: 'KOSDAQ' },
  { symbol: '196490', name: '다이나믹디자인', market: 'KOSDAQ' },
  { symbol: '196700', name: '웹젠', market: 'KOSDAQ' },
  { symbol: '196800', name: '아이에이', market: 'KOSDAQ' },
];

// 개별 종목 주가 가져오기
async function fetchStockPrice(symbol) {
  try {
    const url = `https://finance.naver.com/item/main.nhn?code=${symbol}`;
    
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
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
    const marketCapElement = document.querySelector('.no_info .blind + .blind');

    if (!priceElement) {
      throw new Error('주가 정보를 찾을 수 없습니다');
    }

    const price = parseInt(priceElement.textContent.replace(/,/g, ''));
    const change = changeElement ? parseInt(changeElement.textContent.replace(/,/g, '')) : 0;
    const changePercent = changePercentElement ? parseFloat(changePercentElement.textContent.replace('%', '')) : 0;
    const volume = volumeElement ? parseInt(volumeElement.textContent.replace(/,/g, '')) : 0;
    const marketCap = marketCapElement ? parseInt(marketCapElement.textContent.replace(/,/g, '')) : 0;

    return {
      symbol,
      price,
      change,
      changePercent,
      volume,
      marketCap,
      lastUpdate: new Date().toISOString(),
    };

  } catch (error) {
    console.error(`주가 가져오기 실패 (${symbol}):`, error);
    return null;
  }
}

// 배치로 주가 업데이트
async function updateStocksInBatches(stocks, batchSize = 5) {
  const results = [];
  
  for (let i = 0; i < stocks.length; i += batchSize) {
    const batch = stocks.slice(i, i + batchSize);
    console.log(`배치 ${Math.floor(i/batchSize) + 1} 처리 중... (${batch.length}개 종목)`);
    
    const batchPromises = batch.map(async (stock) => {
      const priceData = await fetchStockPrice(stock.symbol);
      if (priceData) {
        return {
          ...stock,
          ...priceData,
        };
      }
      return stock;
    });

    const batchResults = await Promise.all(batchPromises);
    results.push(...batchResults);
    
    // 배치 간 대기 (API 제한 방지)
    if (i + batchSize < stocks.length) {
      await new Promise(resolve => setTimeout(resolve, 3000));
    }
  }

  return results;
}

export default async function handler(req, res) {
  // Vercel Cron Job에서만 실행되도록 보안
  if (req.headers.authorization !== `Bearer ${process.env.CRON_SECRET}`) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  try {
    console.log('Cron Job: 전체 종목 업데이트 시작...');
    
    // 주요 종목들 업데이트
    const updatedStocks = await updateStocksInBatches(MAJOR_STOCKS, 3);
    
    // 여기서 실제로는 데이터베이스나 파일에 저장
    // 예: await saveAllStockData(updatedStocks);
    
    console.log('Cron Job: 전체 종목 업데이트 완료');
    
    return res.status(200).json({
      success: true,
      message: '전체 종목 업데이트 완료',
      data: updatedStocks,
      summary: {
        totalUpdated: updatedStocks.length,
        kospiCount: updatedStocks.filter(s => s.market === 'KOSPI').length,
        kosdaqCount: updatedStocks.filter(s => s.market === 'KOSDAQ').length,
      },
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
