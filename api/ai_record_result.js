// AI 추천 실제 성과 기록 API
import { recordActualResult } from '../lib/kv_db_setup.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
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
    const { recommendationId, period, result } = req.body;

    if (!recommendationId || !period || !result) {
      return res.status(400).json({
        success: false,
        error: '필수 필드 누락: recommendationId, period, result'
      });
    }

    // 기간 유효성 검사
    const validPeriods = ['dayTrading', 'swingTrading', 'longTerm'];
    if (!validPeriods.includes(period)) {
      return res.status(400).json({
        success: false,
        error: '잘못된 기간. dayTrading, swingTrading, longTerm 중 선택하세요'
      });
    }

    // 결과 필수 필드 검증
    if (result.actualReturn === undefined || result.success === undefined) {
      return res.status(400).json({
        success: false,
        error: '결과 데이터에 actualReturn과 success 필드가 필요합니다'
      });
    }

    // 실제 성과 기록
    const updated = await recordActualResult(recommendationId, period, result);

    console.log(`✅ 성과 기록 완료: ${recommendationId} - ${period}`);

    res.status(200).json({
      success: true,
      message: '성과가 성공적으로 기록되었습니다',
      data: updated
    });

  } catch (error) {
    console.error('❌ 성과 기록 오류:', error);
    res.status(500).json({
      success: false,
      error: error.message || '서버 오류',
    });
  }
}

// 사용 예시:
/*
POST /api/ai_record_result
Content-Type: application/json

{
  "recommendationId": "rec_1234567890_abc123",
  "period": "dayTrading",
  "result": {
    "actualReturn": 5.2,
    "expectedReturn": 3.1,
    "success": true,
    "exitPrice": 76500,
    "exitReason": "target_reached",
    "analysis": "예상보다 2.1% 더 상승. HBM3E 출하량 증가 뉴스가 긍정적으로 작용"
  }
}

응답:
{
  "success": true,
  "message": "성과가 성공적으로 기록되었습니다",
  "data": {
    "id": "rec_1234567890_abc123",
    "actualResults": {
      "dayTrading": {
        "recordedAt": "2025-01-16T10:30:00.000Z",
        "actualReturn": 5.2,
        "expectedReturn": 3.1,
        "success": true,
        "exitPrice": 76500,
        "exitReason": "target_reached",
        "analysis": "예상보다 2.1% 더 상승..."
      }
    },
    "performance": {
      "totalReturn": 5.2,
      "averageReturn": 5.2,
      "successRate": 100,
      "completedPeriods": 1
    },
    "trackingStatus": "active"
  }
}
*/

