// AI 추천 업로드 API (Vercel KV 버전)
import { saveRecommendation } from '../lib/kv_db_setup.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const recommendation = req.body;

    // 필수 필드 검증
    const requiredFields = [
      'stockName', 'stockCode', 'currentPrice', 
      'changePercent', 'changeAmount', 'action', 
      'reasons', 'targetPrice'
    ];

    for (const field of requiredFields) {
      if (!recommendation[field]) {
        return res.status(400).json({
          success: false,
          error: `필수 필드 누락: ${field}`
        });
      }
    }

    // 최소 하나의 투자 전략 필요
    if (!recommendation.dayTrading && !recommendation.swingTrading && !recommendation.longTerm) {
      return res.status(400).json({
        success: false,
        error: '최소 하나의 투자 전략이 필요합니다'
      });
    }

    // Vercel KV에 저장
    const saved = await saveRecommendation(recommendation);

    console.log('✅ AI 추천 저장 완료:', saved.id);

    res.status(200).json({
      success: true,
      message: 'AI 추천이 성공적으로 저장되었습니다',
      data: saved
    });

  } catch (error) {
    console.error('❌ AI 추천 저장 오류:', error);
    res.status(500).json({
      success: false,
      error: '서버 오류',
      details: error.message
    });
  }
}

