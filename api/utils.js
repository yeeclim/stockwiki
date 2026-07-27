// Utility API
// Charts, Commodity Prices, Fear & Greed Index

export default async function handler(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    try {
        const { type } = req.query;

        if (type === 'chart')     return await handleChartProxy(req, res);
        if (type === 'commodity') return await handleCommodityPrice(req, res);
        if (type === 'fear-greed') return await handleFearGreed(req, res);
        if (type === 'cnn-fear-greed') return await handleCnnFearGreed(req, res);

        return res.status(400).json({ error: 'Invalid utility type' });
    } catch (error) {
        console.error('Utils API Error:', error);
        return res.status(200).json({ success: false, error: 'Internal Server Error', fallback: true });
    }
}

// Flutter 코드가 기대하는 Yahoo Finance 형식으로 가격을 감싸는 헬퍼
function wrapPrice(price) {
    return {
        chart: {
            result: [{
                meta: {
                    regularMarketPrice: price,
                    previousClose: price,
                }
            }]
        }
    };
}

async function fetchWithTimeout(url, options = {}, timeoutMs = 8000) {
    const controller = new AbortController();
    const tid = setTimeout(() => controller.abort(), timeoutMs);
    try {
        const r = await fetch(url, { ...options, signal: controller.signal });
        clearTimeout(tid);
        return r;
    } catch (e) {
        clearTimeout(tid);
        throw e;
    }
}

async function handleChartProxy(req, res) {
    const { symbol, period = 'd', isKorean = 'false' } = req.query;
    let targetUrl = '';

    const naverHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://finance.naver.com/',
    };

    if (isKorean === 'true') {
        const periods = period === 'm' ? ['month', 'week']
                      : period === 'w' ? ['week']
                      : ['day'];
        const cleanSymbol = symbol.replace('.KS', '').replace('.KQ', '');
        for (const periodStr of periods) {
            targetUrl = `https://ssl.pstatic.net/imgfinance/chart/item/area/${periodStr}/${cleanSymbol}.png`;
            const response = await fetchWithTimeout(targetUrl, { headers: naverHeaders });
            if (response.ok) {
                res.setHeader('Content-Type', 'image/png');
                res.setHeader('Cache-Control', 'public, max-age=60');
                return res.status(200).send(Buffer.from(await response.arrayBuffer()));
            }
        }
        return res.status(404).end();
    } else {
        targetUrl = `https://charts.finviz.com/chart.ashx?t=${symbol}&ty=c&ta=0&p=${period}&cb=${Date.now()}`;
    }

    const response = await fetchWithTimeout(targetUrl, {
        headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Referer': 'https://finviz.com/',
        }
    });

    if (!response.ok) return res.status(response.status).end();

    res.setHeader('Content-Type', response.headers.get('content-type') || 'image/png');
    res.setHeader('Cache-Control', 'public, max-age=60');
    return res.status(200).send(Buffer.from(await response.arrayBuffer()));
}

