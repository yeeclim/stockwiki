import { applyCors } from '../api/_shared.js';
import { readdirSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const NL = '\n';
const CACHE_RE = /setHeader\(\s*['"]Cache-Control['"]\s*,\s*['"]([^'"]*)/i;
const SHARED_RE = /s-maxage|\bpublic\b/i;

function mkRes() {
  const r = { headers: {}, code: null, body: null, ended: false };
  r.setHeader = (k, v) => { r.headers[k.toLowerCase()] = v; };
  r.status = (c) => { r.code = c; return r; };
  r.json = (b) => { r.body = b; r.ended = true; return r; };
  r.end = () => { r.ended = true; return r; };
  return r;
}
function mkReq(headers = {}, { method = 'GET', query = {} } = {}) {
  return { method, headers, query, socket: { remoteAddress: '203.0.113.' + Math.floor(Math.random()*250) } };
}

let pass = 0, fail = 0;
function t(name, actual, expected) {
  const okv = actual === expected;
  okv ? pass++ : fail++;
  console.log(`${okv ? 'PASS' : 'FAIL'}  ${name}  (got ${actual}, want ${expected})`);
}

// 1. 우리 웹앱 (같은 출처: Origin 없고 Referer 있음)
let req = mkReq({ referer: 'https://stockwiki.vercel.app/?stock=005930' });
let res = mkRes();
t('자사 웹앱 same-origin 허용', applyCors(req, res), false);
t('  └ ACAO 에코', res.headers['access-control-allow-origin'], 'https://stockwiki.vercel.app');

// 2. 외부 사이트에서 fetch
req = mkReq({ origin: 'https://evil-scraper.com', referer: 'https://evil-scraper.com/' });
res = mkRes();
t('외부 웹사이트 차단', applyCors(req, res), true);
t('  └ 403', res.code, 403);
t('  └ ACAO 미설정', res.headers['access-control-allow-origin'], undefined);

// 3. curl (헤더 전무)
req = mkReq({ 'user-agent': 'curl/8.0' });
res = mkRes();
t('생 curl 차단', applyCors(req, res), true);
t('  └ 403', res.code, 403);

// 4. AI 에이전트 UA
req = mkReq({ 'user-agent': 'python-requests/2.31' });
res = mkRes();
t('스크래핑 스크립트 차단', applyCors(req, res), true);

// 5. API 키 보유자
process.env.API_KEYS = 'sk_live_abc123,sk_live_def456';
req = mkReq({ 'user-agent': 'curl/8.0', 'x-api-key': 'sk_live_def456' });
res = mkRes();
t('유효한 API 키 허용', applyCors(req, res), false);

req = mkReq({ 'user-agent': 'curl/8.0', 'x-api-key': 'wrong-key' });
res = mkRes();
t('틀린 API 키 차단', applyCors(req, res), true);

// 6. 쿼리스트링 API 키
req = mkReq({ 'user-agent': 'curl/8.0' }, { query: { api_key: 'sk_live_abc123' } });
res = mkRes();
t('쿼리스트링 API 키 허용', applyCors(req, res), false);

// 7. 검색엔진
req = mkReq({ 'user-agent': 'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)' });
res = mkRes();
t('Googlebot GET 허용', applyCors(req, res), false);

req = mkReq({ 'user-agent': 'Mozilla/5.0 (compatible; Yeti/1.1; +http://naver.me/spd)' });
res = mkRes();
t('네이버 Yeti 허용', applyCors(req, res), false);

req = mkReq({ 'user-agent': 'Googlebot' }, { method: 'POST' });
res = mkRes();
t('Googlebot POST 차단(쓰기 금지)', applyCors(req, res, { methods: 'POST, OPTIONS' }), true);

// 8. AI 크롤러는 이제 막힘
req = mkReq({ 'user-agent': 'Mozilla/5.0 (compatible; GPTBot/1.2; +https://openai.com/gptbot)' });
res = mkRes();
t('GPTBot 차단', applyCors(req, res), true);

// 9. Sec-Fetch-Site 보조 신호
req = mkReq({ 'sec-fetch-site': 'same-origin' });
res = mkRes();
t('Sec-Fetch-Site same-origin 허용', applyCors(req, res), false);

req = mkReq({ 'sec-fetch-site': 'cross-site', origin: 'https://evil.com' });
res = mkRes();
t('Sec-Fetch-Site cross-site 차단', applyCors(req, res), true);

// 10. 프리뷰 배포 / 로컬
req = mkReq({ referer: 'https://stockwiki-git-dev-abc.vercel.app/' });
res = mkRes();
t('Vercel 프리뷰 배포 허용', applyCors(req, res), false);

req = mkReq({ origin: 'http://localhost:3000' });
res = mkRes();
t('로컬 개발 허용', applyCors(req, res), false);

req = mkReq({ origin: 'https://other-project.vercel.app' });
res = mkRes();
t('무관한 vercel.app 차단', applyCors(req, res), true);

// 11. publicAccess (수신거부)
req = mkReq({ 'user-agent': 'Outlook' });
res = mkRes();
t('수신거부 경로는 공개', applyCors(req, res, { publicAccess: true }), false);

// 12. 커스텀 도메인
process.env.ALLOWED_ORIGINS = 'https://stockwiki.co.kr';
req = mkReq({ origin: 'https://stockwiki.co.kr' });
res = mkRes();
t('ALLOWED_ORIGINS 커스텀 도메인 허용', applyCors(req, res), false);

// 13. OPTIONS 프리플라이트
req = mkReq({ origin: 'https://stockwiki.vercel.app' }, { method: 'OPTIONS' });
res = mkRes();
t('OPTIONS 프리플라이트 종료', applyCors(req, res), true);
t('  └ 200', res.code, 200);

// 14. Rate limit — 같은 IP 로 130회
const ip = '198.51.100.7';
let blocked = 0;
for (let i = 0; i < 130; i++) {
  const rq = mkReq({ referer: 'https://stockwiki.vercel.app/', 'x-forwarded-for': ip });
  const rs = mkRes();
  if (applyCors(rq, rs) && rs.code === 429) blocked++;
}
t('130회 중 429 차단 수', blocked, 10);

// 15. 공유 캐시 금지 — 정상 응답이 CDN 에 캐시되면 인증 없는 요청에 HIT 으로 흘러간다.
//     실제 운영에서 X-Vercel-Cache: HIT 으로 403 이 우회되는 것을 확인했다.
req = mkReq({ referer: 'https://stockwiki.vercel.app/' });
res = mkRes();
applyCors(req, res);
t('허용 응답은 공유 캐시 금지', res.headers['cache-control'], 'private, no-store');

req = mkReq({ 'user-agent': 'Outlook' });
res = mkRes();
applyCors(req, res, { publicAccess: true });
t('공개 경로는 캐시 헤더 미설정', res.headers['cache-control'], undefined);

// 16. 핸들러가 applyCors 의 private, no-store 를 공유 캐시 지시어로 덮어쓰지 못하게 한다.
//     단위 테스트로는 못 잡는다 — 핸들러는 applyCors 다음에 헤더를 덮어쓰기 때문이다.
//     실제로 kr-stock-search 의 s-maxage=30 이 인증을 우회시켜 종목 데이터가 유출됐다.
const apiDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'api');
const offenders = readdirSync(apiDir)
  .filter((f) => f.endsWith('.js'))
  .filter((f) => {
    const src = readFileSync(join(apiDir, f), 'utf8');
    return src
      .split(NL)
      .filter((line) => !line.trim().startsWith('//'))
      .some((line) => {
        const m = line.match(CACHE_RE);
        return m ? SHARED_RE.test(m[1]) : false;
      });
  });
t('공유 캐시 지시어를 쓰는 핸들러 수 [' + (offenders.join(', ') || '없음') + ']', offenders.length, 0);

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
