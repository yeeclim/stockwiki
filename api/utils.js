// Utility API
// Charts, Commodity Prices, Fear & Greed Index, 국내주식 KIS 일봉

import { applyCors } from './_shared.js';
import { fetchLiveQuotes } from './_us-recommend-shared.js';
import { handleAdminCandidate } from './_admin-screening.js';
import { handleUnsubscribe } from './_email-unsubscribe.js';

export default async function handler(req, res) {
    if (applyCors(req, res, { methods: 'GET, POST, OPTIONS', json: false })) return;

    try {
        const { type } = req.query;

        if (type === 'chart')     return await handleChartProxy(req, res);
        if (type === 'commodity') return await handleCommodityPrice(req, res);
        if (type === 'fear-greed') return await handleFearGreed(req, res);
        if (type === 'cnn-fear-greed') return await handleCnnFearGreed(req, res);
        if (type === 'kr-candles') return await handleKrCandles(req, res);
        if (type === 'us-candles') return await handleUsCandles(req, res);
        if (type === 'us-quote')   return await handleUsQuote(req, res);
        if (type === 'admin-candidate') return await handleAdminCandidate(req, res);
        if (type === 'unsubscribe') return await handleUnsubscribe(req, res);

        return res.status(400).json({ error: 'Invalid utility type' });
    } catch (error) {
        console.error('Utils API Error:', error);
        return res.status(200).json({ success: false, error: 'Internal Server Error', fallback: true });
    }
}

// ── 국내주식 실차트용 일봉 데이터 (KIS Open API) ──────────────────────────────
// 지표(이평선/볼린저/RSI/MACD 등)는 계산하지 않고 원본 OHLCV만 반환한다 —
// 지표 계산은 Flutter 클라이언트의 k_chart_plus 패키지가 담당한다.

const KIS_BASE_URL = 'https://openapi.koreainvestment.com:9443';
let _kisTokenCache = { token: null, expiresAt: 0 };
let _kisTokenInflight = null;
const _krCandleCache = new Map();
const KR_CANDLE_CACHE_TTL = 4 * 60 * 60 * 1000; // 4시간

// KIS 는 토큰 재발급을 1분 1회로 제한한다. 캐시가 빈 상태에서 요청이 동시에 몰리면
// 전부 발급을 시도해 뒤쪽 요청이 실패했으므로, 진행 중인 발급 하나를 공유한다.
async function getKisToken() {
    if (_kisTokenCache.token && Date.now() < _kisTokenCache.expiresAt) {
        return _kisTokenCache.token;
    }
    if (!_kisTokenInflight) {
        _kisTokenInflight = issueKisToken().finally(() => { _kisTokenInflight = null; });
    }
    return _kisTokenInflight;
}

async function issueKisToken() {
    const appKey = process.env.KIS_APP_KEY;
    const appSecret = process.env.KIS_APP_SECRET;
    if (!appKey || !appSecret) {
        throw new Error('KIS_APP_KEY/KIS_APP_SECRET 미설정');
    }

    const res = await fetch(`${KIS_BASE_URL}/oauth2/tokenP`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
            grant_type: 'client_credentials',
            appkey: appKey,
            appsecret: appSecret,
        }),
    });
    if (!res.ok) {
        const err = await res.text();
        throw new Error(`KIS 토큰 발급 실패: HTTP ${res.status} ${err.substring(0, 150)}`);
    }
    const data = await res.json();
    if (!data.access_token) throw new Error('KIS 토큰 응답이 비어있습니다');

    _kisTokenCache = {
        token: data.access_token,
        expiresAt: Date.now() + (data.expires_in ?? 86400) * 1000 - 5 * 60 * 1000,
    };
    return _kisTokenCache.token;
}

function kisHeaders(token, trId) {
    return {
        'content-type': 'application/json',
        authorization: `Bearer ${token}`,
        appkey: process.env.KIS_APP_KEY,
        appsecret: process.env.KIS_APP_SECRET,
        tr_id: trId,
        custtype: 'P',
    };
}

function formatYmd(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, '0');
    const d = String(date.getDate()).padStart(2, '0');
    return `${y}${m}${d}`;
}

async function fetchKrDailyPage(code, token, dateFrom, dateTo, periodDiv) {
    const url = new URL(`${KIS_BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice`);
    url.search = new URLSearchParams({
        FID_COND_MRKT_DIV_CODE: 'J',
        FID_INPUT_ISCD: code,
        FID_INPUT_DATE_1: dateFrom,
        FID_INPUT_DATE_2: dateTo,
        FID_PERIOD_DIV_CODE: periodDiv,
        FID_ORG_ADJ_PRC: '0',
    }).toString();

    const res = await fetch(url, { headers: kisHeaders(token, 'FHKST03010100') });
    if (!res.ok) {
        const err = await res.text();
        throw new Error(`KIS 차트 조회 실패: HTTP ${res.status} ${err.substring(0, 150)}`);
    }
    const data = await res.json();
    if (data.rt_cd !== '0') {
        throw new Error(`KIS 차트 오류: ${data.msg1 || '알 수 없는 오류'}`);
    }
    return data.output2 || [];
}

