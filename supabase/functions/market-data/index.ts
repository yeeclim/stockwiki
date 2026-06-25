const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS });
  }

  let symbol: string | null = null;

  if (req.method === 'POST') {
    try {
      const body = await req.json();
      symbol = body?.symbol ?? null;
    } catch (_) {}
  } else {
    symbol = new URL(req.url).searchParams.get('symbol');
  }

  if (!symbol) {
    return new Response(JSON.stringify({ error: '심볼 없음' }), {
      status: 400,
      headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
    });
  }

  const encoded = encodeURIComponent(symbol);
  const endpoints = [
    `https://query1.finance.yahoo.com/v8/finance/chart/${encoded}?interval=1d&range=1d`,
    `https://query2.finance.yahoo.com/v8/finance/chart/${encoded}?interval=1d&range=1d`,
  ];

  for (const url of endpoints) {
    try {
      const res = await fetch(url, {
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'application/json',
          'Accept-Language': 'en-US,en;q=0.9',
        },
        signal: AbortSignal.timeout(8000),
      });

      if (res.ok) {
        const data = await res.json();
        const meta = data?.chart?.result?.[0]?.meta;
        const price = meta?.regularMarketPrice ?? meta?.previousClose;
        if (price) {
          return new Response(JSON.stringify(data), {
            status: 200,
            headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
          });
        }
      }
    } catch (_) {}
  }

  return new Response(JSON.stringify({ error: '데이터 없음' }), {
    status: 503,
    headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
  });
});
