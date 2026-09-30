// Exercises the web host's startup lifecycle using Node's existing runtime.
// These checks cover recovery behavior; visual parity requires browser evidence.
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import vm from "node:vm";

const html = await fs.readFile(
  new URL("../../web/index.html", import.meta.url),
  "utf8",
);
const script = html.match(
  /<script id="splash-screen-script">([\s\S]*?)<\/script>/,
)?.[1];
assert.ok(script, "The startup script must be present");

function fixture({ pathname = "/", hash = "" } = {}) {
  const events = new Map();
  const timers = new Map();
  const nodes = new Map();
  let nextTimer = 1;
  let reloads = 0;
  let replacedUrl;
  for (const id of ["splash", "splash-title", "splash-status", "splash-retry"]) {
    const listeners = new Map();
    nodes.set(id, {
      id,
      hidden: id === "splash-retry",
      textContent: "",
      classList: { add() {} },
      setAttribute() {},
      addEventListener(name, listener) { listeners.set(name, listener); },
      click() { listeners.get("click")?.(); },
      parentNode: { removeChild(node) { nodes.delete(node.id); } },
    });
  }
  const document = {
    body: { style: {} },
    getElementById(id) { return nodes.get(id) ?? null; },
  };
  const window = {
    location: { pathname, hash, search: "", reload() { reloads++; } },
    history: { replaceState(_state, _title, url) { replacedUrl = url; } },
    addEventListener(name, callback) {
      const listeners = events.get(name) ?? [];
      listeners.push(callback);
      events.set(name, listeners);
    },
    setTimeout(callback, delay) {
      const id = nextTimer++;
      timers.set(id, { callback, delay });
      return id;
    },
    clearTimeout(id) { timers.delete(id); },
  };
  vm.runInNewContext(script, { window, document });
  return {
    nodes, timers, document,
    emit(name, event = {}) {
      for (const callback of events.get(name) ?? []) callback(event);
    },
    expire() {
      for (const timer of [...timers.values()]) timer.callback();
    },
    get reloads() { return reloads; },
    get replacedUrl() { return replacedUrl; },
  };
}

const results = [];
function check(name, run) {
  run();
  results.push({ name, pass: true });
}

check("Loading waits for Flutter's first frame", () => {
  const f = fixture();
  f.emit("DOMContentLoaded");
  assert.ok(f.nodes.has("splash"));
  assert.equal(f.timers.size, 1);
  f.emit("flutter-first-frame");
  assert.equal(f.nodes.has("splash"), false);
  assert.equal(f.timers.size, 0);
  assert.equal(f.document.body.style.background, "transparent");
});

check("Slow startup offers retry and still accepts a later first frame", () => {
  const f = fixture();
  f.emit("DOMContentLoaded");
  assert.ok([...f.timers.values()][0].delay >= 10000);
  f.expire();
  assert.equal(f.nodes.get("splash-retry").hidden, false);
  assert.match(f.nodes.get("splash-status").textContent, /connection/);
  f.nodes.get("splash-retry").click();
  assert.equal(f.reloads, 1);
  f.emit("flutter-first-frame");
  assert.equal(f.nodes.has("splash"), false);
});

check("Bootstrap asset failure offers recovery", () => {
  const f = fixture();
  f.emit("DOMContentLoaded");
  f.emit("error", { target: { id: "mobio-bootstrap" } });
  assert.equal(f.nodes.get("splash-retry").hidden, false);
  assert.equal(f.timers.size, 0);
});

check("Unrelated image errors preserve the loading state", () => {
  const f = fixture();
  f.emit("DOMContentLoaded");
  f.emit("error", { target: { id: "unrelated-image" } });
  assert.equal(f.nodes.get("splash-retry").hidden, true);
  assert.equal(f.timers.size, 1);
});

check("A first frame before DOM ready leaves no stale timer or callback", () => {
  const f = fixture();
  f.emit("flutter-first-frame");
  f.emit("DOMContentLoaded");
  assert.equal(f.nodes.has("splash"), false);
  assert.equal(f.timers.size, 0);
});

check("BioPay review URL keeps its path while removing the legacy admin hash", () => {
  const f = fixture({ pathname: "/biopay/receive", hash: "#/admin" });
  assert.equal(f.replacedUrl, "/biopay/receive");
});

check("Ordinary product paths keep their existing hash", () => {
  const f = fixture({ pathname: "/", hash: "#/admin-auth" });
  assert.equal(f.replacedUrl, undefined);
});

console.log(JSON.stringify({ scope: "Web host lifecycle", results }, null, 2));
