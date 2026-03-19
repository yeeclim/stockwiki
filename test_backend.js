const urls = [
    'https://stockwiki.vercel.app/api/utils?type=commodity&symbol=KRW=X',
    'https://stockwiki.vercel.app/api/utils?type=commodity&symbol=GOLD',
    'https://stockwiki.vercel.app/api/utils?type=commodity&symbol=SI=F',
    'https://stockwiki.vercel.app/api/utils?type=commodity&symbol=CL=F',
    'https://stockwiki.vercel.app/api/utils?type=commodity&symbol=BTC',
    'https://stockwiki.vercel.app/api/utils?type=fear-greed'
];

async function testParallel() {
    console.log('Fetching concurrently...');
    const promises = urls.map(url => fetch(url).then(async r => {
        return { url, status: r.status, text: (await r.text()).substring(0, 100) };
    }));
    const results = await Promise.all(promises);
    for (const res of results) {
        console.log(`URL: ${res.url}`);
        console.log(`Status: ${res.status}`);
        console.log(`Body: ${res.text}`);
        console.log('---');
    }
}
testParallel();
