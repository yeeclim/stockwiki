import { checkRateLimit, getClientIp, validateSymbol, fail } from './shared.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!checkRateLimit(getClientIp(req), 60, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
  }

  const symbol = validateSymbol(req.query.symbol);
  if (!symbol) {
    return fail(res, 400, '유효한 종목 코드가 필요합니다 (영문/숫자/점/하이픈, 최대 20자)');
  }

  try {
    // 네이버 증권에서 데이터 크롤링
    const stockData = await fetchStockData(symbol);

    if (stockData) {
      return res.status(200).json({
        success: true,
        data: stockData,
        source: 'naver-finance',
        timestamp: new Date().toISOString()
      });
    }

    return res.status(404).json({
      success: false,
      error: '해당 종목 데이터를 찾을 수 없습니다'
    });

  } catch (error) {
    console.error('주식 데이터 가져오기 실패:', error);
    return res.status(500).json({
      success: false,
      error: '서버 오류가 발생했습니다'
    });
  }
}

async function fetchStockData(symbol) {
  try {
    // 1단계: 네이버 증권 실시간 API 시도 (여러 엔드포인트 시도)
    const apiEndpoints = [
      `https://api.finance.naver.com/service/itemSummary.nhn?itemcode=${symbol}`,
      `https://m.stock.naver.com/api/item/stock.nhn?code=${symbol}`,
      `https://finance.naver.com/item/main.nhn?code=${symbol}`
    ];

    for (const apiUrl of apiEndpoints) {
      try {
        const apiResponse = await fetch(apiUrl, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'application/json, text/plain, */*',
            'Referer': 'https://finance.naver.com/',
          }
        });

        if (apiResponse.ok) {
          const apiText = await apiResponse.text();

          // JSONP 형식일 수 있으므로 파싱 시도
          try {
            // JSONP 제거 시도
            let jsonText = apiText.trim();
            if (jsonText.startsWith('(') || jsonText.includes('(')) {
              jsonText = jsonText.replace(/^[^(]*\(/, '').replace(/\);?$/, '');
            }

            const apiData = JSON.parse(jsonText);

            // 다양한 응답 형식 처리
            let price, change, changePercent, volume, name;

            if (apiData.nowVal) {
              // itemSummary.nhn 형식
              price = parseInt(apiData.nowVal.replace(/,/g, ''));
              change = parseInt((apiData.diffVal || '0').replace(/,/g, ''));
              changePercent = parseFloat(apiData.rate || '0');
              volume = parseInt((apiData.quant || '0').replace(/,/g, ''));
              name = apiData.itemName;

              // 전일 종가 계산 (현재가 - 변동가)
              const previousClose = price - change;
            } else if (apiData.result) {
              // stock.nhn 형식
              const result = apiData.result;
              price = parseInt((result.now || result.price || '0').replace(/,/g, ''));
              change = parseInt((result.diff || result.change || '0').replace(/,/g, ''));
              changePercent = parseFloat(result.rate || result.changePercent || '0');
              volume = parseInt((result.quant || result.volume || '0').replace(/,/g, ''));
              name = result.name || result.itemName;
            } else if (apiData.price) {
              // 직접 price 필드
              price = parseInt(apiData.price.toString().replace(/,/g, ''));
              change = parseInt((apiData.change || apiData.diff || '0').toString().replace(/,/g, ''));
              changePercent = parseFloat(apiData.changePercent || apiData.rate || '0');
              volume = parseInt((apiData.volume || apiData.quant || '0').toString().replace(/,/g, ''));
              name = apiData.name || apiData.itemName;
            }

            if (price && price > 0) {
              // 전일 종가 계산 (현재가 - 변동가)
              const previousClose = change !== undefined && change !== null
                ? price - change
                : (changePercent !== 0 ? Math.round(price / (1 + changePercent / 100)) : null);

              const stockData = {
                symbol: symbol,
                name: (name || symbol).replace(/\s*:\s*Npay\s*증권\s*/gi, '').trim(),
                price: price,
                change: change || 0,
                changePercent: changePercent || 0,
                previousClose: previousClose || null, // 전일 종가
                volume: volume || 0,
                marketCap: 0, // API에서 제공하지 않음
                lastUpdate: new Date().toISOString(),
                source: 'naver-api',
                note: '실시간 API 데이터'
              };

              return stockData;
            }
          } catch (parseError) {
            // 다음 엔드포인트 시도
            continue;
          }
        }
      } catch (apiError) {
        // 다음 엔드포인트 시도
        continue;
      }
    }

    // 2단계: HTML 크롤링 (폴백)
    const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;

    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7',
        'Accept-Encoding': 'gzip, deflate, br',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
      }
    });

    if (!response.ok) {
      return null;
    }

    const html = await response.text();

    // 종목명 추출
    const name = extractStockName(html, symbol);

    // 가격 정보 추출 (변동률/변동가 포함)
    const priceInfo = extractPriceInfoWithChange(html);

    if (!priceInfo.price) {
      return null;
    }

    // 전일 종가 계산 (현재가 - 변동가)
    const previousClose = priceInfo.change !== undefined && priceInfo.change !== null && priceInfo.change !== 0
      ? priceInfo.price - priceInfo.change
      : (priceInfo.changePercent !== 0 && priceInfo.changePercent !== null
        ? Math.round(priceInfo.price / (1 + priceInfo.changePercent / 100))
        : null);

    const stockData = {
      symbol: symbol,
      name: name,
      price: priceInfo.price,
      change: priceInfo.change || 0,
      changePercent: priceInfo.changePercent || 0,
      previousClose: previousClose, // 전일 종가
      volume: priceInfo.volume || 0,
      marketCap: priceInfo.marketCap || 0,
      lastUpdate: new Date().toISOString(),
      source: 'naver-finance',
      note: 'HTML 크롤링 데이터 (거의 실시간)'
    };

    return stockData;

  } catch (error) {
    console.error('❌ 크롤링 오류:', error);
    return null;
  }
}

