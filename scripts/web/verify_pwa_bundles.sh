#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

output_root="${1:-build/pwa}"

python3 - <<'PY' "$output_root"
import json
import os
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
    ".well-known/assetlinks.json",
    "__admin_shell",
    "admin-manifest.json",
    "flutter_bootstrap.js",
    "main.dart.js",
    "style.css",
    "script.js",
    "privacy-policy.html",
    "terms-and-conditions.html",
    "account-deletion.html",
    "assets/mobio-journey-hero.jpg",
    "assets/fonts/AeonikPro-Medium.woff2",
    "assets/fonts/AeonikPro-Regular.woff2",
    "assets/fonts/Inter-Regular.woff2",
    "_worker.js",
    "_headers",
    "_redirects",
):
    require((site_dir / filename).is_file(), f"Missing {site_dir / filename}")

admin_manifest = read_manifest(site_dir / "admin-manifest.json")
assetlinks = read_manifest(site_dir / ".well-known/assetlinks.json")
aasa_path = site_dir / ".well-known/apple-app-site-association"

require(admin_manifest.get("name") == "Mobio Admin", "Admin manifest name mismatch")
require(admin_manifest.get("short_name") == "MobioAdmin", "Admin manifest short_name mismatch")
require(admin_manifest.get("start_url") == "/admin-auth", "Admin manifest start_url mismatch")
require(
    admin_manifest.get("description") == "Mobio admin progressive web app.",
    "Admin manifest description mismatch",
)

require(isinstance(assetlinks, list) and assetlinks, "Asset links must be a non-empty array")
assetlinks_target = assetlinks[0].get("target", {})
require(assetlinks_target.get("namespace") == "android_app", "Asset links namespace mismatch")
require(assetlinks_target.get("package_name") == "rw.mobi.app", "Asset links package mismatch")
require(
    "DA:9E:5E:AB:50:D0:85:05:BF:0B:78:7C:EA:B5:DB:5B:40:77:8E:BE:77:62:95:72:16:8A:72:37:D7:79:81:C0"
    in assetlinks_target.get("sha256_cert_fingerprints", []),
    "Asset links fingerprint missing",
)

apple_team_id = os.environ.get("APPLE_TEAM_ID", "").strip()
if apple_team_id:
    aasa = read_manifest(aasa_path)
    expected_app_id = f"{apple_team_id}.rw.mobi.app"
    details = aasa.get("applinks", {}).get("details", [])
    app_ids = []
    for detail in details:
        if "appIDs" in detail and isinstance(detail["appIDs"], list):
            app_ids.extend(detail["appIDs"])
        if "appID" in detail:
            app_ids.append(detail["appID"])
    require(expected_app_id in app_ids, "AASA appID mismatch")
elif not aasa_path.exists():
    print("warning: APPLE_TEAM_ID not set; skipping AASA validation", file=sys.stderr)

landing_index = read_text(site_dir / "index.html")
admin_index = read_text(site_dir / "__admin_shell")
headers = read_text(site_dir / "_headers")
redirects = read_text(site_dir / "_redirects")
worker = read_text(site_dir / "_worker.js")

require(
    "<title>Mobio — Your next connection</title>" in landing_index,
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
    "/.well-known/apple-app-site-association",
):
    require(expected in headers, f"Combined headers missing {expected}")

require(
    "Permissions-Policy: camera=(), geolocation=(), microphone=(), payment=()"
    in headers,
    "Admin permissions policy must deny camera, geolocation, microphone, and payment",
)

print(f"Verified PWA bundles at {root}")
PY
