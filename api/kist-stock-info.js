// api/kis-stock-info.js
import axios from 'axios';

const APP_KEY = 'PSkzcOJI9xwJeh1coKMwFAoMQfI0JxGORUkd';
const APP_SECRET = '5sy6hIoZBjMUHcHiPpHiPquntZAWM3FY3CGAxUCL3jLNG3fZl99LwD29glHGVXtKi/ORNGzuek+XOAQY8wCH5sIrmzPY0WCDX8E7jPvaVBIo7hHQKWzUfkGKwWlyIhJLlsdShXN712ScNBn/OY/44LOVdRm+MZggKq9q5SDm6PovqBBZTR4=';
const BASE_URL = 'https://openapi.koreainvestment.com:9443';
const TR_ID = 'CTPF1002R';
let accessTokenCache = null;
let lastTokenTime = 0;

async function getToken() {
    const now = Date.now();
    if (accessToken && now - tokenTimestamp < 60 * 60 * 1000) return accessToken;
  
    const res = await axios.post(`${BASE_URL}/oauth2/tokenP`, {
      grant_type: 'client_credentials',
      appkey: APP_KEY,
      appsecret: APP_SECRET
    }, { headers: { 'Content-Type': 'application/json' } });
  
    accessToken = res.data.access_token;
    tokenTimestamp = now;
    return accessToken;
  }
  
  export default async function handler(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
  
    const pdno = req.query.pdno || req.query.code;
    if (!pdno) return res.status(400).json({ error: 'pdno required' });
  
    try {
      const token = await getToken();
  
      const response = await axios.get(`${BASE_URL}/uapi/domestic-stock/v1/quotations/search-stock-info`, {
        headers: {
          'authorization': `Bearer ${token}`,
          'appkey': APP_KEY,
          'appsecret': APP_SECRET,
          'tr_id': TR_ID,
          'Content-Type': 'application/json'
        },
        params: { pdno, prdt_type_cd: '300' }
      });
  
      res.status(200).json(response.data);
    } catch (err) {
      res.status(500).json({ error: 'Proxy error', detail: err.response?.data || err.message });
    }
  }