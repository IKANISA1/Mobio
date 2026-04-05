#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

: "${SUPABASE_URL:?Missing SUPABASE_URL}"
: "${SUPABASE_ANON_KEY:?Missing SUPABASE_ANON_KEY}"
: "${PRIVACY_POLICY_URL:?Missing PRIVACY_POLICY_URL}"

output_root="${1:-build/pwa}"
client_dir="$output_root/client"
admin_dir="$output_root/admin"

rm -rf "$output_root"

if [[ "${SKIP_FLUTTER_BUILD:-false}" != "true" ]]; then
  flutter build web --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --dart-define=PRIVACY_POLICY_URL="$PRIVACY_POLICY_URL"
fi

mkdir -p "$client_dir" "$admin_dir"
cp -R build/web/. "$client_dir/"
cp -R build/web/. "$admin_dir/"

cat > "$client_dir/_redirects" <<'EOF'
/* /index.html 200
EOF

cat > "$admin_dir/_redirects" <<'EOF'
/* /index.html 200
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
