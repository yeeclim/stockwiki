// AI 검증위원회 API
// 여러 AI 모델(Claude, ChatGPT, Gemini, DeepSeek)에 동시에 질문하고 결과를 비교

export default async function handler(req, res) {
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

    console.log('🎯 AI 검증위원회 질문:', question);

    // 3개 AI 모델에 동시에 질문 (GPT, Gemini, Ollama)
    const [chatgptResult, geminiResult, ollamaResult] = 
      await Promise.allSettled([
        askChatGPT(question),
        askGemini(question),
        askOllama(question),
      ]);

    // 결과 수집
    const models = [];
    
    if (chatgptResult.status === 'fulfilled') {
      const rawResponse = chatgptResult.value;
      const recommendation = parseRecommendation(rawResponse);
      console.log('🤖 ChatGPT 원본 응답:', rawResponse);
      console.log('📊 ChatGPT 파싱 결과:', recommendation);
      models.push({
        modelName: 'ChatGPT',
        recommendation: recommendation,
        reasoning: rawResponse.substring(0, 200),
        fullResponse: rawResponse,
      });
    } else {
      console.error('❌ ChatGPT 실패:', chatgptResult.reason);
    }
    
    if (geminiResult.status === 'fulfilled') {
      const rawResponse = geminiResult.value;
      const recommendation = parseRecommendation(rawResponse);
      console.log('🤖 Gemini 원본 응답:', rawResponse);
      console.log('📊 Gemini 파싱 결과:', recommendation);
      models.push({
        modelName: 'Gemini',
        recommendation: recommendation,
        reasoning: rawResponse.substring(0, 200),
        fullResponse: rawResponse,
      });
    } else {
      console.error('❌ Gemini 실패:', geminiResult.reason);
    }
    
    if (ollamaResult.status === 'fulfilled') {
      const rawResponse = ollamaResult.value;
      const recommendation = parseRecommendation(rawResponse);
      console.log('🤖 Ollama 원본 응답:', rawResponse);
      console.log('📊 Ollama 파싱 결과:', recommendation);
      models.push({
        modelName: 'Ollama',
        recommendation: recommendation,
        reasoning: rawResponse.substring(0, 200),
        fullResponse: rawResponse,
      });
    } else {
      console.error('❌ Ollama 실패:', ollamaResult.reason);
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

    console.log('✅ AI 검증위원회 결과:', {
      models: models.length,
      verificationScore: verification.score,
      agreement: verification.agreement,
      finalRecommendation,
    });

    return res.status(200).json({
      success: true,
      models: models,
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
    // 환경변수에서 API 키 가져오기
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      console.error('OPENAI_API_KEY 환경변수가 설정되지 않았습니다.');
      throw new Error('OPENAI_API_KEY가 설정되지 않았습니다.');
    }
    
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-3.5-turbo',
        messages: [{
          role: 'user',
          content: question + '\n\n위 주식에 대한 투자 의견을 다음 중 하나로만 답변해주세요:\n- Buy: 매수 추천 (투자 가치가 높고 상승 가능성이 큼)\n- Hold: 보유 추천 (현재 보유 중이면 유지)\n- Watch: 관망 추천 (추가 정보 확인 필요, 신중한 접근)\n- Sell: 매도 추천 (하락 위험이 높거나 투자 가치가 낮음)\n\n반드시 한 단어로만 답변하세요 (Buy, Hold, Watch, 또는 Sell).'
        }],
        max_tokens: 200,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('OpenAI API error:', response.status, errorText);
      throw new Error(`OpenAI API error: ${response.status}`);
    }

    const data = await response.json();
    return data.choices[0].message.content;
  } catch (error) {
    console.error('ChatGPT 오류:', error);
    return 'Watch'; // 기본값
  }
}

