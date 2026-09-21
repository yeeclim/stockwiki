// 공통 헬퍼: 입력 검증, Rate Limiting, 접근 제어, 표준 응답

import { checkAccess, isAllowedOrigin, requestOrigin } from './_guard.js';

// ── Rate Limiting (인스턴스별 sliding window) ──────────────────────────
// Vercel은 인스턴스가 여러 개일 수 있으므로 분산 완벽 보장은 못하지만
// 단일 인스턴스 내 버스트 공격은 방어함
const rateLimitStore = new Map();

/**
 * @param {string} key       - IP 또는 사용자 식별자
 * @param {number} maxReqs   - windowMs 내 최대 요청 수
 * @param {number} windowMs  - 슬라이딩 윈도우 (밀리초)
 * @returns {boolean} true = 허용, false = 차단
 */
export function checkRateLimit(key, maxReqs = 30, windowMs = 60_000) {
  const now = Date.now();
  const record = rateLimitStore.get(key) || { timestamps: [] };

  // 윈도우 밖 오래된 타임스탬프 제거
  record.timestamps = record.timestamps.filter(t => now - t < windowMs);

  if (record.timestamps.length >= maxReqs) {
    rateLimitStore.set(key, record);
    return false;
  }

  record.timestamps.push(now);
  rateLimitStore.set(key, record);

  // 스토어가 너무 커지는 것 방지 (1000개 초과 시 오래된 항목 정리)
  if (rateLimitStore.size > 1000) {
    for (const [k, v] of rateLimitStore) {
      if (v.timestamps.every(t => now - t >= windowMs)) {
        rateLimitStore.delete(k);
      }
    }
  }

  return true;
}

/**
 * req 에서 클라이언트 IP 추출 (Vercel 프록시 헤더 우선)
 */
export function getClientIp(req) {
  return (
    req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
    req.socket?.remoteAddress ||
    'unknown'
  );
}

// ── 입력 검증 ──────────────────────────────────────────────────────────

/**
 * 문자열 파라미터 검증
 * @returns {string|null} 정제된 값, 실패하면 null
 */
export function validateString(value, { maxLen = 100, minLen = 1, pattern = null } = {}) {
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  if (trimmed.length < minLen || trimmed.length > maxLen) return null;
  if (pattern && !pattern.test(trimmed)) return null;
  return trimmed;
}

/**
 * 종목 코드 검증 (숫자/영문/점/하이픈만 허용)
 */
export function validateSymbol(value) {
  return validateString(value, { maxLen: 20, pattern: /^[A-Za-z0-9.\-]+$/ });
}

/**
 * 정수 파라미터 검증
 */
export function validateInt(value, { min = 0, max = 100 } = {}) {
  const n = parseInt(value, 10);
  if (isNaN(n) || n < min || n > max) return null;
  return n;
}

// ── 관리자 인증 ────────────────────────────────────────────────────────

const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || '').trim().toLowerCase();

/**
 * `Authorization: Bearer <supabase JWT>` 를 검증하고 관리자 계정인지 확인한다.
 * Supabase Auth 의 /auth/v1/user 엔드포인트로 토큰 유효성 + 이메일을 확인한다.
 * @returns {Promise<{ok:true, email:string} | {ok:false, status:number, error:string}>}
 */
export async function verifyAdmin(req) {
  const raw = req.headers['authorization'] || req.headers['Authorization'] || '';
  const token = raw.startsWith('Bearer ') ? raw.slice(7).trim() : '';
  if (!token) return { ok: false, status: 401, error: '로그인이 필요합니다' };

  const url = process.env.SUPABASE_URL?.trim();
  const key =
    process.env.SUPABASE_SERVICE_ROLE_KEY?.replace(/\s+/g, '') ||
    process.env.SUPABASE_ANON_KEY?.trim();
  if (!url || !key) return { ok: false, status: 500, error: 'DB 미설정' };
  if (!ADMIN_EMAIL) return { ok: false, status: 500, error: 'ADMIN_EMAIL 미설정' };

  try {
    const r = await fetch(`${url}/auth/v1/user`, {
      headers: { Authorization: `Bearer ${token}`, apikey: key },
    });
    if (!r.ok) return { ok: false, status: 401, error: '유효하지 않은 인증 정보' };
    const user = await r.json();
    const email = (user?.email || '').toLowerCase();
    if (email !== ADMIN_EMAIL) {
      return { ok: false, status: 403, error: '관리자 권한이 필요합니다' };
    }
    return { ok: true, email };
  } catch {
    return { ok: false, status: 502, error: '인증 서버 오류' };
  }
}