// 네이버 증권에서 가격 정보 추출 (변동률/변동가/전일종가 포함)
function extractPriceInfoWithChange(html) {
  const priceInfo = extractPriceInfo(html);

  // 전일 종가 직접 추출 시도
  const previousClosePatterns = [
    /전일[^>]*>([\d,]+)/,
    /종가[^>]*>([\d,]+)/,
    /전일종가[^>]*>([\d,]+)/,
    /<td[^>]*>전일[^>]*>([\d,]+)<\/td>/,
    /<span[^>]*>전일[^>]*>([\d,]+)<\/span>/,
    /<script[^>]*>[\s\S]*?previousClose["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?전일종가["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?yesterdayClose["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/
  ];

  let previousClose = null;
  for (const pattern of previousClosePatterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      const closeStr = match[1].replace(/,/g, '');
      const closeNum = parseInt(closeStr);
      if (!isNaN(closeNum) && closeNum > 0 && closeNum < 10000000) { // 합리적인 범위
        previousClose = closeNum;
        break;
      }
    }
  }

  // 전일 종가가 추출되지 않았고 변동가가 있으면 계산
  if (!previousClose && priceInfo.price && priceInfo.change !== undefined && priceInfo.change !== null && priceInfo.change !== 0) {
    previousClose = priceInfo.price - priceInfo.change;
  }

  // 변동률 추출 (네이버 증권 실제 HTML 구조 기반)
  const changePercentPatterns = [
    // 상승/하락 클래스 기반 추출
    /<em class="no_up"[^>]*>[\s\S]*?<span class="blind"[^>]*>([+-]?[\d.]+)%<\/span>/,
    /<em class="no_down"[^>]*>[\s\S]*?<span class="blind"[^>]*>([+-]?[\d.]+)%<\/span>/,
    /<em class="no_change"[^>]*>[\s\S]*?<span class="blind"[^>]*>([+-]?[\d.]+)%<\/span>/,
    // 직접 패턴
    /<span class="blind"[^>]*>([+-]?[\d.]+)%<\/span>/,
    /<em class="no_up"[^>]*>([+-]?[\d.]+)%<\/em>/,
    /<em class="no_down"[^>]*>([+-]?[\d.]+)%<\/em>/,
    /<em class="no_change"[^>]*>([+-]?[\d.]+)%<\/em>/,
    // 일반 패턴
    /변동률[^>]*>([+-]?[\d.]+)%/,
    /등락률[^>]*>([+-]?[\d.]+)%/,
    // 스크립트에서 추출
    /<script[^>]*>[\s\S]*?changePercent["\s]*:["\s]*([+-]?[\d.]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?변동률["\s]*:["\s]*([+-]?[\d.]+)["\s]*[\s\S]*?<\/script>/
  ];

  let changePercent = 0;
  for (const pattern of changePercentPatterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      const percent = parseFloat(match[1]);
      if (!isNaN(percent) && Math.abs(percent) < 30) { // 합리적인 범위 (-30% ~ +30%)
        changePercent = percent;
        break;
      }
    }
  }

  // 변동가 추출 (네이버 증권에서 직접 추출 시도)
  const changePatterns = [
    /<em class="no_up"[^>]*>[\s\S]*?<span class="blind"[^>]*>([+-]?[\d,]+)<\/span>/,
    /<em class="no_down"[^>]*>[\s\S]*?<span class="blind"[^>]*>([+-]?[\d,]+)<\/span>/,
    /<span class="blind"[^>]*>([+-]?[\d,]+)<\/span>/,
    /변동가[^>]*>([+-]?[\d,]+)/
  ];

  let change = 0;
  for (const pattern of changePatterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      const changeStr = match[1].replace(/,/g, '');
      const changeNum = parseInt(changeStr);
      if (!isNaN(changeNum) && Math.abs(changeNum) < priceInfo.price * 0.3) { // 합리적인 범위
        change = changeNum;
        break;
      }
    }
  }

  // 변동가가 추출되지 않았고 변동률이 있으면 계산
  if (change === 0 && changePercent !== 0 && priceInfo.price) {
    change = Math.round(priceInfo.price * changePercent / 100);
  }

  return {
    ...priceInfo,
    changePercent,
    change,
    previousClose
  };
}

function extractStockName(html, symbol) {
  // 종목명 추출 - 여러 패턴 시도
  const patterns = [
    /<h2 class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<h2[^>]*>([^<]+)<\/h2>/,
    /<title>([^<]+)<\/title>/,
    /<span class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<div class="wrap_company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<strong[^>]*>([^<]+)<\/strong>/,
    /<em[^>]*>([^<]+)<\/em>/,
    /<h1[^>]*>([^<]+)<\/h1>/,
    /<div class="company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<span class="company">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<div class="stock_name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<span class="stock_name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<div class="name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<span class="name">[\s\S]*?<a[^>]*>([^<]+)<\/a>/,
    /<a[^>]*href="[^"]*item[^"]*"[^>]*>([^<]+)<\/a>/,
    /<a[^>]*>([^<]+)<\/a>/,
    /<div[^>]*>([^<]+)<\/div>/,
    /<span[^>]*>([^<]+)<\/span>/,
    /<p[^>]*>([^<]+)<\/p>/,
    /<li[^>]*>([^<]+)<\/li>/,
    /<td[^>]*>([^<]+)<\/td>/,
    /<th[^>]*>([^<]+)<\/th>/,
    /<label[^>]*>([^<]+)<\/label>/,
    /<button[^>]*>([^<]+)<\/button>/,
    /<input[^>]*value="([^"]+)"/,
    /<meta[^>]*content="([^"]+)"/,
    /<script[^>]*>[\s\S]*?name["\s]*:["\s]*([^"']+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?종목명["\s]*:["\s]*([^"']+)["\s]*[\s\S]*?<\/script>/
  ];

  for (const pattern of patterns) {
    const match = html.match(pattern);
    if (match && match[1] && match[1].trim() && match[1] !== '최근조회') {
      const name = match[1].trim();
      return name;
    }
  }

  return symbol;
}