// 일/주/월봉별 페이지당 조회 구간(달력일)과 목표 건수 — KIS는 FID_PERIOD_DIV_CODE로
// 이미 주/월 단위로 집계된 봉을 내려주므로 프론트에서 따로 집계할 필요가 없다.
const PERIOD_CONFIG = {
    D: { pageSpanDays: 140, target: 450, maxPages: 6 }, // ~90~100 거래일/페이지
    W: { pageSpanDays: 800, target: 300, maxPages: 6 }, // ~100주/페이지
    M: { pageSpanDays: 3200, target: 200, maxPages: 5 }, // ~100개월/페이지
};

// 1회 호출당 최대 100건 제한을 우회하기 위해 조회 구간을 뒤로 밀어가며 반복 호출
async function fetchKrDailyCandles(code, periodDiv = 'D') {
    const config = PERIOD_CONFIG[periodDiv] || PERIOD_CONFIG.D;
    const token = await getKisToken();
    const collected = new Map(); // date(yyyymmdd) -> row, 중복 제거용

    let cursorEnd = new Date();

    for (let page = 0; page < config.maxPages && collected.size < config.target; page++) {
        const dateTo = formatYmd(cursorEnd);
        const cursorStart = new Date(cursorEnd);
        cursorStart.setDate(cursorStart.getDate() - config.pageSpanDays);
        const dateFrom = formatYmd(cursorStart);

        const rows = await fetchKrDailyPage(code, token, dateFrom, dateTo, periodDiv);
        if (rows.length === 0) break; // 상장일 이전 구간 도달

        for (const row of rows) {
            const date = row.stck_bsop_date;
            if (date && row.stck_clpr && row.stck_clpr !== '0') {
                collected.set(date, row);
            }
        }

        cursorEnd = cursorStart;
        cursorEnd.setDate(cursorEnd.getDate() - 1);
    }

    const dates = [...collected.keys()].sort();
    return dates.map((date) => {
        const row = collected.get(date);
        const y = Number(date.slice(0, 4));
        const m = Number(date.slice(4, 6)) - 1;
        const d = Number(date.slice(6, 8));
        return {
            time: Date.UTC(y, m, d),
            open: Number(row.stck_oprc),
            high: Number(row.stck_hgpr),
            low: Number(row.stck_lwpr),
            close: Number(row.stck_clpr),
            vol: Number(row.acml_vol || 0),
        };
    });
}

async function handleKrCandles(req, res) {
    const code = (req.query.code || '').toString().trim();
    if (!/^\d{6}$/.test(code)) {
        return res.status(400).json({ success: false, error: '유효하지 않은 종목코드입니다' });
    }
    const periodRaw = (req.query.period || 'D').toString().toUpperCase();
    const period = ['D', 'W', 'M'].includes(periodRaw) ? periodRaw : 'D';

    const cacheKey = `${code}:${period}`;
    const cached = _krCandleCache.get(cacheKey);
    if (cached && Date.now() - cached.time < KR_CANDLE_CACHE_TTL) {
        return res.status(200).json({ success: true, data: cached.data, cached: true });
    }

    try {
        const data = await fetchKrDailyCandles(code, period);
        _krCandleCache.set(cacheKey, { data, time: Date.now() });
        return res.status(200).json({ success: true, data });
    } catch (error) {
        console.error(`❌ 국내주식 차트 조회 실패 (${code}, ${period}):`, error.message);
        return res.status(500).json({ success: false, error: error.message || '차트 조회 중 오류 발생' });
    }
}

