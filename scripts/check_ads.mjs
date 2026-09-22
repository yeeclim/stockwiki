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
import { spawn } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const URL_ARG = process.argv.find((a) => a.startsWith('http')) ?? 'https://stockwiki.vercel.app/';
const KEEP = process.argv.includes('--keep');
const PORT = 9300 + Math.floor(Math.random() * 300);
const WATCH_SECONDS = 25;

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
  ], { stdio: 'ignore', detached: false });
  return child;
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
const ws = new WebSocket(await debuggerUrl());
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

console.log(`점검 대상: ${URL_ARG}\n${WATCH_SECONDS}초 관찰 — DOM 이 바뀔 때만 출력한다.\n`);

let last = null;
const statuses = new Set();
for (let t = 1; t <= WATCH_SECONDS; t++) {
  await sleep(1000);
  const raw = await evaluate(SNAPSHOT);
  if (raw === last) continue;
  last = raw;
  for (const ins of JSON.parse(raw)) {
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
if (mine.length === 0) {
  console.log('✗ 우리 슬롯으로 광고 요청이 안 나갔다. AdBanner 가 안 붙었거나 슬롯 ID 가 비었다.');
} else if ([...statuses].some((s) => s.includes('filled') && !s.includes('unfilled'))) {
  console.log('✓ 광고가 채워졌다(filled).');
} else {
  console.log('△ 요청은 정상, 구글이 아직 안 채운다(unfilled). 신규 슬롯이면 며칠 걸린다.');
}

ws.close();
if (!KEEP) chrome.kill();
