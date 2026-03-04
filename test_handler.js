const handler = require('./api/theme-recommendations.js').default;

const req = {
    method: 'GET',
    query: { action: 'themes' }
};

const res = {
    setHeader: () => { },
    status: (code) => ({
        json: (data) => {
            console.log(`Status: ${code}`);
            console.log(JSON.stringify(data, null, 2));
        },
        end: () => console.log('End')
    })
};

// Top recommendations test
const req2 = {
    method: 'GET',
    query: { action: 'recommendations', limit: 2 }
};

async function run() {
    console.log('--- ACTION: THEMES ---');
    await handler(req, res);

    console.log('\n--- ACTION: RECOMMENDATIONS ---');
    await handler(req2, res);
}

run();
