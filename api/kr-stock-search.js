import { checkRateLimit, getClientIp, fail } from './shared.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Content-Type', 'application/json');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  if (!checkRateLimit(getClientIp(req), 30, 60_000)) {
    return fail(res, 429, '요청이 너무 많습니다.');
  }

  const { query = '', type = 'all' } = req.query;
  const q = query.trim();
  if (!q) return res.json({ success: true, data: [] });

  try {
    const seen = new Map(); // code → item

    // 검색어 준비: 전체 + ASCII prefix
    const queries = [q];
    const asciiPrefix = q.match(/^[A-Za-z0-9\s\-\.]+/)?.[0]?.trim() ?? '';
    if (asciiPrefix && asciiPrefix.length >= 2 && asciiPrefix !== q) {
      queries.push(asciiPrefix);
    }
    // 한국어 ETF 용어 → 영어 번역 쿼리 추가 (TradingView는 영어 description 검색)
    // 예: "SOL 200타겟위클리커버드콜" → "SOL 200 target weekly covered call"
    const translated = translateForTv(q);
    if (translated && translated !== q && translated !== asciiPrefix && !queries.includes(translated)) {
      queries.push(translated);
    }

    // ASCII prefix가 다단어(예: "SOL 200")이면 펀드 패밀리(첫 단어 "SOL")로도 추가 검색
    const asciiParts = asciiPrefix.split(/\s+/).filter(Boolean);
    if (asciiParts.length >= 2) {
      const fundFamily = asciiParts[0];
      if (fundFamily.length >= 2 && !queries.includes(fundFamily)) {
        queries.push(fundFamily);
      }
    }

    // 1차: TradingView + KRX 병렬 (sin1 리전에서 KRX 접근 시도)
    await Promise.all([
      ...queries.map(qry => tradingviewQuery(qry, type, seen, q)),
      ...queries.map(qry => krxQuery(qry, type, seen)),
    ]);
    console.log(`[primary] ${seen.size} results for "${q}"`);

    // 2차: Yahoo Finance (추가 보완)
    if (seen.size < 12) {
      await Promise.all(queries.map(qry => yahooQuery(qry, type, seen)));
      console.log(`[yahoo] ${seen.size} results`);
    }

    // 3차: Daum Finance (카카오)
    if (seen.size < 5) {
      await Promise.all(queries.map(qry => daumQuery(qry, type, seen)));
      console.log(`[daum] ${seen.size} results`);
    }

    // 4차: Naver 모바일 (fallback)
    if (seen.size < 3) {
      for (const qry of queries) {
        await naverMobileQuery(qry, type, seen);
      }
      console.log(`[naver] ${seen.size} results`);
    }

    const items = [...seen.values()].slice(0, 15);
    if (items.length === 0) return res.json({ success: true, data: [] });

    // 가격 병렬 조회
    const settled = await Promise.allSettled(items.map(fetchPrice));
    const data = settled
      .filter(r => r.status === 'fulfilled' && r.value)
      .map(r => r.value);

    res.setHeader('Cache-Control', 's-maxage=30');
    res.json({ success: true, data });
  } catch (e) {
    console.error('kr-stock-search error:', e.message);
    res.status(500).json({ success: false, error: '검색 중 오류: ' + e.message });
  }
}

// KRX 종목코드: 숫자 6자리 또는 숫자로 시작하는 6자리 알파뉴메릭 (예: 0167B0)
const KRX_CODE = /^\d[A-Z0-9]{5}$/i;

