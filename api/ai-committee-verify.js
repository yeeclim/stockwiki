// AI 검증위원회 API
// Gemini (Google AI Studio 무료) + Llama 3.3 / Llama 3.1 / Gemma 2 / Mixtral (Groq 무료)

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
      { name: 'Qwen QwQ',     fn: () => askGroqThink(question, 'qwen-qwq-32b', 'Qwen QwQ') },
      { name: 'Llama 3.3',   fn: () => askGroq(question, 'llama-3.3-70b-versatile', 'Llama 3.3') },
      { name: 'Gemma 2',     fn: () => askGroq(question, 'gemma2-9b-it', 'Gemma 2') },
      { name: 'Mixtral',     fn: () => askGroq(question, 'mixtral-8x7b-32768', 'Mixtral') },
      { name: 'Llama 3.1',   fn: () => askGroq(question, 'llama-3.1-8b-instant', 'Llama 3.1') },
    ];

    const withTimeout = (fn, ms = 20000) => Promise.race([
      fn(),
      new Promise((_, reject) => setTimeout(() => reject(new Error('응답 시간 초과')), ms)),
    ]);

    const allResults = await Promise.allSettled(MODEL_POOL.map(m => withTimeout(m.fn)));

    // 첫 번째 슬롯은 항상 표시 (성공·실패 무관)
    const firstModel = MODEL_POOL[0];
    const firstResult = allResults[0];
    const firstEntry = (firstResult.status === 'fulfilled' && firstResult.value)
      ? { name: firstModel.name, response: firstResult.value }
      : { name: firstModel.name, error: firstResult.reason?.message || '응답 실패' };

    if (firstEntry.error) console.error(`❌ ${firstModel.name} 실패:`, firstEntry.error);

    // 나머지 Groq 모델 중 성공한 것 2개 채움
    const groqSuccesses = [];
    const groqFailures = [];
    allResults.slice(1).forEach((result, i) => {
      const name = MODEL_POOL[i + 1].name;
      if (result.status === 'fulfilled' && result.value) {
        groqSuccesses.push({ name, response: result.value });
      } else {
        const msg = result.reason?.message || '응답 실패';
        console.error(`❌ ${name} 실패:`, msg);
        groqFailures.push({ name, error: msg });
      }
    });

    const selected = [
      firstEntry,
      ...groqSuccesses.slice(0, 2),
      ...groqFailures.slice(0, Math.max(0, 2 - groqSuccesses.length)),
    ];

    const successes = selected.filter(s => s.response);
    const failures = selected.filter(s => s.error);

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
            reasoning: cuteErrorMessage(item.error),
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

    // 성공 → 30분 캐시 / 전체 실패 → 5분 캐시 (rate limit 반복 방지)
    const hasSuccess = models.some(m => m.recommendation !== 'Error');
    const cacheTime = hasSuccess ? Date.now() : Date.now() - (CACHE_TTL - 5 * 60 * 1000);
    cache.set(cacheKey, { data: responseData, time: cacheTime });

    return res.status(200).json(responseData);

  } catch (error) {
    console.error('❌ AI 검증위원회 오류:', error);
    return res.status(500).json({
      success: false,
      error: error.message || 'AI 검증위원회 처리 중 오류 발생',
    });
  }
}

const SYSTEM_INSTRUCTION = `You are a Korean stock market analyst. You MUST write your entire response in Korean (한국어) only.

STRICTLY FORBIDDEN - never use these characters or languages:
- Chinese characters (漢字/한자): 公司, 信號, 財務, 增加, 趨勢, 市場, 維持, 大きい, 稍微 etc.
- Japanese (hiragana/katakana): あいう, アイウ etc.
- Vietnamese or any other non-Korean script.

If you want to write "company" write 회사 (NOT 公司).
If you want to write "signal" write 신호 (NOT 信號).
If you want to write "financial" write 재무 (NOT 財務).
If you want to write "increase" write 증가 (NOT 增加).
If you want to write "trend" write 추세 (NOT 趨勢).
If you want to write "market" write 시장 (NOT 市場).

ALLOWED: Korean (한글), and ONLY these English abbreviations when no Korean equivalent exists: ticker symbols (AAPL, NVDA, TSLA), financial terms (PER, PBR, ROE, EPS, EBITDA, RSI, MACD, MA, ETF, AI, ESG, GDP, CPI).

Write all analysis in natural Korean sentences.`;

