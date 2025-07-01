// api/kis-stock-info.js
import axios from 'axios';

const APP_KEY = 'PSkzcOJI9xwJeh1coKMwFAoMQfI0JxGORUkd';
const APP_SECRET = '5sy6hIoZBjMUHcHiPpHiPquntZAWM3FY3CGAxUCL3jLNG3fZl99LwD29glHGVXtKi/ORNGzuek+XOAQY8wCH5sIrmzPY0WCDX8E7jPvaVBIo7hHQKWzUfkGKwWlyIhJLlsdShXN712ScNBn/OY/44LOVdRm+MZggKq9q5SDm6PovqBBZTR4=';
const BASE_URL = 'https://openapi.koreainvestment.com:9443';
const TR_ID = 'CTPF1002R';
let accessTokenCache = null;
let lastTokenTime = 0;

async function fetchAccessToken() {
  const now = Date.now();
  if (accessTokenCache && now - lastTokenTime < 1000 * 60 * 60) return accessTokenCache;

  const res = await axios.post(`${BASE_URL}/oauth2/tokenP`, {
    grant_type: 'client_credentials',
    appkey: APP_KEY,
    appsecret: APP_SECRET
  }, {
    headers: { 'Content-Type': 'application/json' }
  });

  accessTokenCache = res.data.access_token;
  lastTokenTime = now;
  return accessTokenCache;
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  const pdno = req.query.pdno || req.query.code;
  const prdtTypeCd = req.query.prdt_type_cd || '300';

  if (!pdno) {
    return res.status(400).json({ error: 'pdno 파라미터가 필요합니다' });
  }

  try {
    const token = await fetchAccessToken();

    const result = await axios.get(`${BASE_URL}/uapi/domestic-stock/v1/quotations/search-stock-info`, {
      headers: {
        'Content-Type': 'application/json',
        'authorization': `Bearer ${token}`,
        'appkey': APP_KEY,
        'appsecret': APP_SECRET,
        'tr_id': TR_ID
      },
      params: { pdno, prdt_type_cd: prdtTypeCd }
    });

    res.status(200).json(result.data);
  } catch (err) {
    res.status(500).json({ error: 'Proxy Error', detail: err.response?.data || err.message });
  }
}
