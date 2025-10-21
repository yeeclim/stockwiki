#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
빠른 테스트용 KRX 스크래퍼
적은 수의 페이지만 테스트해서 성능 확인
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
        logging.StreamHandler()
    ]
)

class QuickTestScraper:
    def __init__(self):
        self.output_path = "../assets/data/krx_basic_info.json"
        self.backup_path = "../assets/data/krx_basic_info_backup.json"
        
    def get_stocks_from_page(self, url, market_name):
        """특정 페이지에서 종목 데이터 수집"""
        try:
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.get(url, headers=headers, timeout=10)
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
            
            return stocks
            
        except Exception as e:
            logging.error(f"{market_name} 종목 수집 오류: {e}")
            return []
    
    def quick_test(self):
        """빠른 테스트 실행"""
        logging.info("빠른 테스트 시작 - 3페이지만 수집")
        logging.info("=" * 40)
        
        all_stocks = []
        
        # KOSPI 2페이지 수집
        for page in range(1, 3):
            url = f"https://finance.naver.com/sise/sise_market_sum.naver?sosok=0&page={page}"
            logging.info(f"KOSPI 페이지 {page} 수집 중...")
            
            stocks = self.get_stocks_from_page(url, "KOSPI")
            all_stocks.extend(stocks)
            logging.info(f"KOSPI 페이지 {page}: {len(stocks)}개 종목")
            
            time.sleep(0.3)  # 짧은 딜레이
        
        # KOSDAQ 1페이지 수집
        url = "https://finance.naver.com/sise/sise_market_sum.naver?sosok=1&page=1"
        logging.info("KOSDAQ 페이지 1 수집 중...")
        
        stocks = self.get_stocks_from_page(url, "KOSDAQ")
        all_stocks.extend(stocks)
        logging.info(f"KOSDAQ 페이지 1: {len(stocks)}개 종목")
        
        logging.info(f"총 {len(all_stocks)}개 종목 수집 완료")
        
        # 폴라리스오피스 확인
        polaris = next((s for s in all_stocks if s['code'] == '010940'), None)
        if polaris:
            logging.info(f"폴라리스오피스 발견! 현재가: {polaris['current_price']:,}원")
        else:
            logging.warning("폴라리스오피스를 찾을 수 없습니다")
        
        return all_stocks

def main():
    """메인 실행 함수"""
    scraper = QuickTestScraper()
    stocks = scraper.quick_test()
    return len(stocks) > 0

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
