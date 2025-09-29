// 구글 뉴스 검색 API
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

  try {
    const { keyword, max_results = 10 } = req.method === 'POST' ? req.body : req.query;

    if (!keyword || keyword.trim() === '') {
      res.status(400).json({ 
        success: false,
        error: '키워드가 필요합니다' 
      });
      return;
    }

    // 구글 뉴스 검색 실행
    const newsList = await searchGoogleNews(keyword.trim(), max_results);
    
    const result = {
      success: true,
      keyword: keyword.trim(),
      count: newsList.length,
      results: newsList,
      crawled_at: new Date().toISOString()
    };

    res.status(200).json(result);

  } catch (error) {
    console.error('구글 뉴스 검색 오류:', error);
    res.status(500).json({
      success: false,
      error: '검색 오류',
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

// 구글 뉴스 검색 함수
async function searchGoogleNews(keyword, maxResults = 10) {
  try {
    // URL 인코딩
    const encodedKeyword = encodeURIComponent(keyword);
    
    // 구글 뉴스 검색 URL
    const url = `https://news.google.com/search?q=${encodedKeyword}&hl=ko&gl=KR&ceid=KR:ko`;
    
    // 헤더 설정 (봇 차단 방지)
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'ko-KR,ko;q=0.8,en-US;q=0.5,en;q=0.3',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Cache-Control': 'no-cache',
    };
    
    // 요청 보내기
    const response = await fetch(url, { 
      headers,
      timeout: 15000 
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const html = await response.text();
    
    // HTML 파싱
    const newsList = [];
    
    // 구글 뉴스 아이템 패턴들
    const patterns = [
      /<h3[^>]*class="[^"]*"[^>]*>(.*?)<\/h3>/gs,
      /<h4[^>]*class="[^"]*"[^>]*>(.*?)<\/h4>/gs,
      /<div[^>]*class="[^"]*"[^>]*>(.*?)<\/div>/gs
    ];
    
    let matches = [];
    for (const pattern of patterns) {
      matches = html.match(pattern) || [];
      if (matches.length > 0) {
        console.log(`구글 뉴스 패턴 매칭 성공: ${matches.length}개 아이템`);
        break;
      }
    }
    
    if (matches.length === 0) {
      console.log('구글 뉴스 아이템을 찾을 수 없습니다.');
      return [];
    }
    
    for (let i = 0; i < Math.min(matches.length, maxResults); i++) {
      const match = matches[i];
      
      // 제목 추출
      const titleMatch = match.match(/>(.*?)</);
      if (!titleMatch) continue;
      
      const title = cleanText(titleMatch[1]);
      if (title.length < 5) continue;
      
      // 링크 추출
      const linkMatch = match.match(/href="([^"]+)"/);
      const link = linkMatch ? linkMatch[1] : '';
      
      // 설명은 간단히 생성
      const description = `${keyword} 관련 뉴스입니다.`;
      
      newsList.push({
        title: title,
        description: description,
        link: link,
        published_at: new Date().toISOString()
      });
    }
    
    console.log(`구글 뉴스 검색 완료: ${newsList.length}개`);
    return newsList;
    
  } catch (error) {
    console.error('구글 뉴스 검색 오류:', error);
    return [];
  }
}
