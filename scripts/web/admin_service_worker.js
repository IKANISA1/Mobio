"use strict";

// Replace legacy Flutter workers without navigating clients or deleting their
// caches, sessions or drafts. This worker never caches application/API data.
self.addEventListener("install", event => event.waitUntil(self.skipWaiting()));
self.addEventListener("activate", event => event.waitUntil(self.clients.claim()));

const offline = `<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="theme-color" content="#161618"><title>Mobio Admin — Offline</title>
<style>body{margin:0;background:#161618;color:#f4f4f4;font:18px/1.5 system-ui;display:grid;min-height:100vh;place-items:center}
main{max-width:28rem;padding:24px}h1{font-size:2rem;line-height:1.15}p{color:#c6c6ca}
button{font:600 16px system-ui;min-height:48px;padding:12px 24px;border:0;border-radius:28px;background:#f4f4f4;color:#161618;cursor:pointer}
button:focus-visible{outline:3px solid #7abaff;outline-offset:4px}</style>
<main><p>Mobio Admin</p><h1>You’re offline</h1><p>Reconnect to open this page. If your work is still open in another tab, keep that tab open.</p>
<button onclick="location.reload()">Try again</button></main></html>`;

self.addEventListener("fetch", event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || request.mode !== "navigate" || url.origin !== self.location.origin) return;
  const admin = url.pathname === "/admin-auth" || url.pathname === "/admin" ||
    url.pathname.startsWith("/admin/") ||
    (url.hostname === "mobioadmin.ikanisa.com" && url.pathname === "/");
  if (!admin) return;
  event.respondWith(fetch(request).catch(() => new Response(offline, {
    status: 503,
    headers: {
      "content-type": "text/html; charset=utf-8", "cache-control": "no-store",
      "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    },
  })));
});
