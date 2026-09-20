import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import worker from "../web/pages_worker.mjs";

const adminHtml = '<html><title>Mobio Admin</title><script src="/flutter_bootstrap.js"></script></html>';
const marketing = '<html><title>Mobio — Your next connection</title></html>';
function assets(shell = adminHtml, shellStatus = 200) {
  const requested = [];
  return { requested, ASSETS: { async fetch(request) {
    const path = new URL(request.url).pathname;
    requested.push(path);
    return new Response(path === "/__admin_shell" ? shell : marketing, {
      status: path === "/__admin_shell" ? shellStatus : 200,
      headers: { "content-type": "text/html", "cache-control": "public, max-age=31536000" },
    });
  } } };
}
for (const host of ["mobio.ikanisa.com", "mobioadmin.ikanisa.com"]) {
  for (const path of ["/admin-auth", "/admin", "/admin/users", "/admin/reports?status=open"]) {
    test(`${host}${path} serves the Admin shell with no cached HTML`, async () => {
      const env = assets();
      const response = await worker.fetch(new Request(`https://${host}${path}`), env);
      assert.equal(response.status, 200);
      assert.equal(response.headers.get("x-mobio-surface"), "admin");
      assert.equal(response.headers.get("cache-control"), "no-store");
      assert.match(response.headers.get("content-security-policy"), /frame-ancestors 'none'/);
      assert.equal(await response.text(), adminHtml);
      assert.deepEqual(env.requested, ["/__admin_shell"]);
    });
  }
}
test("Admin hostname root redirects while website root remains marketing", async () => {
  const response = await worker.fetch(new Request("https://mobioadmin.ikanisa.com/"), assets());
  assert.equal(response.status, 302);
  assert.equal(response.headers.get("location"), "https://mobioadmin.ikanisa.com/admin-auth");
  const site = await worker.fetch(new Request("https://mobio.ikanisa.com/"), assets());
  assert.equal(await site.text(), marketing);
  assert.equal(site.headers.get("x-mobio-surface"), "website");
  assert.equal(site.headers.get("cache-control"), "no-store");
});
test("mutable JavaScript is not stored and preserves its content identity", async () => {
  const env = { ASSETS: { fetch: async () => new Response("version two", {
    headers: { "content-type": "text/javascript", etag: '"v2"', "cache-control": "public, max-age=31536000, immutable" },
  }) } };
  const response = await worker.fetch(new Request("https://mobio.ikanisa.com/main.dart.js"), env);
  assert.equal(response.headers.get("cache-control"), "no-store");
  assert.equal(response.headers.get("etag"), '"v2"');
  assert.equal(await response.text(), "version two");
});
test("missing or mispackaged Admin shells return recovery instead of marketing", async () => {
  for (const env of [assets(marketing), assets("Not found", 404)]) {
    const response = await worker.fetch(new Request("https://mobio.ikanisa.com/admin/users"), env);
    assert.equal(response.status, 503);
    assert.equal(response.headers.get("cache-control"), "no-store");
    assert.match(await response.text(), /Please retry/);
  }
});
test("HEAD and unsupported methods preserve HTTP semantics", async () => {
  const head = await worker.fetch(new Request("https://mobio.ikanisa.com/admin-auth", { method: "HEAD" }), assets());
  assert.equal(head.status, 200);
  assert.equal(await head.text(), "");
  const missingHead = await worker.fetch(new Request("https://mobio.ikanisa.com/admin-auth", { method: "HEAD" }), assets("missing", 404));
  assert.equal(missingHead.status, 503);
  assert.equal(await missingHead.text(), "");
  const post = await worker.fetch(new Request("https://mobio.ikanisa.com/admin-auth", { method: "POST" }), assets());
  assert.equal(post.status, 405);
});
test("conditional or range requests still validate a complete current Admin shell", async () => {
  const env = { ASSETS: { async fetch(request) {
    assert.equal(request.method, "GET");
    for (const name of ["if-none-match", "if-modified-since", "range", "if-range"]) assert.equal(request.headers.has(name), false);
    return new Response(adminHtml, { headers: { "content-type": "text/html", etag: '"current"' } });
  } } };
  const response = await worker.fetch(new Request("https://mobio.ikanisa.com/admin/users", {
    headers: { "if-none-match": '"old"', "if-modified-since": "Sat, 05 Sep 2026 12:00:00 GMT", range: "bytes=0-10", "if-range": '"old"' },
  }), env);
  assert.equal(response.status, 200);
  assert.equal(await response.text(), adminHtml);
});

