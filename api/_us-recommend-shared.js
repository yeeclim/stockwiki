// api/_us-recommend-shared.js
// us-recommend.js · us-stock-search.js · utils.js 가 공유하는 Yahoo Finance 실시간 시세 조회 +
// 점수→액션/추천사유 변환 헬퍼. Naver 쪽의 api/_naver-stock.js와 동일한 내부 공용 모듈 컨벤션.

// ── Yahoo Finance 실시간 시세 (표시용 보강) ─────────────────────────────────
// v7/finance/quote 는 쿠키+crumb 없이 부르면 401 이다. 이 레포의 다른 엔드포인트
// (us-stock-search, utils 의 상품 시세, 포트폴리오 시세)가 crumb 없이 부르다가
// 가격이 전부 null 로 떨어졌으므로, 인증이 필요한 호출은 반드시 이 함수를 쓴다.
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36';
const DEFAULT_FIELDS = 'shortName,regularMarketPrice,regularMarketChangePercent,regularMarketVolume,marketCap,fiftyDayAverage,twoHundredDayAverage,fiftyTwoWeekHigh,fiftyTwoWeekLow';
const CRUMB_TTL = 30 * 60 * 1000;
let _auth = null; // { cookie, crumb, time }

async function getYahooAuth(force = false) {
  if (!force && _auth && Date.now() - _auth.time < CRUMB_TTL) return _auth;
  const cookieRes = await fetch('https://fc.yahoo.com', {
    headers: { 'User-Agent': UA },
    redirect: 'manual',
    signal: AbortSignal.timeout(6000),
  });
  // Set-Cookie 의 Expires 값에도 쉼표가 들어가므로 split(',') 대신 getSetCookie() 를 쓴다
  const setCookies = typeof cookieRes.headers.getSetCookie === 'function'
    ? cookieRes.headers.getSetCookie()
    : (cookieRes.headers.get('set-cookie') ?? '').split(/,(?=\s*[A-Za-z0-9_]+=)/);
  const cookie = setCookies.map(c => c.split(';')[0].trim()).filter(Boolean).join('; ');

  const crumbRes = await fetch('https://query1.finance.yahoo.com/v1/test/getcrumb', {
    headers: { 'User-Agent': UA, Cookie: cookie },
    signal: AbortSignal.timeout(6000),
  });
  if (!crumbRes.ok) throw new Error(`Yahoo crumb 발급 실패: ${crumbRes.status}`);
  const crumb = (await crumbRes.text()).trim();
  _auth = { cookie, crumb, time: Date.now() };
  return _auth;
}

async function quoteRequest(symbols, fields, auth) {
  const url = `https://query1.finance.yahoo.com/v7/finance/quote`
    + `?symbols=${symbols.map(encodeURIComponent).join(',')}`
    + `&crumb=${encodeURIComponent(auth.crumb)}&fields=${fields}`;
  return fetch(url, {
    headers: { 'User-Agent': UA, Accept: 'application/json', Cookie: auth.cookie },
    signal: AbortSignal.timeout(8000),
  });
}

/** symbols → { SYMBOL: quote } . 실패 시 {} (호출부는 가격 없음으로 처리) */
export async function fetchLiveQuotes(symbols, fields = DEFAULT_FIELDS) {
  if (!symbols.length) return {};
  const map = {};
  // URL 길이 제한을 피하려고 나눠서 요청한다 (섹터 뷰는 최대 500종목).
  // 한 묶음이 실패해도 앞뒤 묶음 결과는 살린다 — 통째로 {} 를 돌려주면 섹터 뷰 전체가 빈다.
  for (let i = 0; i < symbols.length; i += 100) {
    const batch = symbols.slice(i, i + 100);
    try {
      let auth = await getYahooAuth();
      let response = await quoteRequest(batch, fields, auth);
      if (response.status === 401) {           // crumb 만료 — 한 번만 재발급
        auth = await getYahooAuth(true);
        response = await quoteRequest(batch, fields, auth);
      }
      if (!response.ok) throw new Error(`Yahoo Finance API 오류: ${response.status}`);
      const data = await response.json();
      for (const q of data?.quoteResponse?.result ?? []) map[q.symbol] = q;
    } catch (e) {
      console.error(`Yahoo 실시간 시세 조회 실패 (묶음 ${i / 100 + 1}):`, e);
    }
  }
  return map;
}

// screen_us_broad.py 기준 — 10점 만점, BUY_THRESHOLD(6점) 이상만 us_screening_results.pass=true로 저장됨
export function scoreToAction(score) {
  if (score >= 8) return 'Buy';
  if (score >= 6) return 'Watch';
  return 'Hold';
}

export function buildReasons(row, q) {
  const reasons = [];
  reasons.push(`전체 NASDAQ/NYSE/AMEX 스크리닝 점수 ${row.score}/10점 통과 — 재무비율·이동평균·바닥지표 진입 조건 충족`);

  const cp = q?.regularMarketChangePercent ?? 0;
  if (cp >= 3) reasons.push(`오늘 +${cp.toFixed(2)}% 강한 상승 모멘텀`);
  else if (cp >= 0) reasons.push(`오늘 +${cp.toFixed(2)}% 보합~상승`);
  else reasons.push(`오늘 ${cp.toFixed(2)}% 하락 중 — 진입 타이밍 유의`);

  if (row.sector) reasons.push(`${row.sector} 상장`);
  if (row.screened_at) {
    const d = new Date(row.screened_at);
    reasons.push(`최근 스크리닝: ${d.toLocaleDateString('ko-KR')} 기준`);
  }
  return reasons;
}
