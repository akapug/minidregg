#!/usr/bin/env node
// FOUC check: a CPU-throttled, slow-network filmstrip of first paints, light and dark, for the
// Mini web front end (the real gateway in --dev, with the real page shell and assets) and the
// project site (website/, served statically). For every page it asserts
//   1. no light flash in dark mode (no painted frame brighter than the dark page),
//   2. the first painted frame already has the settled chrome (header band and rail: background,
//      fonts and layout), compared pixel-wise with the settled screenshot, and, on pages that do not
//      fill in afterwards, the whole viewport within 0.5% of settled,
//   3. cumulative layout shift under 0.02 (PerformanceObserver `layout-shift`),
// and, for the pages that must work without JavaScript, that the no-JS first frame has the same
// chrome as the JS one.
//
//   node scripts/check-fouc.mjs [--only app|site] [--bin-dir DIR] [--cpu 4] [--out DIR] [--keep]
//
// App needs the built binaries `mini-web` and `mini-web-spawn` (default: $CARGO_TARGET_DIR/debug or
// ./target/debug). Body pages that need a Host (grants, purse meter) are fixtures: the real shell
// from the real gateway, a stage written here in the body's own markup, fragments answered slowly.
// Every process started is stopped by the PID in its PID file, and only that.
import { spawn } from "node:child_process";
import { createHash, randomBytes } from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const PW = process.env.PLAYWRIGHT_PATH || "/Users/ember/tools/playwright/node_modules/playwright/index.mjs";
const { chromium } = await import(PW);

const args = process.argv.slice(2);
const opt = (name, dflt) => { const i = args.indexOf(`--${name}`); return i < 0 ? dflt : (args[i + 1] ?? true); };
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ONLY = opt("only", "all");
const CPU = Number(opt("cpu", 4));
const BIN = opt("bin-dir", path.join(process.env.CARGO_TARGET_DIR || path.join(ROOT, "target"), "debug"));
const OUT = path.resolve(opt("out", fs.mkdtempSync(path.join(os.tmpdir(), "fouc-out-"))));
const KEEP = args.includes("--keep");
const CLS_MAX = 0.02;
fs.mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------- processes (PID files only)
const pidFiles = [];
function start(name, cmd, argv, extra = {}) {
  const log = fs.openSync(path.join(OUT, `${name}.log`), "w");
  const child = spawn(cmd, argv, { stdio: ["ignore", log, log], ...extra });
  const pidFile = path.join(OUT, `${name}.pid`);
  fs.writeFileSync(pidFile, String(child.pid));
  pidFiles.push(pidFile);
  return child;
}
function stopAll() {
  for (const f of pidFiles.reverse()) {
    try { process.kill(Number(fs.readFileSync(f, "utf8")), "SIGTERM"); } catch { /* already gone */ }
  }
}
process.on("exit", stopAll);
const freePort = () => new Promise((res) => { const s = http.createServer().listen(0, "127.0.0.1", () => { const p = s.address().port; s.close(() => res(p)); }); });
async function waitFor(fn, what, ms = 20000) {
  const t = Date.now();
  while (Date.now() - t < ms) { try { if (await fn()) return; } catch { /* retry */ } await new Promise((r) => setTimeout(r, 100)); }
  throw new Error(`timed out waiting for ${what}`);
}
const get = (port, p, headers = {}) => new Promise((res, rej) => {
  http.get({ host: "127.0.0.1", port, path: p, headers }, (r) => { let b = ""; r.on("data", (d) => (b += d)); r.on("end", () => res({ status: r.statusCode, headers: r.headers, body: b })); }).on("error", rej);
});
const post = (port, p, headers, body) => new Promise((res, rej) => {
  const r = http.request({ host: "127.0.0.1", port, path: p, method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded", "Content-Length": Buffer.byteLength(body), ...headers } },
    (x) => { let b = ""; x.on("data", (d) => (b += d)); x.on("end", () => res({ status: x.statusCode, headers: x.headers, body: b })); });
  r.on("error", rej); r.end(body);
});

// ---------------------------------------------------------------- the app under test
async function startApp() {
  for (const b of ["mini-web", "mini-web-spawn"]) if (!fs.existsSync(path.join(BIN, b))) throw new Error(`${b} not found in ${BIN} (--bin-dir)`);
  const scratch = fs.mkdtempSync(path.join(os.tmpdir(), "fouc-app-"));
  const run = fs.mkdtempSync("/tmp/fouc"); // a unix socket path must stay short
  fs.mkdirSync(path.join(scratch, "state"), { recursive: true });
  fs.mkdirSync(path.join(scratch, "home"));
  const wrapper = path.join(scratch, "wrapper.sh");
  fs.writeFileSync(wrapper, "#!/bin/sh\nprintf 'mini> '\nwhile IFS= read -r line; do\n  case \"$line\" in exit) exit 0;; *) printf '\\r\\nmini> ';; esac\ndone\n", { mode: 0o700 });
  const tool = fs.existsSync("/usr/bin/true") ? "/usr/bin/true" : "/bin/true";
  const config = path.join(scratch, "dev.json");
  fs.writeFileSync(config, JSON.stringify({ mini: tool, host: tool, config: "/dev/null", socket: "/dev/null", wrapper, sessions: { alice: { workspace: `${scratch}/ws`, home: `${scratch}/home` } } }));
  const sock = path.join(run, "spawn.sock");
  start("helper", path.join(BIN, "mini-web-spawn"), ["--dev", config, "--socket", sock, "--state", path.join(scratch, "state"), "--run", run]);
  const port = await freePort();
  const origin = `http://127.0.0.1:${port}`;
  start("gateway", path.join(BIN, "mini-web"), ["--listen", `127.0.0.1:${port}`, "--helper", sock, "--origin", origin, "--shutdown", "the end of this check"]);
  await waitFor(async () => fs.existsSync(sock) && (await get(port, "/healthz")).status === 200, "the gateway");
  const code = randomBytes(32).toString("base64url");
  const logins = path.join(scratch, "state/logins");
  await waitFor(async () => fs.existsSync(logins), "the logins directory");
  fs.writeFileSync(path.join(logins, `${createHash("sha256").update(code).digest("hex")}.json`), JSON.stringify({ name: "alice", expires: Math.floor(Date.now() / 1000) + 3600 }));
  const login = await post(port, "/login", { Origin: origin, "Sec-Fetch-Site": "same-origin" }, `code=${code}`);
  if (login.status !== 303) throw new Error(`login ${login.status}: ${login.body}`);
  const cookie = login.headers["set-cookie"][0].split(";")[0];
  const jar = { Cookie: cookie };
  const home = await get(port, "/sessions", jar);
  const csrf = /name="csrf" value="([^"]+)"/.exec(home.body)?.[1];
  const opened = await post(port, "/term", { ...jar, Origin: origin }, `csrf=${csrf}&cols=100&rows=30`);
  const termPath = opened.headers.location;
  return { port, origin, cookie, jar, csrf, termPath, scratch, run };
}