async function handleCommodityPrice(req, res) {
    const { symbol } = req.query;
    if (!symbol) return res.status(400).json({ error: 'Symbol is required' });

    const s = symbol.toUpperCase();

    // ── USD/KRW: open.er-api.com (무료, 인증 불필요, Vercel에서 안정적) ───────
    if (s === 'KRW=X') {
        try {
            const r = await fetchWithTimeout('https://open.er-api.com/v6/latest/USD');
            if (r.ok) {
                const data = await r.json();
                const rate = data?.rates?.KRW;
                if (rate) return res.status(200).json(wrapPrice(rate));
            }
        } catch (_) {}
        // fallback: Exchangerate.host
        try {
            const r = await fetchWithTimeout('https://api.exchangerate.host/latest?base=USD&symbols=KRW');
            if (r.ok) {
                const data = await r.json();
                const rate = data?.rates?.KRW;
                if (rate) return res.status(200).json(wrapPrice(rate));
            }
        } catch (_) {}
        return res.status(200).json(wrapPrice(1380)); // 최후 fallback
    }

    // ── 기타 상품: Yahoo Finance (query1 → query2 순서로 시도) ───────────────
    let yahooSymbol = symbol;
    if (s === 'WTI')    yahooSymbol = 'CL=F';
    if (s === 'SILVER') yahooSymbol = 'SI=F';
    if (s === 'GOLD')   yahooSymbol = 'GC=F';
    if (s === 'BTC' || s === 'BITCOIN') yahooSymbol = 'BTC-USD';

    const yahooHeaders = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
        'Accept': 'application/json',
        'Accept-Language': 'en-US,en;q=0.9',
    };

    for (const host of ['query1', 'query2']) {
        try {
            const url = `https://${host}.finance.yahoo.com/v8/finance/chart/${yahooSymbol}`;
            const r = await fetchWithTimeout(url, { headers: yahooHeaders }, 6000);
            if (r.ok) {
                const data = await r.json();
                const meta = data?.chart?.result?.[0]?.meta;
                if (meta?.regularMarketPrice || meta?.previousClose) {
                    return res.status(200).json(data);
                }
            }
        } catch (_) {}
    }

    // v7 quote 엔드포인트로 최후 시도
    try {
        const r = await fetchWithTimeout(
            `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${yahooSymbol}`,
            { headers: yahooHeaders },
            6000
        );
        if (r.ok) {
            const data = await r.json();
            const q = data?.quoteResponse?.result?.[0];
            if (q?.regularMarketPrice) {
                return res.status(200).json(wrapPrice(q.regularMarketPrice));
            }
        }
    } catch (_) {}

    return res.status(200).json({ success: false, error: 'Price unavailable' });
}

async function handleFearGreed(req, res) {
    try {
        const r = await fetchWithTimeout('https://api.alternative.me/fng/?limit=1', {
            headers: { 'Accept': 'application/json' }
        });
        const json = await r.json();
        const item = json?.data?.[0];
        const value = item ? parseInt(item.value) : 50;
        const label = item?.value_classification ?? 'Neutral';
        return res.status(200).json({ value, label });
    } catch (e) {
        console.error('Fear & Greed Error:', e);
        return res.status(200).json({ value: 50, label: 'Neutral' });
    }
}

// CNN Business의 실제 주식시장 Fear & Greed Index를 그대로 프록시한다.
// CNN 웹페이지가 내부적으로 쓰는 비공식 데이터 엔드포인트라 CORS가 안 열려있어
// 브라우저(Flutter web)에서 직접 호출이 안 되므로 서버에서 대신 받아온다.
// (기존 handleFearGreed는 api.alternative.me — 암호화폐 전용 지수라 별개)
let _cnnFgCache = null;
let _cnnFgCacheTime = 0;
const _CNN_FG_CACHE_TTL = 15 * 60 * 1000; // 15분

async function handleCnnFearGreed(req, res) {
    try {
        const now = Date.now();
        if (_cnnFgCache && now - _cnnFgCacheTime < _CNN_FG_CACHE_TTL) {
            return res.status(200).json({ ..._cnnFgCache, cached: true });
        }

        const r = await fetchWithTimeout(
            'https://production.dataviz.cnn.io/index/fearandgreed/graphdata',
            {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                    'Referer': 'https://edition.cnn.com/',
                },
            },
            10000
        );
        if (!r.ok) throw new Error(`CNN API 오류: ${r.status}`);

        const data = await r.json();
        const fg = data.fear_and_greed;
        if (!fg) throw new Error('fear_and_greed 필드 없음');

        const result = {
            success: true,
            score: Math.round(fg.score),
            rating: fg.rating,
            previousClose: Math.round(fg.previous_close),
            previous1Week: Math.round(fg.previous_1_week),
            previous1Month: Math.round(fg.previous_1_month),
            previous1Year: Math.round(fg.previous_1_year),
            timestamp: fg.timestamp,
        };

        _cnnFgCache = result;
        _cnnFgCacheTime = now;

        return res.status(200).json({ ...result, cached: false });
    } catch (e) {
        console.error('CNN Fear & Greed Error:', e);
        return res.status(200).json({ success: false, error: e.message });
    }
}
