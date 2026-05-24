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
client_dir="$output_root/client"
admin_dir="$output_root/admin"

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

mkdir -p "$client_dir" "$admin_dir"
cp -R build/web/. "$client_dir/"
cp -R build/web/. "$admin_dir/"

cat > "$client_dir/_redirects" <<'EOF'
/* /index.html 200
EOF

cat > "$admin_dir/_redirects" <<'EOF'
/* /index.html 200
EOF

cat > "$client_dir/_headers" <<'EOF'
/*
  Content-Security-Policy: default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; img-src 'self' data: blob: https:; font-src 'self' data:; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; connect-src 'self' https: wss:; worker-src 'self' blob:; manifest-src 'self'; media-src 'self' blob: data:; upgrade-insecure-requests
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(self), geolocation=(self), microphone=(), payment=()

/index.html
  Cache-Control: no-store

/flutter_bootstrap.js
  Cache-Control: no-store

/flutter_service_worker.js
  Cache-Control: no-store

/assets/*
  Cache-Control: public, max-age=31536000, immutable
EOF

cat > "$admin_dir/_headers" <<'EOF'
/*
  Content-Security-Policy: default-src 'self'; base-uri 'self'; object-src 'none'; frame-ancestors 'none'; form-action 'self'; img-src 'self' data: blob: https:; font-src 'self' data:; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; connect-src 'self' https: wss:; worker-src 'self' blob:; manifest-src 'self'; media-src 'self' blob: data:; upgrade-insecure-requests
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), geolocation=(), microphone=(), payment=()

/index.html
  Cache-Control: no-store

/flutter_bootstrap.js
  Cache-Control: no-store

/flutter_service_worker.js
  Cache-Control: no-store

/assets/*
  Cache-Control: public, max-age=31536000, immutable
EOF

python3 - <<'PY' "$client_dir" "$admin_dir"
import json
import sys
from pathlib import Path

client_dir = Path(sys.argv[1])
admin_dir = Path(sys.argv[2])


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
    html = html.replace(
        '<meta name="description" content="A new Flutter project.">',
        f'<meta name="description" content="{description}">',
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
    client_dir / "manifest.json",
    name="Mobio App",
    short_name="Mobio",
    start_url="/",
    description="Mobio passenger and driver progressive web app.",
)
patch_index(
    client_dir / "index.html",
    title="Mobio App",
    description="Mobio passenger and driver progressive web app.",
    redirect_root_to=None,
)

patch_manifest(
    admin_dir / "manifest.json",
    name="Mobio Admin",
    short_name="MobioAdmin",
    start_url="/admin-auth",
    description="Mobio admin progressive web app.",
)
patch_index(
    admin_dir / "index.html",
    title="Mobio Admin",
    description="Mobio admin progressive web app.",
    redirect_root_to="/admin-auth",
)
PY

printf 'Prepared client bundle at %s\n' "$client_dir"
printf 'Prepared admin bundle at %s\n' "$admin_dir"