// Fixture stages in the body's own markup (native/resource-client/src/web/body.rs: grants, PURSE_LATER, purse_meter).
const refs = ["shared/alpha", "shared/beta", "shared/gamma", "w-1", "w-2", "w-3", "shared/delta", "shared/epsilon"];
const grantsStage = () => `<p>The grants you hold, as the Host's capability view names them, drawn as a tree; then what they cover, verb by verb, prepared and dry-run against the Host (<code>can --all</code>; nothing is submitted).</p>
<section class="grants"><h2>Capability tree</h2><ul class="tree"><li><span class="key">capability</span> <span class="val">observe</span></li><li><span class="key">scope</span> <span class="val">shared/*</span></li></ul></section>
<section><h2>What they cover</h2><p class="note">${refs.length} reference(s), each judged by its own dry run as the page fills; <code>can REF</code> in the shell is the same question for one.</p>
${refs.map((r) => `<section class="grant" data-load="/grants/judge/${r}"><h3><code>${r}</code></h3><div class="fill"><p class="note"><a href="/grants/judge/${r}">judge what my grants cover on ${r}</a></p></div></section>`).join("\n")}
</section>
<section><h2>Delegate</h2><form method="post" action="/grants/delegate" class="row"><div><label for="d-ref">Reference</label><input id="d-ref" name="ref" type="text"></div><button>Delegate</button></form></section>`;
const judged = (r) => `<div class="outcome answered" role="status"><p class="headline">${r}: observe, append</p><p class="note">dry run against the Host: admitted for observe; append within your ceiling.</p></div>`;
const purseStage = `<p>Your purse, and what the tour does with it.</p>
<section data-load="/purse/meter"><div class="fill"><p class="note"><a href="/purse">your purse, as a meter</a></p></div></section>
<h2>Next</h2><p>Open a document, append a line, and watch the meter.</p><table><thead><tr><th>step</th><th>what</th></tr></thead><tbody><tr><td>1</td><td>read</td></tr><tr><td>2</td><td>append</td></tr></tbody></table>`;
const purseMeter = `<section class="purse"><p class="big"><span class="n">1250</span> credits</p><meter min="0" max="1250" low="125" value="1250" aria-label="Purse balance: 1250 credits">1250</meter><p class="note">credit 1250 (account 7)</p></section>`;

