#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
source "$repo_root/scripts/lib/flutter.sh"
proof_output="${1:-build/visual-proof}"
dart_define_file="$(mktemp "${TMPDIR:-/tmp}/mobio-proof-defines.XXXXXX")"
trap 'rm -f "$dart_define_file"' EXIT
python3 "$repo_root/scripts/lib/runtime_defines.py" "$dart_define_file"
# The proof entrypoint has no real auth or Supabase session. Its AppConstants
# fixtures are debug-only; profile builds render those collections as empty.
# Release mode always disables the proof entrypoint.
"$FLUTTER_BIN" build web --debug --no-pub --no-wasm-dry-run \
  --target=tool/revolut_visual_proof_app.dart \
  --dart-define=MOBI_VISUAL_PROOF=true \
  --dart-define-from-file="$dart_define_file" \
  --output="$proof_output"

# The SDK cleanup worker can navigate an open client. Use the same non-reloading
# migration as the public bundle so synthetic inputs survive while inspecting.
python3 - "$proof_output" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, 'scripts/web')
from version_assets import BOOTSTRAP
output = Path(sys.argv[1])
bootstrap = output / 'flutter_bootstrap.js'
source = bootstrap.read_text()
marker = '_flutter.loader.load('
if source.count(marker) != 1:
    raise SystemExit('Unexpected Flutter bootstrap; inspect the SDK output')
bootstrap.write_text(source.split(marker)[0] + BOOTSTRAP.replace('__ASSET_BASE__', '/'))
(output / 'flutter_service_worker.js').write_bytes(Path('scripts/web/admin_service_worker.js').read_bytes())
PY