test("versioned files are immutable while stable release controls are never stored", async () => {
  const env = { ASSETS: { fetch: async () => new Response("public bytes", { headers: { "content-type": "application/javascript" } }) } };
  const response = await worker.fetch(new Request(`https://mobio.ikanisa.com/releases/${'a'.repeat(64)}/main.dart.js`), env);
  assert.equal(response.headers.get('cache-control'), 'public, max-age=31536000, immutable');
  for (const path of ['/release.json', '/admin-manifest.json', '/flutter_bootstrap.js', '/flutter_service_worker.js']) {
    const control = await worker.fetch(new Request('https://mobio.ikanisa.com'+path), env);
    assert.equal(control.headers.get('cache-control'), 'no-store');
  }
});
test("missing or invalid versioned assets fail as 404 instead of a cached marketing page", async () => {
  for (const path of [`/releases/${'a'.repeat(64)}/missing.js`, '/releases/invalid/main.dart.js']) {
    const response = await worker.fetch(new Request('https://mobio.ikanisa.com'+path), assets());
    assert.equal(response.status, 404);
    assert.equal(response.headers.get('cache-control'), 'no-store');
  }
});

// Enumerate the actual router, including its generated BioPay destinations.
// Website / is intentionally separate; this only establishes shell routing.
const routeSource = readFileSync(new URL('../../lib/app/router/app_router.dart', import.meta.url), 'utf8');
const routes = [...routeSource.matchAll(/path:\s*['"]([^'"]+)/g)].flatMap(match =>
  match[1].includes('$section') ? ['requests', 'activity', 'recents', 'templates'].map(section => match[1].replace('$section', section)) : [match[1]]);
for (const route of routes.filter(route => route !== '/')) {
  test(`router destination ${route} receives its own Flutter shell`, async () => {
    const path = route.replace(':id', 'synthetic-trip').replace(':token', 'synthetic-token');
    const expectedAdmin = route.startsWith('/admin');
    const html = expectedAdmin ? adminHtml : '<html><title>Mobio</title></html>';
    let requested;
    const env = { ASSETS: { async fetch(request) {
      requested = new URL(request.url).pathname;
      return new Response(html, { headers: { 'content-type': 'text/html' } });
    } } };
    const response = await worker.fetch(new Request('https://mobio.ikanisa.com' + path), env);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('x-mobio-surface'), expectedAdmin ? 'admin' : 'app');
    assert.equal(response.headers.get('cache-control'), 'no-store');
    assert.equal(requested, expectedAdmin ? '/__admin_shell' : '/__app_shell');
    if (!expectedAdmin) assert.match(response.headers.get('permissions-policy'), /geolocation=\(self\)/);
  });
}

test('private query, cookies and authorization do not enter the static shell request', async () => {
  const env = { ASSETS: { async fetch(request) {
    assert.equal(new URL(request.url).search, '');
    assert.equal(request.headers.has('authorization'), false);
    assert.equal(request.headers.has('cookie'), false);
    return new Response('<html><title>Mobio</title></html>', { headers: { 'content-type': 'text/html' } });
  } } };
  const response = await worker.fetch(new Request('https://mobio.ikanisa.com/biopay/pay/token?private=value', {
    headers: { authorization: 'Bearer synthetic', cookie: 'synthetic=value' },
  }), env);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('referrer-policy'), 'no-referrer');
});

test('oversized, wrongly typed and unavailable shells recover without a cached false success', async () => {
  for (const fixture of [
    () => new Response(adminHtml, { headers: { 'content-type': 'application/octet-stream' } }),
    () => new Response(adminHtml + 'x'.repeat(256 * 1024), { headers: { 'content-type': 'text/html' } }),
    () => { throw new Error('Unavailable assets'); },
  ]) {
    const response = await worker.fetch(new Request('https://mobio.ikanisa.com/admin'), { ASSETS: { fetch: fixture } });
    assert.equal(response.status, 503);
    assert.equal(response.headers.get('cache-control'), 'no-store');
  }
});

test('HEAD returns no body for a static asset and preserves status and validators', async () => {
  const env = { ASSETS: { fetch: async () => new Response('bytes', { headers: { etag: 'current' } }) } };
  const response = await worker.fetch(new Request('https://mobio.ikanisa.com/script.js', { method: 'HEAD' }), env);
  assert.equal(response.status, 200);
  assert.equal(response.headers.get('etag'), 'current');
  assert.equal(await response.text(), '');
});