function appPages(app) {
  const shell = async (pathname, title, stage, ctx) => {
    const r = await get(app.port, "/sessions", app.jar); // the real shell, from the real gateway
    return r.body
      .replace(/<title>[^<]*<\/title>/, `<title>${title} · Mini</title>`)
      .replace(/<body data-path="[^"]*">/, `<body data-path="${pathname}">`)
      .replace(/(<section class="pane" data-path=")[^"]*(" data-title=")[^"]*("><div class="pane-head"><h1 class="pane-title">)[^<]*/, `$1${pathname}$2${title}$3${title}`)
      .replace(/(<div class="pane-body">\n)[\s\S]*(\n<\/div><\/section><\/main>)/, (_, a, b) => a + stage + b);
  };
  const fixture = (pathname, title, stage, fragments) => async (route) => {
    const req = route.request();
    const u = new URL(req.url());
    if (u.pathname === pathname && req.headers()["x-mini-fragment"]) return route.fulfill({ status: 200, contentType: "text/html", headers: { "X-Mini-Title": title }, body: stage });
    if (u.pathname === pathname) return route.fulfill({ status: 200, contentType: "text/html; charset=utf-8", headers: { "Content-Security-Policy": (await get(app.port, "/sessions", app.jar)).headers["content-security-policy"] }, body: await shell(pathname, title, stage) });
    const f = fragments?.(u.pathname);
    if (f) { await new Promise((r) => setTimeout(r, 250)); return route.fulfill({ status: 200, contentType: "text/html", body: f }); }
    return route.continue();
  };
  return [
    { name: "app /sessions", url: `${app.origin}/sessions`, cookies: true, chrome: "shell" },
    { name: "app / (public)", url: `${app.origin}/`, cookies: false, chrome: "shell" },
    { name: "app terminal", url: `${app.origin}${app.termPath}`, cookies: true, chrome: "shell", settle: ".xterm-screen" },
    { name: "app /grants (progressive)", url: `${app.origin}/grants`, cookies: true, chrome: "shell", route: fixture("/grants", "Grants", grantsStage(), (p) => (p.startsWith("/grants/judge/") ? judged(p.slice("/grants/judge/".length)) : null)), settle: "no-pending" },
    { name: "app /tour (purse meter fill)", url: `${app.origin}/tour`, cookies: true, chrome: "shell", route: fixture("/tour", "Tour", purseStage, (p) => (p === "/purse/meter" ? purseMeter : null)), settle: "no-pending" },
    { name: "app workspace (#hash restores panes)", url: `${app.origin}/sessions#${encodeURIComponent("/sessions")}|${encodeURIComponent("/term")}`, cookies: true, chrome: "shell", noCls: true },
  ];
}

// ---------------------------------------------------------------- the site under test
async function startSite() {
  const port = await freePort();
  start("site", "python3", ["-m", "http.server", String(port), "--bind", "127.0.0.1", "-d", path.join(ROOT, "website")]);
  await waitFor(async () => (await get(port, "/index.html")).status === 200, "the site server");
  const css = await get(port, "/site.css");
  if (!/^text\/css/.test(css.headers["content-type"] || "")) throw new Error(`site.css served as ${css.headers["content-type"]}`);
  return fs.readdirSync(path.join(ROOT, "website")).filter((f) => f.endsWith(".html") && !/http-equiv="refresh"/.test(fs.readFileSync(path.join(ROOT, "website", f), "utf8"))).sort() // a redirect page paints nothing to compare.map((f) => ({ name: `site ${f}`, url: `http://127.0.0.1:${port}/${f}`, cookies: false, chrome: "header" }));
}

