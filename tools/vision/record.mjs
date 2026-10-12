#!/usr/bin/env node
/**
 * Last-Space Vision Record Tool — REKAM LAYAR PER FRAME.
 *
 * Headless Chromium (@sparticuz/chromium, SwiftShader software GL — sama dengan
 * semua suite QA) merekam setiap frame via CDP Page.startScreencast.
 * Untuk QA visual frame-by-frame (koreksi human: verifikasi berdasarkan data
 * nyata, bukan asumsi) — misal: tidak ada frame blank/glitch, transisi UI
 * terdeteksi, animasi jalan.
 *
 * Usage:
 *   node record.mjs <url> <outdir> [width] [height] [duration_ms] [options]
 *
 *   <url>          http(s):// URL atau root-relative ("/index.html?mode=ui")
 *   <outdir>       direktori output frame (frame_0001.jpg, dst + report.json)
 *   [width]        viewport width  (default 1280)
 *   [height]       viewport height (default 720)
 *   [duration_ms]  lama perekaman setelah settle (default 10000)
 *
 * Options:
 *   --serve <dir>      serve <dir> over HTTP on 127.0.0.1 (ephemeral port)
 *   --wait-for <re>    tunggu console log match <re> sebelum rekam
 *   --wait-until <m>   domcontentloaded (default) | load
 *   --settle <ms>      diam setelah wait-for sebelum rekam (default 500)
 *   --timeout <ms>     max wait page load / wait-for (default 90000)
 *   --format <f>       jpeg (default, quality 80) | png
 *   --every <n>        salin setiap N frame ke <outdir>/sampled/ (default 5)
 */
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, mkdirSync, statSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';

const args = process.argv.slice(2);
const flags = {};
const positional = [];
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith('--')) {
    flags[args[i].slice(2)] = args[i + 1];
    i++;
  } else {
    positional.push(args[i]);
  }
}

const [target, outdir, w = '1280', h = '720', durationMs = '10000'] = positional;
if (!target || !outdir) {
  console.error('Usage: node record.mjs <url> <outdir> [width] [height] [duration_ms] [--serve dir] [--wait-for re] [--settle ms] [--format jpeg|png] [--every n]');
  process.exit(2);
}
const waitFor = flags['wait-for'] || null;
const waitUntil = flags['wait-until'] || 'domcontentloaded';
const settle = Number(flags['settle'] || 500);
const timeout = Number(flags['timeout'] || 90000);
const format = flags['format'] || 'jpeg';
const every = Number(flags['every'] || 5);
const ext = format === 'png' ? 'png' : 'jpg';
const W = Number(w), H = Number(h), DUR = Number(durationMs);

// --- optional static server (sama seperti capture.mjs) ----------------------
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.json': 'application/json',
  '.css': 'text/css; charset=utf-8',
  '.ico': 'image/x-icon',
};
let server = null;
let baseUrl = null;
if (flags['serve']) {
  const root = flags['serve'];
  server = createServer((req, res) => {
    try {
      const path = normalize(join(root, decodeURIComponent(req.url.split('?')[0])));
      if (!path.startsWith(normalize(root))) {
        res.writeHead(403).end('forbidden');
        return;
      }
      const data = readFileSync(path);
      res.writeHead(200, { 'content-type': MIME[extname(path)] || 'application/octet-stream' });
      res.end(data);
    } catch {
      res.writeHead(404).end('not found');
    }
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
}

const url = /^https?:\/\//.test(target)
  ? target
  : baseUrl && target.startsWith('/')
    ? baseUrl + target
    : 'file://' + (target.startsWith('/') ? target : process.cwd() + '/' + target);

mkdirSync(outdir, { recursive: true });
mkdirSync(join(outdir, 'sampled'), { recursive: true });

const executablePath = await chromium.executablePath();
const browser = await puppeteer.launch({
  args: [...chromium.args, '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  executablePath,
  headless: chromium.headless,
  // device class: W×H = CSS px (= dp Android), dpr = device px/CSS px
  defaultViewport: { width: W, height: H, deviceScaleFactor: Number(flags['dpr'] || 2) },
});
const page = await browser.newPage();
const consoleLogs = [];
const pageErrors = [];
page.on('console', (msg) => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));
page.on('pageerror', (err) => pageErrors.push(String(err)));

await page.goto(url, { waitUntil, timeout });

// tunggu marker (opsional)
let waitForMatched = false;
if (waitFor) {
  const re = new RegExp(waitFor);
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (consoleLogs.some((l) => re.test(l))) {
      waitForMatched = true;
      break;
    }
    await new Promise((r) => setTimeout(r, 100));
  }
}
if (settle > 0) {
  await new Promise((r) => setTimeout(r, settle));
}

// --- rekam per frame via CDP screencast --------------------------------------
const client = await page.target().createCDPSession();
await client.send('Page.enable');
let frameIdx = 0;
let firstTs = null;
let lastTs = null;
client.on('Page.screencastFrame', (ev) => {
  frameIdx++;
  const ts = ev.metadata && ev.metadata.timestamp ? ev.metadata.timestamp : Date.now() / 1000;
  if (firstTs === null) firstTs = ts;
  lastTs = ts;
  const name = `frame_${String(frameIdx).padStart(4, '0')}.${ext}`;
  writeFileSync(join(outdir, name), Buffer.from(ev.data, 'base64'));
  if (frameIdx % every === 0) {
    writeFileSync(join(outdir, 'sampled', name), Buffer.from(ev.data, 'base64'));
  }
  client.send('Page.screencastFrameAck', { sessionId: ev.sessionId }).catch(() => {});
});
await client.send('Page.startScreencast', {
  format,
  quality: format === 'jpeg' ? 80 : undefined,
  everyNthFrame: 1,
  maxWidth: W,
  maxHeight: H,
});
const t0 = Date.now();
await new Promise((r) => setTimeout(r, DUR));
await client.send('Page.stopScreencast').catch(() => {});
const wallMs = Date.now() - t0;

const bytes = consoleLogs.join('\n');
const report = {
  tool: '@sparticuz/chromium + puppeteer-core (CDP Page.startScreencast)',
  chromiumVersion: await browser.version(),
  target: url,
  viewport: { width: W, height: H },
  gl: 'ANGLE (SwiftShader) — sama dengan semua suite QA',
  format,
  waitFor,
  waitForMatched,
  durationMs: DUR,
  wallMs,
  frames: frameIdx,
  fps: frameIdx / (wallMs / 1000.0),
  firstFrameTs: firstTs,
  lastFrameTs: lastTs,
  spanSeconds: firstTs !== null && lastTs !== null ? lastTs - firstTs : null,
  pageErrors,
  consoleLogLines: consoleLogs.length,
  sampledEvery: every,
  outputDir: outdir,
};
writeFileSync(join(outdir, 'report.json'), JSON.stringify(report, null, 1));
console.log(`RECORD: frames=${frameIdx} wall=${wallMs}ms fps=${report.fps.toFixed(1)} -> ${outdir}`);
console.log(`RECORD: waitForMatched=${waitForMatched} pageErrors=${pageErrors.length}`);

await browser.close();
if (server) server.close();
process.exit(pageErrors.length > 0 ? 1 : 0);