// ── TradingView 심볼 검색 ─────────────────────────────────────────────────────
// filterQuery: 결과 관련성 판단에 쓸 원본 쿼리 (예: "SOL 200")
async function tradingviewQuery(q, type, seen, filterQuery = q) {
  // 필터 조건: filterQuery에서 ASCII 단어(2자+) + 3자리 이상 숫자 모두 추출
  // "SOL 200" → ["sol","200"], 결과명에 모두 포함돼야 함 (SOL SP500 같은 오탐 제거)
  const filterTerms = [
    ...(filterQuery.match(/\b[A-Za-z]{2,}\b/g) ?? []).map(w => w.toLowerCase()),
    ...(filterQuery.match(/\b\d{3,}\b/g) ?? []),
  ];

  try {
    // 번역된 영어 쿼리(filterQuery에 한글 없는 경우)는 exchange 필터 없이 글로벌 검색
    // KRX가 일부 ETF를 exchange=KRX 인덱스에 미등록하는 케이스 보완
    const isTranslated = !/[가-힣]/.test(q) && q !== filterQuery && /[가-힣]/.test(filterQuery);
    const exchangeParam = isTranslated ? '' : '&exchange=KRX';
    const url = `https://symbol-search.tradingview.com/symbol_search/?text=${encodeURIComponent(q)}&hl=0${exchangeParam}&lang=ko&type=&domain=production&limit=50`;
    const text = await fetchText(url, 8000, {
      'Referer': 'https://www.tradingview.com/',
      'Accept': 'application/json',
      'Origin': 'https://www.tradingview.com',
    });
    if (!text) return;
    let data; try { data = JSON.parse(text); } catch { console.log('[tv] parse err, raw:', text?.substring(0, 100)); return; }

    const list = Array.isArray(data) ? data : (data?.symbols ?? []);
    for (const item of list) {
      // TradingView: symbol = "466930" or "KRX:0167B0" (알파뉴메릭 포함)
      const raw = item.symbol ?? '';
      const code = raw.replace(/^.*:/, '').replace(/[^A-Z0-9]/gi, '').slice(0, 6).toUpperCase();
      if (!code || !KRX_CODE.test(code) || seen.has(code)) continue;
      // local_description(한글) 우선, 없으면 영문 → 한글 변환
      const rawName = (item.local_description || item.description || '').replace(/<[^>]+>/g, '').trim();
      const name = korenizeName(rawName);
      if (!name) continue;
      // 필터: 쿼리의 모든 핵심 단어/숫자가 결과명에 있어야 함
      if (filterTerms.length > 0) {
        const nl = name.toLowerCase();
        if (!filterTerms.every(t => nl.includes(t))) continue;
      }
      const itemType = (item.type ?? '').toLowerCase();
      const isEtf = itemType === 'fund' || itemType === 'etf' || code.startsWith('5');
      const market = item.exchange || 'KRX';
      if (type === 'stock' && isEtf) continue;
      if (type === 'etf' && !isEtf) continue;
      seen.set(code, { code, name, isEtf, market });
    }
  } catch (e) { console.error('[tv]', e.message); }
}

// ── KRX 공식 종목 검색 ────────────────────────────────────────────────────────
async function krxQuery(q, type, seen) {
  try {
    // ETF·ETN 검색
    if (type !== 'stock') {
      const etfBody = new URLSearchParams({
        bld: 'dbms/comm/finder/finderStkEtfFind',
        searchText: q,
        pageNo: '1',
        pageSize: '30',
      });
      const etfText = await fetchPostText(
        'https://data.krx.co.kr/comm/bldAttendant/getJsonData.cmd',
        etfBody.toString(),
        { 'Referer': 'https://data.krx.co.kr/', 'Origin': 'https://data.krx.co.kr' }
      );
      if (etfText) {
        let d; try { d = JSON.parse(etfText); } catch { d = null; }
        const list = d?.OutBlock_1 ?? d?.result ?? d?.block1 ?? [];
        if (list.length === 0) return; // KRX 응답 파싱 실패
        for (const item of list) {
          const code = (item.ISU_SRT_CD || item.isuSrtCd || item.shortCode || '').replace(/[^A-Z0-9]/gi, '').slice(0, 6).toUpperCase();
          const name = item.ISU_ABBR_NM || item.isuAbbrNm || item.ISU_NM || item.isuNm || '';
          if (!code || !name || !KRX_CODE.test(code) || seen.has(code)) continue;
          const isEtf = true;
          const market = item.MKT_NM || item.mktNm || 'KRX';
          seen.set(code, { code, name, isEtf, market });
        }
      }
    }

    // 일반 주식 검색
    if (type !== 'etf') {
      const stkBody = new URLSearchParams({
        bld: 'dbms/comm/finder/finderStkFind',
        searchText: q,
        pageNo: '1',
        pageSize: '30',
      });
      const stkText = await fetchPostText(
        'https://data.krx.co.kr/comm/bldAttendant/getJsonData.cmd',
        stkBody.toString(),
        { 'Referer': 'https://data.krx.co.kr/', 'Origin': 'https://data.krx.co.kr' }
      );
      if (stkText) {
        let d; try { d = JSON.parse(stkText); } catch { d = null; }
        const list = d?.OutBlock_1 ?? d?.result ?? d?.block1 ?? [];
        if (list.length === 0) return; // KRX 응답 파싱 실패
        for (const item of list) {
          const code = (item.ISU_SRT_CD || item.isuSrtCd || item.shortCode || '').replace(/[^A-Z0-9]/gi, '').slice(0, 6).toUpperCase();
          const name = item.ISU_ABBR_NM || item.isuAbbrNm || item.ISU_NM || item.isuNm || '';
          if (!code || !name || !KRX_CODE.test(code) || seen.has(code)) continue;
          const isEtf = false;
          const market = item.MKT_NM || item.mktNm || '';
          seen.set(code, { code, name, isEtf, market });
        }
      }
    }
  } catch (e) { console.error('[krx]', e.message); }
}

