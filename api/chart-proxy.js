export default async function handler(req, res) {
    // CORS 헤더 설정
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    const { symbol, period = 'd', isKorean = 'false' } = req.query;

    try {
        let targetUrl = '';

        if (isKorean === 'true') {
            let periodStr = 'day';
            if (period === 'w') periodStr = 'week';
            else if (period === 'm') periodStr = 'month';
            else if (period === 'i15') periodStr = 'day'; // 국내는 단기가 기본 일봉으로 처리

            // 네이버 금융은 005930 형태의 6자리 코드만 사용하므로 .KS .KQ 제거
            const cleanSymbol = symbol.replace('.KS', '').replace('.KQ', '');
            targetUrl = `https://ssl.pstatic.net/imgfinance/chart/item/area/${periodStr}/${cleanSymbol}.png`;
        } else {
            const timestamp = Date.now();
            targetUrl = `https://charts.finviz.com/chart.ashx?t=${symbol}&ty=c&ta=0&p=${period}&cb=${timestamp}`;
        }

        const fetchFn = globalThis.fetch || (await import('node-fetch')).default;
        const response = await fetchFn(targetUrl, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': isKorean === 'true' ? 'https://finance.naver.com/' : 'https://finviz.com/'
            }
        });

        if (!response.ok) {
            console.error(`Failed to fetch ${targetUrl} with status ${response.status}`);
            return res.status(response.status).json({ error: 'Failed to fetch image' });
        }

        const contentType = response.headers.get('content-type');
        res.setHeader('Content-Type', contentType || 'image/png');
        // 캐시 설정
        res.setHeader('Cache-Control', 'public, max-age=60');

        const arrayBuffer = await response.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        return res.status(200).send(buffer);
    } catch (error) {
        console.error('Chart Proxy Error:', error);
        return res.status(500).json({ error: 'Internal Server Error' });
    }
}
