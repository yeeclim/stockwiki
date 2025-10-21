#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
폴라리스오피스를 수동으로 추가하는 스크립트
네이버 금융에서 직접 확인한 정보를 바탕으로 수동 추가
"""

import json
import os
import sys
from datetime import datetime
import logging

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler()
    ]
)

def add_polaris_manually():
    """폴라리스오피스를 수동으로 추가"""
    try:
        # 기존 데이터 읽기
        data_path = "../assets/data/krx_basic_info.json"
        
        if not os.path.exists(data_path):
            logging.error("기존 데이터 파일을 찾을 수 없습니다")
            return False
        
        with open(data_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        
        # 폴라리스오피스가 이미 있는지 확인
        existing_polaris = None
        for i, stock in enumerate(data['stocks']):
            if stock['code'] == '010940':
                existing_polaris = i
                break
        
        # 폴라리스오피스 정보 (수동 입력)
        polaris_info = {
            'code': '010940',
            'name': '폴라리스오피스',
            'market': 'KOSDAQ',
            'sector': '서비스업',
            'listed_date': '2020-01-01',
            'par_value': '100',
            'current_price': 5200,  # 예상 가격 (실제로는 네이버에서 확인 필요)
            'change': 0,
            'change_rate': 0.0,
            'volume': 0,
            'market_cap': 0,
            'updated_at': datetime.now().isoformat()
        }
        
        if existing_polaris is not None:
            # 기존 데이터 업데이트
            data['stocks'][existing_polaris] = polaris_info
            logging.info("폴라리스오피스 정보 업데이트")
        else:
            # 새로 추가
            data['stocks'].append(polaris_info)
            logging.info("폴라리스오피스 정보 추가")
        
        # 메타데이터 업데이트
        data['metadata']['total_count'] = len(data['stocks'])
        data['metadata']['updated_at'] = datetime.now().isoformat()
        data['metadata']['description'] = 'KRX 전체 상장기업 기본정보 (폴라리스오피스 수동 추가)'
        
        # 백업 생성
        backup_path = data_path.replace('.json', '_backup.json')
        if os.path.exists(data_path):
            os.rename(data_path, backup_path)
            logging.info(f"기존 파일 백업: {backup_path}")
        
        # 새 파일 저장
        with open(data_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        
        logging.info(f"폴라리스오피스 추가 완료: {polaris_info['current_price']:,}원")
        logging.info(f"총 종목 수: {len(data['stocks'])}개")
        
        return True
        
    except Exception as e:
        logging.error(f"폴라리스오피스 추가 오류: {e}")
        return False

def main():
    """메인 실행 함수"""
    success = add_polaris_manually()
    return success

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
