const iconv = require('iconv-lite');
const { JSDOM } = require('jsdom');

async function scrapeNaverThemeStocks(themeUrl) {
    try {
        const response = await fetch(themeUrl);
        if (!response.ok) return [];

        const arrayBuffer = await response.arrayBuffer();
        const html = iconv.decode(Buffer.from(arrayBuffer), 'euc-kr');

        const dom = new JSDOM(html);
        const doc = dom.window.document;

        const stocks = [];
        // type_5 is the main table for items
        const rows = doc.querySelectorAll('table.type_5 tbody tr');

        rows.forEach(row => {
            // Skip empty or divider rows
            if (row.querySelector('.kline') || row.querySelector('.blank_08')) return;

            const nameArea = row.querySelector('.name_area a');
            if (!nameArea) return;

            const name = nameArea.textContent.trim();
            const symbolMatch = nameArea.href.match(/code=(\d+)/);
            const symbol = symbolMatch ? symbolMatch[1] : '';

            // Select the generic td.number elements
            const numberCells = row.querySelectorAll('td.number');
            if (numberCells.length < 3) return;

            const priceText = numberCells[0].textContent.replace(/,/g, '').trim();
            const changeText = numberCells[1].textContent.replace(/,/g, '').trim();
            const percentText = numberCells[2].textContent.replace(/,/g, '').replace(/%/g, '').trim();

            if (symbol && name) {
                stocks.push({
                    symbol,
                    name,
                    price: parseInt(priceText) || 0,
                    change: parseInt(changeText) || 0,
                    changePercent: parseFloat(percentText) || 0
                });
            }
        });

        return stocks.slice(0, 10);
    } catch (err) {
        console.error(err);
        return [];
    }
}

scrapeNaverThemeStocks('https://finance.naver.com/sise/sise_group_detail.naver?type=theme&no=206').then(console.log);
