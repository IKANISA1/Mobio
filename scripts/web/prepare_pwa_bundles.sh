#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

source "$repo_root/scripts/lib/flutter.sh"

dart_define_file="$(mktemp "${TMPDIR:-/tmp}/mobi-dart-defines.XXXXXX.json")"
trap 'rm -f "${dart_define_file:-}"' EXIT

python3 "$repo_root/scripts/lib/runtime_defines.py" "$dart_define_file"

output_root="${1:-build/pwa}"
site_dir="$output_root/site"

rm -rf "$output_root"

if [[ "${SKIP_FLUTTER_BUILD:-false}" != "true" ]]; then
  if [[ "${WEB_WASM:-false}" == "true" ]]; then
    "$FLUTTER_BIN" build web --release --wasm \
      --dart-define-from-file="$dart_define_file"
  else
    "$FLUTTER_BIN" build web --release --no-wasm-dry-run \
      --dart-define-from-file="$dart_define_file"
  fi
fi

web_build_dir="${WEB_BUILD_DIR:-build/web}"
test -f "$web_build_dir/manifest.json"

mkdir -p "$site_dir"
cp -R "$web_build_dir/." "$site_dir/"
cp "$site_dir/index.html" "$site_dir/__app_shell"
cp "$site_dir/manifest.json" "$site_dir/app-manifest.json"
mv "$site_dir/index.html" "$site_dir/__admin_shell"
mv "$site_dir/manifest.json" "$site_dir/admin-manifest.json"
cp -R landing/. "$site_dir/"

cat > "$site_dir/_redirects" <<'EOF'
# Routing is handled by _worker.js so admin URLs keep their public path.
EOF

cp "$repo_root/scripts/web/pages_worker.mjs" "$site_dir/_worker.js"

cat > "$site_dir/_headers" <<'EOF'
/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), geolocation=(), microphone=(), payment=()

/index.html
  Cache-Control: no-store

/.well-known/assetlinks.json
  Content-Type: application/json; charset=utf-8
  Cache-Control: public, max-age=300

/.well-known/apple-app-site-association
  Content-Type: application/json; charset=utf-8
  Cache-Control: public, max-age=300

/__app_shell
  Cache-Control: no-store
  Referrer-Policy: no-referrer

/__admin_shell
  Content-Security-Policy: default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; img-src 'self' data: blob: https:; font-src 'self' data:; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com; style-src 'self' 'unsafe-inline'; connect-src 'self' https: wss:; worker-src 'self' blob:; manifest-src 'self'; media-src 'self' blob: data:; upgrade-insecure-requests
  Cache-Control: no-store

/flutter_bootstrap.js
  Cache-Control: no-store

/flutter_service_worker.js
  Cache-Control: no-store

/main.dart.js
  Cache-Control: no-cache

/assets/*
  Cache-Control: public, max-age=0, must-revalidate

/canvaskit/*
  Cache-Control: public, max-age=31536000, immutable

/icons/*
  Cache-Control: public, max-age=31536000, immutable

/splash/*
  Cache-Control: public, max-age=31536000, immutable

/*.css
  Cache-Control: public, max-age=86400

/script.js
  Cache-Control: public, max-age=86400
EOF

python3 - <<'PY' "$site_dir"
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

site_dir = Path(sys.argv[1])


def patch_manifest(path: Path, *, name: str, short_name: str, start_url: str, description: str) -> None:
    data = json.loads(path.read_text())
    data["name"] = name
    data["short_name"] = short_name
    data["start_url"] = start_url
    data["description"] = description
    path.write_text(json.dumps(data, indent=2) + "\n")


def patch_index(path: Path, *, title: str, description: str, redirect_root_to: str | None) -> None:
    html = path.read_text()
    html = html.replace("<title>Mobio</title>", f"<title>{title}</title>")
    html = re.sub(
        r'<meta name="description" content="[^"]*">',
        f'<meta name="description" content="{description}">',
        html,
    )
    html = html.replace(
        '<meta name="apple-mobile-web-app-title" content="Mobio">',
        f'<meta name="apple-mobile-web-app-title" content="{title}">',
    )
    if redirect_root_to:
        marker = '<script src="flutter_bootstrap.js" async=""></script>'
        redirect_script = f"""
  <script>
    if (window.location.pathname === "/" || window.location.pathname === "") {{
      window.location.replace("{redirect_root_to}");
    }}
  </script>
  <script src="flutter_bootstrap.js" async=""></script>"""
        html = html.replace(marker, redirect_script)
    path.write_text(html)


patch_manifest(
    site_dir / "admin-manifest.json",
    name="Mobio Admin",
    short_name="MobioAdmin",
    start_url="/admin-auth",
    description="Mobio admin progressive web app.",
)
patch_index(
    site_dir / "__admin_shell",
    title="Mobio Admin",
    description="Mobio admin progressive web app.",
    redirect_root_to=None,
)

patch_manifest(
    site_dir / "app-manifest.json",
    name="Mobio",
    short_name="Mobio",
    start_url="/biopay",
    description="Mobio payment requests and recipient discovery.",
)
app_html = (site_dir / "__app_shell").read_text()
app_html = app_html.replace('<link rel="manifest" href="manifest.json">', '<link rel="manifest" href="/app-manifest.json">')
(site_dir / "__app_shell").write_text(app_html)

admin_html = (site_dir / "__admin_shell").read_text()
admin_html = admin_html.replace(
    '<link rel="manifest" href="manifest.json">',
    '<link rel="manifest" href="/admin-manifest.json">',
)
(site_dir / "__admin_shell").write_text(admin_html)

landing_index = site_dir / "index.html"
html = landing_index.read_text()
admin_host_script = """
  <script>
    if (window.location.hostname === "mobioadmin.ikanisa.com") {
      window.location.replace("/admin-auth");
    }
  </script>
"""
html = html.replace("</head>", admin_host_script + "</head>")
landing_index.write_text(html)
PY

cp "$repo_root/scripts/web/admin_service_worker.js" "$site_dir/flutter_service_worker.js"
python3 "$repo_root/scripts/web/stamp_bundle.py" "$site_dir"
"$repo_root/scripts/web/verify_pwa_bundles.sh" "$output_root"

printf 'Prepared combined Pages bundle at %s\n' "$site_dir"
