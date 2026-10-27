// journey.d/jtour.mjs — the tour, driven headless through Chromium (the same path the front end's
// own drive uses): open the session with the one-time link, open /tour, run step 4's `can` form
// through the pane (its outcome partial lands under the step), open the Terminal pane and see the
// prompt. Stdlib Playwright from PLAYWRIGHT_DIR (node_modules), never installed into the tree.
//
//   node jtour.mjs BASE CODE SUBJECT   -> exit 0 and one summary line on PASS
import { pathToFileURL } from "node:url";
const [base, code, subject] = process.argv.slice(2);
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
  // Step 4: `can` (no arguments) through the real form; the outcome lands under the step.
  await page.click("#step-4 form[action='/tour/4'] button");
  await page.waitForSelector("#step-4 .step-outcome .outcome", { timeout: 60000 });
  const cls = await page.locator("#step-4 .step-outcome .outcome").first().getAttribute("class");
  await page.click(".rail a:has-text('Terminal')");
  await page.waitForSelector(".pane form[action='/term'] button", { timeout: 15000 });
  await page.click(".pane form[action='/term'] button");
  await page.waitForFunction(() => (document.querySelector(".term")?.innerText || "").includes("mini>"), null, { timeout: 30000 });
  await page.keyboard.type("whoami");
  await page.keyboard.press("Enter");
  await page.waitForFunction((s) => (document.querySelector(".term")?.innerText || "").includes(s), subject, { timeout: 30000 });
  console.log(`steps=${steps} step4=${cls} terminal=whoami-ok errors=${errors.length}`);
  await browser.close();
  process.exit(steps === 12 && /outcome (admitted|refused|undecided)/.test(cls || "") && errors.length === 0 ? 0 : 1);
} catch (e) {
  console.log(`jtour: ${String(e).split("\n")[0]}`);
  await browser.close();
  process.exit(1);
}
