import { config } from 'dotenv';
config();
import handler from './ai_recommend_list.js';

async function test() {
    const req = { method: 'GET', query: { refresh: 'true', limit: 3 } };
    const res = {
        setHeader: () => { },
        status: (code) => ({
            json: (data) => console.log(JSON.stringify(data, null, 2)),
            end: () => { }
        })
    };

    await handler(req, res);
}
test();