function extractPriceInfo(html) {
  // 가격 정보 추출 - 여러 패턴 시도
  const pricePatterns = [
    // 네이버 증권 기본 패턴
    /<p class="no_today"[^>]*>[\s\S]*?<span[^>]*>([^<]+)<\/span>/,
    /<span class="no_today"[^>]*>([^<]+)<\/span>/,
    /<em class="no_today"[^>]*>([^<]+)<\/em>/,
    /<strong class="no_today"[^>]*>([^<]+)<\/strong>/,
    /<p class="no_today"[^>]*>([^<]+)<\/p>/,
    /<span[^>]*class="[^"]*no_today[^"]*"[^>]*>([^<]+)<\/span>/,

    // 스크립트에서 가격 추출
    /<script[^>]*>[\s\S]*?price["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?현재가["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?종가["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?value["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?amount["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?close["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?last["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,
    /<script[^>]*>[\s\S]*?final["\s]*:["\s]*([\d,]+)["\s]*[\s\S]*?<\/script>/,

    // HTML 태그에서 가격 추출
    /<td[^>]*>([\d,]+)<\/td>/,
    /<span[^>]*>([\d,]+)<\/span>/,
    /<div[^>]*>([\d,]+)<\/div>/,
    /<p[^>]*>([\d,]+)<\/p>/,
    /<em[^>]*>([\d,]+)<\/em>/,
    /<strong[^>]*>([\d,]+)<\/strong>/,
    /<b[^>]*>([\d,]+)<\/b>/,
    /<i[^>]*>([\d,]+)<\/i>/,
    /<font[^>]*>([\d,]+)<\/font>/,
    /<label[^>]*>([\d,]+)<\/label>/,
    /<button[^>]*>([\d,]+)<\/button>/,
    /<input[^>]*value="([\d,]+)"/,
    /<meta[^>]*content="([\d,]+)"/,

    // 테이블에서 가격 추출
    /<tr[^>]*>[\s\S]*?<td[^>]*>([\d,]+)<\/td>[\s\S]*?<\/tr>/,
    /<table[^>]*>[\s\S]*?<td[^>]*>([\d,]+)<\/td>[\s\S]*?<\/table>/,

    // 특정 클래스에서 가격 추출
    /<span class="[^"]*price[^"]*"[^>]*>([\d,]+)<\/span>/,
    /<div class="[^"]*price[^"]*"[^>]*>([\d,]+)<\/div>/,
    /<span class="[^"]*amount[^"]*"[^>]*>([\d,]+)<\/span>/,
    /<div class="[^"]*amount[^"]*"[^>]*>([\d,]+)<\/div>/,
    /<span class="[^"]*value[^"]*"[^>]*>([\d,]+)<\/span>/,
    /<div class="[^"]*value[^"]*"[^>]*>([\d,]+)<\/div>/
  ];

  let price = null;
  let volume = 0;
  let marketCap = 0;

  // 가격 추출
  for (const pattern of pricePatterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      const priceStr = match[1].replace(/,/g, '');
      const priceNum = parseInt(priceStr);
      if (priceNum && priceNum > 0 && priceNum < 10000000) { // 합리적인 가격 범위
        price = priceNum;
        break;
      }
    }
  }

  // 거래량 추출
  const volumePatterns = [
    /<span class="[^"]*tah[^"]*"[^>]*>([\d,]+)<\/span>/,
    /<td[^>]*>([\d,]+)<\/td>/,
    /<span[^>]*>([\d,]+)<\/span>/,
    /<div[^>]*>([\d,]+)<\/div>/
  ];

  for (const pattern of volumePatterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      const volumeStr = match[1].replace(/,/g, '');
      const volumeNum = parseInt(volumeStr);
      if (volumeNum && volumeNum > 1000) { // 합리적인 거래량 범위
        volume = volumeNum;
        break;
      }
    }
  }

  // 시가총액 추출
  const marketCapPatterns = [
    /시가총액[^>]*>([^<]+)<\/[^>]*>/,
    /시총[^>]*>([^<]+)<\/[^>]*>/,
    /<td[^>]*>([\d,]+억)<\/td>/,
    /<span[^>]*>([\d,]+억)<\/span>/,
    /<div[^>]*>([\d,]+억)<\/div>/
  ];

  for (const pattern of marketCapPatterns) {
    const match = html.match(pattern);
    if (match && match[1]) {
      const marketCapStr = match[1];
      if (marketCapStr.includes('억')) {
        const value = parseFloat(marketCapStr.replace(/[억,]/g, ''));
        marketCap = Math.round(value * 100000000);
        break;
      } else if (marketCapStr.includes('조')) {
        const value = parseFloat(marketCapStr.replace(/[조,]/g, ''));
        marketCap = Math.round(value * 1000000000000);
        break;
      }
    }
  }

  return { price, volume, marketCap };
}

// 서버 로직용 직접 호출 함수 익스포트
export { fetchStockData as fetchStockDataDirect };
