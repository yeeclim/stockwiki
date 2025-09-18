// 📄 /api/krx-all-stocks.js
// 코스닥/코스피 모든 종목의 실시간 가격 수집

import { JSDOM } from 'jsdom';

// KRX에서 전체 종목 리스트 가져오기
async function fetchAllStockList() {
  try {
    // 코스피 종목 리스트
    const kospiUrl = 'https://finance.naver.com/sise/sise_market_sum.nhn?sosok=0&page=1';
    // 코스닥 종목 리스트  
    const kosdaqUrl = 'https://finance.naver.com/sise/sise_market_sum.nhn?sosok=1&page=1';
    
    const [kospiResponse, kosdaqResponse] = await Promise.all([
      fetch(kospiUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      }),
      fetch(kosdaqUrl, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      }),
    ]);

    const kospiHtml = await kospiResponse.text();
    const kosdaqHtml = await kosdaqResponse.text();

    const kospiStocks = parseStockList(kospiHtml, 'KOSPI');
    const kosdaqStocks = parseStockList(kosdaqHtml, 'KOSDAQ');

    return [...kospiStocks, ...kosdaqStocks];
  } catch (error) {
    console.error('종목 리스트 가져오기 실패:', error);
    return [];
  }
}

// HTML에서 종목 정보 파싱
function parseStockList(html, market) {
  const dom = new JSDOM(html);
  const document = dom.window.document;
  const stocks = [];

  const rows = document.querySelectorAll('table.type_2 tbody tr');
  
  rows.forEach(row => {
    const cells = row.querySelectorAll('td');
    if (cells.length >= 10) {
      const symbolElement = cells[1].querySelector('a');
      const nameElement = cells[1].querySelector('a');
      const priceElement = cells[2];
      const changeElement = cells[3];
      const changePercentElement = cells[4];
      const volumeElement = cells[6];
      const marketCapElement = cells[7];

      if (symbolElement && nameElement) {
        const symbol = symbolElement.href.match(/code=(\d+)/)?.[1];
        const name = nameElement.textContent.trim();
        const price = parseInt(priceElement.textContent.replace(/,/g, '')) || 0;
        const change = parseInt(changeElement.textContent.replace(/,/g, '')) || 0;
        const changePercent = parseFloat(changePercentElement.textContent.replace('%', '')) || 0;
        const volume = parseInt(volumeElement.textContent.replace(/,/g, '')) || 0;
        const marketCap = parseInt(marketCapElement.textContent.replace(/,/g, '')) || 0;

        if (symbol && name) {
          stocks.push({
            symbol,
            name,
            market,
            price,
            change,
            changePercent,
            volume,
            marketCap,
            lastUpdate: new Date().toISOString(),
          });
        }
      }
    }
  });

  return stocks;
}

// 배치로 주가 업데이트 (API 제한 고려)
async function updateStocksInBatches(allStocks, batchSize = 50) {
  const results = [];
  
  for (let i = 0; i < allStocks.length; i += batchSize) {
    const batch = allStocks.slice(i, i + batchSize);
    console.log(`배치 ${Math.floor(i/batchSize) + 1} 처리 중... (${batch.length}개 종목)`);
    
    const batchPromises = batch.map(async (stock) => {
      try {
        // 개별 종목 상세 정보 가져오기
        const detailUrl = `https://finance.naver.com/item/main.nhn?code=${stock.symbol}`;
        const response = await fetch(detailUrl, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        });

        if (response.ok) {
          const html = await response.text();
          const dom = new JSDOM(html);
          const document = dom.window.document;

          // 더 정확한 주가 정보 추출
          const priceElement = document.querySelector('.no_today .blind');
          const changeElement = document.querySelector('.no_exday .blind');
          const changePercentElement = document.querySelector('.no_exday .blind + .blind');
          const volumeElement = document.querySelector('.no_info .blind');
          const marketCapElement = document.querySelector('.no_info .blind + .blind');

          if (priceElement) {
            const updatedPrice = parseInt(priceElement.textContent.replace(/,/g, ''));
            const updatedChange = changeElement ? parseInt(changeElement.textContent.replace(/,/g, '')) : 0;
            const updatedChangePercent = changePercentElement ? parseFloat(changePercentElement.textContent.replace('%', '')) : 0;
            const updatedVolume = volumeElement ? parseInt(volumeElement.textContent.replace(/,/g, '')) : 0;

            return {
              ...stock,
              price: updatedPrice,
              change: updatedChange,
              changePercent: updatedChangePercent,
              volume: updatedVolume,
              lastUpdate: new Date().toISOString(),
            };
          }
        }
        
        return stock; // 업데이트 실패시 원본 반환
      } catch (error) {
        console.error(`${stock.symbol} 업데이트 실패:`, error);
        return stock;
      }
    });

    const batchResults = await Promise.all(batchPromises);
    results.push(...batchResults);
    
    // 배치 간 대기 (API 제한 방지)
    if (i + batchSize < allStocks.length) {
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }

  return results;
}

// API 엔드포인트
export default async function handler(req, res) {
  try {
    if (req.method === 'GET') {
      const { market, limit, page } = req.query;
      
      // 전체 종목 리스트 가져오기
      const allStocks = await fetchAllStockList();
      
      let filteredStocks = allStocks;
      
      // 시장별 필터링
      if (market && (market === 'KOSPI' || market === 'KOSDAQ')) {
        filteredStocks = allStocks.filter(stock => stock.market === market);
      }
      
      // 페이지네이션
      const pageSize = parseInt(limit) || 100;
      const currentPage = parseInt(page) || 1;
      const startIndex = (currentPage - 1) * pageSize;
      const endIndex = startIndex + pageSize;
      
      const paginatedStocks = filteredStocks.slice(startIndex, endIndex);
      
      res.setHeader('Access-Control-Allow-Origin', '*');
      return res.status(200).json({
        success: true,
        data: paginatedStocks,
        pagination: {
          currentPage,
          pageSize,
          totalItems: filteredStocks.length,
          totalPages: Math.ceil(filteredStocks.length / pageSize),
        },
        summary: {
          totalStocks: allStocks.length,
          kospiCount: allStocks.filter(s => s.market === 'KOSPI').length,
          kosdaqCount: allStocks.filter(s => s.market === 'KOSDAQ').length,
        },
      });
      
    } else if (req.method === 'POST') {
      // 전체 종목 업데이트 (시간이 오래 걸림)
      console.log('전체 종목 업데이트 시작...');
      
      const allStocks = await fetchAllStockList();
      console.log(`총 ${allStocks.length}개 종목 발견`);
      
      // 배치로 업데이트
      const updatedStocks = await updateStocksInBatches(allStocks, 20);
      
      console.log('전체 종목 업데이트 완료');
      
      res.setHeader('Access-Control-Allow-Origin', '*');
      return res.status(200).json({
        success: true,
        message: '전체 종목 업데이트 완료',
        data: updatedStocks,
        summary: {
          totalUpdated: updatedStocks.length,
          kospiCount: updatedStocks.filter(s => s.market === 'KOSPI').length,
          kosdaqCount: updatedStocks.filter(s => s.market === 'KOSDAQ').length,
        },
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