const PROMPT_SUFFIX = `

분석 후 마지막 줄에 반드시 다음 형식으로만 결론을 작성하세요:
결론: Buy  (또는 Hold, Watch, Sell 중 하나)`;

// 에러 메시지를 귀여운 문구로 변환
function cuteErrorMessage(error) {
  const msg = (error || '').toLowerCase();
  if (msg.includes('429') || msg.includes('quota') || msg.includes('exceeded') || msg.includes('rate limit')) {
    const msgs = [
      '무료 끝났당 ㅠ_ㅠ 내일 다시 만나요!',
      '오늘 할당량 다 썼어요~ 😢 내일 봐요!',
      '열심히 일했더니 쿼터가 동났어요 ㅠㅠ',
      '무료 티켓 소진! 🎟️ 내일 충전돼요~',
    ];
    return msgs[Math.floor(Math.random() * msgs.length)];
  }
  if (msg.includes('미설정') || msg.includes('api_key') || msg.includes('api key')) {
    return '열쇠를 못 찾겠어요 🔑 API 키가 없나봐요';
  }
  if (msg.includes('시간 초과') || msg.includes('timeout')) {
    return '생각하다 잠들었어요 💤 다시 깨워볼까요?';
  }
  if (msg.includes('결론 누락') || msg.includes('불완전')) {
    return '말이 너무 길어져서 결론을 깜빡했대요 🤔';
  }
  if (msg.includes('한자') || msg.includes('cjk') || msg.includes('언어 위반')) {
    return '한자가 너무 좋아서 혼났어요 😅 다시 시도해 보세요!';
  }
  if (msg.includes('network') || msg.includes('fetch') || msg.includes('connect')) {
    return '길을 잃었어요 🗺️ 네트워크가 불안정한가봐요';
  }
  return '앗, 제가 삐끗했어요! 🙈 잠시 후 다시 시도해 보세요';
}

// 주 모델 실패 시 백업 모델 자동 시도
async function askWithFallback(primary, fallback) {
  try {
    return await primary();
  } catch (e) {
    console.warn('⚠️ 주 모델 실패, 백업 시도:', e.message);
    return await fallback();
  }
}

// 한자/일본어 → 한국어 치환 테이블
const CJK_TO_KOREAN = {
  '公司': '회사', '信號': '신호', '財務': '재무', '增加': '증가',
  '趨勢': '추세', '市場': '시장', '維持': '유지', '减少': '감소',
  '分析': '분석', '投資': '투자', '收益': '수익', '利益': '이익',
  '매출液': '매출액', '負債': '부채', '資産': '자산', '株價': '주가',
  '上昇': '상승', '下落': '하락', '比率': '비율', '成長': '성장',
  '企業': '기업', '産業': '산업', '競争': '경쟁', '技術': '기술',
  '實績': '실적', '展望': '전망', '危険': '위험', '安定': '안정',
};

// 허용된 영어 약어 목록 (대소문자 무관)
const ALLOWED_ENGLISH = new Set([
  'per', 'pbr', 'roe', 'eps', 'ebitda', 'rsi', 'macd', 'ma', 'etf', 'ai',
  'esg', 'gdp', 'cpi', 'ipo', 'm&a', 'ev', 'fcf', 'ocf', 'capex', 'wacc',
]);

// 일반 영어 단어 → 한국어 치환 테이블
const ENGLISH_TO_KOREAN = {
  // 기업/시장
  'company': '기업', 'companies': '기업들', 'market': '시장', 'sector': '섹터',
  'industry': '산업', 'stock': '주식', 'stocks': '주식', 'share': '주식', 'shares': '주식',
  // 재무
  'revenue': '매출', 'profit': '이익', 'profits': '이익', 'earnings': '실적',
  'growth': '성장', 'financial': '재무', 'operating': '영업', 'net': '순',
  'gross': '총', 'margin': '마진', 'valuation': '밸류에이션',
  'dividend': '배당', 'buyback': '자사주 매입', 'forecast': '전망',
  'guidance': '가이던스', 'outlook': '전망', 'report': '보고서',
  'quarter': '분기', 'annual': '연간', 'fiscal': '회계',
  // 분석
  'analysis': '분석', 'trend': '추세', 'momentum': '모멘텀',
  'support': '지지', 'resistance': '저항', 'breakout': '돌파',
  'bullish': '강세', 'bearish': '약세', 'volatile': '변동성이 높은',
  'performance': '실적', 'investment': '투자', 'investor': '투자자',
  'investors': '투자자들', 'risk': '리스크', 'risks': '리스크',
  // 동사/형용사
  'increase': '증가', 'decrease': '감소', 'decline': '하락', 'rise': '상승',
  'improve': '개선', 'strong': '강한', 'weak': '약한', 'stable': '안정적인',
  'positive': '긍정적', 'negative': '부정적', 'neutral': '중립적',
  'significant': '상당한', 'potential': '잠재적', 'expected': '예상되는',
  'based on': '기반으로', 'compared to': '대비', 'year-over-year': '전년 대비',
};

