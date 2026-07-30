/**
 * Supabase Edge Function: fmp-proxy
 *
 * FMP(Financial Modeling Prep)와 Finnhub API 키를 서버에 보관하고
 * Flutter 클라이언트의 요청을 대신 전달합니다.
 * API 키가 클라이언트 번들에 노출되지 않도록 보호합니다.
 *
 * Supabase Secrets:
 *   FMP_API_KEY      — Financial Modeling Prep API 키
 *   FINNHUB_API_KEY  — Finnhub API 키
 */

const FMP_API_KEY     = Deno.env.get('FMP_API_KEY')     ?? '';
const FINNHUB_API_KEY = Deno.env.get('FINNHUB_API_KEY') ?? '';
const FMP_BASE        = 'https://financialmodelingprep.com/api/v3';
const FINNHUB_BASE    = 'https://finnhub.io/api/v1';

const CORS_HEADERS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ProxyRequest {
  service: 'fmp' | 'finnhub';
  path:    string;
  params?: Record<string, string>;
}

// 클라이언트(lib/services/*.dart)가 실제로 사용하는 경로만 허용한다.
// 이 프록시는 인증 없이 anon key만으로 호출 가능하므로, 화이트리스트가 없으면
// 누구나 서버가 보관한 FMP/Finnhub 키로 임의의 유료 엔드포인트를 호출할 수 있다.
const ALLOWED_PATH_PATTERNS: RegExp[] = [
  /^\/search$/,
  /^\/quote(\/[^/]+)?$/,
  /^\/stock_news$/,
  /^\/historical-price-full\/[^/]+$/,
  /^\/stock\/profile2$/,
  /^\/stock\/candle$/,
];

function isAllowedPath(path: string): boolean {
  return ALLOWED_PATH_PATTERNS.some((pattern) => pattern.test(path));
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  let body: ProxyRequest;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON body' }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  const { service, path, params = {} } = body;

  if (!path || !path.startsWith('/') || !isAllowedPath(path)) {
    return new Response(JSON.stringify({ error: 'Invalid path' }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  let targetUrl: string;
  if (service === 'fmp') {
    const qp = new URLSearchParams({ ...params, apikey: FMP_API_KEY });
    targetUrl = `${FMP_BASE}${path}?${qp}`;
  } else if (service === 'finnhub') {
    const qp = new URLSearchParams({ ...params, token: FINNHUB_API_KEY });
    targetUrl = `${FINNHUB_BASE}${path}?${qp}`;
  } else {
    return new Response(JSON.stringify({ error: 'Unknown service' }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  try {
    const upstream = await fetch(targetUrl, {
      headers: { 'Accept': 'application/json' },
    });
    const responseBody = await upstream.text();

    return new Response(responseBody, {
      status: upstream.status,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: `Upstream error: ${err}` }), {
      status: 502,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }
});
