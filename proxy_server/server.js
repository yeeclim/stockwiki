//const APP_KEY = 'PSkzcOJI9xwJeh1coKMwFAoMQfI0JxGORUkd';
//const APP_SECRET = '5sy6hIoZBjMUHcHiPpHiPquntZAWM3FY3CGAxUCL3jLNG3fZl99LwD29glHGVXtKi/ORNGzuek+XOAQY8wCH5sIrmzPY0WCDX8E7jPvaVBIo7hHQKWzUfkGKwWlyIhJLlsdShXN712ScNBn/OY/44LOVdRm+MZggKq9q5SDm6PovqBBZTR4=';
const express = require('express');
const axios = require('axios');
const cors = require('cors');

const app = express();
app.use(cors());

const APP_KEY = 'PSkzcOJI9xwJeh1coKMwFAoMQfI0JxGORUkd';
const APP_SECRET = '5sy6hIoZBjMUHcHiPpHiPquntZAWM3FY3CGAxUCL3jLNG3fZl99LwD29glHGVXtKi/ORNGzuek+XOAQY8wCH5sIrmzPY0WCDX8E7jPvaVBIo7hHQKWzUfkGKwWlyIhJLlsdShXN712ScNBn/OY/44LOVdRm+MZggKq9q5SDm6PovqBBZTR4=';
const BASE_URL = 'https://openapi.koreainvestment.com:9443';
const GRANT_TYPE = 'client_credentials';
const TR_ID = 'CTPF1002R'; // 실전 주식기본조회

let accessToken = null;

async function fetchAccessToken() {
  try {
    const response = await axios.post(`${BASE_URL}/oauth2/tokenP`, {
      grant_type: GRANT_TYPE,
      appkey: APP_KEY,
      appsecret: APP_SECRET
    }, {
      headers: { 'Content-Type': 'application/json' }
    });
    accessToken = response.data.access_token;
    console.log('[INFO] Access token 갱신 완료');
  } catch (err) {
    console.error('[ERROR] Access token 요청 실패:', err.response?.data || err.message);
  }
}

app.get('/kis-stock-info', async (req, res) => {
  const pdno = req.query.pdno || req.query.code;
  const prdtTypeCd = req.query.prdt_type_cd || '300'; // 기본값: 국내주식
  if (!pdno) {
    return res.status(400).json({ error: 'pdno 파라미터가 필요합니다' });
  }

  try {
    if (!accessToken) await fetchAccessToken();

    const response = await axios.get(`${BASE_URL}/uapi/domestic-stock/v1/quotations/search-stock-info`, {
      headers: {
        'Content-Type': 'application/json',
        'authorization': `Bearer ${accessToken}`,
        'appkey': APP_KEY,
        'appsecret': APP_SECRET,
        'tr_id': TR_ID
      },
      params: {
        pdno: pdno,
        prdt_type_cd: prdtTypeCd
      }
    });

    res.json(response.data);
  } catch (err) {
    console.error('Proxy Error:', err.response?.data || err.message);
    res.status(500).json({ error: 'Proxy Error', detail: err.response?.data || err.message });
  }
});

app.listen(3000, () => {
  console.log('✅ Proxy server running at http://localhost:3000');
});
