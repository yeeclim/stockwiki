#!/usr/bin/env python3
"""
AI 종목 분석 및 자동 업로드 스크립트

사용법:
    python ai_stock_analyzer.py --stock 005930 --auto-upload

환경변수:
    STOCKWIKI_API_URL: API 엔드포인트 URL (기본값: http://localhost:3000)
"""

import requests
import json
import sys
import argparse
from datetime import datetime

class AIStockAnalyzer:
    def __init__(self, api_url="http://localhost:3000"):
        self.api_url = api_url
        
    def analyze_stock(self, stock_code):
        """
        종목을 분석하고 추천 데이터 생성
        
        TODO: 실제 AI 분석 로직 구현
        현재는 샘플 분석 결과 반환
        """
        
        # 샘플 분석 결과
        analysis = {
            "stockName": "삼성전자",
            "stockCode": stock_code,
            "currentPrice": 75000,
            "changePercent": 2.3,
            "changeAmount": 1700,
            "action": "매수",
            "reasons": [
                "반도체 업황 회복 신호 포착",
                "HBM3E 양산 본격화로 수익성 개선 예상",
                "4분기 실적 시장 컨센서스 상회 전망",
                "기술적 분석: RSI 과매도 구간에서 반등",
                "외국인 매수세 유입 확대"
            ],
            "targetPrice": 85000,
            
            # 단타 전략 (1-3일)
            "dayTrading": {
                "buyPrice": 74500,
                "sellPrice": 76800,
                "stopLoss": 73500,
                "period": "1~3일",
                "expectedReturn": 3.1
            },
            
            # 스윙 전략 (1주일~1개월)
            "swingTrading": {
                "buyPrice": 74000,
                "sellPrice": 81000,
                "stopLoss": 72000,
                "period": "1주~1개월",
                "expectedReturn": 9.5
            },
            
            # 중장기 전략 (3개월~1년)
            "longTerm": {
                "buyPrice": 75000,
                "sellPrice": 92000,
                "stopLoss": 70000,
                "period": "3개월~1년",
                "expectedReturn": 22.7
            }
        }
        
        return analysis
    
    def upload_recommendation(self, recommendation):
        """
        분석 결과를 API에 업로드
        """
        try:
            url = f"{self.api_url}/api/ai_recommend_upload"
            headers = {
                'Content-Type': 'application/json',
            }
            
            response = requests.post(url, json=recommendation, headers=headers)
            
            if response.status_code == 200:
                result = response.json()
                print(f"✅ 업로드 성공: {result['data']['id']}")
                return True
            else:
                print(f"❌ 업로드 실패: {response.status_code}")
                print(response.text)
                return False
                
        except Exception as e:
            print(f"❌ 업로드 오류: {e}")
            return False
    
    def run_analysis_and_upload(self, stock_code, auto_upload=False):
        """
        종목 분석 및 업로드 실행
        """
        print(f"🔍 종목 분석 시작: {stock_code}")
        print("-" * 50)
        
        # 1. AI 분석 수행
        recommendation = self.analyze_stock(stock_code)
        
        # 2. 분석 결과 출력
        print(f"\n📊 분석 결과:")
        print(f"종목: {recommendation['stockName']} ({recommendation['stockCode']})")
        print(f"현재가: ₩{recommendation['currentPrice']:,}")
        print(f"액션: {recommendation['action']}")
        print(f"\n추천 근거:")
        for i, reason in enumerate(recommendation['reasons'], 1):
            print(f"  {i}. {reason}")
        
        print(f"\n💼 투자 전략:")
        
        if 'dayTrading' in recommendation:
            dt = recommendation['dayTrading']
            print(f"\n  🎯 단타 ({dt['period']})")
            print(f"    매수: ₩{dt['buyPrice']:,}")
            print(f"    매도: ₩{dt['sellPrice']:,}")
            print(f"    손절: ₩{dt['stopLoss']:,}")
            print(f"    기대수익: +{dt['expectedReturn']}%")
        
        if 'swingTrading' in recommendation:
            st = recommendation['swingTrading']
            print(f"\n  📊 스윙 ({st['period']})")
            print(f"    매수: ₩{st['buyPrice']:,}")
            print(f"    매도: ₩{st['sellPrice']:,}")
            print(f"    손절: ₩{st['stopLoss']:,}")
            print(f"    기대수익: +{st['expectedReturn']}%")
        
        if 'longTerm' in recommendation:
            lt = recommendation['longTerm']
            print(f"\n  📈 중장기 ({lt['period']})")
            print(f"    매수: ₩{lt['buyPrice']:,}")
            print(f"    매도: ₩{lt['sellPrice']:,}")
            print(f"    손절: ₩{lt['stopLoss']:,}")
            print(f"    기대수익: +{lt['expectedReturn']}%")
        
        print("\n" + "-" * 50)
        
        # 3. 자동 업로드
        if auto_upload:
            print("\n📤 API 업로드 중...")
            success = self.upload_recommendation(recommendation)
            if success:
                print("✨ 종목 추천이 자동으로 게시되었습니다!")
            else:
                print("⚠️ 업로드에 실패했습니다. 데이터를 확인하세요.")
        else:
            print("\n💡 자동 업로드를 원하시면 --auto-upload 옵션을 사용하세요.")
            
            # JSON 파일로 저장
            filename = f"recommendation_{stock_code}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(recommendation, f, ensure_ascii=False, indent=2)
            print(f"📁 분석 결과가 저장되었습니다: {filename}")

def main():
    parser = argparse.ArgumentParser(description='AI 종목 분석 및 자동 업로드')
    parser.add_argument('--stock', required=True, help='종목 코드 (예: 005930)')
    parser.add_argument('--auto-upload', action='store_true', help='자동으로 API에 업로드')
    parser.add_argument('--api-url', default='http://localhost:3000', help='API URL')
    
    args = parser.parse_args()
    
    analyzer = AIStockAnalyzer(api_url=args.api_url)
    analyzer.run_analysis_and_upload(args.stock, auto_upload=args.auto_upload)

if __name__ == '__main__':
    main()

