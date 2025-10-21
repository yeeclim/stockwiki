#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KRX 데이터 업데이트 스크립트 (공개 API 사용)
네이버 금융, 다음 금융 등의 공개 API를 활용하여 KRX 데이터 수집
"""

import requests
import json
import os
import sys
from datetime import datetime
import time
import logging

# 로깅 설정 (이모지 제거)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('krx_update.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)

class KRXPublicAPIUpdater:
    def __init__(self):
        self.output_path = "../assets/data/krx_basic_info.json"
        self.backup_path = "../assets/data/krx_basic_info_backup.json"
        
        # 주요 KRX 상장기업 목록 (실제로는 더 많은 종목이 있지만 주요 종목들)
        self.krx_stocks = [
            # KOSPI 대형주
            {"code": "005930", "name": "삼성전자", "market": "KOSPI", "sector": "전기전자"},
            {"code": "000660", "name": "SK하이닉스", "market": "KOSPI", "sector": "전기전자"},
            {"code": "373220", "name": "LG에너지솔루션", "market": "KOSPI", "sector": "화학"},
            {"code": "035420", "name": "NAVER", "market": "KOSPI", "sector": "서비스업"},
            {"code": "035720", "name": "카카오", "market": "KOSPI", "sector": "서비스업"},
            {"code": "005380", "name": "현대자동차", "market": "KOSPI", "sector": "운수장비"},
            {"code": "000270", "name": "기아", "market": "KOSPI", "sector": "운수장비"},
            {"code": "207940", "name": "삼성바이오로직스", "market": "KOSPI", "sector": "의료정밀"},
            {"code": "006400", "name": "삼성SDI", "market": "KOSPI", "sector": "전기전자"},
            {"code": "051910", "name": "LG화학", "market": "KOSPI", "sector": "화학"},
            {"code": "068270", "name": "셀트리온", "market": "KOSPI", "sector": "의료정밀"},
            {"code": "323410", "name": "카카오뱅크", "market": "KOSPI", "sector": "금융업"},
            {"code": "012330", "name": "현대모비스", "market": "KOSPI", "sector": "운수장비"},
            {"code": "066570", "name": "LG전자", "market": "KOSPI", "sector": "전기전자"},
            {"code": "015760", "name": "한국전력", "market": "KOSPI", "sector": "전기가스업"},
            {"code": "017670", "name": "SK텔레콤", "market": "KOSPI", "sector": "통신업"},
            {"code": "030200", "name": "KT", "market": "KOSPI", "sector": "통신업"},
            {"code": "105560", "name": "KB금융", "market": "KOSPI", "sector": "금융업"},
            {"code": "055550", "name": "신한지주", "market": "KOSPI", "sector": "금융업"},
            {"code": "086280", "name": "현대글로비스", "market": "KOSPI", "sector": "운수창고업"},
            
            # KOSDAQ 주요 종목
            {"code": "207760", "name": "미래에셋대우", "market": "KOSDAQ", "sector": "금융업"},
            {"code": "035900", "name": "JYP Ent.", "market": "KOSDAQ", "sector": "서비스업"},
            {"code": "086520", "name": "에코프로", "market": "KOSDAQ", "sector": "화학"},
            {"code": "247540", "name": "에코프로비엠", "market": "KOSDAQ", "sector": "화학"},
            {"code": "196170", "name": "알테오젠", "market": "KOSDAQ", "sector": "의료정밀"},
            {"code": "065350", "name": "신성델타테크", "market": "KOSDAQ", "sector": "전기전자"},
            {"code": "357780", "name": "솔브레인", "market": "KOSDAQ", "sector": "화학"},
            {"code": "196490", "name": "다이나믹디자인", "market": "KOSDAQ", "sector": "서비스업"},
            {"code": "042700", "name": "한미반도체", "market": "KOSDAQ", "sector": "전기전자"},
            {"code": "200470", "name": "에이펙스반도체", "market": "KOSDAQ", "sector": "전기전자"},
            
            # 추가 주요 종목들
            {"code": "010940", "name": "폴라리스오피스", "market": "KOSDAQ", "sector": "서비스업"},
            {"code": "000810", "name": "삼성화재", "market": "KOSPI", "sector": "보험업"},
            {"code": "003550", "name": "LG", "market": "KOSPI", "sector": "화학"},
            {"code": "096770", "name": "SK이노베이션", "market": "KOSPI", "sector": "화학"},
            {"code": "018260", "name": "삼성에스디에스", "market": "KOSPI", "sector": "서비스업"},
            {"code": "032830", "name": "삼성생명", "market": "KOSPI", "sector": "보험업"},
            {"code": "000720", "name": "현대건설", "market": "KOSPI", "sector": "건설업"},
            {"code": "010130", "name": "고려아연", "market": "KOSPI", "sector": "비금속광물"},
            {"code": "003490", "name": "대한항공", "market": "KOSPI", "sector": "운수장비"},
            {"code": "011200", "name": "HMM", "market": "KOSPI", "sector": "운수장비"},
        ]
    
    def get_stock_price_from_naver(self, code):
        """네이버 금융에서 주가 정보 가져오기"""
        try:
            url = f'https://polling.finance.naver.com/api/realtime/domestic/stock/{code}'
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': 'https://finance.naver.com/'
            }
            
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                return {
                    'current_price': data.get('closePrice', 0),
                    'change': data.get('change', 0),
                    'change_rate': data.get('changeRate', 0),
                    'volume': data.get('volume', 0),
                    'market_cap': data.get('marketCap', 0)
                }
            else:
                logging.warning(f"네이버 API 호출 실패 ({code}): {response.status_code}")
                return None
                
        except Exception as e:
            logging.warning(f"네이버 API 오류 ({code}): {e}")
            return None
    
    def get_stock_price_from_yahoo(self, code):
        """Yahoo Finance에서 주가 정보 가져오기"""
        try:
            url = f'https://query1.finance.yahoo.com/v8/finance/chart/{code}.KS'
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(url, headers=headers, timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                if 'chart' in data and 'result' in data['chart'] and data['chart']['result']:
                    result = data['chart']['result'][0]
                    meta = result.get('meta', {})
                    
                    current_price = meta.get('regularMarketPrice', 0)
                    previous_close = meta.get('previousClose', 0)
                    change = current_price - previous_close if current_price and previous_close else 0
                    change_rate = (change / previous_close * 100) if previous_close != 0 else 0
                    
                    return {
                        'current_price': current_price,
                        'change': change,
                        'change_rate': change_rate,
                        'volume': meta.get('regularMarketVolume', 0),
                        'market_cap': meta.get('marketCap', 0)
                    }
            else:
                logging.warning(f"Yahoo API 호출 실패 ({code}): {response.status_code}")
                return None
                
        except Exception as e:
            logging.warning(f"Yahoo API 오류 ({code}): {e}")
            return None
    
    def update_stock_data(self):
        """전체 주식 데이터 업데이트"""
        logging.info("KRX 데이터 업데이트 시작")
        logging.info("=" * 50)
        
        updated_stocks = []
        success_count = 0
        
        for i, stock in enumerate(self.krx_stocks):
            logging.info(f"처리 중 ({i+1}/{len(self.krx_stocks)}): {stock['name']} ({stock['code']})")
            
            # 네이버 API에서 데이터 가져오기
            naver_data = self.get_stock_price_from_naver(stock['code'])
            
            # 네이버 API 실패 시 Yahoo API 시도
            if not naver_data:
                naver_data = self.get_stock_price_from_yahoo(stock['code'])
            
            # 기본 정보 구성
            stock_data = {
                'code': stock['code'],
                'name': stock['name'],
                'market': stock['market'],
                'sector': stock['sector'],
                'listed_date': '2020-01-01',  # 기본값
                'par_value': '100',  # 기본값
                'current_price': naver_data['current_price'] if naver_data else 0,
                'change': naver_data['change'] if naver_data else 0,
                'change_rate': naver_data['change_rate'] if naver_data else 0,
                'volume': naver_data['volume'] if naver_data else 0,
                'market_cap': naver_data['market_cap'] if naver_data else 0,
                'updated_at': datetime.now().isoformat()
            }
            
            if naver_data:
                success_count += 1
            
            updated_stocks.append(stock_data)
            
            # API 호출 제한을 위한 딜레이
            time.sleep(0.1)
        
        logging.info(f"데이터 수집 완료: {success_count}/{len(self.krx_stocks)}개 성공")
        return updated_stocks
    
    def save_krx_data(self, stocks_data):
        """처리된 데이터를 JSON 파일로 저장"""
        try:
            # 메타데이터 생성
            metadata = {
                'updated_at': datetime.now().isoformat(),
                'total_count': len(stocks_data),
                'source': 'Naver Finance API + Yahoo Finance API',
                'description': 'KRX 상장기업 기본정보 (주요 종목)',
                'version': '3.0',
                'update_type': 'public_api_update'
            }
            
            output_data = {
                'metadata': metadata,
                'stocks': stocks_data
            }
            
            # 백업 생성
            if os.path.exists(self.output_path):
                os.rename(self.output_path, self.backup_path)
                logging.info(f"기존 파일 백업: {self.backup_path}")
            
            # JSON 파일 저장
            with open(self.output_path, 'w', encoding='utf-8') as f:
                json.dump(output_data, f, ensure_ascii=False, indent=2)
            
            logging.info(f"JSON 파일 저장 완료: {self.output_path}")
            return True
            
        except Exception as e:
            logging.error(f"JSON 파일 저장 오류: {e}")
            return False
    
    def run_update(self):
        """전체 업데이트 실행"""
        try:
            # 1단계: 주식 데이터 업데이트
            stocks_data = self.update_stock_data()
            
            if not stocks_data:
                logging.error("데이터 수집 실패")
                return False
            
            # 2단계: JSON 파일 저장
            success = self.save_krx_data(stocks_data)
            
            if success:
                logging.info("=" * 50)
                logging.info("KRX 데이터 업데이트 완료!")
                logging.info(f"총 {len(stocks_data)}개 종목 정보 업데이트")
                logging.info(f"업데이트 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                
                # 폴라리스오피스 정보 확인
                polaris = next((s for s in stocks_data if s['code'] == '010940'), None)
                if polaris:
                    logging.info(f"폴라리스오피스 현재가: {polaris['current_price']:,}원")
                
                return True
            else:
                logging.error("KRX 데이터 업데이트 실패")
                return False
                
        except Exception as e:
            logging.error(f"업데이트 과정에서 오류 발생: {e}")
            return False

def main():
    """메인 실행 함수"""
    updater = KRXPublicAPIUpdater()
    success = updater.run_update()
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
