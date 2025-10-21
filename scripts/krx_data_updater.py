#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KRX 상장기업 기본정보 데이터 업데이트 스크립트
한국거래소에서 최신 상장기업 정보를 가져와서 JSON 파일로 저장
"""

import requests
import pandas as pd
import json
import os
import sys
from datetime import datetime
import time

def download_krx_basic_info():
    """
    KRX에서 상장기업 기본정보를 다운로드
    """
    try:
        print("🔄 KRX 상장기업 기본정보 다운로드 시작...")
        
        # KRX 상장기업현황 URL (실제 URL은 KRX 웹사이트에서 확인 필요)
        url = "http://marketdata.krx.co.kr/contents/COM/GenerateOTP.jspx"
        
        # 1단계: OTP 생성
        otp_params = {
            'name': 'COL_OPR_TBL',
            'filetype': 'xlsx',
            'url': 'MKD/01/0110/01100305/mkd01100305_01'
        }
        
        response = requests.post(url, data=otp_params)
        if response.status_code != 200:
            raise Exception(f"OTP 생성 실패: {response.status_code}")
        
        otp_code = response.text
        print(f"✅ OTP 생성 완료: {otp_code[:10]}...")
        
        # 2단계: 실제 데이터 다운로드
        download_url = "http://file.krx.co.kr/download.jspx"
        download_params = {
            'code': otp_code
        }
        
        headers = {
            'Referer': 'http://marketdata.krx.co.kr/contents/MKD/01/0110/01100305/MKD01100305.jsp',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        print("📥 데이터 다운로드 중...")
        download_response = requests.post(download_url, data=download_params, headers=headers)
        
        if download_response.status_code != 200:
            raise Exception(f"데이터 다운로드 실패: {download_response.status_code}")
        
        # 임시 파일로 저장
        temp_file = "temp_krx_data.xlsx"
        with open(temp_file, 'wb') as f:
            f.write(download_response.content)
        
        print(f"✅ 데이터 다운로드 완료: {temp_file}")
        return temp_file
        
    except Exception as e:
        print(f"❌ KRX 데이터 다운로드 실패: {e}")
        return None

def process_krx_data(file_path):
    """
    다운로드된 KRX 데이터를 처리하여 JSON 형태로 변환
    """
    try:
        print("🔄 KRX 데이터 처리 중...")
        
        # 엑셀 파일 읽기
        df = pd.read_excel(file_path)
        
        # 컬럼명 정리
        df.columns = df.columns.str.strip()
        
        # 필요한 컬럼만 선택 (실제 컬럼명은 다운로드된 파일에 따라 조정 필요)
        required_columns = [
            '종목코드', '종목명', '시장구분', '업종', '상장일', 
            '액면가', '주식수', '시가총액', '상장주식수'
        ]
        
        # 실제 컬럼명 매핑 (KRX에서 제공하는 실제 컬럼명으로 수정 필요)
        column_mapping = {
            '종목코드': 'code',
            '종목명': 'name', 
            '시장구분': 'market',
            '업종': 'sector',
            '상장일': 'listed_date',
            '액면가': 'par_value',
            '주식수': 'shares',
            '시가총액': 'market_cap',
            '상장주식수': 'listed_shares'
        }
        
        # 컬럼명 변경
        df = df.rename(columns=column_mapping)
        
        # 데이터 정리
        df = df.dropna(subset=['code', 'name'])  # 필수 컬럼이 비어있는 행 제거
        
        # 종목코드를 6자리 문자열로 변환
        df['code'] = df['code'].astype(str).str.zfill(6)
        
        # NaN 값을 적절히 처리
        df = df.fillna('')
        
        # JSON 형태로 변환
        stocks_data = []
        for _, row in df.iterrows():
            stock_info = {
                'code': row['code'],
                'name': row['name'],
                'market': row['market'],
                'sector': row['sector'],
                'listed_date': str(row['listed_date']) if pd.notna(row['listed_date']) else '',
                'par_value': str(row['par_value']) if pd.notna(row['par_value']) else '',
                'shares': str(row['shares']) if pd.notna(row['shares']) else '',
                'market_cap': str(row['market_cap']) if pd.notna(row['market_cap']) else '',
                'listed_shares': str(row['listed_shares']) if pd.notna(row['listed_shares']) else ''
            }
            stocks_data.append(stock_info)
        
        print(f"✅ 데이터 처리 완료: {len(stocks_data)}개 종목")
        return stocks_data
        
    except Exception as e:
        print(f"❌ 데이터 처리 실패: {e}")
        return None

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
                'source': 'KRX (한국거래소)',
                'description': '상장기업 기본정보'
            },
            'stocks': stocks_data
        }
        
        # JSON 파일로 저장
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(output_data, f, ensure_ascii=False, indent=2)
        
        print(f"✅ JSON 파일 저장 완료: {output_path}")
        return True
        
    except Exception as e:
        print(f"❌ JSON 파일 저장 실패: {e}")
        return False

def cleanup_temp_files(temp_file):
    """
    임시 파일 정리
    """
    try:
        if os.path.exists(temp_file):
            os.remove(temp_file)
            print(f"🗑️ 임시 파일 삭제 완료: {temp_file}")
    except Exception as e:
        print(f"⚠️ 임시 파일 삭제 실패: {e}")

def main():
    """
    메인 실행 함수
    """
    print("🚀 KRX 데이터 업데이트 시작")
    print("=" * 50)
    
    # 출력 파일 경로 설정
    output_path = "../assets/data/krx_basic_info.json"
    
    # 1단계: KRX에서 데이터 다운로드
    temp_file = download_krx_basic_info()
    if not temp_file:
        print("❌ 데이터 다운로드 실패로 종료")
        return False
    
    # 2단계: 데이터 처리
    stocks_data = process_krx_data(temp_file)
    if not stocks_data:
        cleanup_temp_files(temp_file)
        print("❌ 데이터 처리 실패로 종료")
        return False
    
    # 3단계: JSON 파일로 저장
    success = save_krx_data(stocks_data, output_path)
    
    # 4단계: 임시 파일 정리
    cleanup_temp_files(temp_file)
    
    if success:
        print("=" * 50)
        print("🎉 KRX 데이터 업데이트 완료!")
        print(f"📊 총 {len(stocks_data)}개 종목 정보 업데이트")
        print(f"📅 업데이트 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    else:
        print("❌ KRX 데이터 업데이트 실패")
    
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
