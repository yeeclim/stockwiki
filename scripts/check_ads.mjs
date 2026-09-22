#!/usr/bin/env node
/**
 * AdSense 광고 게재 점검 스크립트.
 *
 * 배포된 사이트를 헤드리스 크롬으로 열어, 우리 AdBanner 가 실제로
 * <ins class="adsbygoogle"> 를 DOM 에 붙이고 광고 요청까지 보내는지,
 * 구글이 광고를 채우는지(filled) 못 채우는지(unfilled) 를 확인한다.
 *
 * Flutter 웹은 화면이 캔버스라 개발자도구로 눈으로 보기 어렵고, 광고는
 * 보는 사람마다 달라서 "직접 들어가 보기" 로는 판정이 안 된다. 그래서
 * DOM 속성과 네트워크 요청을 직접 읽는다.
 *
 * 사용법:
 *   node scripts/check_ads.mjs [url] [--keep]
 *
 *   url      점검할 주소 (기본 https://stockwiki.vercel.app/)
 *   --keep   끝나고 크롬을 닫지 않는다 (직접 더 들여다볼 때)
 *
 * 주의: 자기 사이트를 여는 것은 정책상 문제없지만 광고 클릭은 금지다.
 *       이 스크립트는 클릭하지 않는다.
 */
import { spawn, spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const URL_ARG = process.argv.find((a) => a.startsWith('http')) ?? 'https://stockwiki.vercel.app/';
const KEEP = process.argv.includes('--keep');
const PORT = 9300 + Math.floor(Math.random() * 300);
const WATCH_SECONDS = 25;
const BOOT_SECONDS = 30;

/** 우리 광고 단위. 중복 관리를 피하려고 ads_config.dart 에서 직접 읽는다. */
const SLOTS = [
  ...new Set(
    readFileSync(new URL('../lib/config/ads_config.dart', import.meta.url), 'utf8')
      .matchAll(/static const String \w+ = '(\d{6,})';/g),
  ),
].map((m) => m[1]);
if (SLOTS.length === 0) throw new Error('ads_config.dart 에서 슬롯 ID 를 못 읽었다.');

const CHROME_CANDIDATES = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
];

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function launchChrome() {
  const bin = CHROME_CANDIDATES.find((p) => existsSync(p));
  if (!bin) throw new Error('크롬을 찾지 못했다. CHROME_CANDIDATES 에 경로를 추가해라.');
  const profile = mkdtempSync(join(tmpdir(), 'adcheck-'));
  const child = spawn(bin, [
    '--headless=new',
    '--disable-gpu',
    '--no-first-run',
    '--no-default-browser-check',
    `--remote-debugging-port=${PORT}`,
    `--user-data-dir=${profile}`,
    '--window-size=1280,1600',
    'about:blank',
  ], { stdio: 'ignore', detached: process.platform !== 'win32' });
  return child;
}

/**
 * 크롬은 렌더러·GPU 를 자식 프로세스로 띄운다. 부모만 kill 하면 자식이 남아
 * 다음 실행 때 디버깅 포트를 못 잡는다. 트리째 정리한다.
 */
function killTree(child) {
  if (!child?.pid) return;
  if (process.platform === 'win32') {
    spawnSync('taskkill', ['/pid', String(child.pid), '/T', '/F'], { stdio: 'ignore' });
  } else {
    try { process.kill(-child.pid, 'SIGKILL'); } catch { child.kill('SIGKILL'); }
  }
}

