async function fetchStockData(symbol) {
    try {
        const url = `https://finance.naver.com/item/main.naver?code=${symbol}`;
        const fetch = globalThis.fetch || (await import('node-fetch')).default;
        const response = await fetch(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36',
            },
            timeout: 8000
        });
        const html = await response.text();
        const rateInfoIndex = html.indexOf('<div class="rate_info">');
        if (rateInfoIndex !== -1) {
            console.log(html.substring(rateInfoIndex, rateInfoIndex + 1000));
        }
    } catch (e) {
        console.error(e);
    }
}
fetchStockData('005930');
