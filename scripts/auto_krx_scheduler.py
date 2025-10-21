#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
KRX 데이터 자동 업데이트 스케줄러 (간단 버전)
매일 밤 12시에 KRX 데이터를 자동으로 업데이트
"""

import schedule
import time
import logging
import os
import sys
from datetime import datetime
from krx_public_api_updater import KRXPublicAPIUpdater

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('krx_auto_scheduler.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)

class KRXAutoScheduler:
    def __init__(self):
        self.updater = KRXPublicAPIUpdater()
        self.is_running = False
        
    def scheduled_update(self):
        """스케줄된 업데이트 실행"""
        try:
            logging.info("스케줄된 KRX 데이터 업데이트 시작")
            logging.info(f"실행 시간: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            
            success = self.updater.run_update()
            
            if success:
                logging.info("스케줄된 업데이트 완료")
            else:
                logging.error("스케줄된 업데이트 실패")
                
            return success
            
        except Exception as e:
            logging.error(f"스케줄된 업데이트 중 오류: {e}")
            return False
    
    def start_scheduler(self):
        """스케줄러 시작"""
        try:
            logging.info("KRX 데이터 자동 업데이트 스케줄러 시작")
            logging.info("스케줄: 매일 밤 12시 (00:00)")
            
            # 매일 밤 12시에 실행
            schedule.every().day.at("00:00").do(self.scheduled_update)
            
            # 시작 시 한 번 실행 (테스트용)
            logging.info("시작 시 테스트 실행...")
            self.scheduled_update()
            
            # 스케줄러 루프
            self.is_running = True
            while self.is_running:
                schedule.run_pending()
                time.sleep(60)  # 1분마다 체크
                
        except KeyboardInterrupt:
            logging.info("스케줄러 중지 요청")
            self.stop_scheduler()
        except Exception as e:
            logging.error(f"스케줄러 오류: {e}")
            self.stop_scheduler()
    
    def stop_scheduler(self):
        """스케줄러 중지"""
        self.is_running = False
        logging.info("KRX 데이터 스케줄러 중지")
    
    def run_once(self):
        """한 번만 실행 (테스트용)"""
        logging.info("KRX 데이터 업데이트 (한 번만 실행)")
        return self.scheduled_update()

def main():
    """메인 실행 함수"""
    import argparse
    
    parser = argparse.ArgumentParser(description='KRX 데이터 자동 업데이트 스케줄러')
    parser.add_argument('--once', action='store_true', help='한 번만 실행 (테스트용)')
    parser.add_argument('--daemon', action='store_true', help='백그라운드 데몬으로 실행')
    
    args = parser.parse_args()
    
    scheduler = KRXAutoScheduler()
    
    if args.once:
        # 한 번만 실행
        success = scheduler.run_once()
        sys.exit(0 if success else 1)
    elif args.daemon:
        # 백그라운드 데몬으로 실행
        logging.info("백그라운드 데몬 모드로 실행")
        scheduler.start_scheduler()
    else:
        # 기본 스케줄러 실행
        scheduler.start_scheduler()

if __name__ == "__main__":
    main()