// 알려진 외국어(터키어·베트남어 등) 단어 → 한국어 치환, 나머지는 제거
const FOREIGN_WORDS = {
  // 터키어 (Turkish)
  'uzun': '장기', 'kisa': '단기', 'yuksek': '높은', 'dusuk': '낮은',
  'buyume': '성장', 'artis': '증가', 'azalis': '감소', 'kar': '이익',
  'zarar': '손실', 'piyasa': '시장', 'sirket': '기업', 'hisse': '주식',
  'yatirim': '투자', 'analiz': '분석', 'rapor': '보고서', 'hedef': '목표',
  // 베트남어 (Vietnamese)
  'tang': '증가', 'giam': '감소', 'lon': '큰', 'nho': '작은',
  'thi truong': '시장', 'cong ty': '기업', 'dau tu': '투자',
  // 인도네시아어 / 말레이어
  'pertumbuhan': '성장', 'pendapatan': '매출', 'keuntungan': '이익',
  'pasar': '시장', 'perusahaan': '기업', 'saham': '주식',
};

function removeForeignWords(content) {
  let result = content;

  // 알려진 외국어 단어 → 한국어로 치환
  for (const [foreign, korean] of Object.entries(FOREIGN_WORDS)) {
    result = result.replace(new RegExp(`\\b${foreign}\\b`, 'gi'), korean);
  }

  // 비ASCII 라틴 문자 포함 단어 제거 (ü ı ğ ş ö ç â ê 등 — 영어·한국어 아님)
  result = result.replace(/\b[a-zA-ZÀ-ÖØ-öø-ÿ]*[À-ÖØ-öø-ÿ]+[a-zA-ZÀ-ÖØ-öø-ÿ]*\b/g, '');

  return result.replace(/  +/g, ' ').trim();
}

// 일반 영어 단어를 한국어로 치환 (허용 약어는 유지)
function sanitizeEnglishWords(content) {
  let result = content;
  for (const [en, ko] of Object.entries(ENGLISH_TO_KOREAN)) {
    // 단어 경계 기준, 대소문자 무관 치환
    result = result.replace(new RegExp(`\\b${en}\\b`, 'gi'), (match) => {
      // 전부 대문자인 경우 허용 약어일 수 있으니 확인
      if (ALLOWED_ENGLISH.has(match.toLowerCase())) return match;
      return ko;
    });
  }
  return result;
}

// CJK 문자가 섞인 경우 치환 후 남은 것은 제거 (거부 대신 정제)
function sanitizeAndValidateLanguage(content, displayName) {
  let result = content;
  for (const [cjk, korean] of Object.entries(CJK_TO_KOREAN)) {
    result = result.replaceAll(cjk, korean);
  }
  // 치환 후에도 CJK 통합한자 (U+4E00-U+9FFF) 또는 일본어(U+3040-U+30FF)가 남아 있으면 제거
  if (/[一-鿿㐀-䶿぀-ヿ]/.test(result)) {
    const sample = [...result.matchAll(/[一-鿿㐀-䶿぀-ヿ]/g)]
      .slice(0, 5).map(m => m[0]).join('');
    console.warn(`⚠️ ${displayName} CJK 문자 자동 제거: ${sample}`);
    result = result.replace(/[一-鿿㐀-䶿぀-ヿ]+/g, '').replace(/  +/g, ' ').trim();
  }
  // 일반 영어 단어 → 한국어 치환 (허용 약어 제외)
  result = sanitizeEnglishWords(result);
  // 기타 외국어 단어 제거 (터키어, 베트남어 등)
  result = removeForeignWords(result);

  // 화이트리스트 최종 정제:
  // 허용: 한글(가-힣·자모), ASCII 출력 문자(영문·숫자·구두점), CJK 구두점, 일반 구두점, 줄바꿈
  // 제거: 아랍어·키릴·히브리·태국어·데바나가리 등 비허용 유니코드 블록
  const beforeLen = result.length;
  result = result.replace(/[^가-힤ᄀ-ᇿ㄰-㆏ -~　-〿‐-⁞\n\r]/g, '');
  if (result.length < beforeLen) {
    console.warn(`⚠️ ${displayName} 비허용 문자(아랍어 등) ${beforeLen - result.length}자 제거됨`);
  }
  return result.replace(/[ \t]{2,}/g, ' ').trim();
}