// ── Yahoo Finance ──────────────────────────────────────────────────────────────
async function yahooQuery(q, type, seen) {
  // query1과 query2 병렬 시도 - 서버마다 결과가 다를 수 있음
  const hosts = ['query1.finance.yahoo.com', 'query2.finance.yahoo.com'];
  await Promise.all(hosts.map(host => yahooQueryHost(host, q, type, seen)));
}

async function yahooQueryHost(host, q, type, seen) {
  try {
    const url = `https://${host}/v1/finance/search?q=${encodeURIComponent(q)}&quotesCount=50&newsCount=0&enableFuzzyQuery=true&lang=ko-KR&region=KR`;
    const text = await fetchText(url, 8000, { 'Accept': 'application/json' });
    if (!text) return;
    let data; try { data = JSON.parse(text); } catch { return; }

    for (const quote of (data?.quotes ?? [])) {
      const symbol = quote.symbol ?? '';
      if (!/\.(KS|KQ)$/.test(symbol)) continue;
      const code = symbol.replace(/\.(KS|KQ)$/, '').replace(/[^A-Z0-9]/gi, '').slice(0, 6).toUpperCase();
      if (!KRX_CODE.test(code) || seen.has(code)) continue;
      const name = quote.shortname || quote.longname || '';
      if (!name) continue;
      const isEtf = /^ETF/.test(quote.quoteType ?? '') || code.startsWith('5');
      const market = symbol.endsWith('.KQ') ? 'KOSDAQ' : 'KOSPI';
      if (type === 'stock' && isEtf) continue;
      if (type === 'etf' && !isEtf) continue;
      seen.set(code, { code, name, isEtf, market });
    }
  } catch (e) { console.error('[yahoo]', e.message); }
}

// ── Daum Finance (카카오) ─────────────────────────────────────────────────────
async function daumQuery(q, type, seen) {
  try {
    const url = `https://finance.daum.net/api/search/stocks?q=${encodeURIComponent(q)}&includeEtf=true&includeFund=false&limit=20`;
    const text = await fetchText(url, 8000, {
      'Referer': 'https://finance.daum.net/',
      'Origin': 'https://finance.daum.net',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'ko-KR,ko;q=0.9',
    });
    if (!text) return;
    let data; try { data = JSON.parse(text); } catch { return; }

    const list = data?.data ?? data?.result ?? [];
    for (const item of list) {
      const rawCode = item.shortCode || item.code || item.symbolCode?.replace(/^[A-Z]/, '') || '';
      const code = rawCode.replace(/[^A-Z0-9]/gi, '').slice(0, 6).toUpperCase();
      if (!code || !KRX_CODE.test(code) || seen.has(code)) continue;
      const name = item.name || item.stockName || '';
      if (!name) continue;
      const isEtf = (item.type ?? '').toUpperCase().includes('ETF')
                 || (item.securityType ?? '').toUpperCase().includes('ETF')
                 || code.startsWith('5');
      const market = item.market?.name || item.marketName || '';
      if (type === 'stock' && isEtf) continue;
      if (type === 'etf' && !isEtf) continue;
      seen.set(code, { code, name, isEtf, market });
    }
  } catch (e) { console.error('[daum]', e.message); }
}