// ── CORS + 접근 제어 ──────────────────────────────────────────────────

/**
 * CORS 헤더 설정 + OPTIONS 프리플라이트 처리 + 무단 호출 차단.
 *
 * 모든 엔드포인트가 이미 이 함수를 첫 줄에서 부르고 있으므로, 접근 제어도
 * 여기 한 곳에 모은다 (엔드포인트마다 가드를 빠뜨릴 여지를 없앤다).
 *
 * @param {object} req
 * @param {object} res
 * @param {{methods?: string, json?: boolean, publicAccess?: boolean}} [opts]
 *   methods      - Access-Control-Allow-Methods 값 (기본 'GET, OPTIONS')
 *   json         - Content-Type: application/json 을 미리 설정할지 (기본 true)
 *   publicAccess - 출처 검사를 건너뛰고 누구나 호출 가능하게 한다.
 *                  메일 수신거부 링크처럼 우리 도메인 밖(메일 클라이언트)에서
 *                  열리는 경로에만 쓴다.
 * @returns {boolean} true면 이 함수가 이미 응답을 끝냈으므로 호출부에서 즉시 return 할 것
 */
export function applyCors(req, res, { methods = 'GET, OPTIONS', json = true, publicAccess = false } = {}) {
  const origin = requestOrigin(req);
  const allowedOrigin = isAllowedOrigin(origin) ? origin : null;

  // 인증 결과에 따라 응답이 갈리므로 공유 캐시(Vercel CDN)에 넣으면 안 된다.
  //
  // Vary: Origin 만으로는 못 막는다. 같은 출처 요청은 브라우저가 Origin 을
  // 보내지 않고 Referer/Sec-Fetch-Site 로 인증되는데, 헤더 없는 스크래퍼도
  // Origin 이 없어 캐시 키가 같아진다. 실제로 정상 요청의 200 이 캐시된 뒤
  // 생 curl 이 X-Vercel-Cache: HIT 으로 그 200 을 받아갔다.
  // Referer 로 Vary 하면 URL 마다 캐시가 쪼개져 캐시 자체가 무의미해진다.
  //
  // 상위 API 쿼터는 각 핸들러의 모듈 레벨 캐시(_krCandleCache 등)가 따로 막는다.
  res.setHeader('Vary', 'Origin');
  if (!publicAccess) res.setHeader('Cache-Control', 'private, no-store');
  if (publicAccess) {
    res.setHeader('Access-Control-Allow-Origin', '*');
  } else if (allowedOrigin) {
    res.setHeader('Access-Control-Allow-Origin', allowedOrigin);
  }
  res.setHeader('Access-Control-Allow-Methods', methods);
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-API-Key');
  if (json) res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return true;
  }

  // 엔드포인트별 세부 제한과 별개로 모든 경로에 공통 상한을 둔다.
  // board / theme-recommendations / us-recommend / utils 는 지금까지 제한이 아예 없었다.
  if (!checkRateLimit(`global:${getClientIp(req)}`, 120, 60_000)) {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Retry-After', '60');
    res.status(429).json({ success: false, error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.', code: 'RATE_LIMITED' });
    return true;
  }

  if (!publicAccess) {
    const access = checkAccess(req);
    if (!access.allowed) {
      res.setHeader('Content-Type', 'application/json');
      res.setHeader('Cache-Control', 'no-store');
      res.status(403).json({
        success: false,
        error: '이 API는 StockWiki 웹앱 전용입니다. 외부에서 사용하려면 API 키가 필요합니다.',
        code: 'FORBIDDEN',
        docs: 'https://stockwiki.vercel.app/llms.txt',
      });
      return true;
    }
  }

  return false;
}

// ── 표준 응답 ──────────────────────────────────────────────────────────

export function ok(res, data, extra = {}) {
  return res.status(200).json({
    success: true,
    data,
    timestamp: new Date().toISOString(),
    ...extra,
  });
}

export function fail(res, status, message) {
  return res.status(status).json({
    success: false,
    error: message,
    timestamp: new Date().toISOString(),
  });
}
