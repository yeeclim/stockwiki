#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KRX 전체 상장기업 데이터 업데이트 스크립트
한국거래소에서 전체 상장기업 정보를 가져와서 JSON 파일로 저장
매일 밤 12시에 자동 실행되도록 설계
"""

import requests
import pandas as pd
import json
import os
import sys
from datetime import datetime, timedelta
import time
import logging

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('krx_update.log'),
        logging.StreamHandler()
    ]
)

class KRXDataUpdater:
    def __init__(self):
        self.base_url = "http://marketdata.krx.co.kr"
        self.output_path = "../assets/data/krx_basic_info.json"
        self.backup_path = "../assets/data/krx_basic_info_backup.json"
        
    def get_otp_code(self):
        """KRX에서 OTP 코드 생성"""
        try:
            url = f"{self.base_url}/contents/COM/GenerateOTP.jspx"
            params = {
                'name': 'COL_OPR_TBL',
                'filetype': 'xlsx',
                'url': 'MKD/01/0110/01100305/mkd01100305_01'
            }
            
            response = requests.post(url, data=params, timeout=30)
            if response.status_code == 200:
                return response.text.strip()
            else:
                logging.error(f"OTP 생성 실패: {response.status_code}")
                return None
                
        except Exception as e:
            logging.error(f"OTP 생성 오류: {e}")
            return None
    
    def download_krx_data(self, otp_code):
        """KRX에서 실제 데이터 다운로드"""
        try:
            url = f"{self.base_url}/contents/COM/GenerateOTP.jspx"
            params = {'code': otp_code}
            
            headers = {
                'Referer': 'http://marketdata.krx.co.kr/contents/MKD/01/0110/01100305/MKD01100305.jsp',
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            
            response = requests.post(url, data=params, headers=headers, timeout=60)
            
            if response.status_code == 200:
                temp_file = f"temp_krx_data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx"
                with open(temp_file, 'wb') as f:
                    f.write(response.content)
                logging.info(f"데이터 다운로드 완료: {temp_file}")
                return temp_file
            else:
                logging.error(f"데이터 다운로드 실패: {response.status_code}")
                return None
                
        except Exception as e:
            logging.error(f"데이터 다운로드 오류: {e}")
            return None
    
    def process_krx_data(self, file_path):
        """다운로드된 KRX 데이터 처리"""
        try:
            logging.info("KRX 데이터 처리 시작...")
            
            # 엑셀 파일 읽기
            df = pd.read_excel(file_path)
            logging.info(f"원본 데이터 행 수: {len(df)}")
            
            # 컬럼명 정리
            df.columns = df.columns.str.strip()
            
            # 컬럼명 매핑 (실제 KRX 데이터 구조에 맞게 조정 필요)
            column_mapping = {
                '종목코드': 'code',
                '종목명': 'name',
                '시장구분': 'market',
                '업종': 'sector',
                '상장일': 'listed_date',
                '액면가': 'par_value',
                '주식수': 'shares',
                '시가총액': 'market_cap',
                '상장주식수': 'listed_shares',
                '현재가': 'current_price',
                '전일대비': 'change',
                '등락률': 'change_rate',
                '거래량': 'volume'
            }
            
            # 존재하는 컬럼만 매핑
            existing_columns = {k: v for k, v in column_mapping.items() if k in df.columns}
            df = df.rename(columns=existing_columns)
            
            # 필수 컬럼 확인
            required_columns = ['code', 'name']
            missing_columns = [col for col in required_columns if col not in df.columns]
            if missing_columns:
                logging.error(f"필수 컬럼 누락: {missing_columns}")
                return None
            
            # 데이터 정리
            df = df.dropna(subset=['code', 'name'])
            df['code'] = df['code'].astype(str).str.zfill(6)
            
            # NaN 값 처리
            df = df.fillna('')
            
            # JSON 형태로 변환
            stocks_data = []
            for _, row in df.iterrows():
                stock_info = {
                    'code': str(row['code']),
                    'name': str(row['name']),
                    'market': str(row.get('market', '')),
                    'sector': str(row.get('sector', '')),
                    'listed_date': str(row.get('listed_date', '')),
                    'par_value': str(row.get('par_value', '')),
                    'shares': str(row.get('shares', '')),
                    'market_cap': str(row.get('market_cap', '')),
                    'listed_shares': str(row.get('listed_shares', '')),
                    'current_price': float(row.get('current_price', 0)) if pd.notna(row.get('current_price')) else 0,
                    'change': float(row.get('change', 0)) if pd.notna(row.get('change')) else 0,
                    'change_rate': float(row.get('change_rate', 0)) if pd.notna(row.get('change_rate')) else 0,
                    'volume': int(row.get('volume', 0)) if pd.notna(row.get('volume')) else 0
                }
                stocks_data.append(stock_info)
            
            logging.info(f"처리된 데이터 행 수: {len(stocks_data)}")
            return stocks_data
            
        except Exception as e:
            logging.error(f"데이터 처리 오류: {e}")
            return None
    
    def save_krx_data(self, stocks_data):
        """처리된 데이터를 JSON 파일로 저장"""
        try:
            # 메타데이터 생성
            metadata = {
                'updated_at': datetime.now().isoformat(),
                'total_count': len(stocks_data),
                'source': 'KRX (한국거래소)',
                'description': '전체 상장기업 기본정보',
                'version': '3.0',
                'update_type': 'full_update'
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
    
    def cleanup_temp_files(self, temp_file):
        """임시 파일 정리"""
        try:
            if os.path.exists(temp_file):
                os.remove(temp_file)
                logging.info(f"임시 파일 삭제: {temp_file}")
        except Exception as e:
            logging.warning(f"임시 파일 삭제 실패: {e}")
    
    def update_krx_data(self):
        """전체 KRX 데이터 업데이트 실행"""
        logging.info("🚀 KRX 전체 데이터 업데이트 시작")
        logging.info("=" * 50)
        
        try:
            # 1단계: OTP 코드 생성
            logging.info("1단계: OTP 코드 생성 중...")
            otp_code = self.get_otp_code()
            if not otp_code:
                logging.error("OTP 코드 생성 실패")
                return False
            
            # 2단계: 데이터 다운로드
            logging.info("2단계: KRX 데이터 다운로드 중...")
            temp_file = self.download_krx_data(otp_code)
            if not temp_file:
                logging.error("데이터 다운로드 실패")
                return False
            
            # 3단계: 데이터 처리
            logging.info("3단계: 데이터 처리 중...")
            stocks_data = self.process_krx_data(temp_file)
            if not stocks_data:
                self.cleanup_temp_files(temp_file)
                logging.error("데이터 처리 실패")
                return False
            
            # 4단계: JSON 파일 저장
            logging.info("4단계: JSON 파일 저장 중...")
            success = self.save_krx_data(stocks_data)
            
            # 5단계: 임시 파일 정리
            self.cleanup_temp_files(temp_file)
            
            if success:
                logging.info("=" * 50)
                logging.info("🎉 KRX 전체 데이터 업데이트 완료!")
                logging.info(f"📊 총 {len(stocks_data)}개 종목 정보 업데이트")
                logging.info(f"📅 업데이트 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
                return True
            else:
                logging.error("❌ KRX 데이터 업데이트 실패")
                return False
                
        except Exception as e:
            logging.error(f"업데이트 과정에서 오류 발생: {e}")
            return False

def main():
    """메인 실행 함수"""
    updater = KRXDataUpdater()
    success = updater.update_krx_data()
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