// 응답 마지막 300자 안에 "결론: X" 패턴이 없으면 에러 처리 (체인오브소트 모델 필터링)
function validateConclusion(content, displayName) {
  const tail = content.slice(-400).toLowerCase();
  if (!tail.match(/결론\s*[:：]\s*(buy|hold|watch|sell|매수|매도|보유|관망)/) &&
      !tail.match(/conclusion\s*[:：]\s*(buy|hold|watch|sell)/)) {
    throw new Error(`${displayName} 결론 누락 (응답 불완전)`);
  }
  return content;
}

// DeepSeek 공식 API (deepseek-chat = V3, deepseek-reasoner = R1)
async function askDeepSeek(question, model, displayName) {
  const apiKey = getEnv('DEEPSEEK_API_KEY');
  if (!apiKey) throw new Error('DEEPSEEK_API_KEY 미설정');

  const response = await fetch('https://api.deepseek.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: SYSTEM_INSTRUCTION },
        { role: 'user', content: question + PROMPT_SUFFIX },
      ],
      max_tokens: 1500,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`${displayName} HTTP ${response.status}: ${err.substring(0, 100)}`);
  }
  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error(`${displayName} 응답 파싱 실패`);

  return validateConclusion(sanitizeAndValidateLanguage(content, displayName), displayName);
}

// Groq 추론 모델 — <think> 블록 제거 (QwQ, DeepSeek R1 distill 등)
async function askGroqThink(question, model, displayName) {
  const apiKey = getEnv('GROQ_API_KEY');
  if (!apiKey) throw new Error('GROQ_API_KEY 미설정');

  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: SYSTEM_INSTRUCTION },
        { role: 'user', content: question + PROMPT_SUFFIX },
      ],
      max_tokens: 2000,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`${displayName} HTTP ${response.status}: ${err.substring(0, 100)}`);
  }
  const data = await response.json();
  let content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error(`${displayName} 응답 파싱 실패`);
  content = content.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
  return validateConclusion(sanitizeAndValidateLanguage(content, displayName), displayName);
}

// Google Gemini API (Google AI Studio 무료)
async function askGemini(question, model, displayName) {
  const apiKey = getEnv('GEMINI_API_KEY');
  if (!apiKey) throw new Error('GEMINI_API_KEY 미설정');

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: SYSTEM_INSTRUCTION },
          { role: 'user', content: question + PROMPT_SUFFIX },
        ],
        max_tokens: 1500,
      }),
    }
  );

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`${displayName} HTTP ${response.status}: ${err.substring(0, 100)}`);
  }
  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error(`${displayName} 응답 파싱 실패`);
  return validateConclusion(sanitizeAndValidateLanguage(content, displayName), displayName);
}

// Groq API (빠른 무료 추론)
async function askGroq(question, model, displayName) {
  const apiKey = getEnv('GROQ_API_KEY');
  if (!apiKey) throw new Error('GROQ_API_KEY 미설정');

  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: SYSTEM_INSTRUCTION },
        { role: 'user', content: question + PROMPT_SUFFIX },
      ],
      max_tokens: 1000,
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`${displayName} HTTP ${response.status}: ${err.substring(0, 100)}`);
  }
  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error(`${displayName} 응답 파싱 실패`);
  return validateConclusion(sanitizeAndValidateLanguage(content, displayName), displayName);
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
      max_tokens: 1000,
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

  const conclusionMatch = text.match(/(?:결론|conclusion)\s*[:：]\s*(buy|hold|watch|sell|매수|매도|보유|관망)/);
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
