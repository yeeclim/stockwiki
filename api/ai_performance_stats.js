// AI 추천 성과 통계 조회 API
import { getPerformanceStats, getDashboardStats } from '../lib/kv_db_setup.js';

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
    const { stockCode, type = 'dashboard' } = req.query;

    if (type === 'dashboard') {
      // 전체 대시보드 통계
      const stats = await getDashboardStats();
      
      res.status(200).json({
        success: true,
        data: stats
      });
    } else if (type === 'stock' && stockCode) {
      // 특정 종목 성과
      const stats = await getPerformanceStats(stockCode);
      
      res.status(200).json({
        success: true,
        stockCode,
        data: stats
      });
    } else {
      res.status(400).json({
        success: false,
        error: '잘못된 요청. type=dashboard 또는 type=stock&stockCode=005930'
      });
    }

  } catch (error) {
    console.error('❌ 통계 조회 오류:', error);
    res.status(500).json({
      success: false,
      error: '서버 오류',
      details: error.message
    });
  }
}

// 사용 예시:
/*
# 전체 대시보드 통계
GET /api/ai_performance_stats?type=dashboard

응답:
{
  "success": true,
  "data": {
    "totalRecommendations": 50,
    "completedRecommendations": 12,
    "activeRecommendations": 38,
    "averageSuccessRate": 75.5,
    "averageReturn": 8.3
  }
}

# 특정 종목 통계
GET /api/ai_performance_stats?type=stock&stockCode=005930

응답:
{
  "success": true,
  "stockCode": "005930",
  "data": {
    "dayTrading": {
      "totalRecommendations": 5,
      "successfulRecommendations": 4,
      "totalReturn": 18.5,
      "averageReturn": 3.7
    },
    "swingTrading": {
      "totalRecommendations": 5,
      "successfulRecommendations": 3,
      "totalReturn": 42.3,
      "averageReturn": 8.46
    },
    "longTerm": {
      "totalRecommendations": 3,
      "successfulRecommendations": 2,
      "totalReturn": 65.2,
      "averageReturn": 21.73
    }
  }
}
*/

