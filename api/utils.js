// Utility API
// Charts, Commodity Prices, Fear & Greed Index

export default async function handler(req, res) {
    const fetch = globalThis.fetch || (await import('node-fetch')).default;
    // CORS 헤더 설정
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    const { type } = req.query;

    try {
        if (type === 'chart') {
            return await handleChartProxy(req, res);
        } else if (type === 'commodity') {
            return await handleCommodityPrice(req, res);
        } else if (type === 'fear-greed') {
            return await handleFearGreed(req, res);
        } else {
            res.status(400).json({ error: '유효하지 않은 유틸리티 타입입니다.' });
        }
    } catch (error) {
        console.error('Utils API 오류:', error);
        res.status(500).json({ error: 'Internal Server Error', message: error.message });
    }
}

async function handleChartProxy(req, res) {
    const { symbol, period = 'd', isKorean = 'false' } = req.query;
    let targetUrl = '';

    if (isKorean === 'true') {
        let periodStr = 'day';
        if (period === 'w') periodStr = 'week';
        else if (period === 'm') periodStr = 'month';
        const cleanSymbol = symbol.replace('.KS', '').replace('.KQ', '');
        targetUrl = `https://ssl.pstatic.net/imgfinance/chart/item/area/${periodStr}/${cleanSymbol}.png`;
    } else {
        targetUrl = `https://charts.finviz.com/chart.ashx?t=${symbol}&ty=c&ta=0&p=${period}&cb=${Date.now()}`;
    }

    const response = await fetch(targetUrl, {
        headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': isKorean === 'true' ? 'https://finance.naver.com/' : 'https://finviz.com/'
        }
    });

    if (!response.ok) return res.status(response.status).json({ error: 'Failed to fetch image' });

    res.setHeader('Content-Type', response.headers.get('content-type') || 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=60');
    const buffer = Buffer.from(await response.arrayBuffer());
    return res.status(200).send(buffer);
}

async function handleCommodityPrice(req, res) {
    const { symbol } = req.query;
    if (!symbol) return res.status(400).json({ error: 'Symbol is required' });

    let targetUrl;
    const s = symbol.toUpperCase();
    if (s === 'WTI' || s === 'CL=F') targetUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/CL=F';
    else if (s === 'SILVER' || s === 'SI=F' || s === 'XAGUSD=X') targetUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/SI=F';
    else if (s === 'GOLD' || s === 'GC=F' || s === 'XAUUSD=X') targetUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/GC=F';
    else if (s === 'BTC' || s === 'BITCOIN') targetUrl = 'https://query1.finance.yahoo.com/v8/finance/chart/BTC-USD';
    else targetUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${symbol}`;

    const fetch = globalThis.fetch || (await import('node-fetch')).default;
    const response = await fetch(targetUrl, {
        headers: { 
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'application/json'
        }
    });

    if (!response.ok) throw new Error(`API responded with status: ${response.status}`);
    const data = await response.json();
    return res.status(200).json(data);
}

async function handleFearGreed(req, res) {
    const fetch = globalThis.fetch || (await import('node-fetch')).default;
    try {
        const response = await fetch('https://alternative.me/crypto/fear-and-greed-index/', {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            }
        });
        const html = await response.text();
        const valueMatch = html.match(/class="fng-value">\s*(\d+)/);
        const labelMatch = html.match(/class="fng-text">\s*([^<]+)/);

        const value = valueMatch ? parseInt(valueMatch[1]) : 50;
        const label = labelMatch ? labelMatch[1].trim() : 'Neutral';

        return res.status(200).json({ value, label });
    } catch (e) {
        console.error('Fear & Greed Error:', e);
        return res.status(200).json({ value: 50, label: 'Neutral' });
    }
}
