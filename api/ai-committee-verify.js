// AI 검증위원회 API
// Gemini (Google AI Studio 무료) + Llama 3.3 + Gemma 3 (OpenRouter 무료)

function getEnv(key) {
  const K = key.toUpperCase();
  return process.env[K] || process.env[key.toLowerCase()] || process.env[key] || '';
}

// 종목별 결과 캐시 (30분)
const cache = new Map();
const CACHE_TTL = 30 * 60 * 1000;

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

    // 캐시 확인 (symbol 기준 30분)
    const cacheKey = symbol || question.substring(0, 50);
    const cached = cache.get(cacheKey);
    if (cached && (Date.now() - cached.time) < CACHE_TTL) {
      console.log(`✅ 캐시 응답: ${cacheKey}`);
      return res.status(200).json({ ...cached.data, cached: true });
    }

    // 5개 모델 동시 시도 → 성공한 것 3개만 표시 (provider 다변화)
    const MODEL_POOL = [
      { name: 'Gemini',    fn: () => askGemini(question) },
      { name: 'Qwen3',     fn: () => askOpenRouter(question, 'qwen/qwen3-next-80b-a3b-instruct:free', 'Qwen3') },
      { name: 'Mistral',   fn: () => askOpenRouter(question, 'mistralai/mistral-7b-instruct:free', 'Mistral') },
      { name: 'Llama 3.3', fn: () => askOpenRouter(question, 'meta-llama/llama-3.3-70b-instruct:free', 'Llama 3.3') },
      { name: 'Gemma 4',   fn: () => askOpenRouter(question, 'google/gemma-4-31b-it:free', 'Gemma 4') },
    ];

    const allResults = await Promise.allSettled(MODEL_POOL.map(m => m.fn()));

    const successes = [];
    const failures = [];
    allResults.forEach((result, i) => {
      const name = MODEL_POOL[i].name;
      if (result.status === 'fulfilled' && result.value) {
        successes.push({ name, response: result.value });
      } else {
        const msg = result.reason?.message || '응답 실패';
        console.error(`❌ ${name} 실패:`, msg);
        failures.push({ name, error: msg });
      }
    });

    // 성공 최대 3개 + 부족하면 실패로 채움
    const selected = [
      ...successes.slice(0, 3),
      ...failures.slice(0, Math.max(0, 3 - successes.length)),
    ];

    const models = selected.map(item =>
      item.response
        ? {
            modelName: item.name,
            recommendation: parseRecommendation(item.response),
            reasoning: item.response.substring(0, 200),
            fullResponse: item.response,
          }
        : {
            modelName: item.name,
            recommendation: 'Error',
            reasoning: item.error,
            fullResponse: item.error,
          }
    );

    if (models.length === 0) {
      throw new Error('모든 AI 모델 응답에 실패했습니다.');
    }

    const verification = calculateVerification(models, MODEL_POOL.length);
    const finalRecommendation = determineFinalRecommendation(models);
    const summary = generateSummary(models, finalRecommendation, verification, {
      symbol, price, changePercent, isKorean: isKorean || false,
    });

    const responseData = {
      success: true,
      models,
      verificationCount: MODEL_POOL.length,
      activeCount: successes.length,
      verificationScore: verification.score,
      agreement: verification.agreement,
      finalRecommendation,
      summary,
      timestamp: new Date().toISOString(),
    };

    // 성공한 모델이 1개 이상이면 캐시 저장
    if (models.some(m => m.recommendation !== 'Error')) {
      cache.set(cacheKey, { data: responseData, time: Date.now() });
    }

    return res.status(200).json(responseData);

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

// 주 모델 실패 시 백업 모델 자동 시도
async function askWithFallback(primary, fallback) {
  try {
    return await primary();
  } catch (e) {
    console.warn('⚠️ 주 모델 실패, 백업 시도:', e.message);
    return await fallback();
  }
}

// 응답 마지막 300자 안에 "결론: X" 패턴이 없으면 에러 처리 (체인오브소트 모델 필터링)
function validateConclusion(content, displayName) {
  const tail = content.slice(-300).toLowerCase();
  if (!tail.match(/결론\s*[:：]\s*(buy|hold|watch|sell|매수|매도|보유|관망)/)) {
    throw new Error(`${displayName} 결론 누락 (응답 불완전)`);
  }
  return content;
}

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
  return validateConclusion(data.candidates[0].content.parts[0].text, 'Gemini');
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
  return validateConclusion(content, displayName);
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

function calculateVerification(models, totalTried) {
  const validModels = models.filter(m => m.recommendation !== 'Error');
  if (validModels.length === 0) return { score: 0, agreement: '오류' };

  const successRate = validModels.length / (totalTried || validModels.length);
  const counts = {};
  validModels.forEach(m => counts[m.recommendation] = (counts[m.recommendation] || 0) + 1);
  const maxCount = Math.max(...Object.values(counts));
  const agreementRate = maxCount / validModels.length;
  const score = Math.round(agreementRate * successRate * 100);
  const agreement = agreementRate >= 0.8 ? '일치' : agreementRate >= 0.6 ? '높음' : agreementRate >= 0.4 ? '보통' : '낮음';
  return { score, agreement };
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
