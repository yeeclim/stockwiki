// 공통 헬퍼: 입력 검증, Rate Limiting, 표준 응답

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
