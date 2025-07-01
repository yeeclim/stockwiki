//const APP_KEY = 'PSkzcOJI9xwJeh1coKMwFAoMQfI0JxGORUkd';
//const APP_SECRET = '5sy6hIoZBjMUHcHiPpHiPquntZAWM3FY3CGAxUCL3jLNG3fZl99LwD29glHGVXtKi/ORNGzuek+XOAQY8wCH5sIrmzPY0WCDX8E7jPvaVBIo7hHQKWzUfkGKwWlyIhJLlsdShXN712ScNBn/OY/44LOVdRm+MZggKq9q5SDm6PovqBBZTR4=';
//const BASE_URL = 'https://openapi.koreainvestment.com:9443';
//const TR_ID = 'CTPF1002R';

// api/kis-stock-info.js
import axios from 'axios';

const BASE_URL = 'https://openapi.koreainvestment.com:9443';
const TR_ID = 'CTPF1002R';

// accessToken 매 요청마다 발급 (서버리스 환경에선 캐시 불안정)
async function getToken() {
  try {
    const res = await axios.post(`${BASE_URL}/oauth2/tokenP`, {
      grant_type: 'client_credentials',
      appkey: process.env.APP_KEY,
      appsecret: process.env.APP_SECRET
    }, {
      headers: { 'Content-Type': 'application/json' }
    });

    return res.data.access_token;
  } catch (err) {
    console.error('🔒 Token 발급 실패:', err.response?.data || err.message);
    throw new Error('KIS 인증 토큰 발급 실패');
  }
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
        'appkey': process.env.APP_KEY,
        'appsecret': process.env.APP_SECRET,
        'tr_id': TR_ID,
        'Content-Type': 'application/json'
      },
      params: { pdno, prdt_type_cd: '300' }
    });

    res.status(200).json(response.data);
  } catch (err) {
    console.error('❌ KIS API 요청 실패:', err.response?.data || err.message);
    res.status(500).json({
      error: 'KIS API 호출 실패',
      message: err.message,
      detail: err.response?.data
    });
  }
}

