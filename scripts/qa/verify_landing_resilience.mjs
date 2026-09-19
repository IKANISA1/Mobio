// Uses an existing Playwright runtime; never installs browser dependencies.
const { chromium, webkit } = await import(
  process.env.PLAYWRIGHT_MODULE || "playwright"
);
import fs from "node:fs/promises";
const base = process.env.MOBIO_WEBSITE_QA_URL || "http://127.0.0.1:8764";
if (!["localhost", "127.0.0.1", "[::1]"].includes(new URL(base).hostname)) {
  throw new Error("Loopback fixture host required");
}
const out = process.argv[2];
if (!out) throw new Error("Evidence directory required");
await fs.mkdir(out, { recursive: true });
const results = [];
for (const [name, type] of Object.entries({ chromium, webkit })) {
  const browser = await type.launch();
  for (
    const mode of [
      "normal",
      "script-failed",
      "fonts-failed",
      "image-failed",
      "script-delayed",
    ]
  ) {
    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      reducedMotion: "reduce",
    });
    const page = await context.newPage();
    await page.addInitScript(() => {
      window.qaMetrics = {
        cls: PerformanceObserver.supportedEntryTypes.includes("layout-shift")
          ? 0
          : null,
        lcp: null,
        shifts: [],
        supported: PerformanceObserver.supportedEntryTypes,
      };
      try {
        new PerformanceObserver((list) => {
          for (const e of list.getEntries()) {
            if (!e.hadRecentInput) {
              qaMetrics.cls += e.value;
              qaMetrics.shifts.push({ time: e.startTime, value: e.value });
            }
          }
        }).observe({ type: "layout-shift", buffered: true });
        new PerformanceObserver((list) => {
          for (const e of list.getEntries()) qaMetrics.lcp = e.startTime;
        }).observe({ type: "largest-contentful-paint", buffered: true });
      } catch {}
    });
    await page.route("**/*", async (route) => {
      const url = route.request().url();
      if (new URL(url).origin !== new URL(base).origin) return route.abort();
      if (
        mode === "script-failed" && url.endsWith("script.js") ||
        mode === "fonts-failed" && url.includes("/fonts/") ||
        mode === "image-failed" && url.endsWith("mobio-journey-hero.jpg")
      ) return route.abort();
      if (mode === "script-delayed" && url.endsWith("script.js")) {
        await new Promise((resolve) => setTimeout(resolve, 1500));
      }
      return route.continue();
    });
    await page.goto(base, { waitUntil: "networkidle" });
    await page.waitForTimeout(400);
    const evidence = await page.evaluate(() => ({
      metrics: window.qaMetrics,
      width: innerWidth,
      scrollWidth: document.documentElement.scrollWidth,
      heading: document.querySelector("h1").textContent,
      menuReady: document.querySelector("#nav").classList.contains(
        "menu-ready",
      ),
      fallbackLinksVisible:
        document.querySelector("#nav-links a").getClientRects().length > 0,
      heroBackground:
        getComputedStyle(document.querySelector(".hero")).backgroundColor,
      fonts: document.fonts.status,
    }));
    const passed =
      (evidence.metrics.cls === null || evidence.metrics.cls <= 0.1) &&
      evidence.scrollWidth <= 390 && evidence.heading.trim().length > 0 &&
      (mode !== "script-failed" || evidence.fallbackLinksVisible);
    await page.screenshot({ path: `${out}/${name}-${mode}.png` });
    results.push({ browser: name, mode, passed, ...evidence });
    await context.close();
  }
  await browser.close();
}
await fs.writeFile(
  `${out}/results.json`,
  JSON.stringify(
    {
      at: new Date().toISOString(),
      scope:
        "Local source under intentionally failed/delayed assets; not field-performance or offline PWA acceptance",
      results,
    },
    null,
    2,
  ),
);
console.log(JSON.stringify(results, null, 2));

process.exitCode = results.some((result) => !result.passed) ? 1 : 0;
