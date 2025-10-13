// Vercel KV 데이터베이스 설정 가이드
// 
// 1. Vercel 대시보드에서 KV 데이터베이스 생성
// 2. 환경변수 자동 설정됨
// 3. 아래 코드로 바로 사용 가능

import { kv } from '@vercel/kv';

// ============================================
// 추천 데이터 저장 및 조회
// ============================================

/**
 * AI 추천 저장
 */
export async function saveRecommendation(recommendation) {
  const id = `rec_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  
  const data = {
    ...recommendation,
    id,
    postedAt: new Date().toISOString(),
    likes: 0,
    comments: 0,
    shares: 0,
    bookmarks: 0,
    // 성과 추적용 필드
    trackingStatus: 'active', // active, completed, cancelled
    actualResults: null, // 나중에 실제 결과 업데이트
  };

  // KV에 저장 (만료 없음, 영구 저장)
  await kv.set(`recommendation:${id}`, data);
  
  // 목록 관리를 위한 ID 추가 (Sorted Set)
  await kv.zadd('recommendations:timeline', {
    score: Date.now(),
    member: id,
  });
  
  return data;
}

/**
 * 추천 목록 조회 (최신순)
 */
export async function getRecommendations(limit = 20, offset = 0) {
  // 최신순으로 ID 가져오기
  const ids = await kv.zrange('recommendations:timeline', offset, offset + limit - 1, {
    rev: true, // 역순 (최신부터)
  });
  
  if (!ids || ids.length === 0) {
    return [];
  }
  
  // 각 ID로 데이터 조회
  const pipeline = kv.pipeline();
  ids.forEach(id => {
    pipeline.get(`recommendation:${id}`);
  });
  
  const results = await pipeline.exec();
  return results.filter(r => r !== null);
}

/**
 * 특정 추천 조회
 */
export async function getRecommendation(id) {
  return await kv.get(`recommendation:${id}`);
}

/**
 * 추천 업데이트 (좋아요, 댓글 등)
 */
export async function updateRecommendation(id, updates) {
  const existing = await kv.get(`recommendation:${id}`);
  if (!existing) {
    throw new Error('추천을 찾을 수 없습니다');
  }
  
  const updated = {
    ...existing,
    ...updates,
    updatedAt: new Date().toISOString(),
  };
  
  await kv.set(`recommendation:${id}`, updated);
  return updated;
}

// ============================================
// 성과 추적 기능
// ============================================

/**
 * 추천의 실제 성과 기록
 */
export async function recordActualResult(id, period, result) {
  const recommendation = await kv.get(`recommendation:${id}`);
  if (!recommendation) {
    throw new Error('추천을 찾을 수 없습니다');
  }
  
  const actualResults = recommendation.actualResults || {};
  
  // 기간별 실제 결과 저장
  actualResults[period] = {
    recordedAt: new Date().toISOString(),
    ...result,
    // result 구조:
    // {
    //   actualReturn: 5.2,  // 실제 수익률
    //   expectedReturn: 3.1, // 예상 수익률
    //   success: true, // 목표 달성 여부
    //   exitPrice: 76500, // 청산 가격
    //   exitReason: 'target_reached', // target_reached, stop_loss, manual
    //   analysis: '예상보다 2.1% 더 상승...'
    // }
  };
  
  // 전체 성과 통계 계산
  const performance = calculatePerformance(actualResults);
  
  const updated = {
    ...recommendation,
    actualResults,
    performance,
    trackingStatus: allPeriodsCompleted(actualResults) ? 'completed' : 'active',
    updatedAt: new Date().toISOString(),
  };
  
  await kv.set(`recommendation:${id}`, updated);
  
  // 성과 통계 업데이트
  await updatePerformanceStats(recommendation.stockCode, period, result);
  
  return updated;
}

/**
 * 성과 통계 계산
 */
function calculatePerformance(actualResults) {
  const periods = Object.keys(actualResults);
  if (periods.length === 0) return null;
  
  let totalReturn = 0;
  let successCount = 0;
  
  periods.forEach(period => {
    const result = actualResults[period];
    totalReturn += result.actualReturn || 0;
    if (result.success) successCount++;
  });
  
  return {
    totalReturn,
    averageReturn: totalReturn / periods.length,
    successRate: (successCount / periods.length) * 100,
    completedPeriods: periods.length,
  };
}

/**
 * 모든 기간 완료 확인
 */
function allPeriodsCompleted(actualResults) {
  const periods = ['dayTrading', 'swingTrading', 'longTerm'];
  return periods.every(p => actualResults[p] !== undefined);
}

/**
 * 종목별 성과 통계 업데이트
 */
async function updatePerformanceStats(stockCode, period, result) {
  const key = `stats:${stockCode}:${period}`;
  const stats = await kv.get(key) || {
    totalRecommendations: 0,
    successfulRecommendations: 0,
    totalReturn: 0,
    averageReturn: 0,
  };
  
  stats.totalRecommendations += 1;
  if (result.success) stats.successfulRecommendations += 1;
  stats.totalReturn += result.actualReturn || 0;
  stats.averageReturn = stats.totalReturn / stats.totalRecommendations;
  
  await kv.set(key, stats);
}

/**
 * 종목별 성과 통계 조회
 */
export async function getPerformanceStats(stockCode, period = null) {
  if (period) {
    return await kv.get(`stats:${stockCode}:${period}`);
  }
  
  // 모든 기간 통계 가져오기
  const periods = ['dayTrading', 'swingTrading', 'longTerm'];
  const pipeline = kv.pipeline();
  
  periods.forEach(p => {
    pipeline.get(`stats:${stockCode}:${p}`);
  });
  
  const results = await pipeline.exec();
  
  return {
    dayTrading: results[0],
    swingTrading: results[1],
    longTerm: results[2],
  };
}

/**
 * AI 모델 개선을 위한 학습 데이터 추출
 */
export async function getTrainingData(limit = 100) {
  // 완료된 추천만 가져오기
  const allIds = await kv.zrange('recommendations:timeline', 0, limit - 1, { rev: true });
  
  const pipeline = kv.pipeline();
  allIds.forEach(id => {
    pipeline.get(`recommendation:${id}`);
  });
  
  const recommendations = await pipeline.exec();
  
  // 성과 데이터가 있는 것만 필터링
  return recommendations.filter(r => 
    r && r.actualResults && Object.keys(r.actualResults).length > 0
  );
}

// ============================================
// 통계 및 분석
// ============================================

/**
 * 전체 성과 대시보드 데이터
 */
export async function getDashboardStats() {
  const totalRecs = await kv.zcard('recommendations:timeline');
  
  // 최근 100개 추천 가져오기
  const recentIds = await kv.zrange('recommendations:timeline', 0, 99, { rev: true });
  
  const pipeline = kv.pipeline();
  recentIds.forEach(id => {
    pipeline.get(`recommendation:${id}`);
  });
  
  const recent = await pipeline.exec();
  
  // 통계 계산
  let completedCount = 0;
  let totalSuccess = 0;
  let totalReturn = 0;
  
  recent.forEach(rec => {
    if (rec && rec.trackingStatus === 'completed') {
      completedCount++;
      if (rec.performance) {
        totalSuccess += rec.performance.successRate;
        totalReturn += rec.performance.totalReturn;
      }
    }
  });
  
  return {
    totalRecommendations: totalRecs,
    completedRecommendations: completedCount,
    activeRecommendations: totalRecs - completedCount,
    averageSuccessRate: completedCount > 0 ? totalSuccess / completedCount : 0,
    averageReturn: completedCount > 0 ? totalReturn / completedCount : 0,
  };
}

export default {
  saveRecommendation,
  getRecommendations,
  getRecommendation,
  updateRecommendation,
  recordActualResult,
  getPerformanceStats,
  getTrainingData,
  getDashboardStats,
};