// Gemini API 호출
async function askGemini(question) {
  try {
    // 환경변수에서 API 키 가져오기
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.error('GEMINI_API_KEY 환경변수가 설정되지 않았습니다.');
      throw new Error('GEMINI_API_KEY가 설정되지 않았습니다.');
    }

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${apiKey}`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: question + '\n\n위 주식에 대한 투자 의견을 다음 중 하나로만 답변해주세요:\n- Buy: 매수 추천 (투자 가치가 높고 상승 가능성이 큼)\n- Hold: 보유 추천 (현재 보유 중이면 유지)\n- Watch: 관망 추천 (추가 정보 확인 필요, 신중한 접근)\n- Sell: 매도 추천 (하락 위험이 높거나 투자 가치가 낮음)\n\n반드시 한 단어로만 답변하세요 (Buy, Hold, Watch, 또는 Sell).'
            }]
          }],
        }),
      }
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Gemini API error:', response.status, errorText);
      throw new Error(`Gemini API error: ${response.status}`);
    }

    const data = await response.json();
    return data.candidates[0].content.parts[0].text;
  } catch (error) {
    console.error('Gemini 오류:', error);
    return 'Watch'; // 기본값
  }
}

// Ollama 프롬프트 생성 헬퍼
function buildOllamaPrompt(question) {
  return question + '\n\n위 주식에 대한 투자 의견을 다음 중 하나로만 답변해주세요:\n- Buy: 매수 추천 (투자 가치가 높고 상승 가능성이 큼)\n- Hold: 보유 추천 (현재 보유 중이면 유지)\n- Watch: 관망 추천 (추가 정보 확인 필요, 신중한 접근)\n- Sell: 매도 추천 (하락 위험이 높거나 투자 가치가 낮음)\n\n반드시 한 단어로만 답변하세요 (Buy, Hold, Watch, 또는 Sell).';
}

// Ollama 로컬 서버 호출
async function askOllamaLocal(question) {
  try {
    const localResponse = await fetch('http://localhost:11434/api/generate', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: process.env.OLLAMA_MODEL || 'llama2',
        prompt: buildOllamaPrompt(question),
        stream: false,
      }),
    });

    if (localResponse.ok) {
      const localData = await localResponse.json();
      console.log('✅ Ollama 로컬 서버 응답 성공');
      return localData.response;
    }
  } catch (localError) {
    console.log('⚠️ Ollama 로컬 서버 연결 실패');
  }
  return null;
}

// Ollama 클라우드 서버 호출
async function askOllamaCloud(question) {
  const apiKey = process.env.OLLAMA_API_KEY;
  const ollamaUrl = process.env.OLLAMA_URL;
  
  if (!ollamaUrl) {
    throw new Error('OLLAMA_URL이 설정되지 않았습니다.');
  }
  
  const headers = { 'Content-Type': 'application/json' };
  if (apiKey) {
    headers['Authorization'] = `Bearer ${apiKey}`;
  }
  
  const response = await fetch(ollamaUrl, {
    method: 'POST',
    headers: headers,
    body: JSON.stringify({
      model: process.env.OLLAMA_MODEL || 'llama2',
      messages: [{ role: 'user', content: buildOllamaPrompt(question) }],
      max_tokens: 200,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Ollama API error:', response.status, errorText);
    throw new Error(`Ollama API error: ${response.status}`);
  }

  const data = await response.json();
  return data.choices[0].message.content;
}

// Ollama API 호출 (로컬 우선, 실패 시 클라우드)
async function askOllama(question) {
  const useLocalFirst = process.env.OLLAMA_USE_LOCAL === 'true';
  
  // 로컬 우선인 경우
  if (useLocalFirst) {
    const localResult = await askOllamaLocal(question);
    if (localResult) return localResult;
    console.log('⚠️ 로컬 실패, 클라우드 시도...');
  }
  
  // 클라우드 시도
  try {
    return await askOllamaCloud(question);
  } catch (cloudError) {
    console.error('Ollama 클라우드 오류:', cloudError);
    
    // 클라우드 실패 시 로컬 폴백 (로컬 우선이 아닌 경우에만)
    if (!useLocalFirst) {
      const localResult = await askOllamaLocal(question);
      if (localResult) return localResult;
    }
  }
  
  return 'Watch'; // 기본값
}

// AI 응답에서 추천 파싱 (Buy, Hold, Watch, Sell)
function parseRecommendation(response) {
  const text = response.toLowerCase();
  
  if (text.includes('buy') || text.includes('매수')) {
    return 'Buy';
  } else if (text.includes('hold') || text.includes('보유')) {
    return 'Hold';
  } else if (text.includes('sell') || text.includes('매도')) {
    return 'Sell';
  } else if (text.includes('watch') || text.includes('관망')) {
    return 'Watch';
  }
  
  return 'Watch'; // 기본값
}

// 검증도 계산
function calculateVerification(models) {
  if (models.length === 0) {
    return { score: 0, agreement: '오류' };
  }

  // 각 추천별 개수 계산
  const recommendations = {};
  models.forEach(model => {
    const rec = model.recommendation;
    recommendations[rec] = (recommendations[rec] || 0) + 1;
  });

  // 가장 많은 추천
  const maxCount = Math.max(...Object.values(recommendations));
  const totalCount = models.length;
  const agreementRate = (maxCount / totalCount) * 100;

  // 합의도 결정
  let agreement;
  if (agreementRate >= 75) {
    agreement = '일치';
  } else if (agreementRate >= 50) {
    agreement = '일부일치';
  } else {
    agreement = '분산';
  }

  return {
    score: Math.round(agreementRate),
    agreement: agreement,
  };
}

// 최종 추천 결정
function determineFinalRecommendation(models) {
  if (models.length === 0) return 'Watch';

  // 각 추천별 개수 계산
  const recommendations = {};
  models.forEach(model => {
    const rec = model.recommendation;
    recommendations[rec] = (recommendations[rec] || 0) + 1;
  });

  // 가장 많은 추천 반환
  let maxRec = 'Watch';
  let maxCount = 0;
  
  Object.entries(recommendations).forEach(([rec, count]) => {
    if (count > maxCount) {
      maxCount = count;
      maxRec = rec;
    }
  });

  return maxRec;
}

// 종합 리포트 생성
function generateSummary(models, finalRecommendation, verification, stockInfo) {
  const price = stockInfo.price ? 
    (stockInfo.isKorean ? `₩${Math.round(stockInfo.price).toLocaleString()}` : `$${stockInfo.price.toFixed(2)}`) 
    : 'N/A';
  
  const changePercent = stockInfo.changePercent ? `${stockInfo.changePercent >= 0 ? '+' : ''}${stockInfo.changePercent.toFixed(2)}%` : 'N/A';
  
  let summary = `📊 ${stockInfo.symbol} 종합 분석 리포트\n\n`;
  summary += `현재가: ${price} (${changePercent})\n\n`;
  
  summary += `🤖 AI 검증위원회 결과:\n`;
  summary += `- 검증도: ${verification.score}% (${verification.agreement})\n`;
  summary += `- 최종 추천: ${finalRecommendation}\n\n`;
  
  summary += `📋 AI 모델별 의견:\n`;
  models.forEach(model => {
    summary += `- ${model.modelName}: ${model.recommendation}\n`;
  });
  
  summary += `\n💡 투자 의견:\n`;
  
  // 검증도에 따라 메시지 결정
  if (verification.score >= 75) {
    // 검증도가 높은 경우 (75% 이상)
    if (finalRecommendation === 'Buy') {
      summary += `여러 AI 모델이 일치하는 추천으로, 투자 검증도가 높습니다. 적극적인 매수를 고려해볼 수 있습니다.`;
    } else if (finalRecommendation === 'Sell') {
      summary += `여러 AI 모델이 일치하는 추천으로, 매도 검증도가 높습니다. 신중한 매도를 고려해볼 수 있습니다.`;
    } else if (finalRecommendation === 'Hold') {
      summary += `여러 AI 모델이 일치하는 추천으로, 보유 검증도가 높습니다. 현재 보유를 유지하는 것을 권장합니다.`;
    } else if (finalRecommendation === 'Watch') {
      summary += `여러 AI 모델이 일치하는 추천으로, 관망 검증도가 높습니다. 신중한 관망을 권장하며, 추가 정보를 확인 후 결정하시기 바랍니다.`;
    } else {
      summary += `여러 AI 모델이 일치하는 추천으로, 검증도가 높습니다. AI 검증위원회의 종합 분석 결과를 참고하여 투자 결정을 내리시기 바랍니다.`;
    }
  } else if (verification.score >= 50) {
    // 검증도가 중간인 경우 (50-74%)
    if (finalRecommendation === 'Buy') {
      summary += `AI 모델들 간 의견이 일부 일치하며, 매수를 권장합니다. 추가 분석 후 결정하시기 바랍니다.`;
    } else if (finalRecommendation === 'Sell') {
      summary += `AI 모델들 간 의견이 일부 일치하며, 매도를 고려해볼 수 있습니다. 추가 분석 후 결정하시기 바랍니다.`;
    } else if (finalRecommendation === 'Hold') {
      summary += `AI 모델들 간 의견이 일부 일치하며, 보유를 권장합니다. 추가 분석 후 결정하시기 바랍니다.`;
    } else if (finalRecommendation === 'Watch') {
      summary += `AI 모델들 간 의견이 일부 일치하며, 관망을 권장합니다. 추가 정보를 확인 후 결정하시기 바랍니다.`;
    } else {
      summary += `AI 모델들 간 의견이 일부 일치합니다. 추가 분석 후 결정하시기 바랍니다.`;
    }
  } else {
    // 검증도가 낮은 경우 (50% 미만)
    summary += `AI 모델들 간 의견이 분산되어 있어, 신중한 판단이 필요합니다. 추가 정보를 확인하고 전문가의 조언을 구하시기 바랍니다.`;
  }
  
  return summary;
}

