#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
supabase_bin="${SUPABASE_BIN:-$(command -v supabase || true)}"
docker_bin="${DOCKER_BIN:-$(command -v docker || true)}"
deno_bin="${DENO_BIN:-$(command -v deno || true)}"
for executable in "$supabase_bin" "$docker_bin" "$deno_bin"; do
  [[ -n "$executable" && -x "$executable" ]] || { printf 'Auth fixture requires installed Supabase, Docker and Deno executables.\n' >&2; exit 1; }
done
# The tracked concurrency driver uses Docker from PATH. Keep the selected
# executable consistent without changing any user's installed tools.
export PATH="$(dirname "$docker_bin"):$PATH"
qa_dir="$(mktemp -d)"
project="mobio_auth_$$"
evidence_base="${MOBIO_AUTH_EVIDENCE_DIR:-$root/build/qa/readiness-20261001/goal/auth}"
mkdir -p "$evidence_base"
evidence_dir="$(cd "$evidence_base" && pwd)/run-$$"
mkdir -p "$evidence_dir"
chmod 700 "$qa_dir"
source_manifest() {
  python3 - "$1" <<'PY'
from pathlib import Path
import hashlib,json,sys
paths=set(Path('supabase/migrations').glob('*.sql'))
for pattern in ['supabase/functions/_shared/*.ts','supabase/functions/send-login-otp/*.ts',
 'supabase/functions/verify-login-otp/*.ts','supabase/functions/verify-otp/*.ts',
 'supabase/functions/store-review-session/*.ts','supabase/functions/maps-gateway/*.ts',
 'supabase/functions/biopay-face-provider/*.ts','supabase/functions/biopay-face-maintenance/*.ts',
 'scripts/qa/test_auth_session_authority*',
 'scripts/qa/face_maps_http_authority.ts','scripts/qa/test_face_maps_authority_concurrency.py',
 'scripts/qa/admin_users_role_http_authority.ts','scripts/qa/privacy_subject_http_authority.ts',
 'scripts/qa/permission_clock_http_authority.ts',
 'scripts/qa/cleanup_supabase_fixture.py']:
 paths.update(Path().glob(pattern))
paths.update(Path(p) for p in ['supabase/config.toml','deno.lock',
 'supabase/tests/consumer_session_proof.sql','supabase/tests/store_review_login_integration.sql',
 'supabase/tests/face_maps_interactive_authority.sql'])
Path(sys.argv[1]).write_text(json.dumps({str(p):hashlib.sha256(p.read_bytes()).hexdigest()
 for p in sorted(paths) if p.is_file()},indent=2)+'\n')
PY
}
source_manifest "$evidence_dir/source-before.json"
"$supabase_bin" --version > "$evidence_dir/supabase-version.txt" 2>&1
"$deno_bin" --version > "$evidence_dir/deno-version.txt" 2>&1
"$docker_bin" version --format '{{.Client.Version}} {{.Server.Version}}' > "$evidence_dir/docker-version.txt"
cleanup() {
  source_manifest "$evidence_dir/source-after.json"
  if cmp -s "$evidence_dir/source-before.json" "$evidence_dir/source-after.json"; then
    printf '{"source_unchanged":true}\n' > "$evidence_dir/source-stability.json"
  else
    printf '{"source_unchanged":false}\n' > "$evidence_dir/source-stability.json"
    printf 'Auth fixture source changed during the run; repeat current-source acceptance.\n' >&2
  fi
  if ! python3 scripts/qa/cleanup_supabase_fixture.py --project "$project" > "$evidence_dir/owned-cleanup.json" 2>&1; then
    printf 'Owned Auth fixture cleanup failed; private temporary workspace retained.\n' >&2
    return 1
  fi
  rm -rf "$qa_dir"
  printf '{"project":"%s","containers_absent":true,"volumes_absent":true,"networks_absent":true,"temporary_workdir_absent":true}\n' "$project" > "$evidence_dir/cleanup.json"
}
trap cleanup EXIT
db_psql() {
  "$docker_bin" exec -i "supabase_db_$project" sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql "$@"' sh "$@"
}
"$supabase_bin" --workdir "$qa_dir" init > "$qa_dir/init.log" 2>&1
python3 - "$qa_dir" "$project" <<'PY'
from pathlib import Path
import socket,sys,re
work=Path(sys.argv[1]); s=Path('supabase/config.toml').read_text()
s=re.sub(r'^project_id = .*$',f'project_id = "{sys.argv[2]}"',s,flags=re.M)
ports={}
for port in sorted(set(re.findall(r'^\s*(?:port|shadow_port) = (\d+)$',s,re.M))):
 with socket.socket() as sock:
  sock.bind(('127.0.0.1',0));ports[port]=str(sock.getsockname()[1])
for old,new in ports.items():s=re.sub(r'(^\s*(?:port|shadow_port) = )'+old+r'$',lambda m:m[1]+new,s,flags=re.M)
s=s.replace('sql_paths = ["./seed.sql"]','sql_paths = []')
import os
if os.environ.get('MOBIO_AUTH_ENABLE_PASSWORD_PROVIDERS')=='1':
 for section in ['email','sms']:
  s=re.sub(r'(\[auth\.'+section+r'\]\n(?:(?!\[).)*?enable_signup = )false',r'\g<1>true',s,flags=re.S)
