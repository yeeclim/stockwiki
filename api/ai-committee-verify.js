// AI 검증위원회 API
// Gemini (Google AI Studio 무료) + Llama 3 + Mistral (OpenRouter 무료)

function getEnv(key) {
  const K = key.toUpperCase();
  return process.env[K] || process.env[key.toLowerCase()] || process.env[key] || '';
}

export default async function handler(req, res) {
  const fetch = globalThis.fetch || (await import('node-fetch')).default;
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') { res.status(200).end(); return; }
  if (req.method !== 'POST') { res.status(405).json({ error: 'Method not allowed' }); return; }

  try {
    const { question, symbol, price, changePercent, isKorean = false } = req.body;

    if (!question) {
      return res.status(400).json({ success: false, error: '질문이 필요합니다' });
    }

    const tasks = [
      { name: 'Gemini',   fn: () => askGemini(question) },
      { name: 'Llama 3.3', fn: () => askOpenRouter(question, 'meta-llama/llama-3.3-70b-instruct:free', 'Llama 3.3') },
      { name: 'Gemma 3',  fn: () => askOpenRouter(question, 'google/gemma-3-27b-it:free', 'Gemma 3') },
    ];

    const results = await Promise.allSettled(tasks.map(t => t.fn()));

    const models = [];
    results.forEach((result, index) => {
      const taskName = tasks[index].name;
      if (result.status === 'fulfilled' && result.value) {
        const rawResponse = result.value;
        models.push({
          modelName: taskName,
          recommendation: parseRecommendation(rawResponse),
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
      throw new Error('모든 AI 모델 응답에 실패했습니다.');
    }

    const verification = calculateVerification(models);
    const finalRecommendation = determineFinalRecommendation(models);
    const summary = generateSummary(models, finalRecommendation, verification, {
      symbol, price, changePercent, isKorean: isKorean || false,
    });

    return res.status(200).json({
      success: true,
      models,
      verificationCount: tasks.length,
      activeCount: models.length,
      verificationScore: verification.score,
      agreement: verification.agreement,
      finalRecommendation,
      summary,
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

const PROMPT_SUFFIX = `

분석 후 마지막 줄에 반드시 다음 형식으로만 결론을 작성하세요:
결론: Buy  (또는 Hold, Watch, Sell 중 하나)`;

// Gemini API (Google AI Studio 무료)
async function askGemini(question) {
  const apiKey = getEnv('GEMINI_API_KEY');
  if (!apiKey) throw new Error('GEMINI_API_KEY 미설정');

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contents: [{ parts: [{ text: question + PROMPT_SUFFIX }] }] }),
    }
  );

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Gemini HTTP ${response.status}: ${err.substring(0, 100)}`);
  }
  const data = await response.json();
  return data.candidates[0].content.parts[0].text;
}

// OpenRouter API (무료 모델 공용 함수)
async function askOpenRouter(question, model, displayName) {
  const apiKey = getEnv('OPENROUTER_API_KEY');
  if (!apiKey) throw new Error('OPENROUTER_API_KEY 미설정');

  const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://stockwiki.vercel.app',
      'X-Title': 'StockWiki AI Committee',
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: question + PROMPT_SUFFIX }],
      max_tokens: 500,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`${displayName} HTTP ${response.status}: ${err.substring(0, 100)}`);
  }
  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error(`${displayName} 응답 파싱 실패`);
  return content;
}

// AI 응답에서 추천 파싱
function parseRecommendation(response) {
  const text = response.toLowerCase();

  const conclusionMatch = text.match(/결론\s*[:：]\s*(buy|hold|watch|sell|매수|매도|보유|관망)/);
  if (conclusionMatch) {
    const v = conclusionMatch[1];
    if (v === 'buy'   || v === '매수') return 'Buy';
    if (v === 'hold'  || v === '보유') return 'Hold';
    if (v === 'sell'  || v === '매도') return 'Sell';
    if (v === 'watch' || v === '관망') return 'Watch';
  }

  if (text.includes('strong sell') || text.includes('강력 매도')) return 'Sell';
  if (text.includes('strong buy')  || text.includes('강력 매수')) return 'Buy';
  if (text.includes('sell')  || text.includes('매도')) return 'Sell';
  if (text.includes('buy')   || text.includes('매수')) return 'Buy';
  if (text.includes('hold')  || text.includes('보유')) return 'Hold';
  if (text.includes('watch') || text.includes('관망')) return 'Watch';
  return 'Watch';
}

function calculateVerification(models) {
  const validModels = models.filter(m => m.recommendation !== 'Error');
  if (validModels.length === 0) return { score: 0, agreement: '오류' };

  const counts = {};
  validModels.forEach(m => counts[m.recommendation] = (counts[m.recommendation] || 0) + 1);
  const maxCount = Math.max(...Object.values(counts));
  const rate = (maxCount / validModels.length) * 100;
  const agreement = rate >= 80 ? '일치' : rate >= 60 ? '높음' : rate >= 40 ? '보통' : '낮음';
  return { score: Math.round(rate), agreement };
}

function determineFinalRecommendation(models) {
  const validModels = models.filter(m => m.recommendation !== 'Error');
  if (validModels.length === 0) return 'Watch';
  const counts = {};
  validModels.forEach(m => counts[m.recommendation] = (counts[m.recommendation] || 0) + 1);
  return Object.entries(counts).reduce((a, b) => b[1] > a[1] ? b : a)[0];
}

function generateSummary(models, finalRecommendation, verification, stockInfo) {
  const price = stockInfo.price
    ? (stockInfo.isKorean ? `₩${Math.round(stockInfo.price).toLocaleString()}` : `$${stockInfo.price.toFixed(2)}`)
    : 'N/A';
  const change = stockInfo.changePercent
    ? `${stockInfo.changePercent >= 0 ? '+' : ''}${stockInfo.changePercent.toFixed(2)}%`
    : 'N/A';

  let summary = `📊 ${stockInfo.symbol} 종합 분석 리포트\n\n`;
  summary += `현재가: ${price} (${change})\n\n`;
  summary += `🤖 AI 검증위원회 결과:\n- 검증도: ${verification.score}% (${verification.agreement})\n- 최종 추천: ${finalRecommendation}\n\n`;
  summary += `📋 모델별 의견:\n` + models.map(m => `- ${m.modelName}: ${m.recommendation}`).join('\n') + `\n\n`;

  const advice = {
    'Buy':   '다수의 AI 모델이 매수를 제안하고 있습니다. 긍정적인 추세가 예상되나 항상 리스크를 고려하세요.',
    'Sell':  '다수의 AI 모델이 매도를 제안하고 있습니다. 하방 압력이 존재할 수 있으니 주의가 필요합니다.',
    'Hold':  '현재 상태 유지를 권장하는 의견이 많습니다. 추가적인 모멘텀을 확인하세요.',
    'Watch': '불확실성이 높거나 관망이 필요한 종목입니다. 시장 상황을 좀 더 지켜보시기 바랍니다.',
  };

  summary += `💡 투자 조언: ${advice[finalRecommendation] || advice['Watch']}\n`;
  if (verification.score < 50) summary += `⚠️ 주의: 모델간 의견이 분분하여 검증도가 낮습니다. 신중하게 접근하세요.`;

  return summary;
}
