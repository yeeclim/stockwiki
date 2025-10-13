#!/usr/bin/env python3
"""
AI 추천 성과 자동 추적 스크립트

실제 주가를 확인하여 추천의 성과를 자동으로 기록합니다.

사용법:
    # 특정 추천 추적
    python track_performance.py --id rec_1234567890_abc123
    
    # 모든 활성 추천 추적
    python track_performance.py --track-all
    
    # 일일 자동 추적 (크론잡 등록)
    0 18 * * * python track_performance.py --track-all
"""

import requests
import argparse
import json
from datetime import datetime, timedelta

class PerformanceTracker:
    def __init__(self, api_url="http://localhost:3000"):
        self.api_url = api_url
    
    def get_current_price(self, stock_code):
        """
        현재 주가 조회
        
        TODO: 실제 주가 API 연동
        현재는 샘플 가격 반환
        """
        # 샘플 가격 (실제로는 KRX, 네이버 금융 등에서 가져옴)
        sample_prices = {
            '005930': 76500,  # 삼성전자
            '000660': 189000,  # SK하이닉스
            '035420': 242000,  # NAVER
            '035720': 53500,   # 카카오
            '373220': 435000,  # LG에너지솔루션
        }
        
        return sample_prices.get(stock_code, 0)
    
    def check_recommendation(self, recommendation):
        """
        추천의 현재 상태 확인 및 성과 기록
        """
        rec_id = recommendation['id']
        stock_code = recommendation['stockCode']
        posted_at = datetime.fromisoformat(recommendation['postedAt'].replace('Z', '+00:00'))
        current_price = self.get_current_price(stock_code)
        
        if current_price == 0:
            print(f"⚠️  {rec_id}: 주가 조회 실패")
            return
        
        print(f"\n📊 추천 확인: {recommendation['stockName']} ({stock_code})")
        print(f"   추천일: {posted_at.strftime('%Y-%m-%d')}")
        print(f"   현재가: ₩{current_price:,}")
        
        results_to_record = []
        
        # 단타 확인 (1-3일)
        if 'dayTrading' in recommendation and recommendation['dayTrading']:
            results_to_record.extend(
                self._check_period(
                    recommendation, 'dayTrading', 
                    current_price, posted_at, 
                    days_min=1, days_max=3
                )
            )
        
        # 스윙 확인 (7-30일)
        if 'swingTrading' in recommendation and recommendation['swingTrading']:
            results_to_record.extend(
                self._check_period(
                    recommendation, 'swingTrading', 
                    current_price, posted_at, 
                    days_min=7, days_max=30
                )
            )
        
        # 중장기 확인 (90-365일)
        if 'longTerm' in recommendation and recommendation['longTerm']:
            results_to_record.extend(
                self._check_period(
                    recommendation, 'longTerm', 
                    current_price, posted_at, 
                    days_min=90, days_max=365
                )
            )
        
        # 결과 기록
        for result in results_to_record:
            self._record_result(rec_id, result['period'], result['data'])
    
    def _check_period(self, recommendation, period, current_price, posted_at, days_min, days_max):
        """
        특정 기간 전략 확인
        """
        strategy = recommendation[period]
        buy_price = strategy['buyPrice']
        sell_price = strategy['sellPrice']
        stop_loss = strategy.get('stopLoss')
        expected_return = strategy['expectedReturn']
        
        days_passed = (datetime.now() - posted_at).days
        
        # 이미 기록된 결과가 있는지 확인
        actual_results = recommendation.get('actualResults', {})
        if period in actual_results:
            print(f"   ✅ {period}: 이미 기록됨")
            return []
        
        # 기간 확인
        if days_passed < days_min:
            print(f"   ⏳ {period}: 대기 중 ({days_passed}/{days_min}일)")
            return []
        
        if days_passed > days_max:
            print(f"   ⏰ {period}: 기간 만료 ({days_passed}일)")
            # 기간 만료 시 현재가로 강제 청산
            actual_return = ((current_price - buy_price) / buy_price) * 100
            success = actual_return >= expected_return * 0.7  # 70% 달성도
            
            return [{
                'period': period,
                'data': {
                    'actualReturn': round(actual_return, 2),
                    'expectedReturn': expected_return,
                    'success': success,
                    'exitPrice': current_price,
                    'exitReason': 'period_expired',
                    'analysis': f'기간 만료로 청산. 목표 대비 {actual_return - expected_return:+.2f}%'
                }
            }]
        
        # 목표가 달성 확인
        if current_price >= sell_price:
            actual_return = ((sell_price - buy_price) / buy_price) * 100
            
            print(f"   🎯 {period}: 목표가 달성! {actual_return:.2f}%")
            
            return [{
                'period': period,
                'data': {
                    'actualReturn': round(actual_return, 2),
                    'expectedReturn': expected_return,
                    'success': True,
                    'exitPrice': sell_price,
                    'exitReason': 'target_reached',
                    'analysis': f'목표가 달성. 예상 수익률 {expected_return}% vs 실제 {actual_return:.2f}%'
                }
            }]
        
        # 손절가 확인
        if stop_loss and current_price <= stop_loss:
            actual_return = ((stop_loss - buy_price) / buy_price) * 100
            
            print(f"   🛑 {period}: 손절 발동 {actual_return:.2f}%")
            
            return [{
                'period': period,
                'data': {
                    'actualReturn': round(actual_return, 2),
                    'expectedReturn': expected_return,
                    'success': False,
                    'exitPrice': stop_loss,
                    'exitReason': 'stop_loss',
                    'analysis': f'손절가 도달. 손실 {actual_return:.2f}%'
                }
            }]
        
        print(f"   📈 {period}: 진행 중 ({days_passed}일)")
        return []
    
    def _record_result(self, rec_id, period, result_data):
        """
        성과를 API에 기록
        """
        try:
            url = f"{self.api_url}/api/ai_record_result"
            
            payload = {
                'recommendationId': rec_id,
                'period': period,
                'result': result_data
            }
            
            response = requests.post(url, json=payload)
            
            if response.status_code == 200:
                print(f"   ✅ {period} 성과 기록 완료")
                return True
            else:
                print(f"   ❌ {period} 기록 실패: {response.status_code}")
                print(f"      {response.text}")
                return False
                
        except Exception as e:
            print(f"   ❌ {period} 기록 오류: {e}")
            return False
    
    def track_all_active(self):
        """
        모든 활성 추천 추적
        """
        try:
            url = f"{self.api_url}/api/ai_recommend_list_kv?limit=100"
            response = requests.get(url)
            
            if response.status_code != 200:
                print(f"❌ 추천 목록 조회 실패: {response.status_code}")
                return
            
            data = response.json()
            recommendations = data.get('data', [])
            
            print(f"📋 총 {len(recommendations)}개 추천 확인 중...")
            print("=" * 60)
            
            active_count = 0
            for rec in recommendations:
                # 활성 상태만 확인
                if rec.get('trackingStatus') == 'active':
                    active_count += 1
                    self.check_recommendation(rec)
            
            print("\n" + "=" * 60)
            print(f"✅ 추적 완료: {active_count}개 활성 추천 확인")
            
        except Exception as e:
            print(f"❌ 전체 추적 오류: {e}")
    
    def track_single(self, rec_id):
        """
        특정 추천만 추적
        """
        try:
            # TODO: 단일 추천 조회 API 구현 필요
            # 현재는 목록에서 검색
            url = f"{self.api_url}/api/ai_recommend_list_kv?limit=100"
            response = requests.get(url)
            
            if response.status_code != 200:
                print(f"❌ 추천 조회 실패: {response.status_code}")
                return
            
            data = response.json()
            recommendations = data.get('data', [])
            
            recommendation = next((r for r in recommendations if r['id'] == rec_id), None)
            
            if not recommendation:
                print(f"❌ 추천을 찾을 수 없습니다: {rec_id}")
                return
            
            self.check_recommendation(recommendation)
            
        except Exception as e:
            print(f"❌ 추적 오류: {e}")

def main():
    parser = argparse.ArgumentParser(description='AI 추천 성과 자동 추적')
    parser.add_argument('--id', help='추적할 추천 ID')
    parser.add_argument('--track-all', action='store_true', help='모든 활성 추천 추적')
    parser.add_argument('--api-url', default='http://localhost:3000', help='API URL')
    
    args = parser.parse_args()
    
    tracker = PerformanceTracker(api_url=args.api_url)
    
    if args.track_all:
        tracker.track_all_active()
    elif args.id:
        tracker.track_single(args.id)
    else:
        print("사용법: --id <추천ID> 또는 --track-all")

if __name__ == '__main__':
    main()

