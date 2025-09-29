// 📄 /api/naver_news_python.js
// Python 스크립트의 로직을 JavaScript로 포팅

export default async function handler(req, res) {
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // OPTIONS 요청 처리
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  // POST 요청만 허용
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { keyword, max_results = 20 } = req.body;

    if (!keyword || keyword.trim() === '') {
      res.status(400).json({ 
        success: false,
        error: '키워드가 필요합니다' 
      });
      return;
    }

    // 네이버 뉴스 크롤링 실행
    const newsList = await searchNaverNews(keyword.trim(), max_results);
    
    const result = {
      success: true,
      keyword: keyword.trim(),
      count: newsList.length,
      results: newsList,
      crawled_at: new Date().toISOString()
    };

    res.status(200).json(result);

  } catch (error) {
    console.error('네이버 뉴스 크롤링 오류:', error);
    res.status(500).json({
      success: false,
      error: '크롤링 오류',
      details: error.message
    });
  }
}

// 텍스트 정리 함수
function cleanText(text) {
  if (!text) return "";
  // HTML 태그 제거
  text = text.replace(/<[^>]+>/g, '');
  // 공백 정리
  text = text.replace(/\s+/g, ' ').trim();
  return text;
}

// 네이버 뉴스 검색 함수 (RSS 피드 방식)
async function searchNaverNews(keyword, maxResults = 20) {
  try {
    // URL 인코딩
    const encodedKeyword = encodeURIComponent(keyword);
    
    // 네이버 뉴스 RSS URL 사용 (봇 차단 우회)
    const rssUrl = `https://news.naver.com/main/rss/section.naver?sid=101&query=${encodedKeyword}`;
    
    console.log('네이버 RSS URL:', rssUrl);
    
    // 헤더 설정
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'application/rss+xml, application/xml, text/xml, */*',
    };
    
    // RSS 요청 보내기
    const response = await fetch(rssUrl, { 
      headers,
      timeout: 10000 
    });
    
    if (!response.ok) {
      console.log(`RSS 요청 실패: ${response.status}`);
      return [];
    }
    
    const xmlText = await response.text();
    console.log('RSS 응답 길이:', xmlText.length);
    
    // 개선된 HTML 파싱
    const newsList = [];
    
    // 다양한 뉴스 아이템 패턴 시도
    const patterns = [
      /<div class="news_area"[^>]*>(.*?)<\/div>/gs,
      /<div class="news_info"[^>]*>(.*?)<\/div>/gs,
      /<div class="news_tit"[^>]*>(.*?)<\/div>/gs,
      /<a[^>]*class="news_tit"[^>]*>(.*?)<\/a>/gs
    ];
    
    let matches = [];
    for (const pattern of patterns) {
      matches = html.match(pattern) || [];
      if (matches.length > 0) {
        console.log(`패턴 매칭 성공: ${matches.length}개 아이템`);
        break;
      }
    }
    
    if (matches.length === 0) {
      console.log('뉴스 아이템을 찾을 수 없습니다. HTML 구조 확인 필요');
      return [];
    }
    
    for (let i = 0; i < Math.min(matches.length, maxResults); i++) {
      try {
        const itemHtml = matches[i];
        
        // 제목과 링크 추출 (더 유연한 패턴)
        const titlePatterns = [
          /<a[^>]*class="news_tit"[^>]*href="([^"]*)"[^>]*>([^<]*)<\/a>/,
          /<a[^>]*href="([^"]*)"[^>]*class="news_tit"[^>]*>([^<]*)<\/a>/,
          /<a[^>]*href="([^"]*)"[^>]*>([^<]*)<\/a>/
        ];
        
        let title = '';
        let link = '';
        
        for (const pattern of titlePatterns) {
          const match = itemHtml.match(pattern);
          if (match) {
            link = match[1];
            title = cleanText(match[2]);
            break;
          }
        }
        
        // 요약 추출
        const summaryPatterns = [
          /<div[^>]*class="news_dsc"[^>]*>([^<]*)<\/div>/,
          /<div[^>]*class="dsc_wrap"[^>]*>([^<]*)<\/div>/,
          /<p[^>]*>([^<]*)<\/p>/
        ];
        
        let summary = '';
        for (const pattern of summaryPatterns) {
          const match = itemHtml.match(pattern);
          if (match) {
            summary = cleanText(match[1]);
            break;
          }
        }
        
        // 언론사 추출
        const pressPatterns = [
          /<span[^>]*class="info_group"[^>]*>([^<]*)<\/span>/,
          /<span[^>]*class="press"[^>]*>([^<]*)<\/span>/,
          /<em[^>]*>([^<]*)<\/em>/
        ];
        
        let press = '';
        for (const pattern of pressPatterns) {
          const match = itemHtml.match(pattern);
          if (match) {
            press = cleanText(match[1]);
            break;
          }
        }
        
        // 날짜 추출
        const datePatterns = [
          /<span[^>]*class="info"[^>]*>([^<]*)<\/span>/,
          /<span[^>]*class="date"[^>]*>([^<]*)<\/span>/,
          /<time[^>]*>([^<]*)<\/time>/
        ];
        
        let date = '';
        for (const pattern of datePatterns) {
          const match = itemHtml.match(pattern);
          if (match) {
            date = cleanText(match[1]);
            break;
          }
        }
        
        if (title && link) {
          newsList.push({
            title: title,
            description: summary,
            link: link,
            source: press || '네이버뉴스',
            date: date,
            crawled_at: new Date().toISOString()
          });
        }
        
      } catch (itemError) {
        console.error('뉴스 아이템 파싱 오류:', itemError);
        continue;
      }
    }
    
    console.log(`네이버 뉴스 크롤링 완료: ${newsList.length}개 결과`);
    return newsList;
    
  } catch (error) {
    console.error('네이버 뉴스 크롤링 오류:', error);
    return [];
  }
}
