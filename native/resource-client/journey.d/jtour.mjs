// journey.d/jtour.mjs — the tour, driven headless through Chromium (the same path the front end's
// own drive uses): open the session with the one-time link, open /tour, run step 4's `can` form
// through the pane on one named reference (its outcome partial lands under the step), open the
// Terminal pane and see the prompt. Stdlib Playwright from PLAYWRIGHT_DIR (node_modules), never
// installed into the tree.
//
//   node jtour.mjs BASE CODE SUBJECT DOC   -> exit 0 and one summary line on PASS
//
// Step 4 asks `can DOC`, as the tour-step row does: a bare `can` judges every grant held and on a
// used workspace runs to the body's deadline. The wait for the step's own outcome element is the
// body's deadline (MINI_BODY_DEADLINE_S, 100) plus 30 s, and the elapsed time is printed.
import { pathToFileURL } from "node:url";
const [base, code, subject, doc] = process.argv.slice(2);
if (!doc) { console.log("jtour: usage: jtour.mjs BASE CODE SUBJECT DOC"); process.exit(2); }
const outcomeWait = (Number(process.env.MINI_BODY_DEADLINE_S || 100) + 30) * 1000;
const dir = process.env.PLAYWRIGHT_DIR || `${process.env.HOME}/tools/playwright/node_modules`;
const { chromium } = await import(pathToFileURL(`${dir}/playwright/index.mjs`).href);
const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const errors = [];
page.on("pageerror", (e) => errors.push(String(e)));
try {
  await page.goto(`${base}/login/${code}`);
  await page.click("button:has-text('Open my session')");
  await page.waitForURL(`${base}/`);
  await page.click(".rail a:has-text('Tour')");
  await page.waitForSelector("#step-4 form[action='/tour/4']", { timeout: 15000 });
  const steps = await page.locator("ol.tour > li.step").count();
  // Step 4: `can DOC` through the real form (its first shape); the outcome lands under the step.
  const form = page.locator("#step-4 form[action='/tour/4']").first();
  const field = form.locator("[name=a1]");
  if ((await field.count()) !== 1) throw new Error("step 4's form has no reference field a1 (the selector drifted)");
  if ((await field.evaluate((e) => e.tagName)) === "SELECT") await field.selectOption(doc); else await field.fill(doc);
  const started = Date.now();
  await form.locator("button").click();
  await page.waitForSelector("#step-4 .step-outcome .outcome", { timeout: outcomeWait });
  const elapsed = Date.now() - started;
  const cls = await page.locator("#step-4 .step-outcome .outcome").first().getAttribute("class");
  const said = ((await page.locator("#step-4 .step-outcome").first().innerText()) || "").replace(/\s+/g, " ").slice(0, 160);
  await page.click(".rail a:has-text('Terminal')");
  await page.waitForSelector(".pane form[action='/term'] button", { timeout: 15000 });
  await page.click(".pane form[action='/term'] button");
  await page.waitForFunction(() => (document.querySelector(".term")?.innerText || "").includes("mini>"), null, { timeout: 30000 });
  await page.keyboard.type("whoami");
  await page.keyboard.press("Enter");
  await page.waitForFunction((s) => (document.querySelector(".term")?.innerText || "").includes(s), subject, { timeout: 30000 });
  console.log(`steps=${steps} step4=${cls} step4-ms=${elapsed} terminal=whoami-ok errors=${errors.length}${/answered/.test(cls || "") ? "" : " said: " + said}`);
  await browser.close();
  // `can` is a read: its class is `answered` (outcome truth), never a world transition.
  process.exit(steps === 12 && /\boutcome answered\b/.test(cls || "") && errors.length === 0 ? 0 : 1);
} catch (e) {
  console.log(`jtour: ${String(e).split("\n")[0]}`);
  await browser.close();
  process.exit(1);
}