async function debuggerUrl() {
  for (let i = 0; i < 60; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json();
      const page = list.find((t) => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch { /* 아직 안 떴다 */ }
    await sleep(500);
  }
  throw new Error('크롬 디버깅 포트에 붙지 못했다.');
}

/** shadow DOM 까지 재귀로 훑는다. Flutter 플랫폼 뷰가 glass-pane 섀도우 안에 있다. */
const SNAPSHOT = `(() => {
  const all = [];
  const walk = (root) => {
    for (const el of root.querySelectorAll('*')) {
      all.push(el);
      if (el.shadowRoot) walk(el.shadowRoot);
    }
  };
  walk(document);
  return JSON.stringify(
    all.filter((e) => e.tagName === 'INS' && e.classList.contains('adsbygoogle')).map((i) => ({
      slot: i.getAttribute('data-ad-slot'),
      status: i.getAttribute('data-ad-status'),
      pushed: i.getAttribute('data-adsbygoogle-status'),
      auto: i.hasAttribute('data-ad-hi'),
      w: i.offsetWidth,
      h: i.offsetHeight,
    })),
  );
})()`;

const chrome = launchChrome();
process.on('exit', () => { if (!KEEP) killTree(chrome); });
for (const sig of ['SIGINT', 'SIGTERM']) process.on(sig, () => process.exit(130));

let ws;
try {
  ws = new WebSocket(await debuggerUrl());
} catch (e) {
  killTree(chrome);
  throw e;
}
await new Promise((r) => ws.addEventListener('open', r, { once: true }));

let seq = 0;
const pending = new Map();
const adRequests = [];
ws.addEventListener('message', (e) => {
  const msg = JSON.parse(e.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
    return;
  }
  if (msg.method === 'Network.requestWillBeSent') {
    const url = msg.params.request.url;
    if (/doubleclick\.net\/pagead\/ads|\/pagead\/ads\?/.test(url)) adRequests.push(url);
  }
});

const send = (method, params = {}) =>
  new Promise((res) => {
    const id = ++seq;
    pending.set(id, res);
    ws.send(JSON.stringify({ id, method, params }));
  });

const evaluate = async (expression) => {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  return r.result.result.value;
};

await send('Page.enable');
await send('Runtime.enable');
await send('Network.enable');
await send('Page.navigate', { url: URL_ARG });

console.log(`점검 대상: ${URL_ARG}`);

// Flutter 앱이 첫 프레임을 그리기 전에는 AdBanner 자체가 존재하지 않는다.
// 부팅을 먼저 기다려야 "광고 요청이 없다" 는 오진을 안 한다.
const BOOT = `(() => JSON.stringify({
  flutter: !!document.querySelector('flt-glass-pane'),
  adScript: !!document.querySelector('script[src*="adsbygoogle.js"]'),
}))()`;
let booted = false;
for (let t = 1; t <= BOOT_SECONDS; t++) {
  await sleep(1000);
  const b = JSON.parse(await evaluate(BOOT));
  if (b.flutter) {
    booted = true;
    console.log(`앱 부팅 확인 (+${t}s) · adsbygoogle.js ${b.adScript ? '로드됨' : '없음'}`);
    break;
  }
}
if (!booted) console.log(`경고: ${BOOT_SECONDS}초 안에 Flutter 앱이 안 떴다.`);
console.log(`${WATCH_SECONDS}초 관찰 — DOM 이 바뀔 때만 출력한다.`);
console.log('');

let last = null;
let sawOurIns = false;
const statuses = new Set();
for (let t = 1; t <= WATCH_SECONDS; t++) {
  await sleep(1000);
  const raw = await evaluate(SNAPSHOT);
  if (raw === last) continue;
  last = raw;
  for (const ins of JSON.parse(raw)) {
    if (ins.slot && !ins.auto) sawOurIns = true;
    const who = ins.auto || !ins.slot ? '자동광고' : `슬롯 ${ins.slot}`;
    if (ins.status) statuses.add(`${who}=${ins.status}`);
    console.log(
      `[+${String(t).padStart(2)}s] ${who.padEnd(14)} ` +
        `크기=${ins.w}x${ins.h} push=${ins.pushed ?? '-'} 상태=${ins.status ?? '대기'}`,
    );
  }
  if (JSON.parse(raw).length === 0) console.log(`[+${String(t).padStart(2)}s] ins 없음 (접힘)`);
}

const mine = adRequests.filter((u) => SLOTS.some((s) => u.includes(s)));
console.log('\n── 광고 요청 ──────────────────────────────');
console.log(`전체 ${adRequests.length}건 · 우리 슬롯 ${mine.length}건`);
for (const u of mine) console.log('  ' + u.slice(0, 160));

console.log('\n── 판정 ──────────────────────────────────');
const filled = [...statuses].some((s) => s.includes('=filled'));
if (!booted) {
  console.log('? 앱이 안 떠서 판정 불가. 네트워크가 느렸을 수 있다. 다시 돌려봐라.');
} else if (!sawOurIns) {
  console.log('✗ 우리 <ins> 가 DOM 에 안 붙었다. AdBanner 미배치이거나 슬롯 ID 가 비었다.');
} else if (mine.length === 0) {
  console.log('✗ <ins> 는 붙었는데 광고 요청이 안 나갔다. push 실패이거나 차단기에 막혔다.');
} else if (filled) {
  console.log('✓ 광고가 채워졌다(filled).');
} else {
  console.log('△ 요청은 정상, 구글이 아직 안 채운다(unfilled). 신규 슬롯이면 며칠 걸린다.');
}

ws.close();
if (!KEEP) killTree(chrome);
