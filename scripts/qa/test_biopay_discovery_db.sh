#!/usr/bin/env bash
set -euo pipefail
# Disposable, network-isolated PostgreSQL fixture. No Supabase credentials.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root"
name="mobio-biopay-test-$$"
qa_dir="$(mktemp -d)"
cleanup() { docker rm --force "$name" >/dev/null 2>&1 || true; rm -rf "$qa_dir"; }
trap cleanup EXIT
docker run --detach --rm --name "$name" --network none --tmpfs /var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=local-fixture-only postgres:17-alpine >/dev/null
for attempt in {1..30}; do
  if docker exec "$name" pg_isready -U postgres >/dev/null 2>&1; then break; fi
  sleep 1
done
python3 - "$qa_dir/baseline.sql" <<'PY'
from pathlib import Path
import sys
fixture='''create role anon; create role authenticated; create role service_role;
create schema auth; create schema extensions;
create extension pgcrypto with schema extensions;
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
create table public.profiles(id uuid primary key, name text default '', phone text default '', member_id text, whatsapp_verified_at timestamptz, role text default 'passenger', momo_number text, momo_pay_code text);
create table public.admin_whatsapp_numbers(phone_e164 text,country_code text not null,is_active boolean);
'''
legacy=Path('supabase/migrations/20260612133000_biopay_ussd_aws_reactivation.sql').read_text()
fixture+=legacy[legacy.index('create table if not exists public.biopay_profiles'):legacy.index('alter table public.biopay_profiles enable')]
Path(sys.argv[1]).write_text(fixture)
PY
docker exec -i "$name" psql -U postgres -v ON_ERROR_STOP=1 < "$qa_dir/baseline.sql" >/dev/null
for migration in supabase/migrations/2026090809*.sql; do
  docker exec -i "$name" psql -U postgres -v ON_ERROR_STOP=1 < "$migration" >/dev/null
done
docker exec -i "$name" psql -U postgres -v ON_ERROR_STOP=1 < supabase/tests/biopay_discovery_behavior.sql
