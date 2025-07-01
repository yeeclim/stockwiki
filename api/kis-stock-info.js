//const APP_KEY = 'PSkzcOJI9xwJeh1coKMwFAoMQfI0JxGORUkd';
//const APP_SECRET = '5sy6hIoZBjMUHcHiPpHiPquntZAWM3FY3CGAxUCL3jLNG3fZl99LwD29glHGVXtKi/ORNGzuek+XOAQY8wCH5sIrmzPY0WCDX8E7jPvaVBIo7hHQKWzUfkGKwWlyIhJLlsdShXN712ScNBn/OY/44LOVdRm+MZggKq9q5SDm6PovqBBZTR4=';
//const BASE_URL = 'https://openapi.koreainvestment.com:9443';
//const TR_ID = 'CTPF1002R';

// api/kis-stock-info.js
import axios from 'axios';

const APP_KEY = process.env.APP_KEY;
const APP_SECRET = process.env.APP_SECRET;
const BASE_URL = 'https://openapi.koreainvestment.com:9443';
const TR_ID = 'CTPF1002R';

let token = null;
let tokenTime = 0;

async function getToken() {
  const now = Date.now();
  if (token && now - tokenTime < 1000 * 60 * 60) return token;

  try {
    const res = await axios.post(`${BASE_URL}/oauth2/tokenP`, {
      grant_type: 'client_credentials',
      appkey: APP_KEY,
      appsecret: APP_SECRET
    }, {
      headers: { 'Content-Type': 'application/json' }
    });

    token = res.data.access_token;
    tokenTime = now;
    return token;
  } catch (err) {
    console.error('🔒 Token 발급 실패:', err.response?.data || err.message);
    throw new Error('KIS 인증 토큰 발급 실패');
  }
}

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');

  const pdno = req.query.pdno || req.query.code;
  if (!pdno) {
    return res.status(400).json({ error: '요청 오류', message: 'pd

