#!/usr/bin/env node
/**
 * Last-Space Vision Capture Tool
 *
 * Headless Chromium (via the @sparticuz/chromium npm package) driven by
 * puppeteer-core. Captures a screenshot ("vision" evidence) of a page —
 * typically a Godot web build served locally — plus console logs and page
 * metadata, and writes a JSON report next to the PNG.
 *
 * Usage:
 *   node capture.mjs <url> <output.png> [width] [height] [options]
 *
 *   <url>          http(s):// URL, a local file path, or a root-relative
 *                  path ("/index.html") when --serve is used.
 *   <output.png>   screenshot destination (a .json report is written beside it)
 *   [width]        viewport width  (default 1280)
 *   [height]       viewport height (default 720)
 *
 * Options:
 *   --serve <dir>      serve <dir> over HTTP on 127.0.0.1 (ephemeral port)
 *   --wait-for <re>    wait until a console log line matches <re> before the
 *                      screenshot (default: none)
 *   --timeout <ms>     max wait for page load / --wait-for (default 60000)
 *   --throttle <n>     emulate CPU class via CDP Emulation.setCPUThrottlingRate
 *                      (1 = no throttle; 4 ≈ mid-tier mobile; 6 ≈ low-end
 *                      budget device) — for device-class perf measurement
 */
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import { createServer } from 'node:http';
import { readFileSync, statSync } from 'node:fs';
import { extname, join, normalize, dirname } from 'node:path';
import { writeFileSync, mkdirSync } from 'node:fs';

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

const [target, out, w = '1280', h = '720'] = positional;
if (!target || !out) {
  console.error('Usage: node capture.mjs <url> <output.png> [width] [height] [--serve dir] [--wait-for regex] [--timeout ms]');
  process.exit(2);
}
const waitFor = flags['wait-for'] || null;
const timeout = Number(flags['timeout'] || 60000);
const waitUntil = flags['wait-until'] || 'networkidle0';

// --- optional static server (Godot web builds need HTTP, not file://) ------
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

const executablePath = await chromium.executablePath();
const browser = await puppeteer.launch({
  args: [...chromium.args, '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  executablePath,
  headless: chromium.headless,
  defaultViewport: { width: Number(w), height: Number(h), deviceScaleFactor: 1 },
});
const page = await browser.newPage();
// Emulasi device class: CPU throttling (data nyata untuk keputusan device class,
// DEV_PLAN M2 #5). 1 = tanpa throttle (baseline sandbox).
const throttle = Number(flags['throttle'] || 1);
if (throttle > 1) {
  const client = await page.target().createCDPSession();
  await client.send('Emulation.setCPUThrottlingRate', { rate: throttle });
}
const consoleLogs = [];
page.on('console', (msg) => consoleLogs.push(`[${msg.type()}] ${msg.text()}`));
const pageErrors = [];
page.on('pageerror', (err) => pageErrors.push(String(err)));

await page.goto(url, { waitUntil: waitUntil, timeout });

if (waitFor) {
  const pattern = new RegExp(waitFor);
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    if (consoleLogs.some((line) => pattern.test(line))) break;
    if (pageErrors.length > 0 && pattern.test(pageErrors.join('\n'))) break;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  // give the first rendered frames a moment to land
  const settle = Number(flags["settle"] || 1000);
  await new Promise((resolve) => setTimeout(resolve, settle));
}

mkdirSync(dirname(out), { recursive: true });
await page.screenshot({ path: out });

// Read PNG dimensions from IHDR (bytes 16..24) as lightweight vision evidence
const buf = readFileSync(out);
const isPng = buf.subarray(1, 4).toString() === 'PNG';
const width = buf.readUInt32BE(16);
const height = buf.readUInt32BE(20);

const report = {
  tool: '@sparticuz/chromium + puppeteer-core',
  chromiumVersion: await browser.version(),
  target: url,
  cpuThrottle: throttle,
  servedFrom: baseUrl || null,
  output: out,
  png: { valid: isPng, width, height, bytes: buf.length },
  pageTitle: await page.title(),
  userAgent: await page.evaluate(() => navigator.userAgent),
  webgl: await page.evaluate(() => {
    const canvas = document.createElement('canvas');
    const gl = canvas.getContext('webgl2');
    if (!gl) return { webgl2: false };
    const dbg = gl.getExtension('WEBGL_debug_renderer_info');
    return {
      webgl2: true,
      vendor: gl.getParameter(dbg ? dbg.UNMASKED_VENDOR_WEBGL : gl.VENDOR),
      renderer: gl.getParameter(dbg ? dbg.UNMASKED_RENDERER_WEBGL : gl.RENDERER),
    };
  }),
  waitFor: waitFor || null,
  waitForMatched: waitFor ? consoleLogs.some((line) => new RegExp(waitFor).test(line)) : null,
  consoleLogs,
  pageErrors,
  metrics: await page.metrics(), // JSHeapUsedSize, JSHeapTotalSize, Nodes, ... (data nyata dari Chromium)
};
await browser.close();
if (server) server.close();
writeFileSync(out + '.json', JSON.stringify(report, null, 2));
console.log(JSON.stringify(report, null, 2));
