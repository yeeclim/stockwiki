// AI 추천 목록 조회 API (Vercel KV 버전)
import { getRecommendations } from '../lib/kv_db_setup.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { limit = '20', offset = '0' } = req.query;

    const recommendations = await getRecommendations(
      parseInt(limit),
      parseInt(offset)
    );

    res.status(200).json({
      success: true,
      count: recommendations.length,
      data: recommendations
    });

  } catch (error) {
    console.error('❌ AI 추천 조회 오류:', error);
    res.status(500).json({
      success: false,
      error: '서버 오류',
      details: error.message
    });
  }
}

