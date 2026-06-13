#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

output_root="${1:-build/pwa}"

python3 - <<'PY' "$output_root"
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
site_dir = root / "site"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def read_text(path: Path) -> str:
    require(path.is_file(), f"Missing required PWA file: {path}")
    return path.read_text(encoding="utf-8")


def read_manifest(path: Path) -> dict[str, object]:
    require(path.is_file(), f"Missing required PWA manifest: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


require(site_dir.is_dir(), f"Missing combined Pages bundle directory: {site_dir}")
for filename in (
    "index.html",
    "__admin_shell",
    "admin-manifest.json",
    "flutter_bootstrap.js",
    "main.dart.js",
    "style.css",
    "script.js",
    "_worker.js",
    "_headers",
    "_redirects",
):
    require((site_dir / filename).is_file(), f"Missing {site_dir / filename}")

admin_manifest = read_manifest(site_dir / "admin-manifest.json")

require(admin_manifest.get("name") == "Mobio Admin", "Admin manifest name mismatch")
require(admin_manifest.get("short_name") == "MobioAdmin", "Admin manifest short_name mismatch")
require(admin_manifest.get("start_url") == "/admin-auth", "Admin manifest start_url mismatch")
require(
    admin_manifest.get("description") == "Mobio admin progressive web app.",
    "Admin manifest description mismatch",
)

landing_index = read_text(site_dir / "index.html")
admin_index = read_text(site_dir / "__admin_shell")
headers = read_text(site_dir / "_headers")
redirects = read_text(site_dir / "_redirects")
worker = read_text(site_dir / "_worker.js")

require(
    "<title>Mobio — Mobility Discovery in Rwanda</title>" in landing_index,
    "Landing index title mismatch",
)
require(
    'window.location.hostname === "mobioadmin.ikanisa.com"' in landing_index,
    "Admin custom-domain landing redirect missing",
)
require(
    'window.location.replace("/admin-auth")' in landing_index,
    "Admin custom-domain redirect target mismatch",
)
require("<title>Mobio Admin</title>" in admin_index, "Admin index title mismatch")
require(
    '<link rel="manifest" href="/admin-manifest.json">' in admin_index,
    "Admin manifest link mismatch",
)
require(
    "Mobio admin progressive web app." in admin_index,
    "Admin index description mismatch",
)

require(
    "Routing is handled by _worker.js" in redirects,
    "Redirects must delegate route control to the Pages worker",
)

for expected in (
    'const ADMIN_HOST = "mobioadmin.ikanisa.com";',
    'pathname === "/admin-auth"',
    'pathname === "/admin"',
    'pathname.startsWith("/admin/")',
    'Response.redirect(`${url.origin}/admin-auth`, 302)',
    'const response = await serveAsset(env, request, "/__admin_shell");',
    'headers.set("content-type", "text/html; charset=utf-8");',
    "return serveAdminShell(env, request);",
    "return env.ASSETS.fetch(request);",
):
    require(expected in worker, f"Pages worker missing {expected}")

for expected in (
    "Content-Security-Policy:",
    "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com",
    "X-Frame-Options: DENY",
    "X-Content-Type-Options: nosniff",
    "Referrer-Policy: strict-origin-when-cross-origin",
    "Cache-Control: no-store",
    "Cache-Control: public, max-age=31536000, immutable",
):
    require(expected in headers, f"Combined headers missing {expected}")

require(
    "Permissions-Policy: camera=(), geolocation=(), microphone=(), payment=()"
    in headers,
    "Admin permissions policy must deny camera, geolocation, microphone, and payment",
)

print(f"Verified PWA bundles at {root}")
PY
