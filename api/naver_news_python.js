// 📄 /api/naver_news_python.js
// 네이버 뉴스 RSS 크롤링

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

    console.log('네이버 RSS 뉴스 검색:', keyword);

    // 네이버 뉴스 RSS 크롤링 실행
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
  text = text.replace(/<[^>]*>/g, '');
  
  // HTML 엔티티 디코딩
  text = text.replace(/&lt;/g, '<')
             .replace(/&gt;/g, '>')
             .replace(/&amp;/g, '&')
             .replace(/&quot;/g, '"')
             .replace(/&#39;/g, "'")
             .replace(/&nbsp;/g, ' ');

  // 공백 정리
  text = text.replace(/\s+/g, ' ').trim();
  return text;
}

// 네이버 뉴스 RSS 검색 함수
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
    
    // RSS XML 파싱
    const newsList = [];
    
    // <item> 태그들 찾기
    const itemPattern = /<item[^>]*>(.*?)<\/item>/gs;
    const items = xmlText.match(itemPattern) || [];
    
    console.log(`RSS 아이템 개수: ${items.length}`);

    for (let i = 0; i < Math.min(items.length, maxResults); i++) {
      try {
        const itemXml = items[i];
        
        // 제목 추출 (CDATA 처리)
        const titleMatch = itemXml.match(/<title[^>]*><!\[CDATA\[(.*?)\]\]><\/title>/) || 
                          itemXml.match(/<title[^>]*>(.*?)<\/title>/);
        const title = titleMatch ? cleanText(titleMatch[1]) : '';
        
        // 링크 추출
        const linkMatch = itemXml.match(/<link[^>]*><!\[CDATA\[(.*?)\]\]><\/link>/) || 
                         itemXml.match(/<link[^>]*>(.*?)<\/link>/);
        const link = linkMatch ? linkMatch[1] : '';
        
        // 설명 추출
        const descMatch = itemXml.match(/<description[^>]*><!\[CDATA\[(.*?)\]\]><\/description>/) || 
                         itemXml.match(/<description[^>]*>(.*?)<\/description>/);
        const description = descMatch ? cleanText(descMatch[1]) : '';
        
        // 발행일 추출
        const pubDateMatch = itemXml.match(/<pubDate[^>]*>(.*?)<\/pubDate>/);
        const pubDate = pubDateMatch ? pubDateMatch[1] : '';
        
        // 언론사 추출 (제목에서 [언론사] 패턴)
        const sourceMatch = title.match(/\[(.*?)\]/);
        const source = sourceMatch ? sourceMatch[1] : '네이버뉴스';
        
        if (title && link) {
          newsList.push({
            title: title,
            description: description,
            link: link,
            source: source,
            published_at: pubDate,
            crawled_at: new Date().toISOString()
          });
        }
        
      } catch (itemError) {
        console.error('RSS 아이템 파싱 오류:', itemError);
        continue;
      }
    }

    console.log(`네이버 RSS 뉴스 크롤링 완료: ${newsList.length}개 결과`);
    return newsList;
    
  } catch (error) {
    console.error('네이버 뉴스 크롤링 오류:', error);
    return [];
  }
}