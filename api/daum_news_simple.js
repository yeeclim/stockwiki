// 다음 뉴스 검색 API
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
    const { keyword, max_results = 10 } = req.body;

    if (!keyword || keyword.trim() === '') {
      res.status(400).json({ 
        success: false,
        error: '키워드가 필요합니다' 
      });
      return;
    }

    console.log('다음 뉴스 검색:', keyword);

    // 다음 뉴스 검색 URL
    const encodedKeyword = encodeURIComponent(keyword.trim());
    const searchUrl = `https://search.daum.net/search?w=news&q=${encodedKeyword}&sort=recency`;
    
    console.log('다음 뉴스 URL:', searchUrl);

    // 다음 뉴스 요청
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'ko-KR,ko;q=0.8,en-US;q=0.5,en;q=0.3',
      },
      timeout: 10000
    });

    if (!response.ok) {
      console.log(`다음 뉴스 요청 실패: ${response.status}`);
      return res.status(200).json({
        success: true,
        keyword: keyword.trim(),
        count: 0,
        results: [],
        error: '다음 뉴스 요청 실패'
      });
    }

    const htmlText = await response.text();
    console.log('다음 뉴스 응답 길이:', htmlText.length);

    // HTML 파싱
    const newsList = [];
    
    // 다음 뉴스 아이템 패턴
    const itemPattern = /<div[^>]*class="item-title"[^>]*>(.*?)<\/div>/gs;
    const items = htmlText.match(itemPattern) || [];
    
    console.log(`다음 뉴스 아이템 개수: ${items.length}`);

    for (let i = 0; i < Math.min(items.length, max_results); i++) {
      try {
        const itemHtml = items[i];
        
        // 제목과 링크 추출
        const linkMatch = itemHtml.match(/<a[^>]*href="([^"]*)"[^>]*>([^<]*)<\/a>/);
        if (linkMatch) {
          const link = linkMatch[1];
          const title = cleanText(linkMatch[2]);
          
          if (title && link) {
            newsList.push({
              title: title,
              description: '',
              link: link,
              source: '다음뉴스',
              published_at: new Date().toISOString(),
              crawled_at: new Date().toISOString()
            });
          }
        }
        
      } catch (itemError) {
        console.error('다음 뉴스 아이템 파싱 오류:', itemError);
        continue;
      }
    }

    console.log(`다음 뉴스 크롤링 완료: ${newsList.length}개 결과`);

    const result = {
      success: true,
      keyword: keyword.trim(),
      count: newsList.length,
      results: newsList,
      crawled_at: new Date().toISOString()
    };

    res.status(200).json(result);

  } catch (error) {
    console.error('다음 뉴스 크롤링 오류:', error);
    res.status(500).json({
      success: false,
      error: '다음 뉴스 크롤링 오류',
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
