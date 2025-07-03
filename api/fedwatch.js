// File: api/fedwatch.js
export default async function handler(req, res) {
    const targetDate = req.query.date || '20250731'; // 기본값 설정
    const url = `https://www.cmegroup.com/CmeWS/mvc/InterestRates/FedWatchTool/Probabilities/${targetDate}`;
  
    try {
      const response = await fetch(url);
      if (!response.ok) throw new Error('Failed to fetch from CME');
  
      const data = await response.json();
      res.setHeader('Cache-Control', 's-maxage=300'); // 5분 캐싱
      res.status(200).json(data);
    } catch (error) {
      res.status(500).json({ error: 'Failed to load FedWatch data' });
    }
  }
  