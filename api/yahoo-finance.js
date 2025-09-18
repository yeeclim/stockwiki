// 📄 /api/yahoo-finance.js
export default async function handler(req, res) {
  try {
    const { symbol } = req.query;
    
    if (!symbol) {
      return res.status(400).json({
        success: false,
        error: 'Symbol parameter is required'
      });
    }

    // Yahoo Finance API 호출
    const yahooUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${symbol}`;
    
    const response = await fetch(yahooUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      },
    });

    if (!response.ok) {
      throw new Error(`Yahoo Finance API error: ${response.status}`);
    }

    const data = await response.json();
    
    // 데이터 파싱
    if (data.chart && data.chart.result && data.chart.result.length > 0) {
      const result = data.chart.result[0];
      const meta = result.meta;
      
      if (meta) {
        const currentPrice = meta.regularMarketPrice || 0;
        const previousClose = meta.previousClose || 0;
        const change = currentPrice - previousClose;
        const changePercent = previousClose > 0 ? (change / previousClose * 100) : 0;

        const stockData = {
          name: meta.longName || symbol,
          price: currentPrice,
          change: change,
          changePercent: changePercent,
          volume: meta.regularMarketVolume || 0,
          marketCap: meta.marketCap || 0,
        };

        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
        
        return res.status(200).json({
          success: true,
          data: stockData,
          symbol: symbol,
          timestamp: new Date().toISOString(),
        });
      }
    }

    throw new Error('No data found in Yahoo Finance response');

  } catch (error) {
    console.error('Yahoo Finance API error:', error);
    
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    
    return res.status(500).json({
      success: false,
      error: error.message,
      symbol: req.query.symbol,
    });
  }
}
