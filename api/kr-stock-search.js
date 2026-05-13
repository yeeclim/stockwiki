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
    // finance.naver.com 검색 결과 HTML 파싱 (Vercel에서 접근 가능한 도메인)
    let items = await naverFinanceSearch(q, type);

    if (items.length === 0) {
      return res.json({ success: true, data: [] });
    }

    items = items.slice(0, 15);

    // 가격 병렬 조회
    const settled = await Promise.allSettled(items.map(item => fetchPrice(item)));
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

// ── Naver Finance 검색 (HTML 파싱) ─────────────────────────────────────────────
async function naverFinanceSearch(q, type) {
  const encoded = encodeURIComponent(q);
  const url = `https://finance.naver.com/search/searchList.naver?query=${encoded}`;

  const html = await fetchText(url, 10000, {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ko-KR,ko;q=0.9',
  });

  if (!html) {
    console.error('[naverFinanceSearch] empty response');
    return [];
  }

  const results = [];
  const seen = new Set();

  // href="/item/main.naver?code=XXXXXX" 패턴으로 종목 코드·이름 추출
  // 종목 이름은 <a> 태그 텍스트 또는 내부 <em>/<strong> 텍스트
  const linkRe = /href="\/item\/(?:main|sise)\.naver\?code=(\d{6})"[^>]*>([\s\S]*?)<\/a>/gi;
  let m;
  while ((m = linkRe.exec(html)) !== null) {
    const code = m[1];
    // 내부 태그 제거하여 순수 텍스트 추출
    const rawName = m[2].replace(/<[^>]+>/g, '').trim();
    if (!rawName || seen.has(code)) continue;
    seen.add(code);

    const isEtf = code.startsWith('5') // ETN 코드 대역
               || /ETF|ETN|레버리지|인버스|선물|채권|리츠|커버드콜|인컴|위클리|월지급/i.test(rawName);
    const market = ''; // HTML에서 시장 구분은 별도 파싱 필요 시 추가

    if (type === 'stock' && isEtf) continue;
    if (type === 'etf' && !isEtf) continue;

    results.push({ code, name: rawName, isEtf, market });
  }

  // 결과가 없으면 더 넓은 패턴으로 재시도 (code= 포함 링크만)
  if (results.length === 0) {
    const codeRe = /[?&]code=(\d{6})[^"]*"[^>]*>([^<]{2,40})</gi;
    while ((m = codeRe.exec(html)) !== null) {
      const code = m[1];
      const name = m[2].trim();
      if (!name || name.length < 2 || seen.has(code)) continue;
      seen.add(code);
      const isEtf = code.startsWith('5')
                 || /ETF|ETN|레버리지|인버스|선물|채권|리츠|커버드콜|인컴|위클리|월지급/i.test(name);
      if (type === 'stock' && isEtf) continue;
      if (type === 'etf' && !isEtf) continue;
      results.push({ code, name, isEtf, market: '' });
    }
  }

  return results;
}

// ── 가격 조회 (Naver fchart) ───────────────────────────────────────────────────
async function fetchPrice(item) {
  const { code, name, isEtf, market } = item;
  let price = null, changePercent = null;
  try {
    const url = `https://fchart.stock.naver.com/sise.nhn?symbol=${code}&timeframe=day&count=2&requestType=0`;
    const text = await fetchText(url, 5000);
    if (text) {
      const matches = [...text.matchAll(/data="[^|"]+\|[^|"]+\|[^|"]+\|[^|"]+\|([^|"]+)\|/g)];
      const closes = matches.map(m2 => parseFloat(m2[1])).filter(v => !isNaN(v) && v > 0);
      if (closes.length >= 1) price = closes[closes.length - 1];
      if (closes.length >= 2) {
        const prev = closes[closes.length - 2];
        if (prev > 0) changePercent = (price - prev) / prev * 100;
      }
    }
  } catch (_) {}
  return { code, name, isEtf, market, price, changePercent };
}

// ── 공통 fetch 유틸 ────────────────────────────────────────────────────────────
async function fetchText(url, timeoutMs = 8000, extraHeaders = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://finance.naver.com/',
        ...extraHeaders,
      },
      signal: controller.signal,
    });
    if (!res.ok) {
      console.error('[fetchText] HTTP', res.status, url);
      return null;
    }
    return await res.text();
  } catch (e) {
    if (e.name !== 'AbortError') console.error('[fetchText]', e.message, url);
    return null;
  } finally {
    clearTimeout(timer);
  }
}
