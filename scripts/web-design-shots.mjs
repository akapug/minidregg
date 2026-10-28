#!/usr/bin/env node
// Screenshots of actual renderer output from the opt-in design_preview tests.
// node scripts/web-design-shots.mjs FIXTURE_DIR before|after [OUTPUT_DIR]
const { chromium } = await import(process.env.PLAYWRIGHT_PATH || "/Users/ember/tools/playwright/node_modules/playwright/index.mjs");
import fs from "node:fs";
import path from "node:path";
import http from "node:http";
const [source, tag, output = "docs/web-shots"] = process.argv.slice(2);
const dir = source && path.resolve(source);
if (!dir || !tag) throw new Error("FIXTURE_DIR before|after [OUTPUT_DIR]");
fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(dir, "screenshots.pid"), String(process.pid));
const pages = JSON.parse(fs.readFileSync(path.join(dir, "pages.json")));
const server = http.createServer((req, res) => {
  const pathname = new URL(req.url, "http://localhost").pathname;
  const match = pages.find(p => p.path === pathname);
  const file = path.resolve(dir, match ? `${match.name}.html` : pathname.replace(/^\//, ""));
  if (!file.startsWith(dir + path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) { res.writeHead(404); res.end("Preview has no such fixture"); return; }
  if (match && req.headers["x-mini-fragment"]) {
    res.setHeader("X-Mini-Title", match.title);
    res.setHeader("Content-Type", "text/html; charset=utf-8");
    res.end(match.body); return;
  }
  res.setHeader("Content-Type", file.endsWith(".css") ? "text/css" : file.endsWith(".js") ? "text/javascript" : "text/html; charset=utf-8");
  res.end(fs.readFileSync(file));
});
await new Promise(r => server.listen(0, "127.0.0.1", r));
const origin = `http://127.0.0.1:${server.address().port}`;
if (process.env.WEB_SHOTS_SERVE === "1") {
  console.log(`Preview: ${origin}`);
  await new Promise(() => {});
}
const browser = await chromium.launch({ headless: true });
const results = [];
try {
  for (const variant of [
    { name: "light", colorScheme: "light", width: 1440, height: 1050, javaScriptEnabled: true },
    { name: "dark", colorScheme: "dark", width: 1440, height: 1050, javaScriptEnabled: true },
    { name: "phone", colorScheme: "light", width: 390, height: 844, javaScriptEnabled: false },
  ]) {
    const context = await browser.newContext({ colorScheme: variant.colorScheme, viewport: { width: variant.width, height: variant.height }, javaScriptEnabled: variant.javaScriptEnabled });
    const page = await context.newPage();
    const external = [];
    page.on("request", r => { if (!r.url().startsWith(origin)) external.push(r.url()); });
    for (const p of pages) {
      await page.goto(`${origin}${p.path}`, { waitUntil: "networkidle" });
      // Red-proof the layout/label check on a deliberately broken rendered page.
      if (process.env.WEB_SHOTS_PLANT === "1") await page.evaluate(() => {
        const field = document.createElement("input");
        field.style.width = "2000px"; field.style.maxWidth = "none";
        document.body.appendChild(field);
      });
      await page.screenshot({ path: path.join(output, `${tag}-${p.name}-${variant.name}.png`), fullPage: true });
      const layout = await page.evaluate(() => ({
        overflow: document.documentElement.scrollWidth > innerWidth,
        unlabelled: [...document.querySelectorAll("input:not([type=hidden]),textarea,select")].filter(e => !e.labels?.length && !e.getAttribute("aria-label")).map(e => e.outerHTML),
      }));
      results.push({ page: p.name, variant: variant.name, ...layout });
      if (tag === "after" && (layout.overflow || layout.unlabelled.length)) throw new Error(JSON.stringify(results.at(-1)));
    }
    if (external.length) throw new Error(`External requests: ${external}`);
    await context.close();
  }
  if (tag === "after") {
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.clock.install();
    let activityReads = 0;
    await page.route("**/activity", async route => {
      activityReads++;
      await route.fulfill({ contentType: "text/html", body: pages.find(p => p.name === "front").body.replace("Life in this world", "Activity refreshed") });
    });
    await page.goto(origin, { waitUntil: "networkidle" });
    await page.keyboard.press("Tab");
    if (await page.locator(":focus").getAttribute("class") !== "skip") throw new Error("Skip link is not first in keyboard order");
    await page.keyboard.press("Enter");
    if (await page.locator(":focus").getAttribute("id") !== "stage") throw new Error("Skip link did not focus the stage");
    await page.locator('.rail a[href="/apps"]').click();
    await page.locator('.pane[data-path="/apps"] .app-card').first().waitFor();
    if (await page.locator('.pane').count() !== 2) throw new Error("App navigation did not open a pane");
    await page.locator('.pane[data-path="/apps"] button[aria-label="Close"]').click();
    if (await page.locator('.pane').count() !== 1) throw new Error("Pane did not close");
    const reading = await page.locator(".doc").innerHTML();
    await page.clock.fastForward(31000);
    await page.getByRole("heading", { name: "Activity refreshed" }).waitFor();
    if (activityReads !== 1 || await page.locator(".doc").innerHTML() !== reading) throw new Error("Activity refresh disturbed the document");
    // Put another real derived form in this live pane, edit it, then move focus away.
    await page.locator(".pane-body").evaluate((el, html) => el.insertAdjacentHTML("beforeend", html), pages.find(p => p.name === "command").body);
    const field = page.locator('.verb-form input:not([type="hidden"])').first();
    await field.fill("Keep my unfinished message");
    await page.locator(".pane-title").click();
    await page.clock.fastForward(31000);
    if (activityReads !== 1 || await field.inputValue() !== "Keep my unfinished message") throw new Error("Live refresh discarded an edited form");
    await context.close();
  }
  fs.writeFileSync(path.join(output, `${tag}-checks.json`), JSON.stringify(results, null, 2) + "\n");
  console.log(`${tag}: ${results.length} screenshots; phone has JavaScript disabled`);
} finally { await browser.close(); await new Promise(r => server.close(r)); }
