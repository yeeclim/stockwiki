#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KRX 데이터 업데이트 스크립트 (웹 스크래핑 방식)
네이버 금융 웹페이지를 직접 스크래핑하여 데이터 수집
"""

import requests
from bs4 import BeautifulSoup
import json
import os
import sys
from datetime import datetime
import time
import logging
import re

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('krx_scraper.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)

class KRXWebScraperUpdater:
    def __init__(self):
        self.output_path = "../assets/data/krx_basic_info.json"
        self.backup_path = "../assets/data/krx_basic_info_backup.json"
        
        # 주요 KRX 상장기업 목록
        self.krx_stocks = [
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
    
    def scrape_naver_finance(self, code):
        """네이버 금융 웹페이지에서 주가 정보 스크래핑"""
        try:
            url = f'https://finance.naver.com/item/main.naver?code={code}'
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                'Accept-Language': 'ko-KR,ko;q=0.8,en-US;q=0.5,en;q=0.3',
                'Accept-Encoding': 'gzip, deflate',
                'Connection': 'keep-alive',
                'Upgrade-Insecure-Requests': '1',
            }
            
            response = requests.get(url, headers=headers, timeout=15)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.content, 'html.parser')
            
            # 현재가 추출
            current_price_elem = soup.find('p', class_='no_today')
            if current_price_elem:
                price_text = current_price_elem.get_text().strip()
                # 숫자만 추출
                price_match = re.search(r'[\d,]+', price_text.replace(',', ''))
                if price_match:
                    current_price = int(price_match.group().replace(',', ''))
                else:
                    current_price = 0
            else:
                current_price = 0
            
            # 전일대비 추출
            change_elem = soup.find('span', class_='tah p11')
            if change_elem:
                change_text = change_elem.get_text().strip()
                change_match = re.search(r'([+-]?[\d,]+)', change_text.replace(',', ''))
                if change_match:
                    change = int(change_match.group().replace(',', ''))
                else:
                    change = 0
            else:
                change = 0
            
            # 등락률 추출
            change_rate_elem = soup.find('span', class_='tah p11 red') or soup.find('span', class_='tah p11 blue')
            if change_rate_elem:
                rate_text = change_rate_elem.get_text().strip()
                rate_match = re.search(r'([+-]?[\d.]+)', rate_text)
                if rate_match:
                    change_rate = float(rate_match.group())
                else:
                    change_rate = 0.0
            else:
                change_rate = 0.0
            
            # 거래량 추출
            volume_elem = soup.find('span', class_='tah p11')
            if volume_elem:
                volume_text = volume_elem.get_text().strip()
                volume_match = re.search(r'[\d,]+', volume_text.replace(',', ''))
                if volume_match:
                    volume = int(volume_match.group().replace(',', ''))
                else:
                    volume = 0
            else:
                volume = 0
            
            return {
                'current_price': current_price,
                'change': change,
                'change_rate': change_rate,
                'volume': volume,
                'market_cap': 0  # 시가총액은 별도 계산 필요
            }
            
        except Exception as e:
            logging.warning(f"네이버 금융 스크래핑 오류 ({code}): {e}")
            return None
    
    def update_stock_data(self):
        """전체 주식 데이터 업데이트"""
        logging.info("KRX 데이터 웹 스크래핑 업데이트 시작")
        logging.info("=" * 50)
        
        updated_stocks = []
        success_count = 0
        
        for i, stock in enumerate(self.krx_stocks):
            logging.info(f"처리 중 ({i+1}/{len(self.krx_stocks)}): {stock['name']} ({stock['code']})")
            
            # 네이버 금융에서 웹 스크래핑
            scraped_data = self.scrape_naver_finance(stock['code'])
            
            # 기본 정보 구성
            stock_data = {
                'code': stock['code'],
                'name': stock['name'],
                'market': stock['market'],
                'sector': stock['sector'],
                'listed_date': '2020-01-01',  # 기본값
                'par_value': '100',  # 기본값
                'current_price': scraped_data['current_price'] if scraped_data else 0,
                'change': scraped_data['change'] if scraped_data else 0,
                'change_rate': scraped_data['change_rate'] if scraped_data else 0,
                'volume': scraped_data['volume'] if scraped_data else 0,
                'market_cap': scraped_data['market_cap'] if scraped_data else 0,
                'updated_at': datetime.now().isoformat()
            }
            
            if scraped_data and scraped_data['current_price'] > 0:
                success_count += 1
                logging.info(f"  -> 현재가: {scraped_data['current_price']:,}원")
            
            updated_stocks.append(stock_data)
            
            # 요청 간 딜레이 (서버 부하 방지)
            time.sleep(1)
        
        logging.info(f"데이터 수집 완료: {success_count}/{len(self.krx_stocks)}개 성공")
        return updated_stocks
    
    def save_krx_data(self, stocks_data):
        """처리된 데이터를 JSON 파일로 저장"""
        try:
            # 메타데이터 생성
            metadata = {
                'updated_at': datetime.now().isoformat(),
                'total_count': len(stocks_data),
                'source': 'Naver Finance Web Scraping',
                'description': 'KRX 상장기업 기본정보 (웹 스크래핑)',
                'version': '4.0',
                'update_type': 'web_scraping_update'
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
                logging.info("KRX 데이터 웹 스크래핑 업데이트 완료!")
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
    updater = KRXWebScraperUpdater()
    success = updater.run_update()
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
