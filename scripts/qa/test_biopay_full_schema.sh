#!/usr/bin/env bash
set -euo pipefail

# Rebuild all tracked migrations in a disposable Supabase PostgreSQL instance.
# A unique project and unused ports keep other projects and linked databases safe.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
supabase_bin="${SUPABASE_BIN:-supabase}"
supabase_bin="$(command -v "$supabase_bin")"
qa_dir="$(mktemp -d)"
project="mobio_replay_$$"
cleanup() {
  "$supabase_bin" --workdir "$qa_dir" stop --project-id "$project" --no-backup >/dev/null 2>&1 || true
  rm -rf "$qa_dir"
}
trap cleanup EXIT
"$supabase_bin" --workdir "$qa_dir" init > "$qa_dir/init.log" 2>&1
python3 - "$qa_dir/supabase/config.toml" "$project" <<'PY'
from pathlib import Path
import socket,sys,re
p=Path(sys.argv[1])
s=p.read_text()
s=re.sub(r'^project_id = .*$',f'project_id = "{sys.argv[2]}"',s,flags=re.M)
# The services are excluded; only DB binds a host port. Choose an unused port.
with socket.socket() as sock:
    sock.bind(('127.0.0.1',0))
    port=sock.getsockname()[1]
s=s.replace('port = 54322',f'port = {port}')
p.write_text(s)
PY
"$supabase_bin" --workdir "$qa_dir" start \
  -x gotrue,realtime,storage-api,imgproxy,kong,mailpit,postgrest,postgres-meta,studio,edge-runtime,logflare,vector,supavisor \
  > "$qa_dir/start.log" 2>&1 || { tail -n 35 "$qa_dir/start.log"; exit 1; }

# This timestamp helper was verified live but omitted from historical migrations.
docker exec -i "supabase_db_$project" psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/fixtures/replay_prerequisites.sql > "$qa_dir/prerequisites.log" 2>&1
mkdir -p "$qa_dir/supabase/migrations"
cp supabase/migrations/*.sql "$qa_dir/supabase/migrations/"
"$supabase_bin" --workdir "$qa_dir" migration up --local > "$qa_dir/migrate.log" 2>&1 \
  || { tail -n 35 "$qa_dir/migrate.log"; exit 1; }
docker exec -i "supabase_db_$project" psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/biopay_discovery_behavior.sql > "$qa_dir/behavior.log" 2>&1 \
  || { tail -n 35 "$qa_dir/behavior.log"; exit 1; }
docker exec -i "supabase_db_$project" psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/backend_security_assertions.sql > "$qa_dir/security.log" 2>&1 \
  || { tail -n 35 "$qa_dir/security.log"; exit 1; }
count="$(docker exec "supabase_db_$project" psql -U postgres -Atc 'select count(*) from supabase_migrations.schema_migrations')"
echo "Full-schema BioPay rehearsal passed: $count migrations; behavior and backend security assertions passed."
