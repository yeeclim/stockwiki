// 국내주식 실차트용 일봉 데이터 (KIS Open API)
// 지표(이평선/볼린저/RSI/MACD 등)는 계산하지 않고 원본 OHLCV만 반환한다 —
// 지표 계산은 Flutter 클라이언트의 k_chart_plus 패키지가 담당한다.

const BASE_URL = 'https://openapi.koreainvestment.com:9443';

// 모듈 스코프 캐시 — 같은 Vercel 함수 인스턴스가 재사용되는 동안(warm) 유지된다.
let tokenCache = { token: null, expiresAt: 0 };
const candleCache = new Map();
const CANDLE_CACHE_TTL = 4 * 60 * 60 * 1000; // 4시간 (일봉은 장마감 후에나 갱신되므로 충분)

async function getKisToken() {
  if (tokenCache.token && Date.now() < tokenCache.expiresAt) {
    return tokenCache.token;
  }

  const appKey = process.env.KIS_APP_KEY;
  const appSecret = process.env.KIS_APP_SECRET;
  if (!appKey || !appSecret) {
    throw new Error('KIS_APP_KEY/KIS_APP_SECRET 미설정');
  }

  const res = await fetch(`${BASE_URL}/oauth2/tokenP`, {
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

  tokenCache = {
    token: data.access_token,
    // expires_in(초)에서 5분 여유를 두고 캐시 만료 처리
    expiresAt: Date.now() + (data.expires_in ?? 86400) * 1000 - 5 * 60 * 1000,
  };
  return tokenCache.token;
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

// 일봉 한 구간(최대 100건) 조회
async function fetchDailyPage(code, token, dateFrom, dateTo) {
  const url = new URL(`${BASE_URL}/uapi/domestic-stock/v1/quotations/inquire-daily-itemchartprice`);
  url.search = new URLSearchParams({
    FID_COND_MRKT_DIV_CODE: 'J',
    FID_INPUT_ISCD: code,
    FID_INPUT_DATE_1: dateFrom,
    FID_INPUT_DATE_2: dateTo,
    FID_PERIOD_DIV_CODE: 'D',
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

// 1회 호출당 최대 100건 제한을 우회하기 위해 조회 구간을 뒤로 밀어가며 반복 호출
async function fetchDailyCandles(code, minDays = 450) {
  const token = await getKisToken();
  const collected = new Map(); // date(yyyymmdd) -> row, 중복 제거용

  let cursorEnd = new Date();
  const MAX_PAGES = 6;
  const PAGE_SPAN_DAYS = 140; // 달력일 기준 — 거래일로는 대략 90~100일 정도 확보됨

  for (let page = 0; page < MAX_PAGES && collected.size < minDays; page++) {
    const dateTo = formatYmd(cursorEnd);
    const cursorStart = new Date(cursorEnd);
    cursorStart.setDate(cursorStart.getDate() - PAGE_SPAN_DAYS);
    const dateFrom = formatYmd(cursorStart);

    const rows = await fetchDailyPage(code, token, dateFrom, dateTo);
    if (rows.length === 0) break; // 상장일 이전 구간 도달

    for (const row of rows) {
      const date = row.stck_bsop_date;
      if (date && row.stck_clpr && row.stck_clpr !== '0') {
        collected.set(date, row);
      }
    }

    // 다음 페이지는 이번 구간의 가장 이른 날짜 하루 전부터
    cursorEnd = cursorStart;
    cursorEnd.setDate(cursorEnd.getDate() - 1);
  }

  const dates = [...collected.keys()].sort(); // 오름차순(과거→최근)
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

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'GET') { res.status(405).json({ success: false, error: 'Method not allowed' }); return; }

  const code = (req.query.code || '').toString().trim();
  if (!/^\d{6}$/.test(code)) {
    res.status(400).json({ success: false, error: '유효하지 않은 종목코드입니다' });
    return;
  }

  const cached = candleCache.get(code);
  if (cached && Date.now() - cached.time < CANDLE_CACHE_TTL) {
    res.status(200).json({ success: true, data: cached.data, cached: true });
    return;
  }

  try {
    const data = await fetchDailyCandles(code, 450);
    candleCache.set(code, { data, time: Date.now() });
    res.status(200).json({ success: true, data });
  } catch (error) {
    console.error(`❌ 국내주식 차트 조회 실패 (${code}):`, error.message);
    res.status(500).json({ success: false, error: error.message || '차트 조회 중 오류 발생' });
  }
}