// ── Naver 모바일 ───────────────────────────────────────────────────────────────
async function naverMobileQuery(q, type, seen) {
  const endpoints = [
    `https://m.stock.naver.com/api/search/searchWord?searchWord=${encodeURIComponent(q)}&pageSize=20`,
    `https://m.stock.naver.com/api/stocks/search?keyword=${encodeURIComponent(q)}&page=1&pageSize=20`,
  ];
  for (const url of endpoints) {
    try {
      const text = await fetchText(url, 8000, { 'Referer': 'https://m.stock.naver.com/' });
      if (!text) continue;
      let data; try { data = JSON.parse(text); } catch { continue; }
      const list = data?.stockList || data?.stocks || data?.items || data?.result?.stockList || [];
      if (!Array.isArray(list) || list.length === 0) continue;
      for (const item of list) {
        const code = (item.itemCode || item.stockCode || item.code || '').replace(/[^A-Z0-9]/gi, '').slice(0, 6).toUpperCase();
        const name = item.itemName || item.stockName || item.name || '';
        if (!code || !name || !KRX_CODE.test(code) || seen.has(code)) continue;
        const isEtf = !!(item.etfType) || code.startsWith('5');
        const market = item.stockExchangeType?.name || item.market || '';
        if (type === 'stock' && isEtf) continue;
        if (type === 'etf' && !isEtf) continue;
        seen.set(code, { code, name, isEtf, market });
      }
      if (seen.size > 0) break;
    } catch (e) { console.error('[naver]', url, e.message); }
  }
}

// ── Naver fchart 가격 ─────────────────────────────────────────────────────────
async function fetchPrice(item) {
  const { code, name, isEtf, market } = item;
  let price = null, changePercent = null;
  try {
    const url = `https://fchart.stock.naver.com/sise.nhn?symbol=${code}&timeframe=day&count=2&requestType=0`;
    const text = await fetchText(url, 5000);
    if (text) {
      const matches = [...text.matchAll(/data="[^|"]+\|[^|"]+\|[^|"]+\|[^|"]+\|([^|"]+)\|/g)];
      const closes = matches.map(m => parseFloat(m[1])).filter(v => !isNaN(v) && v > 0);
      if (closes.length >= 1) price = closes[closes.length - 1];
      if (closes.length >= 2) {
        const prev = closes[closes.length - 2];
        if (prev > 0) changePercent = (price - prev) / prev * 100;
      }
    }
  } catch (_) {}
  return { code, name, isEtf, market, price, changePercent };
}

// ── 한국어 ETF 용어 → 영어 번역 (TradingView 검색 최적화) ──────────────────────
const KO_EN = [
  ['타겟위클리커버드콜', 'target weekly covered call'],
  ['위클리커버드콜', 'weekly covered call'],
  ['커버드콜', 'covered call'],
  ['위클리', 'weekly'],
  ['타겟', 'target'],
  ['인버스2x', 'inverse 2x'],
  ['인버스', 'inverse'],
  ['레버리지', 'leverage'],
  ['배당성장', 'dividend growth'],
  ['배당', 'dividend'],
  ['성장', 'growth'],
  ['가치', 'value'],
  ['모멘텀', 'momentum'],
  ['헬스케어', 'healthcare'],
  ['반도체', 'semiconductor'],
  ['금융', 'financial'],
  ['리츠', 'reits'],
  ['선물', 'futures'],
  ['단기채', 'short term bond'],
  ['국채', 'government bond'],
  ['회사채', 'corporate bond'],
  ['채권', 'bond'],
];

