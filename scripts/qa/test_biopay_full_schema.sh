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
  local original_status="$?"
  if python3 scripts/qa/cleanup_supabase_fixture.py --project "$project" > "$qa_dir/cleanup.log" 2>&1; then
    rm -rf "$qa_dir"
  else
    cat "$qa_dir/cleanup.log" >&2
    echo "Owned fixture cleanup failed; private evidence retained at $qa_dir" >&2
    if [[ "$original_status" == 0 ]]; then exit 1; fi
  fi
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
  || { cat "$qa_dir/migrate.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/hardening/2026-09-28/post_install_assertions.sql > "$qa_dir/post-install.log" 2>&1 \
  || { tail -n 35 "$qa_dir/post-install.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/biopay_discovery_behavior.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/behavior.log" 2>&1 \
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
# The outbox test replaces pg_net HTTP with a fail-closed function inside a
# rolled-back transaction; the administrator owns the extension function.
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/notification_dispatch_behavior.sql | db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 > "$qa_dir/notification-dispatch.log" 2>&1 \
  || { tail -n 35 "$qa_dir/notification-dispatch.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/notification_current_session_authority.sql | db_psql -U postgres -d postgres -v ON_ERROR_STOP=1 > "$qa_dir/notification-current-session.log" 2>&1 \
  || { tail -n 35 "$qa_dir/notification-current-session.log"; exit 1; }
python3 scripts/qa/test_otp_rate_limit_db.py --container "supabase_db_$project" \
  --output "$qa_dir/otp-rate-limit.json" > "$qa_dir/otp-rate-limit.log" 2>&1 \
  || { tail -n 35 "$qa_dir/otp-rate-limit.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/notification_realtime_authority.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/notification-realtime.log" 2>&1 \
  || { tail -n 35 "$qa_dir/notification-realtime.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/permission_expiry_behavior.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/permission-expiry.log" 2>&1 \
  || { tail -n 35 "$qa_dir/permission-expiry.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/live_identity_behavior.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/live-identity.log" 2>&1 \
  || { tail -n 35 "$qa_dir/live-identity.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/profile_identity_authority.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/profile-identity-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/profile-identity-authority.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/admin_login_authority.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/admin-login-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/admin-login-authority.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/driver_discovery_authority.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/driver-discovery-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/driver-discovery-authority.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/organization_permission_authority.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/organization-permission-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/organization-permission-authority.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/admin_recent_auth_authority.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/admin-recent-auth-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/admin-recent-auth-authority.log"; exit 1; }
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/admin_user_queries_role_receipts.sql | db_psql -U postgres -v ON_ERROR_STOP=1 > "$qa_dir/admin-user-query-role-receipts.log" 2>&1 \
  || { tail -n 35 "$qa_dir/admin-user-query-role-receipts.log"; exit 1; }
python3 scripts/qa/test_admin_role_operations_concurrency.py "supabase_db_$project" \
  > "$qa_dir/admin-role-concurrency.log" 2>&1 \
  || { tail -n 35 "$qa_dir/admin-role-concurrency.log"; exit 1; }
# Platform-owned Storage fixture rows require the administrator for setup; the
# rolled-back regression switches to the real authenticated/service SQL roles.
cat supabase/tests/helpers/seed_interactive_authority.sql supabase/tests/store_review_authority.sql | db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 > "$qa_dir/store-review-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/store-review-authority.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/consumer_session_proof.sql > "$qa_dir/consumer-session-proof.log" 2>&1 \
  || { tail -n 35 "$qa_dir/consumer-session-proof.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/store_review_login_integration.sql > "$qa_dir/store-review-login.log" 2>&1 \
  || { tail -n 35 "$qa_dir/store-review-login.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/face_maps_interactive_authority.sql > "$qa_dir/face-maps-authority.log" 2>&1 \
  || { tail -n 35 "$qa_dir/face-maps-authority.log"; exit 1; }
db_psql -U postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/privacy_subject_authority_fence.sql > "$qa_dir/privacy-subject-fence.log" 2>&1 \
  || { tail -n 35 "$qa_dir/privacy-subject-fence.log"; exit 1; }
python3 scripts/qa/test_privacy_subject_authority_fence_concurrency.py "supabase_db_$project" \
  > "$qa_dir/privacy-subject-fence-concurrency.log" 2>&1 \
  || { tail -n 35 "$qa_dir/privacy-subject-fence-concurrency.log"; exit 1; }
tail -n 5 "$qa_dir/privacy-subject-fence.log"
cat "$qa_dir/privacy-subject-fence-concurrency.log"
db_psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 \
  < supabase/tests/face_pending_subject_admission.sql > "$qa_dir/face-pending-admission.log" 2>&1 \
  || { tail -n 35 "$qa_dir/face-pending-admission.log"; exit 1; }
tail -n 5 "$qa_dir/face-pending-admission.log"
count="$(db_psql -U postgres -Atc 'select count(*) from supabase_migrations.schema_migrations')"
echo "Full-schema rehearsal passed: $count migrations; post-install catalog/invariants, BioPay, security, schema, provider, notification/current-session authority, realtime authority, permission expiry, live identity, profile identity authority, Admin login, driver discovery, organization permission authority, recent Admin authentication, Admin user snapshots/role receipts/concurrency, store-review foundation/login, consumer exact-session proof, Face/Maps authority, privacy subject authority fence/concurrency, pending Face admission and OTP rate-limit assertions passed."
