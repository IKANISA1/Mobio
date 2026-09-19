// Uses an already installed Playwright runtime; this command installs nothing.
const { chromium, webkit } = await import(
  process.env.PLAYWRIGHT_MODULE || "playwright"
);
import fs from "node:fs/promises";
import path from "node:path";

const base = process.env.MOBIO_WEBSITE_QA_URL || "http://127.0.0.1:8764";
if (!["127.0.0.1", "localhost", "[::1]"].includes(new URL(base).hostname)) {
  throw new Error("Website fixture QA accepts loopback hosts only");
}
const out = process.argv[2];
if (!out) throw new Error("Evidence directory required");
await fs.mkdir(out, { recursive: true });
const browsers = { chromium, webkit };
const report = {
  at: new Date().toISOString(),
  mode: "local static landing source; no provider or account calls",
  browserPlugin: "Browser plugin not available",
  tool: "Existing Playwright runtime",
  cases: [],
  screenshots: [],
  browserVersions: {},
};
const record = (browser, name, pass, details = {}) =>
  report.cases.push({ browser, name, pass, ...details });
for (const [name, type] of Object.entries(browsers)) {
  let browser;
  try {
    browser = await type.launch({ headless: true });
  } catch (error) {
    record(name, "browser available", false, {
      blocked: true,
      error: error.message,
    });
    continue;
  }
  report.browserVersions[name] = browser.version();
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    reducedMotion: "reduce",
  });
  const page = await context.newPage();
  const errors = [], requests = [], nonLocal = [];
  page.on(
    "pageerror",
    (error) => errors.push({ type: "pageerror", message: error.message }),
  );
  page.on("console", (message) => {
    if (["error", "warning"].includes(message.type())) {
      errors.push({ type: message.type(), message: message.text() });
    }
  });
  page.on("response", (response) => {
    if (response.status() >= 400) {
      requests.push({ url: response.url(), status: response.status() });
    }
  });
  await context.route("**/*", (route) => {
    if (new URL(route.request().url()).origin !== new URL(base).origin) {
      nonLocal.push(route.request().url());
      return route.abort();
    }
    return route.continue();
  });
  const screenshot = async (label, fullPage = false) => {
    const filename = `${name}-${label}.png`;
    await page.screenshot({
      path: path.join(out, filename),
      fullPage,
      animations: "disabled",
    });
    report.screenshots.push(filename);
  };
  const size = async (width, height = 900) => {
    await page.setViewportSize({ width, height });
    await page.evaluate(() => document.fonts.ready);
  };
  const checkLayout = async (label) => {
    const details = await page.evaluate(() => ({
      viewport: innerWidth,
      document: document.documentElement.scrollWidth,
      body: document.body.scrollWidth,
      overflow: [...document.querySelectorAll("h1,h2,h3,p,a,button,summary")]
        .filter((el) =>
          el.getClientRects().length &&
          (el.getBoundingClientRect().right > innerWidth + 1 ||
            el.getBoundingClientRect().left < -1)
        ).map((el) => ({
          tag: el.tagName,
          text: el.textContent.trim().slice(0, 70),
          left: el.getBoundingClientRect().left,
          right: el.getBoundingClientRect().right,
        })),
    }));
    record(
      name,
      label,
      details.document <= details.viewport + 1 && details.overflow.length === 0,
      details,
    );
  };
  try {
    const response = await page.goto(base, { waitUntil: "networkidle" });
    await page.evaluate(() => document.fonts.ready);
    record(
      name,
      "homepage identity and meaningful content",
      response.status() === 200 &&
        (await page.title()) === "Mobio — Your next connection" &&
        await page.locator("h1").innerText() === "Your next\nconnection.",
      { url: page.url(), title: await page.title() },
    );
    record(
      name,
      "images and local fonts loaded",
      await page.evaluate(() =>
        [...document.images].every((image) =>
          image.complete && image.naturalWidth > 0
        ) && document.fonts.check("16px Aeonik")
      ),
    );
    await fs.writeFile(
      path.join(out, `${name}-home.aria.txt`),
      await page.locator("body").ariaSnapshot(),
    );
    await checkLayout("desktop 1440 layout");
    await screenshot("desktop");
    await page.keyboard.press(name === "webkit" ? "Alt+Tab" : "Tab");
    record(
      name,
      "skip link is first full-navigation keyboard stop",
      await page.locator(".skip-link").evaluate((el) =>
        document.activeElement === el
      ),
      {
        shortcut: name === "webkit"
          ? "Alt+Tab (WebKit links preference)"
          : "Tab",
      },
    );
    await page.keyboard.press("Enter");
    await page.keyboard.press(name === "webkit" ? "Alt+Tab" : "Tab");
    const focusAfterSkip = await page.evaluate(() => ({
      text: document.activeElement.textContent.trim(),
      inMain: !!document.activeElement.closest("main"),
    }));
    record(
      name,
      "skip link bypasses header controls",
      focusAfterSkip.inMain,
      focusAfterSkip,
    );
    await page.locator('.nav-links a[href="#trips"]').click();
    record(
      name,
      "desktop section navigation",
      page.url().endsWith("#trips") &&
        await page.locator("#trips h2").isVisible(),
    );
    const summaries = page.locator(".faq-list summary");
    for (let i = 0; i < await summaries.count(); i++) {
      await summaries.nth(i).focus();
      await page.keyboard.press("Enter");
      await page.waitForFunction(
        (index) => document.querySelectorAll(".faq-list details")[index].open,
        i,
        { timeout: 1500 },
      );
      const opened = await summaries.nth(i).evaluate((el) =>
        el.parentElement.open
      );
      await page.keyboard.press("Space");
      await page.waitForFunction(
        (index) => !document.querySelectorAll(".faq-list details")[index].open,
        i,
        { timeout: 1500 },
      );
      record(
        name,
        `FAQ ${i + 1} keyboard open and close`,
        opened &&
          !(await summaries.nth(i).evaluate((el) => el.parentElement.open)),
      );
    }
    const localLinks = await page.locator("a").evaluateAll(
      (links) => [
        ...new Set(
          links.map((a) => a.getAttribute("href")).filter((href) =>
            href && !href.startsWith("#") && !href.startsWith("mailto:") &&
            !href.startsWith("http")
          ),
        ),
      ],
    );
    record(
      name,
      "local HTML link destinations exist",
      (await Promise.all(
        localLinks.filter((link) => link !== "/admin-auth").map(async (link) =>
          (await context.request.get(new URL(link, base).href)).status()
        ),
      )).every((status) => status === 200),
      {
        links: localLinks,
        excluded: "/admin-auth is a Flutter shell outside this static server",
      },
    );
    await size(390, 844);
    await page.goto(base, { waitUntil: "networkidle" });
    await checkLayout("mobile 390 layout");
    await screenshot("mobile");
    const toggle = page.getByRole("button", { name: "Open menu" });
    await toggle.click();
    record(
      name,
      "mobile menu opens and moves focus",
      await page.locator("#nav-toggle").getAttribute("aria-expanded") ===
          "true" &&
        await page.locator("#nav-links a").first().evaluate((el) =>
          document.activeElement === el
        ),
    );
    record(
      name,
      "mobile menu background is inert",
      await page.locator("main").evaluate((el) => el.inert) &&
        await page.locator("footer").evaluate((el) => el.inert),
    );
    const menuCta = await page.locator(".nav-cta .btn").evaluate((el) => ({
      foreground: getComputedStyle(el).color,
      background: getComputedStyle(el).backgroundColor,
      surrounding: getComputedStyle(el.closest("header")).backgroundColor,
    }));
    record(
      name,
      "mobile menu CTA has visible surface separation",
      menuCta.background !== menuCta.surrounding,
      menuCta,
    );
    await screenshot("menu");
    await page.locator(".nav-cta .btn").click();
    record(
      name,
      "menu download action closes overlay and releases content",
      page.url().endsWith("#download") &&
        await page.locator("#nav-toggle").getAttribute("aria-expanded") ===
          "false" &&
        !await page.locator("main").evaluate((el) => el.inert),
    );
    await page.locator("#nav-toggle").click();
    for (let i = 0; i < 12; i++) {
      await page.keyboard.press("Tab");
      if (
        !(await page.evaluate(() => !!document.activeElement.closest("nav")))
      ) {
        record(name, "mobile focus stays in menu", false);
        break;
      }
      if (i === 11) record(name, "mobile focus stays in menu", true);
    }
    await page.keyboard.press("Escape");
    record(
      name,
      "Escape closes menu and restores focus",
      await page.locator("#nav-toggle").getAttribute("aria-expanded") ===
          "false" &&
        await page.locator("#nav-toggle").evaluate((el) =>
          document.activeElement === el
        ) && !await page.locator("main").evaluate((el) => el.inert),
    );
    await page.locator("#nav-toggle").click();
    await page.locator('#nav-links a[href="#biopay"]').click();
    record(
      name,
      "mobile section selection closes menu",
      page.url().endsWith("#biopay") &&
        await page.locator("#nav-toggle").getAttribute("aria-expanded") ===
          "false",
    );
    await page.locator("#nav-toggle").click();
    await size(1280);
    await page.waitForFunction(
      () =>
        document.querySelector("#nav-toggle").getAttribute("aria-expanded") ===
          "false" && !document.querySelector("main").inert,
      undefined,
      { timeout: 1500 },
    );
    record(
      name,
      "desktop resize releases mobile menu",
      await page.locator("#nav-toggle").getAttribute("aria-expanded") ===
          "false" && !await page.locator("main").evaluate((el) => el.inert),
    );
    for (const width of [320, 360, 768, 820, 1024, 1920]) {
      await size(width);
      await page.goto(base);
      await checkLayout(`homepage ${width} layout`);
      if (width === 320 || width === 768) await screenshot(`width-${width}`);
    }
    for (
      const filename of [
        "privacy-policy.html",
        "terms-and-conditions.html",
        "account-deletion.html",
      ]
    ) {
      const legal = await page.goto(`${base}/${filename}`, {
        waitUntil: "networkidle",
      });
      record(
        name,
        `${filename} identity`,
        legal.status() === 200 &&
          (await page.locator("main h1").innerText()).length > 5,
        { title: await page.title(), url: page.url() },
      );
      for (const width of [1440, 390, 320]) {
        await size(width);
        await checkLayout(`${filename} ${width} layout`);
      }
      await screenshot(filename.replace(".html", "") + "-320");
      await page.locator("#nav-toggle").click();
      record(
        name,
        `${filename} mobile menu`,
        await page.locator("#nav-toggle").getAttribute("aria-expanded") ===
          "true",
      );
      await page.keyboard.press("Escape");
    }
    await size(390, 844);
    await page.goto(base);

    record(
      name,
      "reduced motion disables smooth scroll",
      await page.evaluate(() =>
        getComputedStyle(document.documentElement).scrollBehavior === "auto"
      ),
    );
    const review = await page.goto(
      `${base}/play-review/foreground-location-demo.html`,
      { waitUntil: "networkidle" },
    );
    record(
      name,
      "review video page identity",
      review.status() === 200 &&
        await page.title() === "Mobio foreground location demo",
    );
    for (const width of [1440, 390, 320]) {
      await size(width);
      await checkLayout(`review video page ${width} layout`);
    }
    await size(390, 844);
    // The public instructions contain the owner's review credential. Capture
    // only the page header; do not copy credentials into screenshot reports.
    const reviewHeader = `${name}-review-page-header.png`;
    await page.screenshot({
      path: path.join(out, reviewHeader),
      clip: { x: 0, y: 0, width: 390, height: 280 },
    });
    report.screenshots.push(reviewHeader);
    await page.waitForFunction(() =>
      document.querySelector("video").readyState >= 1
    );
    const video = await page.locator("video").evaluate((el) => ({
      duration: el.duration,
      width: el.videoWidth,
      height: el.videoHeight,
    }));
    record(
      name,
      "review video metadata loads",
      video.duration > 0 &&
        video.width === 1080 && video.height === 1920,
      video,
    );
    await page.locator("video").evaluate((el) => {
      el.muted = true;
      return el.play();
    });
    await page.waitForFunction(() =>
      document.querySelector("video").currentTime > 0.1
    );
    await page.locator("video").evaluate((el) => el.pause());
    record(
      name,
      "review video playback and pause",
      await page.locator("video").evaluate(
        (el) => el.paused && el.currentTime > 0.1,
      ),
    );
    await page.getByRole("link", { name: "Mobio home", exact: true }).click();
    record(
      name,
      "review page returns to homepage",
      await page.title() ===
        "Mobio — Your next connection",
    );
    record(
      name,
      "no browser runtime or asset errors",
      errors.length === 0 && requests.length === 0,
      { errors, failedRequests: requests },
    );
    record(name, "no external application calls", nonLocal.length === 0, {
      requests: nonLocal,
    });
    const noJs = await browser.newContext({
      javaScriptEnabled: false,
      viewport: { width: 390, height: 844 },
    });
    const plain = await noJs.newPage();
    await plain.goto(base);
    record(
      name,
      "no-JavaScript mobile navigation is available",
      await plain.locator("#nav-links a").first().isVisible(),
      {
        meaningfulContent: await plain.locator("h1").isVisible(),
        note:
          "Progressive enhancement; footer destinations separately remain available.",
      },
    );
    await plain.screenshot({
      path: path.join(out, `${name}-no-js-mobile.png`),
    });
    report.screenshots.push(`${name}-no-js-mobile.png`);
    await noJs.close();
  } catch (error) {
    record(name, "runner completion", false, { error: error.stack });
  }
  await context.close();
  await browser.close();
  await fs.writeFile(
    path.join(out, "results.json"),
    JSON.stringify(report, null, 2),
  );
}
await fs.writeFile(
  path.join(out, "results.json"),
  JSON.stringify(report, null, 2),
);
const failed = report.cases.filter((test) => !test.pass);
console.log(
  JSON.stringify(
    {
      versions: report.browserVersions,
      count: report.cases.length,
      passed: report.cases.length - failed.length,
      failed: failed.length,
      failures: failed,
    },
    null,
    2,
  ),
);
process.exitCode = failed.length ? 1 : 0;
