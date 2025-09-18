// 📄 /api/naver_news.js
import { spawn } from 'child_process';
import path from 'path';

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

    // Python 스크립트 실행
    const pythonScript = path.join(process.cwd(), 'scripts', 'naver_news_crawler.py');
    
    const pythonProcess = spawn('python3', [
      pythonScript,
      keyword.trim(),
      max_results.toString()
    ], {
      cwd: process.cwd(),
      stdio: ['pipe', 'pipe', 'pipe']
    });

    let stdout = '';
    let stderr = '';

    pythonProcess.stdout.on('data', (data) => {
      stdout += data.toString();
    });

    pythonProcess.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    // 프로세스 완료 대기
    const exitCode = await new Promise((resolve) => {
      pythonProcess.on('close', resolve);
    });

    if (exitCode === 0) {
      try {
        const result = JSON.parse(stdout);
        res.status(200).json(result);
      } catch (parseError) {
        console.error('JSON 파싱 오류:', parseError);
        console.error('Python 출력:', stdout);
        res.status(500).json({
          success: false,
          error: 'Python 스크립트 출력 파싱 오류',
          details: parseError.message
        });
      }
    } else {
      console.error('Python 스크립트 실행 오류:', stderr);
      res.status(500).json({
        success: false,
        error: 'Python 스크립트 실행 실패',
        details: stderr,
        exitCode: exitCode
      });
    }

  } catch (error) {
    console.error('API 오류:', error);
    res.status(500).json({
      success: false,
      error: '서버 오류',
      details: error.message
    });
  }
}

