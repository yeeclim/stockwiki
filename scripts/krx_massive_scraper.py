#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KRX 대량 종목 데이터 스크래핑 스크립트
500-1000개 종목을 수집하는 고성능 스크래퍼
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
import concurrent.futures
import threading

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('krx_massive_scraper.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)

class KRXMassiveScraper:
    def __init__(self):
        self.output_path = "../assets/data/krx_basic_info.json"
        self.backup_path = "../assets/data/krx_basic_info_backup.json"
        self.all_stocks = []
        self.lock = threading.Lock()
        
    def get_stocks_from_page(self, url, market_name, page_num):
        """특정 페이지에서 종목 데이터 수집"""
        try:
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
            table = soup.find('table', class_='type_2')
            if not table:
                return []
            
            stocks = []
            rows = table.find_all('tr')[1:]  # 헤더 제외
            
            for row in rows:
                try:
                    cells = row.find_all('td')
                    if len(cells) >= 12:
                        name_cell = cells[1].find('a')
                        if name_cell:
                            name = name_cell.get_text().strip()
                            code = name_cell.get('href', '').split('code=')[-1] if 'code=' in name_cell.get('href', '') else ''
                            
                            if name and code and len(code) == 6:
                                # 현재가 추출
                                current_price_text = cells[2].get_text().strip().replace(',', '')
                                current_price = int(current_price_text) if current_price_text.isdigit() else 0
                                
                                # 전일대비 추출
                                change_text = cells[3].get_text().strip().replace(',', '')
                                change = int(change_text) if change_text.lstrip('+-').isdigit() else 0
                                
                                # 등락률 추출
                                change_rate_text = cells[4].get_text().strip().replace('%', '')
                                change_rate = float(change_rate_text) if change_rate_text.replace('+', '').replace('-', '').replace('.', '').isdigit() else 0.0
                                
                                # 거래량 추출
                                volume_text = cells[6].get_text().strip().replace(',', '')
                                volume = int(volume_text) if volume_text.isdigit() else 0
                                
                                stock_info = {
                                    'code': code,
                                    'name': name,
                                    'market': market_name,
                                    'sector': '기타',
                                    'listed_date': '2020-01-01',
                                    'par_value': '100',
                                    'current_price': current_price,
                                    'change': change,
                                    'change_rate': change_rate,
                                    'volume': volume,
                                    'market_cap': 0,
                                    'updated_at': datetime.now().isoformat()
                                }
                                
                                stocks.append(stock_info)
                                
                except Exception as e:
                    continue
            
            with self.lock:
                logging.info(f"{market_name} 페이지 {page_num}: {len(stocks)}개 종목 수집")
            
            return stocks
            
        except Exception as e:
            with self.lock:
                logging.error(f"{market_name} 페이지 {page_num} 수집 오류: {e}")
            return []
    
    def get_market_stocks(self, market_code, market_name, max_pages=50):
        """특정 시장의 모든 종목 수집"""
        all_stocks = []
        
        # 병렬 처리를 위한 스레드 풀
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = []
            
            for page in range(1, max_pages + 1):
                url = f"https://finance.naver.com/sise/sise_market_sum.naver?sosok={market_code}&page={page}"
                future = executor.submit(self.get_stocks_from_page, url, market_name, page)
                futures.append(future)
                
                # 요청 간 딜레이
                time.sleep(0.1)
            
            # 결과 수집
            for future in concurrent.futures.as_completed(futures):
                try:
                    stocks = future.result()
                    if stocks:
                        all_stocks.extend(stocks)
                    else:
                        # 빈 결과가 나오면 더 이상 페이지가 없다고 가정
                        break
                except Exception as e:
                    logging.error(f"Future 결과 처리 오류: {e}")
        
        return all_stocks
    
    def get_all_stocks(self):
        """전체 상장기업 데이터 수집"""
        logging.info("KRX 대량 종목 데이터 수집 시작")
        logging.info("=" * 50)
        
        all_stocks = []
        
        # KOSPI 종목 수집 (최대 50페이지)
        logging.info("KOSPI 종목 수집 시작...")
        kospi_stocks = self.get_market_stocks(0, "KOSPI", 50)
        all_stocks.extend(kospi_stocks)
        logging.info(f"KOSPI 수집 완료: {len(kospi_stocks)}개 종목")
        
        # KOSDAQ 종목 수집 (최대 50페이지)
        logging.info("KOSDAQ 종목 수집 시작...")
        kosdaq_stocks = self.get_market_stocks(1, "KOSDAQ", 50)
        all_stocks.extend(kosdaq_stocks)
        logging.info(f"KOSDAQ 수집 완료: {len(kosdaq_stocks)}개 종목")
        
        logging.info(f"전체 종목 수집 완료: {len(all_stocks)}개")
        logging.info(f"KOSPI: {len(kospi_stocks)}개, KOSDAQ: {len(kosdaq_stocks)}개")
        
        return all_stocks
    
    def save_krx_data(self, stocks_data):
        """처리된 데이터를 JSON 파일로 저장"""
        try:
            # 메타데이터 생성
            metadata = {
                'updated_at': datetime.now().isoformat(),
                'total_count': len(stocks_data),
                'source': 'Naver Finance Massive Scraping',
                'description': 'KRX 대량 상장기업 기본정보',
                'version': '7.0',
                'update_type': 'massive_scraping'
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
            # 1단계: 전체 주식 데이터 수집
            stocks_data = self.get_all_stocks()
            
            if not stocks_data:
                logging.error("데이터 수집 실패")
                return False
            
            # 2단계: JSON 파일 저장
            success = self.save_krx_data(stocks_data)
            
            if success:
                logging.info("=" * 50)
                logging.info("KRX 대량 종목 데이터 수집 완료!")
                logging.info(f"총 {len(stocks_data)}개 종목 정보 수집")
                logging.info(f"업데이트 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                
                # 폴라리스오피스 정보 확인
                polaris = next((s for s in stocks_data if s['code'] == '010940'), None)
                if polaris:
                    logging.info(f"폴라리스오피스 현재가: {polaris['current_price']:,}원")
                else:
                    logging.warning("폴라리스오피스를 찾을 수 없습니다")
                
                return True
            else:
                logging.error("KRX 데이터 업데이트 실패")
                return False
                
        except Exception as e:
            logging.error(f"업데이트 과정에서 오류 발생: {e}")
            return False

def main():
    """메인 실행 함수"""
    scraper = KRXMassiveScraper()
    success = scraper.run_update()
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
