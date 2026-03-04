#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KRX 상장기업 기본정보 데이터 업데이트 스크립트 (간단 버전)
Yahoo Finance API와 공개 데이터를 활용하여 KRX 데이터를 업데이트
"""

import requests
import json
import os
import sys
from datetime import datetime
import time

def get_krx_stock_list():
    """
    네이버 증권 시가총액 상위 종목을 크롤링하여 KRX 종목 목록을 동적으로 가져옵니다.
    """
    print("🌐 네이버 증권에서 상장 종목 리스트 가져오는 중...")
    stocks = []
    
    # 코스피(KOSPI) 시가총액 상위 1페이지 (50종목)
    # 코스닥(KOSDAQ) 시가총액 상위 1페이지 (50종목)
    markets = [
        {"name": "KOSPI", "url": "https://finance.naver.com/sise/sise_market_sum.naver?sosok=0&page=1"},
        {"name": "KOSDAQ", "url": "https://finance.naver.com/sise/sise_market_sum.naver?sosok=1&page=1"}
    ]
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
    }
    
    for market in markets:
        try:
            response = requests.get(market['url'], headers=headers, timeout=10)
            if response.status_code == 200:
                # 간단한 정규표현식으로 종목코드와 이름 추출 (BeautifulSoup 없이)
                import re
                # <a href="/item/main.naver?code=005930" class="tltle">삼성전자</a>
                pattern = r'code=(\d{6})".*?class="tltle">(.*?)</a>'
                matches = re.findall(pattern, response.text)
                
                for code, name in matches:
                    stocks.append({
                        "code": code,
                        "name": name,
                        "market": market['name']
                    })
                print(f"✅ {market['name']} {len(matches)}개 종목 로드 완료")
        except Exception as e:
            print(f"⚠️ {market['name']} 로드 중 오류: {e}")
            
    if not stocks:
        print("⚠️ 동적 로드 실패, 최소한의 폴백 데이터 사용")
        return [
            {"code": "005930", "name": "삼성전자", "market": "KOSPI"},
            {"code": "000660", "name": "SK하이닉스", "market": "KOSPI"},
            {"code": "373220", "name": "LG에너지솔루션", "market": "KOSPI"}
        ]
        
    return stocks

def get_stock_info_from_yahoo(symbol):
    """
    Yahoo Finance API를 통해 주식 정보 가져오기
    """
    try:
        # Yahoo Finance API URL (무료 버전)
        url = f"https://query1.finance.yahoo.com/v8/finance/chart/{symbol}.KS"
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            
            if 'chart' in data and 'result' in data['chart'] and data['chart']['result']:
                result = data['chart']['result'][0]
                meta = result.get('meta', {})
                
                return {
                    'current_price': meta.get('regularMarketPrice', 0),
                    'previous_close': meta.get('previousClose', 0),
                    'volume': meta.get('regularMarketVolume', 0),
                    'market_cap': meta.get('marketCap', 0),
                    'currency': meta.get('currency', 'KRW')
                }
        
        return None
        
    except Exception as e:
        print(f"⚠️ Yahoo Finance API 오류 ({symbol}): {e}")
        return None

def create_updated_krx_data():
    """
    업데이트된 KRX 데이터 생성
    """
    print("🔄 KRX 데이터 업데이트 시작...")
    
    # 기본 종목 리스트 가져오기
    base_stocks = get_krx_stock_list()
    
    updated_stocks = []
    
    for i, stock in enumerate(base_stocks):
        print(f"📊 처리 중 ({i+1}/{len(base_stocks)}): {stock['name']} ({stock['code']})")
        
        # Yahoo Finance에서 실시간 데이터 가져오기
        # 마켓에 따라 접미사 결정 (KOSPI -> .KS, KOSDAQ -> .KQ)
        suffix = ".KS" if stock['market'] == "KOSPI" else ".KQ"
        yahoo_symbol = f"{stock['code']}{suffix}"
        stock_info = get_stock_info_from_yahoo(yahoo_symbol)
        
        # 기본 정보 구성
        stock_data = {
            'code': stock['code'],
            'name': stock['name'],
            'market': stock['market'],
            'sector': '기타',  # 기본값
            'listed_date': '2020-01-01',  # 기본값
            'par_value': '100',  # 기본값
            'current_price': stock_info['current_price'] if stock_info else 0,
            'previous_close': stock_info['previous_close'] if stock_info else 0,
            'volume': stock_info['volume'] if stock_info else 0,
            'market_cap': stock_info['market_cap'] if stock_info else 0,
            'change': 0,
            'change_rate': 0,
            'updated_at': datetime.now().isoformat()
        }
        
        # 변동률 계산
        if stock_info and stock_info['current_price'] and stock_info['previous_close']:
            change = stock_info['current_price'] - stock_info['previous_close']
            change_rate = (change / stock_info['previous_close']) * 100 if stock_info['previous_close'] != 0 else 0
            
            stock_data['change'] = round(change, 2)
            stock_data['change_rate'] = round(change_rate, 2)
        
        updated_stocks.append(stock_data)
        
        # API 호출 제한을 위한 딜레이
        time.sleep(0.1)
    
    return updated_stocks

def save_krx_data(stocks_data, output_path):
    """
    처리된 데이터를 JSON 파일로 저장
    """
    try:
        print(f"💾 JSON 파일 저장 중: {output_path}")
        
        # 메타데이터 추가
        output_data = {
            'metadata': {
                'updated_at': datetime.now().isoformat(),
                'total_count': len(stocks_data),
                'source': 'Yahoo Finance API + Manual Data',
                'description': 'KRX 상장기업 기본정보 (주요 종목)',
                'version': '2.0'
            },
            'stocks': stocks_data
        }
        
        # 백업 파일 생성
        backup_path = output_path.replace('.json', '_backup.json')
        if os.path.exists(output_path):
            os.rename(output_path, backup_path)
            print(f"📦 기존 파일 백업: {backup_path}")
        
        # JSON 파일로 저장
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        
        print(f"✅ JSON 파일 저장 완료: {output_path}")
        return True
        
    except Exception as e:
        print(f"❌ JSON 파일 저장 실패: {e}")
        return False

def main():
    """
    메인 실행 함수
    """
    print("🚀 KRX 데이터 업데이트 시작")
    print("=" * 50)
    
    # 출력 파일 경로 설정
    output_path = "../assets/data/krx_basic_info.json"
    
    try:
        # 1단계: 업데이트된 KRX 데이터 생성
        stocks_data = create_updated_krx_data()
        
        if not stocks_data:
            print("❌ 데이터 생성 실패")
            return False
        
        # 2단계: JSON 파일로 저장
        success = save_krx_data(stocks_data, output_path)
        
        if success:
            print("=" * 50)
            print("🎉 KRX 데이터 업데이트 완료!")
            print(f"📊 총 {len(stocks_data)}개 종목 정보 업데이트")
            print(f"📅 업데이트 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            
            # 가격 정보가 있는 종목 수 확인
            stocks_with_price = len([s for s in stocks_data if float(s.get('current_price', 0)) > 0])
            print(f"💰 가격 정보 포함 종목: {stocks_with_price}개")
        else:
            print("❌ KRX 데이터 업데이트 실패")
        
        return success
        
    except Exception as e:
        print(f"❌ 업데이트 과정에서 오류 발생: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
