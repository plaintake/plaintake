#!/usr/bin/env node
/*
 * Static server for the quickstart tutorial pages — the one process `make quickstart-demo`
 * starts before recording. Zero dependencies on purpose: the recipe in README.md should be
 * runnable with nothing but node.
 *
 * Serves ./pages at the root, plus two virtual mounts so nothing derived is ever copied
 * into public/ (which syncs to the public repository and is pinned by an exact file list
 * in test/integration/release-docs.spec.ts):
 *
 *   /assets/fonts/NotoSans-Regular.ttf  -> <repo>/assets/fonts/NotoSans-Regular.ttf
 *   /assets/example-demo.mp4            -> <repo>/artifacts/release-approval/output/release-approval.mp4
 *
 * Usage: node serve.mjs [--port 4173]   (or QUICKSTART_PORT=…)
 */

import { createReadStream, existsSync, statSync } from 'node:fs';
import { createServer } from 'node:http';
import { extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = fileURLToPath(new URL('.', import.meta.url));
const REPO = resolve(HERE, '..', '..', '..');
const PAGES = join(HERE, 'pages');

const MOUNTS = new Map([
  ['/assets/fonts/NotoSans-Regular.ttf', join(REPO, 'assets', 'fonts', 'NotoSans-Regular.ttf')],
  ['/assets/example-demo.mp4', join(REPO, 'artifacts', 'release-approval', 'output', 'release-approval.mp4')],
]);

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.ttf': 'font/ttf',
  '.mp4': 'video/mp4',
};

const argv = process.argv.slice(2);
const portFlag = argv.indexOf('--port');
const port = Number(portFlag >= 0 ? argv[portFlag + 1] : process.env.QUICKSTART_PORT ?? 4173);

/** Resolve a request path to a file, or null. Only the docroot and the two exact mounts. */
function resolveFile(pathname) {
  const clean = pathname.split('?')[0].replace(/\/+$/, '') || '/install.html';
  if (MOUNTS.has(clean)) return MOUNTS.get(clean);
  if (!/^\/[\w.-]+$/.test(clean)) return null; // flat pages dir; rejects traversal
  const file = join(PAGES, clean.slice(1));
  return file.startsWith(PAGES) ? file : null;
}

function sendError(res, code, message) {
  res.writeHead(code, { 'content-type': 'text/plain; charset=utf-8' });
  res.end(message);
}

createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') return sendError(res, 405, 'GET only');

  let pathname;
  try {
    pathname = decodeURIComponent(new URL(req.url ?? '/', 'http://127.0.0.1').pathname);
  } catch {
    return sendError(res, 400, 'bad path');
  }

  const file = resolveFile(pathname);
  if (!file) return sendError(res, 404, 'not found');
  if (!existsSync(file)) {
    return pathname === '/assets/example-demo.mp4'
      ? sendError(res, 404, 'example video missing — run `make quickstart-demo` first')
      : sendError(res, 404, 'not found');
  }

  const { size } = statSync(file);
  const type = MIME[extname(file)] ?? 'application/octet-stream';

  // Minimal single-range support, enough for a <video> element that skips around.
  const range = req.headers.range;
  if (range && type === 'video/mp4') {
    const match = /^bytes=(\d*)-(\d*)$/.exec(range);
    if (!match) {
      res.writeHead(416, { 'content-range': `bytes */${size}` });
      return res.end();
    }
    const start = match[1] ? Number(match[1]) : 0;
    const end = match[2] ? Math.min(Number(match[2]), size - 1) : size - 1;
    if (start > end || start >= size) {
      res.writeHead(416, { 'content-range': `bytes */${size}` });
      return res.end();
    }
    res.writeHead(206, {
      'content-type': type,
      'content-length': end - start + 1,
      'content-range': `bytes ${start}-${end}/${size}`,
      'accept-ranges': 'bytes',
    });
    if (req.method === 'HEAD') return res.end();
    createReadStream(file, { start, end }).pipe(res);
    return;
  }

  res.writeHead(200, { 'content-type': type, 'content-length': size, 'accept-ranges': 'bytes' });
  if (req.method === 'HEAD') return res.end();
  createReadStream(file).pipe(res);
}).listen(port, '127.0.0.1', () => {
  process.stdout.write(`quickstart pages on http://127.0.0.1:${port}\n`);
});
