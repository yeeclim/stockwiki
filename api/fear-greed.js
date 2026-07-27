// api/fear-greed.js
// CNN Business의 실제 Fear & Greed Index를 그대로 프록시한다.
// CNN 페이지가 내부적으로 쓰는 비공식 데이터 엔드포인트라 CORS가 안 열려있어
// 브라우저(Flutter web)에서 직접 호출이 안 되므로 서버에서 대신 받아온다.

const CNN_URL = 'https://production.dataviz.cnn.io/index/fearandgreed/graphdata';

let cache = null;
let cacheTime = 0;
const CACHE_TTL = 15 * 60 * 1000; // 15분

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }

  try {
    const now = Date.now();
    if (cache && now - cacheTime < CACHE_TTL) {
      return res.status(200).json({ ...cache, cached: true });
    }

    const response = await fetch(CNN_URL, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://edition.cnn.com/',
      },
    });
    if (!response.ok) throw new Error(`CNN API 오류: ${response.status}`);

    const data = await response.json();
    const fg = data.fear_and_greed;
    if (!fg) throw new Error('fear_and_greed 필드 없음');

    const result = {
      success: true,
      score: Math.round(fg.score),
      rating: fg.rating,
      previousClose: Math.round(fg.previous_close),
      previous1Week: Math.round(fg.previous_1_week),
      previous1Month: Math.round(fg.previous_1_month),
      previous1Year: Math.round(fg.previous_1_year),
      timestamp: fg.timestamp,
    };

    cache = result;
    cacheTime = now;

    return res.status(200).json({ ...result, cached: false });

  } catch (error) {
    console.error('fear-greed API 오류:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
}
