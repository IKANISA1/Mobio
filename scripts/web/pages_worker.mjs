// The Pages bundle copies this module, so tests exercise the deployed worker.
const ADMIN_HOST = "mobioadmin.ikanisa.com";
const RELEASE_ID = "__MOBIO_RELEASE_ID__";
const MAX_SHELL_BYTES = 256 * 1024;
const APP_PATHS = new Set([
  "/config-error", "/login", "/home", "/bookings", "/nearby", "/ev-chargers",
  "/notifications", "/ledger", "/schedule", "/chat", "/edit-profile",
  "/wallet", "/mobio-plus", "/profile", "/biopay",
]);
const STABLE_CONTROLS = new Set([
  "/release.json", "/flutter.js", "/flutter_bootstrap.js", "/flutter_service_worker.js",
  "/admin-manifest.json", "/app-manifest.json", "/manifest.json",
]);
const APP_CSP = "default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; img-src 'self' data: blob: https:; font-src 'self' data:; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com; style-src 'self' 'unsafe-inline'; connect-src 'self' https: wss:; worker-src 'self' blob:; manifest-src 'self'; media-src 'self' blob: data:; upgrade-insecure-requests";

function isAdminPath(pathname) {
  return pathname === "/admin-auth" || pathname === "/admin" ||
    pathname.startsWith("/admin/") || pathname === "/__admin_shell";
}

function isAppPath(pathname) {
  return APP_PATHS.has(pathname) || pathname.startsWith("/biopay/") ||
    pathname.startsWith("/profile/") || /^\/trip\/[^/]+(?:\/edit)?\/?$/.test(pathname) ||
    pathname === "/__app_shell";
}

function identify(response, surface, pathname = "", head = false) {
  const headers = new Headers(response.headers);
  headers.set("x-mobio-release", RELEASE_ID);
  headers.set("x-mobio-surface", surface);
  headers.set("x-content-type-options", "nosniff");
  headers.set("x-frame-options", "DENY");
  headers.set("referrer-policy", surface === "asset" || surface === "website"
    ? "strict-origin-when-cross-origin" : "no-referrer");
  const versioned = /^\/releases\/[0-9a-f]{64}\/.+/.test(pathname);
  const mutableRuntime = pathname.startsWith("/main.dart.js") || STABLE_CONTROLS.has(pathname);
  headers.set("cache-control", surface === "asset" && response.status < 400 && !mutableRuntime
    ? (versioned ? "public, max-age=31536000, immutable" : "no-cache, must-revalidate")
    : "no-store");
  return new Response(head ? null : response.body, {
    status: response.status, statusText: response.statusText, headers,
  });
}

function unavailable(request, surface) {
  return identify(new Response(request.method === "HEAD" ? null : "Mobio is temporarily unavailable. Please retry.", {
    status: 503,
    headers: { "content-type": "text/plain; charset=utf-8", "retry-after": "30" },
  }), `${surface}-unavailable`);
}

async function readShell(response) {
  if (response.status !== 200 || !response.headers.get("content-type")?.toLowerCase().includes("text/html") ||
      Number(response.headers.get("content-length")) > MAX_SHELL_BYTES || !response.body) {
    await response.body?.cancel();
    return null;
  }
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let size = 0;
  let html = "";
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) return html + decoder.decode();
      size += value.byteLength;
      if (size > MAX_SHELL_BYTES) {
        await reader.cancel();
        return null;
      }
      html += decoder.decode(value, { stream: true });
    }
  } finally {
    reader.releaseLock();
  }
}

async function serveFlutterShell(env, request, surface) {
  const url = new URL(request.url);
  url.pathname = surface === "admin" ? "/__admin_shell" : "/__app_shell";
  url.search = "";
  // HEAD/conditional/range requests still require a complete current shell.
  // Static assets do not need authorization, cookies or private link queries.
  const response = await env.ASSETS.fetch(new Request(url, {
    method: "GET", headers: { accept: "text/html" },
  }));
  const html = await readShell(response);
  const title = surface === "admin" ? "Mobio Admin" : "Mobio";
  if (!html?.includes(`<title>${title}</title>`)) return unavailable(request, surface);
  const headers = new Headers(response.headers);
  headers.delete("content-length");
  headers.delete("content-encoding");
  headers.set("content-type", "text/html; charset=utf-8");
  headers.set("content-security-policy", APP_CSP);
  headers.set("permissions-policy", surface === "admin"
    ? "camera=(), geolocation=(), microphone=(), payment=()"
    : "camera=(self), geolocation=(self), microphone=(), payment=()");
  headers.set("x-robots-tag", "noindex, nofollow");
  return identify(new Response(request.method === "HEAD" ? null : html, { headers }), surface);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method !== "GET" && request.method !== "HEAD") {
      return identify(new Response("Method not allowed", {
        status: 405, headers: { allow: "GET, HEAD" },
      }), "unavailable");
    }
    if (url.hostname === ADMIN_HOST && url.pathname === "/") {
      return identify(Response.redirect(`${url.origin}/admin-auth`, 302), "admin");
    }
    const surface = isAdminPath(url.pathname) ? "admin" : isAppPath(url.pathname) ? "app" : null;
    try {
      if (surface) return await serveFlutterShell(env, request, surface);
      const response = await env.ASSETS.fetch(request);
      const isHtml = response.headers.get("content-type")?.toLowerCase().includes("text/html");
      if (url.pathname.startsWith("/releases/") &&
          (isHtml || !/^\/releases\/[0-9a-f]{64}\/.+/.test(url.pathname))) {
        await response.body?.cancel();
        return identify(new Response(request.method === "HEAD" ? null : "Release asset not found", {
          status: 404,
        }), "asset", url.pathname);
      }
      if (request.method === "HEAD") await response.body?.cancel();
      return identify(response, isHtml ? "website" : "asset", url.pathname, request.method === "HEAD");
    } catch {
      return unavailable(request, surface ?? "website");
    }
  },
};
