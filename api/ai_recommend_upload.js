// AI 종목 추천 자동 업로드 API
// POST로 추천 데이터를 받아서 저장 (메모리 기반 - 재시작 시 초기화됨)

// 메모리 저장소 (개발용 - 재시작 시 초기화됨)
const recommendationsStore = [];

export default async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // POST 요청만 허용
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const recommendation = req.body;

    // 필수 필드 검증
    const requiredFields = [
      'stockName',
      'stockCode',
      'currentPrice',
      'changePercent',
      'changeAmount',
      'action',
      'reasons',
      'targetPrice'
    ];

    for (const field of requiredFields) {
      if (!recommendation[field]) {
        return res.status(400).json({
          success: false,
          error: `필수 필드 누락: ${field}`
        });
      }
    }

    // 투자 전략 검증 (최소 하나는 있어야 함)
    if (!recommendation.dayTrading && !recommendation.swingTrading && !recommendation.longTerm) {
      return res.status(400).json({
        success: false,
        error: '최소 하나의 투자 전략이 필요합니다 (단타/스윙/중장기)'
      });
    }

    // 메모리 저장소에 저장
    const savedRecommendation = {
      ...recommendation,
      id: generateId(),
      postedAt: new Date().toISOString(),
      likes: 0,
      comments: 0,
      shares: 0,
    };

    // 배열 앞에 추가 (최신 순)
    recommendationsStore.unshift(savedRecommendation);
    
    // 최대 100개까지만 유지
    if (recommendationsStore.length > 100) {
      recommendationsStore.length = 100;
    }

    console.log(`✅ AI 추천 저장 (메모리): ${savedRecommendation.id}`);
    console.log(`📊 현재 저장된 추천: ${recommendationsStore.length}개`);

    res.status(200).json({
      success: true,
      message: 'AI 추천이 성공적으로 업로드되었습니다',
      data: savedRecommendation
    });

  } catch (error) {
    console.error('❌ AI 추천 업로드 오류:', error);
    res.status(500).json({
      success: false,
      error: '서버 오류',
      details: error.message
    });
  }
}

// ID 생성 함수 (간단한 타임스탬프 기반)
function generateId() {
  return `rec_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

// 저장소 조회 함수 (다른 API에서 사용)
export function getRecommendationsStore() {
  return recommendationsStore;
}

// 사용 예시:
/*
POST /api/ai_recommend_upload
Content-Type: application/json

{
  "stockName": "삼성전자",
  "stockCode": "005930",
  "currentPrice": 75000,
  "changePercent": 2.3,
  "changeAmount": 1700,
  "action": "매수",
  "reasons": [
    "반도체 업황 회복 신호",
    "HBM3E 양산 본격화",
    "4분기 실적 개선 전망"
  ],
  "targetPrice": 85000,
  "dayTrading": {
    "buyPrice": 74500,
    "sellPrice": 76800,
    "stopLoss": 73500,
    "period": "1~3일",
    "expectedReturn": 3.1
  },
  "swingTrading": {
    "buyPrice": 74000,
    "sellPrice": 81000,
    "stopLoss": 72000,
    "period": "1주~1개월",
    "expectedReturn": 9.5
  },
  "longTerm": {
    "buyPrice": 75000,
    "sellPrice": 92000,
    "stopLoss": 70000,
    "period": "3개월~1년",
    "expectedReturn": 22.7
  }
}
*/