// ---------------------------------------------------------------- the filmstrip
const GRID_W = 64, GRID_H = 40;
let sampler;
async function sampleFrames(browser, pngs) {
  sampler ??= await (await browser.newContext()).newPage();
  return sampler.evaluate(async ({ pngs, GRID_W, GRID_H }) => {
    const out = [];
    for (const b64 of pngs) {
      const img = new Image();
      await new Promise((ok) => { img.onload = ok; img.src = "data:image/png;base64," + b64; });
      const c = new OffscreenCanvas(GRID_W, GRID_H), g = c.getContext("2d", { willReadFrequently: true });
      g.drawImage(img, 0, 0, GRID_W, GRID_H);
      out.push(Array.from(g.getImageData(0, 0, GRID_W, GRID_H).data));
    }
    return out;
  }, { pngs, GRID_W, GRID_H });
}
const lum = (d, i) => (0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]) / 255;
const blank = (d) => { for (let i = 4; i < d.length; i += 4) if (Math.abs(d[i] - d[0]) > 2 || Math.abs(d[i + 1] - d[1]) > 2 || Math.abs(d[i + 2] - d[2]) > 2) return false; return true; };
function regionDiff(a, b, x0, y0, x1, y1) {
  let sum = 0, n = 0;
  for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) { const i = (y * GRID_W + x) * 4; sum += (Math.abs(a[i] - b[i]) + Math.abs(a[i + 1] - b[i + 1]) + Math.abs(a[i + 2] - b[i + 2])) / (3 * 255); n++; }
  return sum / n;
}
// grid cells of the chrome regions at 1280x800: the header band (top 52px) and the rail (x < 208, y 52..520)
const REGIONS = {
  shell: [[0, 0, GRID_W, 2], [0, 3, 10, 25]],
  header: [[0, 0, GRID_W, 2]],
};
const regionMax = (a, b, kind) => Math.max(...REGIONS[kind].map(([x0, y0, x1, y1]) => regionDiff(a, b, x0, y0, x1, y1)));

async function filmstrip(browser, page, scheme, js) {
  const context = await browser.newContext({ colorScheme: scheme, javaScriptEnabled: js, viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 });
  if (page.cookies) { const u = new URL(page.url); await context.addCookies([{ name: "mini_session", value: page.cookieValue, domain: u.hostname, path: "/" }]); }
  const tab = await context.newPage();
  if (page.route) await tab.route("**/*", page.route);
  await tab.addInitScript(() => {
    window.__cls = 0;
    try { new PerformanceObserver((l) => { for (const e of l.getEntries()) if (!e.hadRecentInput) window.__cls += e.value; }).observe({ type: "layout-shift", buffered: true }); } catch { /* no layout-shift support */ }
  });
  const cdp = await context.newCDPSession(tab);
  const frames = [];
  cdp.on("Page.screencastFrame", (f) => { frames.push({ t: f.metadata.timestamp, data: f.data }); cdp.send("Page.screencastFrameAck", { sessionId: f.sessionId }).catch(() => {}); });
  await cdp.send("Network.enable");
  await cdp.send("Network.emulateNetworkConditions", { offline: false, latency: 400, downloadThroughput: (500 * 1024) / 8, uploadThroughput: (400 * 1024) / 8 }); // slow 3G
  await cdp.send("Emulation.setCPUThrottlingRate", { rate: CPU });
  await cdp.send("Page.startScreencast", { format: "png", maxWidth: 1280, maxHeight: 800, everyNthFrame: 1 });
  const t0 = Date.now() / 1000;
  await tab.goto(page.url, { waitUntil: "load", timeout: 120000 });
  if (js && page.settle === "no-pending") await tab.waitForFunction(() => document.querySelectorAll("[data-load]:not([data-loaded])").length === 0 && ![...document.querySelectorAll("[data-load] .fill")].some((f) => f.querySelector("a[href^='/grants/judge'], a[href='/purse']")), null, { timeout: 120000 });
  else if (js && page.settle) await tab.waitForSelector(page.settle, { timeout: 120000 });
  await tab.waitForTimeout(page.url.includes("#") ? 4000 : 1500);
  await cdp.send("Page.stopScreencast");
  const cls = js ? await tab.evaluate(() => window.__cls) : null;
  await cdp.send("Emulation.setCPUThrottlingRate", { rate: 1 });
  await cdp.send("Network.emulateNetworkConditions", { offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1 });
  const settled = (await tab.screenshot()).toString("base64");
  const tag = `${page.name.replace(/[^a-z0-9]+/gi, "_")}-${scheme}${js ? "" : "-nojs"}`;
  fs.mkdirSync(path.join(OUT, tag), { recursive: true });
  frames.forEach((f, i) => fs.writeFileSync(path.join(OUT, tag, `frame-${String(i).padStart(2, "0")}-${Math.round((f.t - t0) * 1000)}ms.png`), Buffer.from(f.data, "base64")));
  fs.writeFileSync(path.join(OUT, tag, "settled.png"), Buffer.from(settled, "base64"));
  await context.close();
  const grids = await sampleFrames(browser, [...frames.map((f) => f.data), settled]);
  const S = grids.pop();
  const firstContent = grids.findIndex((g) => !blank(g));
  const flash = scheme === "dark" ? grids.findIndex((g) => !blank(g) && lum(g, 0) > 0.5) : -1; // a light frame in a dark page
  const first = grids[firstContent];
  return {
    frames: frames.length,
    firstContentMs: firstContent < 0 ? null : Math.round((frames[firstContent].t - t0) * 1000),
    chromeDiff: first ? regionMax(first, S, page.chrome) : 1,
    wholeDiff: first ? regionDiff(first, S, 0, 0, GRID_W, GRID_H) : 1,
    flash: flash >= 0,
    cls,
    dir: path.join(OUT, tag),
  };
}

