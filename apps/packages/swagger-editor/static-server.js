// Minimal static file server for the Swagger Editor single-page build.
//
// Listens on 127.0.0.1 for the Sandstorm HTTP bridge (plain HTTP; the bridge
// terminates the grain's network). Serves the upstream Vite build directory
// with correct MIME types — including application/wasm for the tree-sitter
// parsers the editor loads at runtime. Browser edits live in the session; the
// grain's specification lives server-side at /editor/spec (PUT replaces,
// GET reads back), the role the 2016 Sandstorm port's service played. It is
// stored under /var so it survives restarts, and the editor can load it with
// /?url=/editor/spec.
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = Number(process.env.PORT || 9001);
const DOCROOT = process.env.DOCROOT || '/opt/app/swagger-editor';
const SPEC_PATH = process.env.SPEC_PATH || '/var/spec.yaml';
const SPEC_MAX_BYTES = 1048576; // mirrors the interface declaration's yaml bound

const TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
  '.md': 'text/markdown; charset=utf-8',
  '.wasm': 'application/wasm',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.webmanifest': 'application/manifest+json',
};

const fail = (res, status, text, extra) => {
  res.writeHead(status, { 'content-type': 'text/plain', ...extra });
  res.end(text + '\n');
};

const specStore = (req, res) => {
  if (req.method === 'PUT') {
    const chunks = [];
    let size = 0;
    let refused = false;
    req.on('data', (chunk) => {
      if (refused) return;
      size += chunk.length;
      if (size > SPEC_MAX_BYTES) {
        refused = true;
        fail(res, 413, 'spec over bound', { allow: 'GET, PUT' }); // answer; the rest drains unread
        return;
      }
      chunks.push(chunk);
    });
    req.on('error', () => {}); // a client that vanishes mid-body must not kill the grain
    req.on('end', () => {
      if (refused) return;
      try {
        fs.mkdirSync(path.dirname(SPEC_PATH), { recursive: true });
        const tmp = SPEC_PATH + '.tmp';
        fs.writeFileSync(tmp, Buffer.concat(chunks));
        fs.renameSync(tmp, SPEC_PATH); // readers never see a torn spec
      } catch (e) {
        fail(res, 500, 'spec write failed', { allow: 'GET, PUT' });
        return;
      }
      res.writeHead(204, { allow: 'GET, PUT', 'cache-control': 'no-store' });
      res.end();
    });
    return;
  }
  if (req.method === 'GET' || req.method === 'HEAD') {
    let data;
    try {
      data = fs.readFileSync(SPEC_PATH);
    } catch (e) {
      fail(res, 404, 'no spec stored', { allow: 'GET, PUT' });
      return;
    }
    const headers = {
      'content-type': 'application/yaml',
      'content-length': data.length,
      'cache-control': 'no-store',
    };
    res.writeHead(200, headers);
    req.method === 'HEAD' ? res.end() : res.end(data);
    return;
  }
  fail(res, 405, 'method not allowed', { allow: 'GET, PUT' });
};

const server = http.createServer((req, res) => {
  let urlPath;
  try {
    urlPath = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  } catch (e) {
    res.writeHead(400, { 'content-type': 'text/plain' });
    res.end('bad request\n');
    return;
  }
  if (urlPath === '/editor/spec') {
    specStore(req, res);
    return;
  }
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    fail(res, 405, 'method not allowed', { allow: 'GET, HEAD' });
    return;
  }
  if (urlPath === '/') urlPath = '/index.html';
  const resolved = path.normalize(path.join(DOCROOT, urlPath));
  if (resolved !== DOCROOT && !resolved.startsWith(DOCROOT + path.sep)) {
    res.writeHead(403, { 'content-type': 'text/plain' });
    res.end('forbidden\n');
    return;
  }
  fs.stat(resolved, (err, st) => {
    if (err || !st.isFile()) {
      res.writeHead(404, { 'content-type': 'text/plain' });
      res.end('not found\n');
      return;
    }
    const ext = path.extname(resolved).toLowerCase();
    const headers = {
      'content-type': TYPES[ext] || 'application/octet-stream',
      'content-length': st.size,
      // Hashed Vite assets are immutable; everything else revalidates.
      'cache-control': urlPath.startsWith('/assets/')
        ? 'public, max-age=31536000, immutable'
        : 'no-cache',
    };
    if (req.method === 'HEAD') {
      res.writeHead(200, headers);
      res.end();
      return;
    }
    res.writeHead(200, headers);
    fs.createReadStream(resolved).on('error', () => res.destroy()).pipe(res);
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`swagger-editor static server on 127.0.0.1:${PORT}, docroot ${DOCROOT}`);
});
