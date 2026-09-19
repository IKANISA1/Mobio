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
db_psql() {
  # The pinned Supabase image authenticates local SQL connections. Read the
  # fixture's existing password inside its container; never echo or copy it.
  docker exec -i "supabase_db_$project" sh -c \
    'PGPASSWORD="$POSTGRES_PASSWORD" exec psql "$@"' sh "$@"
}
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

# Job execution is a separate test. Keep migration-created schedules dormant in
# this disposable schema/authority fixture before applying application SQL.
db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 \
  -c 'alter system set cron.launch_active_jobs = off' > "$qa_dir/cron.log" 2>&1 \
  || { tail -n 35 "$qa_dir/cron.log"; exit 1; }
db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 \
  -c 'select pg_reload_conf()' >> "$qa_dir/cron.log" 2>&1 \
  || { tail -n 35 "$qa_dir/cron.log"; exit 1; }
if [[ "$(db_psql -U postgres -Atc 'show cron.launch_active_jobs')" != off ]]; then
  echo 'Disposable database job execution could not be disabled.'
  exit 1
fi

# Replay the actual migration chain without injecting application prerequisites.
mkdir -p "$qa_dir/supabase/migrations"
cp supabase/migrations/*.sql "$qa_dir/supabase/migrations/"
"$supabase_bin" --workdir "$qa_dir" migration up --local > "$qa_dir/migrate.log" 2>&1 \
  || { tail -n 35 "$qa_dir/migrate.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/biopay_discovery_behavior.sql > "$qa_dir/behavior.log" 2>&1 \
  || { tail -n 35 "$qa_dir/behavior.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/backend_security_assertions.sql > "$qa_dir/security.log" 2>&1 \
  || { tail -n 35 "$qa_dir/security.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/schema_replay_assertions.sql > "$qa_dir/schema-replay.log" 2>&1 \
  || { tail -n 35 "$qa_dir/schema-replay.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/provider_authority_assertions.sql > "$qa_dir/provider-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/provider-authority.log"; exit 1; }
# This test replaces pg_net HTTP inside a rolled-back transaction. The local
# database administrator is required to replace that extension-owned function.
db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/notification_dispatch_behavior.sql > "$qa_dir/notification-dispatch.log" 2>&1 \
  || { tail -n 35 "$qa_dir/notification-dispatch.log"; exit 1; }
python3 scripts/qa/test_otp_rate_limit_db.py --container "supabase_db_$project" \
  --output "$qa_dir/otp-rate-limit.json" > "$qa_dir/otp-rate-limit.log" 2>&1 \
  || { tail -n 35 "$qa_dir/otp-rate-limit.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/notification_realtime_authority.sql > "$qa_dir/notification-realtime.log" 2>&1 \
  || { tail -n 35 "$qa_dir/notification-realtime.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/permission_expiry_behavior.sql > "$qa_dir/permission-expiry.log" 2>&1 \
  || { tail -n 35 "$qa_dir/permission-expiry.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/live_identity_behavior.sql > "$qa_dir/live-identity.log" 2>&1 \
  || { tail -n 35 "$qa_dir/live-identity.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/admin_login_authority.sql > "$qa_dir/admin-login-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/admin-login-authority.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/driver_discovery_authority.sql > "$qa_dir/driver-discovery-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/driver-discovery-authority.log"; exit 1; }
count="$(db_psql -U postgres -Atc 'select count(*) from supabase_migrations.schema_migrations')"
echo "Full-schema rehearsal passed: $count migrations; BioPay, security, schema, provider, notification, realtime authority, permission expiry, live identity, Admin login, driver discovery and OTP rate-limit assertions passed."
