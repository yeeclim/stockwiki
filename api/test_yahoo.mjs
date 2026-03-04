async function fetchYahoo(symbol) {
    try {
        const url = `https://query1.finance.yahoo.com/v8/finance/chart/${symbol}.KS?interval=1d&range=1d`;
        console.log("Fetching", url);
        const fetch = globalThis.fetch || (await import('node-fetch')).default;
        const response = await fetch(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            },
        });
        const data = await response.json();
        console.log(JSON.stringify(data, null, 2));
    } catch (e) { console.error(e); }
}
fetchYahoo("005930");
