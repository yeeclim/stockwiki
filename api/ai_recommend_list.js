// AI 종목 추천 목록 조회 API
// GET으로 저장된 추천 목록을 반환 (메모리 기반)

// 메모리 저장소 참조
let recommendationsStore = [];

export default async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // GET 요청만 허용
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { limit = '20', offset = '0' } = req.query;
    
    // 샘플 데이터로 초기화 (저장소가 비어있으면)
    if (recommendationsStore.length === 0) {
      recommendationsStore = getSampleRecommendations();
      console.log('📊 샘플 데이터로 초기화: 5개 추천');
    }
    
    const limitNum = parseInt(limit);
    const offsetNum = parseInt(offset);
    
    const paginatedResults = recommendationsStore.slice(
      offsetNum,
      offsetNum + limitNum
    );

    console.log(`📥 추천 목록 조회: ${paginatedResults.length}개 (전체 ${recommendationsStore.length}개)`);

    res.status(200).json({
      success: true,
      total: recommendationsStore.length,
      count: paginatedResults.length,
      data: paginatedResults
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

function getSampleRecommendations() {
  return [
    {
      id: 'rec_sample_001',
      stockName: '삼성전자',
      stockCode: '005930',
      currentPrice: 75000,
      changePercent: 2.3,
      changeAmount: 1700,
      action: '매수',
      reasons: [
        '반도체 업황 회복 신호 포착',
        'HBM3E 양산 본격화로 수익성 개선',
        '4분기 실적 시장 컨센서스 상회 전망',
      ],
      targetPrice: 85000,
      postedAt: new Date(Date.now() - 2 * 60 * 60 * 1000).toISOString(),
      likes: 156,
      comments: 12,
      shares: 23,
      dayTrading: {
        buyPrice: 74500,
        sellPrice: 76800,
        stopLoss: 73500,
        period: '1~3일',
        expectedReturn: 3.1,
      },
      swingTrading: {
        buyPrice: 74000,
        sellPrice: 81000,
        stopLoss: 72000,
        period: '1주~1개월',
        expectedReturn: 9.5,
      },
      longTerm: {
        buyPrice: 75000,
        sellPrice: 92000,
        stopLoss: 70000,
        period: '3개월~1년',
        expectedReturn: 22.7,
      },
    },
    {
      id: 'rec_sample_002',
      stockName: 'SK하이닉스',
      stockCode: '000660',
      currentPrice: 185000,
      changePercent: 1.8,
      changeAmount: 3300,
      action: '매수',
      reasons: [
        'AI 반도체 수요 급증',
        'HBM 시장 점유율 1위 유지',
        '영업이익률 지속 개선 중',
      ],
      targetPrice: 210000,
      postedAt: new Date(Date.now() - 5 * 60 * 60 * 1000).toISOString(),
      likes: 243,
      comments: 34,
      shares: 45,
      dayTrading: {
        buyPrice: 184000,
        sellPrice: 189500,
        stopLoss: 181000,
        period: '1~3일',
        expectedReturn: 3.0,
      },
      swingTrading: {
        buyPrice: 183000,
        sellPrice: 198000,
        stopLoss: 178000,
        period: '1주~1개월',
        expectedReturn: 8.2,
      },
      longTerm: {
        buyPrice: 185000,
        sellPrice: 230000,
        stopLoss: 175000,
        period: '3개월~1년',
        expectedReturn: 24.3,
      },
    },
    {
      id: 'rec_sample_003',
      stockName: 'NAVER',
      stockCode: '035420',
      currentPrice: 235000,
      changePercent: -0.8,
      changeAmount: -1900,
      action: '보유',
      reasons: [
        'AI 검색 서비스 강화 중',
        '클라우드 사업 성장세 지속',
        '단기 조정 후 반등 예상',
      ],
      targetPrice: 260000,
      postedAt: new Date(Date.now() - 8 * 60 * 60 * 1000).toISOString(),
      likes: 98,
      comments: 15,
      shares: 12,
      swingTrading: {
        buyPrice: 232000,
        sellPrice: 248000,
        stopLoss: 225000,
        period: '1주~1개월',
        expectedReturn: 6.9,
      },
      longTerm: {
        buyPrice: 235000,
        sellPrice: 280000,
        stopLoss: 220000,
        period: '3개월~1년',
        expectedReturn: 19.1,
      },
    },
    {
      id: 'rec_sample_004',
      stockName: '카카오',
      stockCode: '035720',
      currentPrice: 51000,
      changePercent: 3.5,
      changeAmount: 1700,
      action: '매수',
      reasons: [
        '카카오페이 IPO 기대감 확대',
        '광고 매출 회복세 뚜렷',
        '저평가 구간 진입으로 매수 타이밍',
      ],
      targetPrice: 62000,
      postedAt: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(),
      likes: 187,
      comments: 28,
      shares: 31,
      dayTrading: {
        buyPrice: 50500,
        sellPrice: 52800,
        stopLoss: 49500,
        period: '1~3일',
        expectedReturn: 4.6,
      },
      swingTrading: {
        buyPrice: 50000,
        sellPrice: 56500,
        stopLoss: 48000,
        period: '1주~1개월',
        expectedReturn: 13.0,
      },
      longTerm: {
        buyPrice: 51000,
        sellPrice: 68000,
        stopLoss: 47000,
        period: '3개월~1년',
        expectedReturn: 33.3,
      },
    },
    {
      id: 'rec_sample_005',
      stockName: 'LG에너지솔루션',
      stockCode: '373220',
      currentPrice: 420000,
      changePercent: 1.2,
      changeAmount: 5000,
      action: '매수',
      reasons: [
        '북미 IRA 수혜주로 주목',
        '전기차 배터리 점유율 확대 중',
        '폴란드 신규 공장 가동 임박',
      ],
      targetPrice: 480000,
      postedAt: new Date(Date.now() - 27 * 60 * 60 * 1000).toISOString(),
      likes: 321,
      comments: 52,
      shares: 67,
      swingTrading: {
        buyPrice: 415000,
        sellPrice: 445000,
        stopLoss: 400000,
        period: '1주~1개월',
        expectedReturn: 7.2,
      },
      longTerm: {
        buyPrice: 420000,
        sellPrice: 520000,
        stopLoss: 390000,
        period: '3개월~1년',
        expectedReturn: 23.8,
      },
    },
  ];
}

// 저장소 조회 함수 export
export function getRecommendationsStore() {
  return recommendationsStore;
}

// 사용 예시:
/*
GET /api/ai_recommend_list?limit=10&offset=0

응답:
{
  "success": true,
  "total": 50,
  "count": 10,
  "data": [...]
}
*/