// ---------------------------------------------------------------- run
const results = [];
let failed = 0;
let app;
try {
  const pages = [];
  if (ONLY === "all" || ONLY === "app") { app = await startApp(); pages.push(...appPages(app)); }
  if (ONLY === "all" || ONLY === "site") pages.push(...(await startSite()));
  const browser = await chromium.launch();
  for (const page of pages) {
    page.cookieValue = app?.cookie.split("=")[1];
    for (const scheme of ["light", "dark"]) {
      const r = await filmstrip(browser, page, scheme, true);
      const problems = [];
      if (r.firstContentMs === null) problems.push("no painted frame");
      if (r.flash) problems.push("light flash in dark");
      if (r.chromeDiff > 0.02) problems.push(`first-paint chrome differs from settled by ${(r.chromeDiff * 100).toFixed(1)}%`);
      // A page that does not fill in afterwards must be final in its first frame, down to the pane head and padding.
      if (!page.noCls && page.settle !== "no-pending" && r.wholeDiff > 0.005) problems.push(`first frame differs from settled by ${(r.wholeDiff * 100).toFixed(1)}% of the viewport`);
      if (!page.noCls && r.cls !== null && r.cls >= CLS_MAX) problems.push(`CLS ${r.cls.toFixed(3)} >= ${CLS_MAX}`);
      if (scheme === "light" && page.chrome === "shell" && !page.route) {
        const n = await filmstrip(browser, page, scheme, false); // the no-JS first frame is final too
        if (n.chromeDiff > 0.02 && !page.noCls) problems.push(`no-JS chrome differs by ${(n.chromeDiff * 100).toFixed(1)}%`);
      }
      const line = `${problems.length ? "FAIL" : "ok  "} ${page.name.padEnd(40)} ${scheme.padEnd(5)} first paint ${String(r.firstContentMs).padStart(5)}ms  chrome diff ${(r.chromeDiff * 100).toFixed(2).padStart(5)}%  page diff ${(r.wholeDiff * 100).toFixed(1).padStart(5)}%  CLS ${r.cls === null ? "-" : r.cls.toFixed(4)}  frames ${r.frames}${problems.length ? "  <- " + problems.join("; ") : ""}`;
      console.log(line);
      results.push({ page: page.name, scheme, ...r, problems });
      if (problems.length) failed++;
    }
  }
  await browser.close();
  fs.writeFileSync(path.join(OUT, "results.json"), JSON.stringify(results, null, 2));
  console.log(`\nfilmstrips and results.json under ${OUT}`);
} finally {
  stopAll();
  if (app && !KEEP) { fs.rmSync(app.scratch, { recursive: true, force: true }); fs.rmSync(app.run, { recursive: true, force: true }); }
}
process.exit(failed ? 1 : 0);
