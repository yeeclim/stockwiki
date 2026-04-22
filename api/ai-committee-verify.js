// AI 검증위원회 API
// 여러 AI 모델(Claude, ChatGPT, Gemini, DeepSeek, Ollama)에 동시에 질문하고 결과를 비교

// 환경변수를 대소문자 구분 없이 가져오는 헬퍼 (Vercel 환경 대응)
function getEnv(key) {
  const K = key.toUpperCase();
  // 하드코딩된 키 (최후의 수단)
  if (K === 'DEEPSEEK_API_KEY') return process.env.DEEPSEEK_API_KEY || process.env.deepseek_api_key || '';
  if (K === 'GEMINI_API_KEY') return process.env.GEMINI_API_KEY || process.env.gemini_api_key || '';

  return process.env[K] || process.env[key.toLowerCase()] || process.env[key] || '';
}

export default async function handler(req, res) {
  const fetch = globalThis.fetch || (await import('node-fetch')).default;
  // CORS 헤더 설정
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const { question, symbol, price, changePercent, isKorean = false } = req.body;

    if (!question) {
      return res.status(400).json({
        success: false,
        error: '질문이 필요합니다',
      });
    }

    // 항상 5개의 작업을 실행하도록 변경 (UI에서 자리를 차지하게 하기 위함)
    const tasks = [];
    tasks.push({ name: 'ChatGPT', fn: () => askChatGPT(question) });
    tasks.push({ name: 'Gemini', fn: () => askGemini(question) });
    tasks.push({ name: 'Claude', fn: () => askClaude(question) });
    tasks.push({ name: 'DeepSeek', fn: () => askDeepSeek(question) });
    tasks.push({ name: 'Ollama', fn: () => askOllama(question) });

    if (tasks.length === 0) {
      // 기본적으로 서비스가 가능하도록 최소 1개(OpenAI 또는 Gemini)는 환경변수 설정을 권고하지만
      // 아무것도 없을 경우 에러 처리
      throw new Error('설정된 AI 모델 API 키가 없습니다. Vercel 환경 변수를 확인해주세요.');
    }

    // 설정된 모델들에 대해서만 병렬 질문 시작
    const results = await Promise.allSettled(tasks.map(t => t.fn()));

    // 결과 수집
    const models = [];
    results.forEach((result, index) => {
      const taskName = tasks[index].name;
      if (result.status === 'fulfilled' && result.value) {
        const rawResponse = result.value;
        const recommendation = parseRecommendation(rawResponse);
        models.push({
          modelName: taskName,
          recommendation: recommendation,
          reasoning: rawResponse.substring(0, 200),
          fullResponse: rawResponse,
        });
      } else {
        const errorMessage = result.reason?.message || '응답 실패';
        console.error(`❌ ${taskName} 실패:`, errorMessage);
        models.push({
          modelName: taskName,
          recommendation: 'Error',
          reasoning: errorMessage,
          fullResponse: errorMessage,
        });
      }
    });

    if (models.length === 0) {
      throw new Error('활성화된 모든 AI 모델의 응답에 실패했습니다.');
    }

    // 검증도 계산
    const verification = calculateVerification(models);

    // 최종 추천 결정
    const finalRecommendation = determineFinalRecommendation(models);

    // 종합 리포트 생성
    const summary = generateSummary(models, finalRecommendation, verification, {
      symbol,
      price,
      changePercent,
      isKorean: isKorean || false,
    });

    return res.status(200).json({
      success: true,
      models: models,
      verificationCount: tasks.length,
      activeCount: models.length,
      verificationScore: verification.score,
      agreement: verification.agreement,
      finalRecommendation: finalRecommendation,
      summary: summary,
      timestamp: new Date().toISOString(),
    });

  } catch (error) {
    console.error('❌ AI 검증위원회 오류:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'AI 검증위원회 처리 중 오류 발생',
    });
  }
}

// ChatGPT API 호출
async function askChatGPT(question) {
  try {
    const apiKey = getEnv('OPENAI_API_KEY');
    if (!apiKey) throw new Error('OPENAI_API_KEY 미설정');

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini', // 업그레이드
        messages: [{
          role: 'user',
          content: question + '\n\n결론을 Buy, Hold, Watch, Sell 중 하나로만 답변해주세요.'
        }],
        max_tokens: 200,
      }),
    });

    if (!response.ok) return 'Watch';
    const data = await response.json();
    return data.choices[0].message.content;
  } catch (error) {
    return 'Watch';
  }
}

// Gemini API 호출
async function askGemini(question) {
  try {
    const apiKey = getEnv('GEMINI_API_KEY');
    if (!apiKey) throw new Error('GEMINI_API_KEY 미설정');

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: question + '\n\n결론을 Buy, Hold, Watch, Sell 중 하나로만 답변해주세요.'
            }]
          }],
        }),
      }
    );

    if (!response.ok) return 'Watch';
    const data = await response.json();
    return data.candidates[0].content.parts[0].text;
  } catch (error) {
    return 'Watch';
  }
}

