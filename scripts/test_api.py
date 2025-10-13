#!/usr/bin/env python3
"""
API 테스트 스크립트

사용법:
    python scripts/test_api.py
"""

import requests
import json
from datetime import datetime

# 로컬 테스트용 (Vercel 배포 시 URL 변경)
API_URL = "http://localhost:3000"

def test_upload_recommendation():
    """추천 업로드 테스트"""
    print("🧪 1. 추천 업로드 테스트...")
    
    data = {
        "stockName": "삼성전자",
        "stockCode": "005930",
        "currentPrice": 75000,
        "changePercent": 2.3,
        "changeAmount": 1700,
        "action": "매수",
        "reasons": [
            "반도체 업황 회복 신호 포착",
            "HBM3E 양산 본격화로 수익성 개선 예상",
            "4분기 실적 시장 컨센서스 상회 전망"
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
    
    try:
        # KV 버전 테스트 (실제 DB 필요)
        # response = requests.post(f"{API_URL}/api/ai_recommend_upload_kv", json=data)
        
        # 임시 버전 테스트 (샘플 데이터)
        response = requests.post(f"{API_URL}/api/ai_recommend_upload", json=data)
        
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ 업로드 성공!")
            print(f"   ID: {result.get('data', {}).get('id', 'N/A')}")
            return result['data']
        else:
            print(f"   ❌ 업로드 실패: {response.status_code}")
            print(f"   {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ 오류: {e}")
        return None

def test_list_recommendations():
    """추천 목록 조회 테스트"""
    print("\n🧪 2. 추천 목록 조회 테스트...")
    
    try:
        # response = requests.get(f"{API_URL}/api/ai_recommend_list_kv?limit=5")
        response = requests.get(f"{API_URL}/api/ai_recommend_list?limit=5")
        
        if response.status_code == 200:
            result = response.json()
            count = result.get('count', 0)
            print(f"   ✅ 조회 성공: {count}개 추천")
            
            if count > 0:
                first = result['data'][0]
                print(f"   첫 번째: {first.get('stockName')} ({first.get('stockCode')})")
            
            return result
        else:
            print(f"   ❌ 조회 실패: {response.status_code}")
            print(f"   {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ 오류: {e}")
        return None

def test_record_result(rec_id):
    """성과 기록 테스트"""
    print(f"\n🧪 3. 성과 기록 테스트 (ID: {rec_id})...")
    
    data = {
        "recommendationId": rec_id,
        "period": "dayTrading",
        "result": {
            "actualReturn": 4.2,
            "expectedReturn": 3.1,
            "success": True,
            "exitPrice": 76200,
            "exitReason": "target_reached",
            "analysis": "예상보다 1.1% 더 상승. 외국인 매수세 유입이 긍정적으로 작용"
        }
    }
    
    try:
        response = requests.post(f"{API_URL}/api/ai_record_result", json=data)
        
        if response.status_code == 200:
            result = response.json()
            print(f"   ✅ 성과 기록 성공!")
            performance = result.get('data', {}).get('performance', {})
            if performance:
                print(f"   평균 수익률: {performance.get('averageReturn', 0):.2f}%")
                print(f"   성공률: {performance.get('successRate', 0):.1f}%")
            return result
        else:
            print(f"   ❌ 기록 실패: {response.status_code}")
            print(f"   {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ 오류: {e}")
        return None

def test_performance_stats():
    """성과 통계 테스트"""
    print("\n🧪 4. 성과 통계 조회 테스트...")
    
    try:
        # 대시보드 통계
        response = requests.get(f"{API_URL}/api/ai_performance_stats?type=dashboard")
        
        if response.status_code == 200:
            result = response.json()
            stats = result.get('data', {})
            print(f"   ✅ 통계 조회 성공!")
            print(f"   총 추천: {stats.get('totalRecommendations', 0)}개")
            print(f"   완료: {stats.get('completedRecommendations', 0)}개")
            print(f"   평균 성공률: {stats.get('averageSuccessRate', 0):.1f}%")
            return result
        else:
            print(f"   ❌ 조회 실패: {response.status_code}")
            print(f"   {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ 오류: {e}")
        return None

def main():
    print("=" * 60)
    print("🚀 StockWiki AI 추천 API 테스트")
    print("=" * 60)
    print(f"API URL: {API_URL}\n")
    
    # 1. 업로드 테스트
    uploaded = test_upload_recommendation()
    
    # 2. 목록 조회 테스트
    test_list_recommendations()
    
    # 3. 성과 기록 테스트 (업로드 성공한 경우)
    if uploaded and uploaded.get('id'):
        test_record_result(uploaded['id'])
    
    # 4. 통계 조회 테스트
    test_performance_stats()
    
    print("\n" + "=" * 60)
    print("✅ 모든 테스트 완료!")
    print("=" * 60)

if __name__ == '__main__':
    main()