// TradingView 영문 ETF명 → 한글 변환
// "Shinhan SOL 200 Target Weekly Covered Call ETF Units" → "SOL 200타겟위클리커버드콜"
const ETF_BRANDS = [
  'KODEX', 'TIGER', 'RISE', 'KBSTAR', 'ARIRANG', 'HANARO', 'ACE',
  'KOSEF', 'SOL', 'FOCUS', 'MASTER', 'PLUS', 'TRUE', 'TIMEFOLIO',
  'TREX', 'BNK', 'WOORI',
];

function korenizeName(name) {
  if (!name || /[가-힣]/.test(name)) return name; // 이미 한글이면 그대로

  let n = name;

  // ETF 브랜드명 앞에 붙은 운용사 이름 통째로 제거
  // "Shinhan SOL ..." → "SOL ...", "Mirae Asset TIGER ..." → "TIGER ..."
  for (const brand of ETF_BRANDS) {
    const idx = n.search(new RegExp(`\\b${brand}\\b`, 'i'));
    if (idx > 0) { n = n.slice(idx); break; }
  }

  // 뒤쪽 "ETF Units / ETF / Units / Fund" 제거
  n = n.replace(/\s+(ETF Units|ETF|Units|Fund)\s*$/i, '').trim();

  // 영어 ETF 용어 → 한글 (긴 표현 먼저)
  for (const [en, ko] of [
    ['Target Weekly Covered Call', '타겟위클리커버드콜'],
    ['Weekly Covered Call', '위클리커버드콜'],
    ['Covered Call', '커버드콜'],
    ['Inverse 2[xX]', '인버스2X'],
    ['Leverage', '레버리지'],
    ['Inverse', '인버스'],
    ['Dividend Growth', '배당성장'],
    ['Dividend', '배당'],
    ['Momentum', '모멘텀'],
    ['Healthcare', '헬스케어'],
    ['Semiconductor', '반도체'],
    ['Government Bond', '국채'],
    ['Corporate Bond', '회사채'],
    ['Bond', '채권'],
    ['REITs', '리츠'],
    ['Futures', '선물'],
    ['Total Return', 'TR'],
    ['Weekly', '위클리'],
    ['Top 10', 'TOP10'],
  ]) {
    n = n.replace(new RegExp(en, 'gi'), ko);
  }

  // 한글 앞 공백 제거: "SOL 200 타겟위클리" → "SOL 200타겟위클리"
  n = n.replace(/\s+(?=[가-힣])/g, '');

  return n.trim() || name;
}

function translateForTv(q) {
  let result = q;
  for (const [ko, en] of KO_EN) {
    result = result.replace(new RegExp(ko, 'g'), ' ' + en);
  }
  // 숫자+한글 사이 공백 정리, 연속 공백 제거, 앞뒤 정리
  return result.replace(/\s+/g, ' ').trim();
}

// ── 공통 GET fetch ────────────────────────────────────────────────────────────
async function fetchText(url, timeoutMs = 8000, extraHeaders = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://finance.naver.com/',
        ...extraHeaders,
      },
      signal: controller.signal,
    });
    if (!res.ok) { console.error('[fetchText] HTTP', res.status, url); return null; }
    return await res.text();
  } catch (e) {
    if (e.name !== 'AbortError') console.error('[fetchText]', e.message, url);
    return null;
  } finally {
    clearTimeout(timer);
  }
}

// ── 공통 POST fetch ────────────────────────────────────────────────────────────
async function fetchPostText(url, body, extraHeaders = {}, timeoutMs = 8000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Accept': 'application/json, text/plain, */*',
        ...extraHeaders,
      },
      body,
      signal: controller.signal,
    });
    if (!res.ok) { console.error('[fetchPost] HTTP', res.status, url); return null; }
    return await res.text();
  } catch (e) {
    if (e.name !== 'AbortError') console.error('[fetchPost]', e.message, url);
    return null;
  } finally {
    clearTimeout(timer);
  }
}
