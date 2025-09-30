#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
네이버 뉴스 크롤링 스크립트
Flutter 앱에서 호출하여 네이버 뉴스 검색 결과를 JSON으로 반환
"""

import requests
from bs4 import BeautifulSoup
import json
import sys
import urllib.parse
from datetime import datetime
import re

def clean_text(text):
    """텍스트 정리 함수"""
    if not text:
        return ""
    # HTML 태그 제거
    text = re.sub(r'<[^>]+>', '', text)
    # 공백 정리
    text = re.sub(r'\s+', ' ', text).strip()
    return text

def search_naver_news(keyword, max_results=20):
    """
    네이버 뉴스 검색
    
    Args:
        keyword (str): 검색 키워드
        max_results (int): 최대 결과 수
    
    Returns:
        list: 뉴스 리스트
    """
    try:
        # URL 인코딩
        encoded_keyword = urllib.parse.quote(keyword)
        
        # 네이버 뉴스 검색 URL
        url = f"https://search.naver.com/search.naver?where=news&query={encoded_keyword}&sort=1"
        
        # 헤더 설정 (봇 차단 방지)
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'ko-KR,ko;q=0.8,en-US;q=0.5,en;q=0.3',
            'Accept-Encoding': 'gzip, deflate',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
        }
        
        # 요청 보내기
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        # HTML 파싱
        soup = BeautifulSoup(response.content, 'html.parser')
        
        news_list = []
        
        # 뉴스 아이템 찾기 - 새로운 네이버 구조에 맞게 수정
        news_items = []
        
        # 1. 기존 방식 시도
        news_items.extend(soup.find_all('div', class_='news_area'))
        
        # 2. 새로운 구조에서 뉴스 링크 직접 찾기
        all_links = soup.find_all('a', href=True)
        news_links = []
        
        for link in all_links:
            href = link.get('href', '')
            text = link.get_text().strip()
            
            # 뉴스 사이트 도메인 확인
            news_domains = [
                'news.naver.com', 'news.daum.net', 'news.khan.co.kr', 
                'news.mk.co.kr', 'news.jtbc.co.kr', 'news.sbs.co.kr',
                'news.kbs.co.kr', 'news.mbc.co.kr', 'news.hankyung.com',
                'news.chosun.com', 'news.joins.com', 'news.donga.com',
                'news.hankookilbo.com', 'news.heraldcorp.com', 'news.seoul.co.kr'
            ]
            
            if any(domain in href for domain in news_domains) and len(text) > 10:
                news_links.append({
                    'title': text,
                    'link': href,
                    'domain': next((domain for domain in news_domains if domain in href), 'unknown')
                })
        
        # 기존 방식으로 뉴스 파싱
        for item in news_items[:max_results]:
            try:
                # 제목 추출
                title_elem = item.find('a', class_='news_tit')
                title = clean_text(title_elem.get_text()) if title_elem else ""
                link = title_elem.get('href') if title_elem else ""
                
                # 요약 추출
                summary_elem = item.find('div', class_='news_dsc')
                summary = clean_text(summary_elem.get_text()) if summary_elem else ""
                
                # 언론사 추출
                press_elem = item.find('span', class_='info_group')
                press = clean_text(press_elem.get_text()) if press_elem else ""
                
                # 날짜 추출
                date_elem = item.find('span', class_='info')
                date = clean_text(date_elem.get_text()) if date_elem else ""
                
                if title and link:
                    news_item = {
                        'title': title,
                        'description': summary,
                        'link': link,
                        'source': press,
                        'date': date,
                        'crawled_at': datetime.now().isoformat()
                    }
                    news_list.append(news_item)
                    
            except Exception as e:
                print(f"뉴스 아이템 파싱 오류: {e}", file=sys.stderr)
                continue
        
        # 기존 방식이 실패하면 직접 찾은 뉴스 링크 사용
        if not news_list and news_links:
            for i, news_link in enumerate(news_links[:max_results]):
                try:
                    news_item = {
                        'title': news_link['title'],
                        'description': '',
                        'link': news_link['link'],
                        'source': news_link['domain'],
                        'date': '',
                        'crawled_at': datetime.now().isoformat()
                    }
                    news_list.append(news_item)
                except Exception as e:
                    print(f"뉴스 링크 파싱 오류: {e}", file=sys.stderr)
                    continue
        
        return news_list
        
    except requests.RequestException as e:
        print(f"네트워크 오류: {e}", file=sys.stderr)
        return []
    except Exception as e:
        print(f"크롤링 오류: {e}", file=sys.stderr)
        return []

def main():
    """메인 함수"""
    if len(sys.argv) < 2:
        print(json.dumps({
            'error': '키워드가 필요합니다',
            'usage': 'python naver_news_crawler.py "검색키워드"'
        }))
        sys.exit(1)
    
    keyword = sys.argv[1]
    max_results = int(sys.argv[2]) if len(sys.argv) > 2 else 20
    
    try:
        news_list = search_naver_news(keyword, max_results)
        
        result = {
            'success': True,
            'keyword': keyword,
            'count': len(news_list),
            'results': news_list,
            'crawled_at': datetime.now().isoformat()
        }
        
        print(json.dumps(result, ensure_ascii=False, indent=2))
        
    except Exception as e:
        error_result = {
            'success': False,
            'error': str(e),
            'keyword': keyword
        }
        print(json.dumps(error_result, ensure_ascii=False, indent=2))
        sys.exit(1)

if __name__ == "__main__":
    main()


