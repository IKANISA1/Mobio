#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

default_flutter="/Volumes/PRO-G40/flutter_3_44/bin/flutter"
if [[ -z "${FLUTTER_BIN:-}" && -x "$default_flutter" ]]; then
  FLUTTER_BIN="$default_flutter"
else
  FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
fi

dart_define_file="$(mktemp "${TMPDIR:-/tmp}/mobi-dart-defines.XXXXXX.json")"
trap 'rm -f "${dart_define_file:-}"' EXIT

python3 - <<'PY' "$dart_define_file"
import json
import os
import sys
from pathlib import Path

path = sys.argv[1]
required = (
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "PRIVACY_POLICY_URL",
    "ACCOUNT_DELETION_URL",
)


def parse_dotenv(dotenv_path: Path) -> dict[str, str]:
    if not dotenv_path.exists():
        return {}
    values: dict[str, str] = {}
    for raw_line in dotenv_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[len("export "):].strip()
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'\"")
        if key:
            values[key] = value
    return values


dotenv = parse_dotenv(Path(".env"))
defines = {}
missing = []
for key in required:
    value = os.environ.get(key) or dotenv.get(key)
    if not value:
        missing.append(key)
    else:
        defines[key] = value

if missing:
    print(
        "Missing " + ", ".join(missing) + ". Add them to .env or export them before building.",
        file=sys.stderr,
    )
    raise SystemExit(1)

with open(path, "w", encoding="utf-8") as fh:
    json.dump(defines, fh)
PY

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

test -f build/web/manifest.json

mkdir -p "$site_dir"
cp -R build/web/. "$site_dir/"
mv "$site_dir/index.html" "$site_dir/__admin_shell"
mv "$site_dir/manifest.json" "$site_dir/admin-manifest.json"
cp -R landing/. "$site_dir/"

cat > "$site_dir/_redirects" <<'EOF'
# Routing is handled by _worker.js so admin URLs keep their public path.
EOF

cat > "$site_dir/_worker.js" <<'EOF'
const ADMIN_HOST = "mobioadmin.ikanisa.com";

function isAdminPath(pathname) {
  return pathname === "/admin-auth" ||
    pathname === "/admin" ||
    pathname.startsWith("/admin/");
}

async function serveAsset(env, request, pathname) {
  const url = new URL(request.url);
  url.pathname = pathname;
  return env.ASSETS.fetch(new Request(url, request));
}

async function serveAdminShell(env, request) {
  const response = await serveAsset(env, request, "/__admin_shell");
  const headers = new Headers(response.headers);
  headers.set("content-type", "text/html; charset=utf-8");
  return new Response(response.body, {
    status: 200,
    headers,
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.hostname === ADMIN_HOST && url.pathname === "/") {
      return Response.redirect(`${url.origin}/admin-auth`, 302);
    }

    if (isAdminPath(url.pathname)) {
      return serveAdminShell(env, request);
    }

    return env.ASSETS.fetch(request);
  },
};
EOF

cat > "$site_dir/_headers" <<'EOF'
/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), geolocation=(), microphone=(), payment=()

/index.html
  Cache-Control: no-store

/__admin_shell
  Content-Security-Policy: default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; img-src 'self' data: blob: https:; font-src 'self' data:; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' https://www.gstatic.com; style-src 'self' 'unsafe-inline'; connect-src 'self' https: wss:; worker-src 'self' blob:; manifest-src 'self'; media-src 'self' blob: data:; upgrade-insecure-requests
  Cache-Control: no-store

/flutter_bootstrap.js
  Cache-Control: no-store

/flutter_service_worker.js
  Cache-Control: no-store

/main.dart.js
  Cache-Control: public, max-age=31536000, immutable

/assets/*
  Cache-Control: public, max-age=31536000, immutable

/canvaskit/*
  Cache-Control: public, max-age=31536000, immutable

/icons/*
  Cache-Control: public, max-age=31536000, immutable

/splash/*
  Cache-Control: public, max-age=31536000, immutable

/*.css
  Cache-Control: public, max-age=86400

/*.js
  Cache-Control: public, max-age=86400
EOF

python3 - <<'PY' "$site_dir"
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

"$repo_root/scripts/web/verify_pwa_bundles.sh" "$output_root"

printf 'Prepared combined Pages bundle at %s\n' "$site_dir"
