// API 접근 제어 — 무단 스크래핑 차단
//
// /api/* 는 원래 완전 공개였다 (CORS `*`, 인증 없음, llms.txt 로 사용법까지 공개).
// 그래서 상위 데이터 소스(KIS·Yahoo·네이버) 호출 쿼터와 Vercel 함수 실행량을
// 제3자가 그대로 가져다 쓸 수 있었다. 호출 주체를 자사 웹앱 + 발급 키 보유자로 제한한다.
//
// 한계는 분명히 해 둔다. Origin/Referer/Sec-Fetch-* 는 브라우저가 붙이는 값이라
// curl 같은 비브라우저 클라이언트는 얼마든지 위조할 수 있다. 이 계층이 실제로 막는 것은
//   (1) 다른 웹사이트가 우리 API 를 그대로 끌어다 쓰는 것 (브라우저 CORS 로 강제됨)
//   (2) 헤더를 손대지 않은 손쉬운 자동 수집·AI 에이전트 호출
// 작정하고 헤더를 위조하는 수집가는 Rate Limit(_shared.js)과
// Vercel Firewall 규칙으로 막아야 한다.

import { createHash, timingSafeEqual } from 'node:crypto';

// 프로덕션 + Vercel 프리뷰 배포 + 로컬 개발.
// `*.vercel.app` 전체를 열면 아무 Vercel 프로젝트나 우리 API 를 쓸 수 있으므로
// 프로젝트 이름으로 시작하는 배포 URL 만 허용한다.
const DEFAULT_ORIGIN_PATTERNS = [
  /^https:\/\/stockwiki(-[a-z0-9-]+)?\.vercel\.app$/i,
  /^http:\/\/localhost(:\d+)?$/i,
  /^http:\/\/127\.0\.0\.1(:\d+)?$/i,
];

// 커스텀 도메인을 붙이면 Vercel 환경변수 ALLOWED_ORIGINS 에 콤마로 나열한다.
//   ALLOWED_ORIGINS=https://stockwiki.co.kr,https://www.stockwiki.co.kr
function extraOrigins() {
  return (process.env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((s) => s.trim().replace(/\/+$/, ''))
    .filter(Boolean);
}

function toOrigin(value) {
  if (!value) return null;
  try {
    return new URL(value).origin;
  } catch {
    return null;
  }
}

/**
 * 요청의 출처를 추정한다.
 * 같은 출처 요청에는 브라우저가 Origin 을 생략하므로 Referer 로 보완한다.
 */
export function requestOrigin(req) {
  return toOrigin(req.headers['origin']) || toOrigin(req.headers['referer']);
}

export function isAllowedOrigin(origin) {
  if (!origin) return false;
  if (DEFAULT_ORIGIN_PATTERNS.some((re) => re.test(origin))) return true;
  return extraOrigins().includes(origin);
}

// ── API 키 ────────────────────────────────────────────────────────────
// Vercel 환경변수 API_KEYS 에 콤마로 나열한다. 비워 두면 키 인증 자체가 꺼진다.
function sha256(value) {
  return createHash('sha256').update(String(value)).digest();
}

function hasValidApiKey(req) {
  const keys = (process.env.API_KEYS || '').split(',').map((s) => s.trim()).filter(Boolean);
  if (!keys.length) return false;

  const presented =
    (req.headers['x-api-key'] || req.query?.api_key || '').toString().trim();
  if (!presented) return false;

  // 길이가 달라도 timingSafeEqual 이 던지지 않도록 해시(고정 32바이트)끼리 비교한다.
  const digest = sha256(presented);
  return keys.some((key) => timingSafeEqual(digest, sha256(key)));
}

// ── 검색엔진 크롤러 ───────────────────────────────────────────────────
// 실제로 검색봇이 /api/* 를 크롤링할 일은 거의 없지만(HTML 페이지만 긁는다),
// sitemap 이나 외부 링크로 API URL 이 노출됐을 때 403 이 쌓이지 않게 한다.
// UA 는 위조 가능하므로 "허용"이지 "인증"이 아니다 — 읽기(GET)에만 적용한다.
const SEARCH_BOT_UA = /(googlebot|bingbot|yeti|daum(oa)?|naverbot|duckduckbot|applebot)/i;

function isSearchBot(req) {
  return req.method === 'GET' && SEARCH_BOT_UA.test(req.headers['user-agent'] || '');
}

/**
 * 호출 허용 여부 판정.
 * @returns {{allowed: boolean, via: string, origin: string|null}}
 */
export function checkAccess(req) {
  if (hasValidApiKey(req)) return { allowed: true, via: 'api-key', origin: null };

  const origin = requestOrigin(req);
  if (isAllowedOrigin(origin)) return { allowed: true, via: 'origin', origin };

  // Referrer-Policy 설정이나 브라우저 정책 때문에 Referer 가 잘려 오는 경우가 있다.
  // Sec-Fetch-Site 는 브라우저가 항상 붙이고 스크립트로 덮어쓸 수 없으므로 보조 신호로 쓴다.
  if (req.headers['sec-fetch-site'] === 'same-origin') {
    return { allowed: true, via: 'sec-fetch-site', origin };
  }

  if (isSearchBot(req)) return { allowed: true, via: 'search-bot', origin };

  return { allowed: false, via: 'blocked', origin };
}