(work/'supabase/config.toml').write_text(s)
PY
"$supabase_bin" --workdir "$qa_dir" start -x imgproxy,postgres-meta,studio,edge-runtime,logflare,vector,supavisor > "$qa_dir/start.log" 2>&1 || { printf 'Auth fixture startup failed (private log retained until cleanup).\n' >&2; exit 1; }
db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -c 'alter system set cron.launch_active_jobs = off' > "$qa_dir/cron.log" 2>&1
db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -c 'select pg_reload_conf()' >> "$qa_dir/cron.log" 2>&1
[[ "$(db_psql -U postgres -Atc 'show cron.launch_active_jobs')" == off ]]
mkdir -p "$qa_dir/supabase/migrations"
python3 - "$qa_dir" "$evidence_dir" <<'PY'
from pathlib import Path
import hashlib,json,shutil,sys
out=Path(sys.argv[1])/'supabase/migrations'; sources={}
for p in sorted(Path('supabase/migrations').glob('*.sql')):
 if p.name<'20261001210000':
  shutil.copyfile(p,out/p.name);sources[p.name]=hashlib.sha256(p.read_bytes()).hexdigest()
Path(sys.argv[2],'baseline-source.json').write_text(json.dumps(sources,indent=2)+'\n')
PY
"$supabase_bin" --workdir "$qa_dir" migration up --local > "$evidence_dir/baseline-migration.log" 2>&1
"$supabase_bin" --workdir "$qa_dir" status -o json > "$qa_dir/keys.json" 2> "$qa_dir/status.log"
chmod 600 "$qa_dir/keys.json"
"$docker_bin" inspect "supabase_auth_$project" --format '{{.Config.Image}} {{.Image}}' > "$evidence_dir/auth-image.txt"
python3 - "$docker_bin" "$project" "$evidence_dir" <<'PY'
import subprocess,json,sys
d=json.loads(subprocess.check_output([sys.argv[1],'inspect','supabase_auth_'+sys.argv[2]]))[0]
e=dict(x.split('=',1) for x in d['Config']['Env'] if '=' in x)
keys=['GOTRUE_EXTERNAL_PHONE_ENABLED','GOTRUE_EXTERNAL_EMAIL_ENABLED','GOTRUE_DISABLE_SIGNUP','GOTRUE_SMS_AUTOCONFIRM','GOTRUE_SECURITY_UPDATE_PASSWORD_REQUIRE_REAUTHENTICATION','GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED']
from pathlib import Path
Path(sys.argv[3],'effective-auth-settings.json').write_text(json.dumps({k:e.get(k) for k in keys},indent=2)+'\n')
PY
python3 scripts/qa/test_auth_session_authority.py --credentials "$qa_dir/keys.json" --output "$evidence_dir/baseline.json" --mode baseline
if [[ "${MOBIO_AUTH_BASELINE_ONLY:-0}" != 1 ]]; then
  python3 - "$qa_dir" <<'PY'
from pathlib import Path
import shutil,sys
out=Path(sys.argv[1])/'supabase/migrations'
for p in sorted(Path('supabase/migrations').glob('*.sql')):
 if p.name>='20261001210000':shutil.copyfile(p,out/p.name)
PY
  python3 - "$qa_dir" "$evidence_dir" <<'PY'
from pathlib import Path
import hashlib,json,sys
paths=Path(sys.argv[1],'supabase/migrations').glob('*.sql')
Path(sys.argv[2],'corrected-source.json').write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest()
 for p in sorted(paths)},indent=2)+'\n')
PY
  "$supabase_bin" --workdir "$qa_dir" migration up --local > "$evidence_dir/corrected-migration.log" 2>&1
  for name in consumer_session_proof store_review_login_integration; do
    db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < "supabase/tests/$name.sql" > "$evidence_dir/$name.log" 2>&1
  done
  python3 scripts/qa/test_auth_session_authority.py --credentials "$qa_dir/keys.json" --output "$evidence_dir/corrected.json" --mode corrected
  MOBIO_AUTH_FIXTURE_PROJECT="$project" MOBIO_AUTH_FIXTURE_DOCKER="$docker_bin" \
    "$deno_bin" run --cached-only --frozen --lock=deno.lock --allow-env --allow-read --allow-write --allow-net --allow-run="$docker_bin" \
    scripts/qa/test_auth_session_authority_http.ts "$qa_dir/keys.json" "$evidence_dir/handler-http.json"
  db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 < supabase/tests/face_maps_interactive_authority.sql > "$evidence_dir/face_maps_interactive_authority.log" 2>&1
  python3 scripts/qa/test_face_maps_authority_concurrency.py "supabase_db_$project" \
    --authorized-shared-container "supabase_db_$project" > "$evidence_dir/face-maps-concurrency.log" 2>&1
fi
source_manifest "$evidence_dir/source-after.json"
cmp -s "$evidence_dir/source-before.json" "$evidence_dir/source-after.json" || { printf 'Source changed during Auth fixture; acceptance is invalid.\n' >&2; exit 1; }
printf 'Auth authority fixture completed: %s\n' "$evidence_dir"
