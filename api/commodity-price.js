
export default async function handler(req, res) {
    // CORS 헤더 설정
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    const { symbol } = req.query;

    if (!symbol) {
        return res.status(400).json({ error: 'Symbol is required' });
    }

    try {
        let targetUrl;
        let isCoinGecko = false;

        if (symbol === 'WTI' || symbol === 'CL=F') {
            targetUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/CL=F';
        } else if (symbol === 'SILVER' || symbol === 'SI=F' || symbol === 'XAGUSD=X') {
            targetUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/SI=F';
        } else if (symbol === 'GOLD' || symbol === 'GC=F' || symbol === 'XAUUSD=X') {
            targetUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/GC=F';
        } else if (symbol.toLowerCase() === 'btc' || symbol.toLowerCase() === 'bitcoin') {
            // Option 1: Yahoo Finance BTC-USD
            targetUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/BTC-USD';
            // Option 2: CoinGecko (uncomment if preferred)
            // targetUrl = 'https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd';
            // isCoinGecko = true;
        } else {
            // General Yahoo Finance proxy
            targetUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${symbol}`;
        }

        const response = await fetch(targetUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
        });

        if (!response.ok) {
            throw new Error(`API responded with status: ${response.status}`);
        }

        const data = await response.json();
        return res.status(200).json(data);
    } catch (error) {
        console.error('Proxy error:', error);
        return res.status(500).json({ error: 'Failed to fetch data', message: error.message });
    }
}