// 미국주식 일/주/월봉 — Yahoo Finance.
//
// 예전엔 finviz 차트 PNG를 프록시해 이미지로 보여줬는데, finviz 가 Cloudflare 로
// 막히면서(자기 자신으로 302 무한 리다이렉트) 미국 차트가 통째로 죽어 있었다.
// 국내(kr-candles)와 똑같은 JSON 형태로 내려주고 클라이언트의 k_chart_plus 가
// 그리게 하면, 이미지 소스 한 곳이 막힌다고 차트가 사라지는 구조에서 벗어난다.
async function handleUsCandles(req, res) {
    const raw = (req.query.symbol || '').toString().trim().toUpperCase();
    if (!/^[A-Z][A-Z0-9.\-]{0,9}$/.test(raw)) {
        return res.status(400).json({ success: false, error: '유효하지 않은 심볼입니다' });
    }
    // Yahoo 는 클래스주를 BRK-B 처럼 하이픈으로 쓴다. /api/us-stock-search 도
    // 하이픈 형식을 주므로 실사용 경로는 그대로지만, 다른 소스에서 온 BRK.B
    // 형식이 들어와도 404 로 떨어지지 않도록 맞춰 준다.
    const symbol = raw.replace('.', '-');
    const periodRaw = (req.query.period || 'D').toString().toUpperCase();
    const period = ['D', 'W', 'M'].includes(periodRaw) ? periodRaw : 'D';

    const cacheKey = `us:${symbol}:${period}`;
    const cached = _krCandleCache.get(cacheKey);
    if (cached && Date.now() - cached.time < KR_CANDLE_CACHE_TTL) {
        return res.status(200).json({ success: true, data: cached.data, cached: true });
    }

    const { range, interval } = period === 'M' ? { range: '10y', interval: '1mo' }
                             : period === 'W' ? { range: '5y',  interval: '1wk' }
                             : { range: '2y',  interval: '1d' };

    try {
        const url = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}`
                  + `?range=${range}&interval=${interval}`;
        const response = await fetchWithTimeout(url, {
            headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' },
        });
        if (!response.ok) throw new Error(`Yahoo ${response.status}`);

        const json = await response.json();
        const result = json?.chart?.result?.[0];
        const stamps = result?.timestamp || [];
        const q = result?.indicators?.quote?.[0] || {};
        if (!stamps.length) throw new Error('데이터 없음');

        // 종가가 null 인 봉(거래정지·데이터 결측)은 건너뛴다. k_chart_plus 가
        // null 을 만나면 지표 계산에서 NaN 이 번진다.
        const data = [];
        for (let i = 0; i < stamps.length; i++) {
            const close = q.close?.[i];
            if (close === null || close === undefined) continue;
            data.push({
                time:  stamps[i] * 1000,
                open:  Number(q.open?.[i] ?? close),
                high:  Number(q.high?.[i] ?? close),
                low:   Number(q.low?.[i] ?? close),
                close: Number(close),
                vol:   Number(q.volume?.[i] ?? 0),
            });
        }
        if (!data.length) throw new Error('유효한 봉 없음');

        _krCandleCache.set(cacheKey, { data, time: Date.now() });
        return res.status(200).json({ success: true, data });
    } catch (error) {
        console.error(`❌ 미국주식 차트 조회 실패 (${symbol}, ${period}):`, error.message);
        return res.status(500).json({ success: false, error: error.message || '차트 조회 중 오류 발생' });
    }
}

// 포트폴리오 화면의 미국 종목 현재가. 별도 api/us-quote.js 를 만들면 Vercel Hobby
// 함수 12개 한도를 넘으므로 여기서 분기한다 (클라이언트가 404 를 받고 있었다).
async function handleUsQuote(req, res) {
    // 요청 표기(BRK.B) → Yahoo 표기(BRK-B). 응답은 요청 표기 그대로 돌려줘야 클라이언트 키와 맞는다.
    const requested = [...new Set(
        (req.query.symbols || '').toString().toUpperCase().split(',')
            .map(s => s.trim())
            .filter(s => /^[A-Z][A-Z0-9.\-]{0,9}$/.test(s))
    )].slice(0, 50);
    if (!requested.length) {
        return res.status(400).json({ success: false, error: 'symbols 파라미터가 필요합니다' });
    }
    const toYahoo = (s) => s.replace('.', '-');
    const map = await fetchLiveQuotes(requested.map(toYahoo), 'symbol,regularMarketPrice,regularMarketChangePercent');
    const data = requested
        .filter(s => map[toYahoo(s)]?.regularMarketPrice != null)
        .map(s => ({
            symbol: s,
            price: map[toYahoo(s)].regularMarketPrice,
            changePercent: map[toYahoo(s)].regularMarketChangePercent ?? null,
        }));
    res.setHeader('Cache-Control', 's-maxage=60');
    return res.status(200).json({ success: true, data });
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
        // 예전엔 여기서 1380 을 실제 환율인 것처럼 돌려줬다. 틀린 숫자보다 실패가 낫다.
        return res.status(200).json({ success: false, error: 'Rate unavailable' });
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

    // v7 quote 로 최후 시도 (crumb 필요 — 공용 헬퍼 사용)
    const quote = (await fetchLiveQuotes([yahooSymbol], 'symbol,regularMarketPrice'))[yahooSymbol];
    if (quote?.regularMarketPrice) {
        return res.status(200).json(wrapPrice(quote.regularMarketPrice));
    }

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