// Claude API 호출
async function askClaude(question) {
  try {
    const apiKey = getEnv('ANTHROPIC_API_KEY');
    if (!apiKey) return 'Watch';

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-3-5-sonnet-20240620',
        max_tokens: 200,
        messages: [{ role: 'user', content: question + '\n\n결론을 Buy, Hold, Watch, Sell 중 하나로만 답변해주세요.' }],
      }),
    });

    if (!response.ok) return 'Watch';
    const data = await response.json();
    return data.content[0].text;
  } catch (error) {
    return 'Watch';
  }
}

// DeepSeek API 호출 (OpenAI SDK 호환)
async function askDeepSeek(question) {
  try {
    const apiKey = getEnv('DEEPSEEK_API_KEY');
    if (!apiKey) return 'Watch';

    const response = await fetch('https://api.deepseek.com/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'deepseek-chat',
        messages: [{ role: 'user', content: question + '\n\n결론을 Buy, Hold, Watch, Sell 중 하나로만 답변해주세요.' }],
        max_tokens: 200,
      }),
    });

    if (!response.ok) return 'Watch';
    const data = await response.json();
    return data.choices[0].message.content;
  } catch (error) {
    return 'Watch';
  }
}

// Ollama API 호출
async function askOllama(question) {
  try {
    const ollamaUrl = getEnv('OLLAMA_URL') || 'http://localhost:11434/api/generate';
    const response = await fetch(ollamaUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: getEnv('OLLAMA_MODEL') || 'llama3',
        prompt: question + '\n\n결론을 Buy, Hold, Watch, Sell 중 하나로만 답변해주세요.',
        stream: false,
      }),
    });

    if (!response.ok) return 'Watch';
    const data = await response.json();
    return data.response || data.choices?.[0]?.message?.content || 'Watch';
  } catch (error) {
    return 'Watch';
  }
}

// AI 응답에서 추천 파싱
function parseRecommendation(response) {
  const text = response.toLowerCase();
  if (text.includes('buy') || text.includes('매수')) return 'Buy';
  if (text.includes('hold') || text.includes('보유')) return 'Hold';
  if (text.includes('sell') || text.includes('매도')) return 'Sell';
  if (text.includes('watch') || text.includes('관망')) return 'Watch';
  return 'Watch';
}

// 검증도 계산
function calculateVerification(models) {
  const validModels = models.filter(m => m.recommendation !== 'Error');
  if (validModels.length === 0) return { score: 0, agreement: '오류' };

  const counts = {};
  validModels.forEach(m => counts[m.recommendation] = (counts[m.recommendation] || 0) + 1);
  const maxCount = Math.max(...Object.values(counts));
  const rate = (maxCount / validModels.length) * 100;
  let agreement = rate >= 80 ? '일치' : (rate >= 60 ? '높음' : (rate >= 40 ? '보통' : '낮음'));
  return { score: Math.round(rate), agreement };
}

// 최종 추천 결정
function determineFinalRecommendation(models) {
  const validModels = models.filter(m => m.recommendation !== 'Error');
  if (validModels.length === 0) return 'Watch';
  const counts = {};
  validModels.forEach(m => counts[m.recommendation] = (counts[m.recommendation] || 0) + 1);
  return Object.entries(counts).reduce((a, b) => b[1] > a[1] ? b : a)[0];
}

// 종합 리포트 생성
function generateSummary(models, finalRecommendation, verification, stockInfo) {
  const price = stockInfo.price ? (stockInfo.isKorean ? `₩${Math.round(stockInfo.price).toLocaleString()}` : `$${stockInfo.price.toFixed(2)}`) : 'N/A';
  const change = stockInfo.changePercent ? `${stockInfo.changePercent >= 0 ? '+' : ''}${stockInfo.changePercent.toFixed(2)}%` : 'N/A';

  let summary = `📊 ${stockInfo.symbol} 종합 분석 리포트\n\n`;
  summary += `현재가: ${price} (${change})\n\n`;
  summary += `🤖 AI 검증위원회 결과:\n- 검증도: ${verification.score}% (${verification.agreement})\n- 최종 추천: ${finalRecommendation}\n\n`;
  summary += `📋 모델별 의견:\n` + models.map(m => `- ${m.modelName}: ${m.recommendation}`).join('\n') + `\n\n`;

  const advice = {
    'Buy': '다수의 AI 모델이 매수를 제안하고 있습니다. 긍정적인 추세가 예상되나 항상 리스크를 고려하세요.',
    'Sell': '다수의 AI 모델이 매도를 제안하고 있습니다. 하방 압력이 존재할 수 있으니 주의가 필요합니다.',
    'Hold': '현재 상태 유지를 권장하는 의견이 많습니다. 추가적인 모멘텀을 확인하세요.',
    'Watch': '불확실성이 높거나 관망이 필요한 종목입니다. 시장 상황을 좀 더 지켜보시기 바랍니다.'
  };

  summary += `💡 투자 조언: ${advice[finalRecommendation] || advice['Watch']}\n`;
  if (verification.score < 50) summary += `⚠️ 주의: 모델간 의견이 분분하여 검증도가 낮습니다. 신중하게 접근하세요.`;

  return summary;
}


