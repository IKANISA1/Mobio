#!/usr/bin/env python3
# Mobio production hardening increment 01 | 2026-09-28
# Reviewable source generator, NOT a deployment or production-readiness claim.
# Python 3.10+. The source export may use UTF-8 BOM/CRLF; Python accepts these.
from __future__ import annotations
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys


PIN_PATH = 'scripts/ci/check_github_actions_pinned.sh'
GATE_PATH = 'scripts/qa/verify_mobio_feature_readiness.sh'
LOGIN_PATH = 'supabase/functions/verify-login-otp/index.ts'
OTP_PATH = 'supabase/functions/_shared/whatsapp-cloud.ts'
GRADLE_PATH = 'android/app/build.gradle.kts'
HCE_PATH = 'android/app/src/main/kotlin/rw/mobi/app/BioPayHostApduService.kt'
ACTIVITY_PATH = 'android/app/src/main/kotlin/rw/mobi/app/MainActivity.kt'


PIN_SCRIPT = r'''#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"
# Narrow static scanner; retain separate YAML/actionlint validation.
if [[ ! -d .github/workflows || -L .github || -L .github/workflows ]]; then
  echo "Missing or symlinked workflow directory." >&2
  exit 1
fi
shopt -s nullglob
workflows=(.github/workflows/*.yml .github/workflows/*.yaml)
if [[ ${#workflows[@]} -eq 0 ]]; then
  echo "No workflows found; validation is incomplete." >&2
  exit 1
fi
failures=0
uses_pattern='^[[:space:]-]*uses:[[:space:]]*([^[:space:]#]+)'
local_pattern='^\./\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml$'
remote_pattern='^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*@[0-9a-fA-F]{40}$'
for workflow in "${workflows[@]}"; do
  if [[ ! -f "$workflow" || ! -r "$workflow" || -L "$workflow" ]]; then
    echo "Unreadable or symlinked workflow: $workflow" >&2
    failures=1
    continue
  fi
  line_number=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_number=$((line_number + 1))
    if [[ "$line" =~ $uses_pattern ]]; then
      action_ref="${BASH_REMATCH[1]}"
      case "$action_ref" in
        \"*\"|\'*\') action_ref="${action_ref:1:${#action_ref}-2}" ;;
      esac
      if [[ "$action_ref" =~ $local_pattern ]]; then
        if [[ -f "$action_ref" && -r "$action_ref" && ! -L "$action_ref" ]]; then
          continue
        fi
        echo "Missing or symlinked local workflow: ${workflow}:${line_number}: ${action_ref}" >&2
        failures=1
      elif [[ ! "$action_ref" =~ $remote_pattern ]]; then
        echo "Unpinned or unsupported reference: ${workflow}:${line_number}: ${action_ref}" >&2
        failures=1
      fi
    fi
  done < "$workflow"
done
if [[ "$failures" -ne 0 ]]; then
  echo "Remote references require full commit SHAs; local reusable workflows must exist." >&2
  exit 1
fi
echo "github-actions pin check passed"
'''


GATE_PREFIX = r'''failures=0
# A skipped top-level group must never become a passing integrated gate.
# This does not certify nested checks, artifacts, or optional Face readiness.
for required_gate in RUN_MOBIO_CONTRACT_TESTS RUN_MOBIO_BIOPAY_FEATURE_GATE; do
  gate_setting="${!required_gate-true}"
  if [[ "$gate_setting" != "true" ]]; then
    echo "INCOMPLETE: $required_gate must be true for this integrated gate." >&2
    exit 2
  fi
done
'''


IDENTITY_HELPER = r'''export type VerifiedLoginUser = {
  id: string;
  phone?: string | null;
  phone_confirmed_at?: string | null;
  is_anonymous?: boolean;
  app_metadata?: Record<string, unknown>;
  banned_until?: string | null;
};


// Called only after OTP consumption. Profile/contact aliases are not authority.
export function assertVerifiedLoginIdentity(
  user: VerifiedLoginUser,
  expectedPhone: string,
  now = Date.now(),
): void {
  if (!/^\+[1-9][0-9]{7,14}$/.test(expectedPhone)) {
    throw new Error("AUTH_IDENTITY_INVALID");
  }
  const rawPhone = user.phone?.trim() ?? "";
  if (!/^\+?[1-9][0-9]{7,14}$/.test(rawPhone)) {
    throw new Error("AUTH_IDENTITY_INVALID");
  }
  const canonicalPhone = rawPhone.startsWith("+") ? rawPhone : `+${rawPhone}`;
  if (canonicalPhone !== expectedPhone) {
    throw new Error("AUTH_IDENTITY_MISMATCH");
  }
  if (user.is_anonymous || !user.phone_confirmed_at ||
      !Number.isFinite(Date.parse(user.phone_confirmed_at))) {
    throw new Error("AUTH_IDENTITY_UNVERIFIED");
  }
  if (user.app_metadata?.role === "admin") {
    throw new Error("ADMIN_PROFILE_REQUIRES_ADMIN_LOGIN");
  }
  if (user.banned_until) {
    const bannedUntil = Date.parse(user.banned_until);
    if (!Number.isFinite(bannedUntil) || bannedUntil > now) {
      throw new Error("AUTH_IDENTITY_BANNED");
    }
  }
}
'''


IDENTITY_TESTS = r'''import { assertVerifiedLoginIdentity, type VerifiedLoginUser } from "./verified-login-identity.ts";
const phone = "+250788000001";
const now = Date.parse("2026-09-28T00:00:00Z");
const base: VerifiedLoginUser = {
  id: "00000000-0000-4000-8000-000000000001",
  phone,
  phone_confirmed_at: "2026-09-01T00:00:00Z",
  is_anonymous: false,
  app_metadata: { role: "passenger" },
};
function rejects(user: VerifiedLoginUser, expectedCode: string): void {
  try { assertVerifiedLoginIdentity(user, phone, now); }
  catch (error) {
    if (error instanceof Error && error.message === expectedCode) return;
    throw error;
  }
  throw new Error(`Expected ${expectedCode}`);
}
Deno.test("confirmed canonical phone accepted", () => assertVerifiedLoginIdentity(base, phone, now));
Deno.test("Auth digits-only representation accepted", () => assertVerifiedLoginIdentity({ ...base, phone: "250788000001" }, phone, now));
Deno.test("different phone rejected", () => rejects({ ...base, phone: "+250788000002" }, "AUTH_IDENTITY_MISMATCH"));
Deno.test("unconfirmed phone rejected", () => rejects({ ...base, phone_confirmed_at: null }, "AUTH_IDENTITY_UNVERIFIED"));
Deno.test("invalid confirmation time rejected", () => rejects({ ...base, phone_confirmed_at: "invalid" }, "AUTH_IDENTITY_UNVERIFIED"));
Deno.test("anonymous identity rejected", () => rejects({ ...base, is_anonymous: true }, "AUTH_IDENTITY_UNVERIFIED"));
Deno.test("admin uses separate flow", () => rejects({ ...base, app_metadata: { role: "admin" } }, "ADMIN_PROFILE_REQUIRES_ADMIN_LOGIN"));
Deno.test("active ban rejected", () => rejects({ ...base, banned_until: "2099-01-01T00:00:00Z" }, "AUTH_IDENTITY_BANNED"));
Deno.test("expired ban accepted", () => assertVerifiedLoginIdentity({ ...base, banned_until: "2026-01-01T00:00:00Z" }, phone, now));
Deno.test("malformed phone rejected without stripping arbitrary text", () => rejects({ ...base, phone: "user250788000001" }, "AUTH_IDENTITY_INVALID"));
'''


OTP_POLICY = r'''// Production code never simulates a successful OTP delivery.
// Tests should stub the provider; do not enable a delivery bypass by environment.
export function assertOtpDeliveryMode(raw: string | undefined): void {
  const mode = raw?.trim().toLowerCase();
  if (mode === undefined || mode === "" || mode === "false") return;
  if (mode === "true") throw new Error("OTP_DRY_RUN_DISABLED");
  throw new Error("OTP_DELIVERY_MODE_INVALID");
}
'''


OTP_TESTS = r'''import { assertOtpDeliveryMode } from "./otp-runtime-policy.ts";
Deno.test("real delivery is default", () => {
  for (const value of [undefined, "", "false", " FALSE "]) assertOtpDeliveryMode(value);
});
Deno.test("dry run cannot claim delivery success", () => {
  for (const value of ["true", " TRUE "]) {
    let denied = false;
    try { assertOtpDeliveryMode(value); }
    catch (error) { denied = error instanceof Error && error.message === "OTP_DRY_RUN_DISABLED"; }
    if (!denied) throw new Error("Dry-run configuration was accepted");
  }
});
Deno.test("unknown configuration fails closed", () => {
  for (const value of ["1", "yes", "enabled"]) {
    let denied = false;
    try { assertOtpDeliveryMode(value); }
    catch (error) { denied = error instanceof Error && error.message === "OTP_DELIVERY_MODE_INVALID"; }
    if (!denied) throw new Error("Unknown delivery configuration was accepted");
  }
});
'''


IDENTITY_SQL = r'''-- Candidate forward migration body. Generate its filename with Supabase CLI.
-- Does not repair historical misbindings or expose Auth users to client roles.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
create or replace function public.rpc_resolve_app_login_identity(p_phone text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_ids uuid[];
  v_owner auth.users%rowtype;
begin
  if p_phone is null or p_phone !~ '^\+[1-9][0-9]{7,14}$' then
    raise exception 'AUTH_IDENTITY_INVALID' using errcode = '22023';
  end if;
  select array_agg(u.id order by u.id) into v_ids
  from auth.users u
  where u.phone in (p_phone, substring(p_phone from 2));
  if coalesce(cardinality(v_ids), 0) = 0 then return null; end if;
  if cardinality(v_ids) <> 1 then
    raise exception 'AUTH_IDENTITY_AMBIGUOUS' using errcode = '28000';
  end if;
  select * into strict v_owner from auth.users where id = v_ids[1];
  if v_owner.phone_confirmed_at is null or coalesce(v_owner.is_anonymous, false) then
    raise exception 'AUTH_IDENTITY_UNVERIFIED' using errcode = '28000';
  end if;
  if v_owner.banned_until is not null and v_owner.banned_until > now() then
    raise exception 'AUTH_IDENTITY_BANNED' using errcode = '28000';
  end if;
  if v_owner.raw_app_meta_data ->> 'role' = 'admin' then
    raise exception 'ADMIN_PROFILE_REQUIRES_ADMIN_LOGIN' using errcode = '28000';
  end if;
  return v_owner.id;
end;
$function$;
revoke all on function public.rpc_resolve_app_login_identity(text) from public, anon, authenticated;
grant execute on function public.rpc_resolve_app_login_identity(text) to service_role;
comment on function public.rpc_resolve_app_login_identity(text) is
  'Service-only confirmed Auth phone resolution; never editable profile aliases.';
notify pgrst, 'reload schema';
commit;
'''


BOOKING_SQL = r'''-- M015 containment only: client writes removed, existing reads preserved.
-- Rehearse agency UI/RPC compatibility before any production application.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '30s';
alter table public.bus_bookings enable row level security;
revoke insert, update, delete, truncate, references, trigger
  on table public.bus_bookings from public, anon, authenticated;
do $containment$
declare
  columns_sql text;
  role_name text;
begin
  select string_agg(quote_ident(attname), ', ' order by attnum) into columns_sql
  from pg_catalog.pg_attribute
  where attrelid = 'public.bus_bookings'::regclass and attnum > 0 and not attisdropped;
  if columns_sql is null then raise exception 'Booking schema unavailable'; end if;
  execute format(
    'revoke insert (%s), update (%s), references (%s) on table public.bus_bookings from public, anon, authenticated',
    columns_sql, columns_sql, columns_sql
  );
  foreach role_name in array array['anon', 'authenticated'] loop
    if pg_catalog.has_table_privilege(role_name, 'public.bus_bookings', 'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
       or pg_catalog.has_any_column_privilege(role_name, 'public.bus_bookings', 'INSERT')
       or pg_catalog.has_any_column_privilege(role_name, 'public.bus_bookings', 'UPDATE')
       or pg_catalog.has_any_column_privilege(role_name, 'public.bus_bookings', 'REFERENCES') then
      raise exception 'Effective booking write privileges remain for %', role_name;
    end if;
  end loop;
end;
$containment$;
drop policy if exists bus_bookings_update_owner_hold_or_agency on public.bus_bookings;
notify pgrst, 'reload schema';
commit;
'''


SQL_VERIFY = r'''-- Run against an isolated migrated database with psql -v ON_ERROR_STOP=1.
-- These are privilege assertions, not provider, Auth-session or concurrency tests.
begin;
do $verify$
declare r text;
begin
  if not (select relrowsecurity from pg_catalog.pg_class where oid = 'public.bus_bookings'::regclass) then
    raise exception 'bus_bookings RLS disabled';
  end if;
  foreach r in array array['anon', 'authenticated'] loop
    if pg_catalog.has_table_privilege(r, 'public.bus_bookings', 'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
       or pg_catalog.has_any_column_privilege(r, 'public.bus_bookings', 'INSERT')
       or pg_catalog.has_any_column_privilege(r, 'public.bus_bookings', 'UPDATE')
       or pg_catalog.has_any_column_privilege(r, 'public.bus_bookings', 'REFERENCES') then
      raise exception 'Forbidden booking privilege: %', r;
    end if;
    if pg_catalog.has_function_privilege(r, 'public.rpc_resolve_app_login_identity(text)', 'EXECUTE') then
      raise exception 'Client can call service-only identity resolver: %', r;
    end if;
  end loop;
  if not pg_catalog.has_function_privilege('service_role', 'public.rpc_resolve_app_login_identity(text)', 'EXECUTE') then
    raise exception 'Service resolver grant missing';
  end if;
end;
$verify$;
rollback;
'''


GATE_TESTS = r'''import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]


class ProductionGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)


    def script(self, relative):
        destination = self.root / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, destination)
        return destination


    def pin(self, ref, create_local=False, symlink_local=False, newline=True):
        script = self.script('scripts/ci/check_github_actions_pinned.sh')
        workflows = self.root / '.github/workflows'
        workflows.mkdir(parents=True, exist_ok=True)
        content = 'name: fixture\non: push\njobs:\n  check:\n    uses: ' + ref
        (workflows / 'caller.yml').write_text(content + ('\n' if newline else ''), encoding='utf-8')
        if create_local:
            (workflows / 'child.yml').write_text('name: child\non: workflow_call\njobs: {}\n', encoding='utf-8')
        if symlink_local:
            (workflows / 'child.yml').symlink_to(workflows / 'caller.yml')
        return subprocess.run(['bash', str(script)], capture_output=True, text=True, timeout=10, check=False)


    def test_pinned_remote(self):
        result = self.pin('actions/checkout@' + 'a' * 40)
        self.assertEqual(result.returncode, 0, result.stderr)


    def test_quoted_pinned_remote(self):
        result = self.pin('"actions/checkout@' + 'a' * 40 + '"')
        self.assertEqual(result.returncode, 0, result.stderr)


    def test_unpinned_remote(self):
        self.assertNotEqual(self.pin('actions/checkout@v4').returncode, 0)


    def test_partial_sha(self):
        self.assertNotEqual(self.pin('actions/checkout@abc123').returncode, 0)


    def test_local_workflow(self):
        result = self.pin('./.github/workflows/child.yml', create_local=True)
        self.assertEqual(result.returncode, 0, result.stderr)


    def test_missing_local(self):
        self.assertNotEqual(self.pin('./.github/workflows/child.yml').returncode, 0)


    def test_symlink_local(self):
        self.assertNotEqual(self.pin('./.github/workflows/child.yml', symlink_local=True).returncode, 0)


    def test_traversal(self):
        self.assertNotEqual(self.pin('./.github/workflows/../child.yml').returncode, 0)


    def test_final_line_without_newline(self):
        self.assertNotEqual(self.pin('actions/checkout@v4', newline=False).returncode, 0)


    def test_no_workflows(self):
        script = self.script('scripts/ci/check_github_actions_pinned.sh')
        (self.root / '.github/workflows').mkdir(parents=True)
        result = subprocess.run(['bash', str(script)], capture_output=True, text=True, timeout=10, check=False)
        self.assertNotEqual(result.returncode, 0)


    def test_skip_invalid_empty_fail_before_flutter(self):
        script = self.script('scripts/qa/verify_mobio_feature_readiness.sh')
        for variable in ['RUN_MOBIO_CONTRACT_TESTS', 'RUN_MOBIO_BIOPAY_FEATURE_GATE']:
            for value in ['false', '0', 'yes', '']:
                with self.subTest(variable=variable, value=value):
                    env = dict(os.environ)
                    env.update(RUN_MOBIO_CONTRACT_TESTS='true', RUN_MOBIO_BIOPAY_FEATURE_GATE='true')
                    env[variable] = value
                    result = subprocess.run(['bash', str(script)], env=env, capture_output=True, text=True, timeout=10, check=False)
                    self.assertEqual(result.returncode, 2, result.stderr)
                    self.assertIn('INCOMPLETE:', result.stderr)
                    self.assertNotIn('PASS:', result.stdout)


    def test_child_failure_propagates(self):
        script = self.script('scripts/qa/verify_mobio_feature_readiness.sh')
        helper = self.root / 'scripts/lib/flutter.sh'
        helper.parent.mkdir(parents=True, exist_ok=True)
        helper.write_text('FLUTTER_BIN=/usr/bin/false\n', encoding='utf-8')
        child = self.root / 'scripts/qa/verify_biopay_live_readiness.sh'
        child.write_text('#!/usr/bin/env bash\nexit 1\n', encoding='utf-8')
        child.chmod(0o755)
        env = dict(os.environ, RUN_MOBIO_CONTRACT_TESTS='true', RUN_MOBIO_BIOPAY_FEATURE_GATE='true')
        result = subprocess.run(['bash', str(script)], env=env, capture_output=True, text=True, timeout=10, check=False)
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('NO-GO:', result.stderr)


if __name__ == '__main__':
    unittest.main()
'''


README = '''# Mobio hardening increment 01 - source candidate


Status: authored and exported, not runtime-tested or deployed in ChatGPT.
Scope: partial M003, M012, M015, M044, M047, M074 and M075. No 95-task completion claim.


The Python delivery file reads seven exact repository paths, checks source anchors,
and generates normalized UTF-8/LF overlay files, a reviewable patch and SHA-256
manifest. It does not edit the input repository, fetch dependencies, run migrations,
rotate keys, send OTPs or change production. Use --run-fixtures only to execute the
supplied local Python/Bash fixtures and pure Deno tests in the generated overlay.
Missing tooling remains unavailable, never passed.


Review and apply only on a controlled branch:
1. Inspect changes.patch and MANIFEST.json against your actual checkout.
2. Run git apply --check against the patch, then apply on the review branch.
3. Generate a forward migration filename with the installed Supabase CLI:
   supabase migration new --help
   supabase migration new production_identity_and_booking_containment
4. Copy both SQL bodies from supabase/production-patches into the generated file,
   preserving their order: verified_login_identity.sql, booking_write_authority.sql.
   Do not edit historical migrations or deploy Edge login before the resolver.
5. Rehearse clean and forward schema upgrades in an isolated database. Execute
   scripts/sql/verify_increment_01_privileges.sql with ON_ERROR_STOP enabled.
6. Run the full existing Deno/Flutter suite and real Auth/PostgREST role tests.
   Existing tests using the old OTP dry-run bypass must use provider stubs instead.
7. Test login, blocked/anonymous/admin identities, ordinary profile preservation,
   new-user races and agency booking compatibility before any promotion.


Limits: confirmed Auth phone replaces editable profile aliases for LOGIN only.
Historical identity remediation, verified phone-change workflow, profile column
protection and phone-based BioPay discovery remain open. Random password rotation
still needs concurrent-login acceptance; this increment does not redesign sessions.
Booking containment removes direct agency writes too. Authorized RPCs, seat expiry,
receipt uniqueness, cancellation and refunds need their separate backlog work.
Top-level skipped gates now fail; nested gates and artifact-bound promotion still
need M075/M081 work. The pin scanner remains deliberately narrower than YAML syntax.
Android targetSdk is set to 36; no signed-build or Android 16 compatibility result is claimed.
NFC policy rejects missing, malformed or expired UTC/offset timestamps and malformed SELECT APDUs;
start validates expiry, status reflects expiry, and explicit stop clears stored payload/token/expiry.
Receiving-mode expiry must be supplied by the Flutter caller; missing expiry now fails closed.
Account ownership, restart/clock manipulation and complete logout/reboot cleanup still need M007/M047 work.
Run the pure JVM policy checks with kotlinc (policy file plus scripts/tests/BioPayNfcPolicyCheck.kt),
then java -jar on the resulting executable jar. This is separate from --run-fixtures and not a device test.
Face-USSD scope, no-liveness decision and disabled feature policy are unchanged.


The original Drive source files are not modified by this delivery. Never interpret
uploaded source, generated files or fixture results as production acceptance.
'''


NFC_POLICY = r'''package rw.mobi.app


import java.time.Instant


// Pure policy: no Android state or credentials, suitable for JVM fixture tests.
object BioPayNfcPolicy {
    fun isFresh(expiresAt: String?, nowMillis: Long = System.currentTimeMillis()): Boolean {
        if (expiresAt.isNullOrBlank()) return false
        return try {
            Instant.parse(expiresAt).toEpochMilli() > nowMillis
        } catch (_: java.time.DateTimeException) {
            false
        } catch (_: ArithmeticException) {
            false
        }
    }


    fun isSelectAid(command: ByteArray): Boolean {
        val expected = byteArrayOf(
            0x00, 0xA4.toByte(), 0x04, 0x00, 0x07,
            0xF0.toByte(), 0x4D, 0x4F, 0x42, 0x49, 0x4F, 0x00,
        )
        if (command.size != expected.size && command.size != expected.size + 1) return false
        if (!expected.indices.all { command[it] == expected[it] }) return false
        return command.size == expected.size || command.last() == 0.toByte()
    }
}
'''


NFC_TESTS = r'''import rw.mobi.app.BioPayNfcPolicy
import java.time.Instant


// Pure JVM assertions. This is not an Android emulator or physical-reader test.
fun main() {
    val select = byteArrayOf(0x00, 0xA4.toByte(), 0x04, 0x00, 0x07, 0xF0.toByte(), 0x4D, 0x4F, 0x42, 0x49, 0x4F, 0x00)
    check(BioPayNfcPolicy.isSelectAid(select))
    check(BioPayNfcPolicy.isSelectAid(select + byteArrayOf(0x00)))
    check(!BioPayNfcPolicy.isSelectAid(select + byteArrayOf(0x01)))
    check(!BioPayNfcPolicy.isSelectAid(select + byteArrayOf(0x00, 0x00)))
    check(!BioPayNfcPolicy.isSelectAid(select.copyOf().also { it[4] = 0x06 }))
    check(!BioPayNfcPolicy.isSelectAid(select.copyOf().also { it[11] = 0x01 }))
    check(!BioPayNfcPolicy.isSelectAid(byteArrayOf()))
    check(BioPayNfcPolicy.isFresh(Instant.ofEpochMilli(2000).toString(), 1000))
    check(!BioPayNfcPolicy.isFresh(Instant.ofEpochMilli(1000).toString(), 1000))
    check(!BioPayNfcPolicy.isFresh(Instant.ofEpochMilli(999).toString(), 1000))
    check(!BioPayNfcPolicy.isFresh(null, 1000))
    check(!BioPayNfcPolicy.isFresh("not-a-date", 1000))
    check(!BioPayNfcPolicy.isFresh("2026-09-28T10:00:00", 1000))
    println("Pure NFC policy assertions passed; device acceptance still required.")
}
'''


def patch_hce(source: str) -> str:
    anchor = '        if (!prefs.getBoolean(KEY_ENABLED, false)) return status("6A82")'
    replacement = anchor + '\n        if (!BioPayNfcPolicy.isFresh(prefs.getString(KEY_EXPIRES_AT, null))) return status("6A82")'
    source = once(source, anchor, replacement, 'native NFC expiry')
    old = '        val command = commandApdu.toHex()\n        return command.startsWith("00A40400") && command.contains(BIOPAY_AID)'
    return once(source, old, '        return BioPayNfcPolicy.isSelectAid(commandApdu)', 'strict SELECT APDU')


def patch_activity(source: str) -> str:
    old_start = '\n'.join([
        '                    val prefs = getSharedPreferences(BioPayHostApduService.PREFS_NAME, MODE_PRIVATE)',
        '                    prefs.edit()',
        '                        .putBoolean(BioPayHostApduService.KEY_ENABLED, true)',
    ])
    new_start = '\n'.join([
        '                    val expiresAt = call.argument<String>("expiresAt")',
        '                    if (!BioPayNfcPolicy.isFresh(expiresAt)) {',
        '                        result.error("INVALID_EXPIRY", "A future timezone-qualified NFC expiry is required.", null)',
        '                        return@setMethodCallHandler',
        '                    }',
        '                    val prefs = getSharedPreferences(BioPayHostApduService.PREFS_NAME, MODE_PRIVATE)',
        '                    prefs.edit()',
        '                        .putBoolean(BioPayHostApduService.KEY_ENABLED, true)',
    ])
    source = once(source, old_start, new_start, 'NFC start expiry validation')
    source = once(source, '.putString(BioPayHostApduService.KEY_EXPIRES_AT, call.argument<String>("expiresAt"))', '.putString(BioPayHostApduService.KEY_EXPIRES_AT, expiresAt)', 'persist validated NFC expiry')
    source = once(source, 'prefs.edit().putBoolean(BioPayHostApduService.KEY_ENABLED, false).apply()', 'prefs.edit().putBoolean(BioPayHostApduService.KEY_ENABLED, false)\n                        .remove(BioPayHostApduService.KEY_PAYLOAD)\n                        .remove(BioPayHostApduService.KEY_TOKEN)\n                        .remove(BioPayHostApduService.KEY_EXPIRES_AT).apply()', 'NFC explicit stop erasure')
    old_status = '        val enabled = supported && adapter?.isEnabled == true &&\n            prefs.getBoolean(BioPayHostApduService.KEY_ENABLED, false)'
    new_status = old_status + ' &&\n            BioPayNfcPolicy.isFresh(prefs.getString(BioPayHostApduService.KEY_EXPIRES_AT, null))'
    return once(source, old_status, new_status, 'truthful NFC enabled status')


def normalize(value: str) -> str:
    return value.lstrip('\ufeff').replace('\r\n', '\n').replace('\r', '\n').rstrip('\n') + '\n'


def once(source: str, old: str, new: str, label: str) -> str:
    if source.count(old) != 1:
        raise ValueError(f'Source drift at {label}; refusing to guess or overwrite')
    return source.replace(old, new, 1)


def patch_login(source: str) -> str:
    start = source.index('async function findExistingProfile(')
    end = source.index('async function loadAuthUserById(', start)
    old_lookup = source[start:end]
    for anchor in ['.eq("whatsapp_e164", phone)', '.eq("phone", phone)', '.order("created_at"']:
        if anchor not in old_lookup:
            raise ValueError('Login lookup source has changed; reconcile manually')
    replacement = '''async function findExistingProfile(
  supabase: ReturnType<typeof createAdminClient>,
  userId: string | null,
): Promise<ExistingProfileRow | null> {
  if (!userId) return null;
  const { data, error } = await supabase.from("profiles")
    .select("id, name, display_name, phone, role, location, vehicle, category, is_driver, vehicle_type, whatsapp, whatsapp_e164, country_code, momo_number, momo_pay_code, avatar_url, created_at")
    .eq("id", userId).maybeSingle();
  if (error) throw error;
  return data as ExistingProfileRow | null;
}


'''
    source = source[:start] + replacement + source[end:]
    source = once(source, 'import "jsr:@supabase/functions-js/edge-runtime.d.ts";', 'import "jsr:@supabase/functions-js/edge-runtime.d.ts";\nimport { assertVerifiedLoginIdentity } from "../_shared/verified-login-identity.ts";', 'identity helper import')
    source = once(source, '  if (error || !data.user) {\n    return null;\n  }', '  if (error) throw error;\n  if (!data.user) throw new Error("AUTH_IDENTITY_MISSING");', 'Auth read failure')
    source = once(source, '  let authUser = await loadAuthUserById(supabase, profileSeed?.id ?? null);', '', 'old alias-selected Auth user')
    new_start = '''  const { data: resolvedUserId, error: identityError } = await supabase.rpc(
    "rpc_resolve_app_login_identity", { p_phone: normalizedPhone },
  );
  if (identityError) throw identityError;
  if (resolvedUserId !== null && typeof resolvedUserId !== "string") {
    throw new Error("AUTH_IDENTITY_INVALID");
  }
  let authUser = await loadAuthUserById(supabase, resolvedUserId as string | null);
  if (authUser) assertVerifiedLoginIdentity(authUser, normalizedPhone);
  if (authUser && !authUser.email?.trim()) throw new Error("AUTH_EMAIL_RECOVERY_REQUIRED");
  const profileSeed = await findExistingProfile(supabase, authUser?.id ?? null);'''
    source = once(source, '  const profileSeed = await findExistingProfile(supabase, normalizedPhone);', new_start, 'verified identity selection')
    old_update = '\n'.join([
        '    const email = authUser.email?.trim() || fallbackEmail;',
        '    const { error } = await supabase.auth.admin.updateUserById(authUser.id, {',
        '      email,', '      email_confirm: true,', '      phone: normalizedPhone,',
        '      phone_confirm: true,', '      password,',
    ])
    new_update = '\n'.join([
        '    const { error } = await supabase.auth.admin.updateUserById(authUser.id, {',
        '      password,',
    ])
    source = once(source, old_update, new_update, 'remove existing Auth phone/email reassignment')
    source = once(source, '  const authEmail = authUser.email?.trim() || fallbackEmail;', '  assertVerifiedLoginIdentity(authUser, normalizedPhone);\n  const authEmail = authUser.email?.trim() || fallbackEmail;', 'post-create identity assertion')
    # Keep the existing email-password exchange after resolving the confirmed Auth phone.
    # This avoids introducing a new phone-provider configuration dependency.
    source = once(source, '    console.error("verify-login-otp error:", error);', '    console.error("verify-login-otp failed", { error_name: error instanceof Error ? error.name : "unknown" });', 'sanitized error logging')
    return source


def patch_otp(source: str) -> str:
    old = '\n'.join([
        '  if (Deno.env.get("WHATSAPP_CLOUD_DRY_RUN") == "true") {',
        '    console.log(`[whatsapp-cloud:dry-run] ${recipientPhone} -> ${code}`);',
        '    return;', '  }',
    ])
    source = once(source, old, '  assertOtpDeliveryMode(Deno.env.get("WHATSAPP_CLOUD_DRY_RUN"));', 'OTP dry-run branch')
    return 'import { assertOtpDeliveryMode } from "./otp-runtime-policy.ts";\n' + source


def safe_path(root: Path, relative: str) -> Path:
    path = root / relative
    if Path(relative).is_absolute() or '..' in Path(relative).parts:
        raise ValueError('Unsafe relative path')
    for parent in [path, *path.parents]:
        if parent == root: break
        if parent.is_symlink(): raise ValueError(f'Symlink not allowed: {relative}')
    if not path.resolve().is_relative_to(root): raise ValueError('Path escapes root')
    return path


def read_source(root: Path, relative: str) -> str:
    path = safe_path(root, relative)
    if not path.is_file() or path.stat().st_size > 2_000_000:
        raise ValueError(f'Missing or oversized source: {relative}')
    return normalize(path.read_text(encoding='utf-8-sig'))


def run_fixture_checks(root: Path) -> list[dict]:
    checks = [
        ('bash_syntax_pin', ['bash', '-n', str(root / PIN_PATH)]),
        ('bash_syntax_gate', ['bash', '-n', str(root / GATE_PATH)]),
        ('python_bash_fixtures', [sys.executable, str(root / 'scripts/tests/test_production_gate_containment.py')]),
        ('pure_deno_identity_and_otp', ['deno', 'test', '--no-config', str(root / 'supabase/functions/_shared/verified-login-identity.test.ts'), str(root / 'supabase/functions/_shared/otp-runtime-policy.test.ts')]),
    ]
    results = []
    for name, command in checks:
        if shutil.which(command[0]) is None:
            results.append({'name': name, 'status': 'unavailable', 'reason': 'required executable not found'})
            continue
        try:
            result = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=120, check=False)
            results.append({'name': name, 'status': 'passed' if result.returncode == 0 else 'failed', 'exit_code': result.returncode, 'stdout': result.stdout, 'stderr': result.stderr})
        except subprocess.TimeoutExpired:
            results.append({'name': name, 'status': 'failed', 'reason': 'timeout'})
    return results


def main() -> int:
    parser = argparse.ArgumentParser(description='Generate a reviewable Mobio patch; never modify the input repository or deploy.')
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path, help='New directory outside the input repository')
    parser.add_argument('--run-fixtures', action='store_true', help='Execute only generated local fixtures; no live providers or database')
    args = parser.parse_args()
    repo = args.repo.resolve(strict=True)
    output = args.output.resolve()
    if output == repo or output.is_relative_to(repo):
        parser.error('--output must be outside the input repository')
    if output.exists(): parser.error('--output must not already exist')
    originals = {p: read_source(repo, p) for p in [PIN_PATH, GATE_PATH, LOGIN_PATH, OTP_PATH, GRADLE_PATH, HCE_PATH, ACTIVITY_PATH]}
    if 'GitHub Actions must be pinned to immutable 40-character commit SHAs.' not in originals[PIN_PATH]:
        raise ValueError('Pin-check baseline changed; reconcile before replacing')
    gate = once(originals[GATE_PATH], 'failures=0\n', normalize(GATE_PREFIX), 'integrated gate preflight')
    payloads = {
        PIN_PATH: normalize(PIN_SCRIPT), GATE_PATH: normalize(gate),
        GRADLE_PATH: normalize(once(originals[GRADLE_PATH], '        targetSdk = 35', '        targetSdk = 36', 'Android target SDK')),
        HCE_PATH: normalize(patch_hce(originals[HCE_PATH])),
        ACTIVITY_PATH: normalize(patch_activity(originals[ACTIVITY_PATH])),
        'android/app/src/main/kotlin/rw/mobi/app/BioPayNfcPolicy.kt': normalize(NFC_POLICY),
        'scripts/tests/BioPayNfcPolicyCheck.kt': normalize(NFC_TESTS),
        LOGIN_PATH: normalize(patch_login(originals[LOGIN_PATH])),
        OTP_PATH: normalize(patch_otp(originals[OTP_PATH])),
        'scripts/tests/test_production_gate_containment.py': normalize(GATE_TESTS),
        'supabase/functions/_shared/verified-login-identity.ts': normalize(IDENTITY_HELPER),
        'supabase/functions/_shared/verified-login-identity.test.ts': normalize(IDENTITY_TESTS),
        'supabase/functions/_shared/otp-runtime-policy.ts': normalize(OTP_POLICY),
        'supabase/functions/_shared/otp-runtime-policy.test.ts': normalize(OTP_TESTS),
        'supabase/production-patches/verified_login_identity.sql': normalize(IDENTITY_SQL),
        'supabase/production-patches/booking_write_authority.sql': normalize(BOOKING_SQL),
        'scripts/sql/verify_increment_01_privileges.sql': normalize(SQL_VERIFY),
        'docs/release/production-hardening-increment-01.md': normalize(README),
    }
    for relative in payloads:
        if relative not in originals and safe_path(repo, relative).exists():
            raise ValueError(f'New-file collision: {relative}; refusing to overwrite')
    # Recheck sources after planning; concurrent edits invalidate this candidate.
    for relative, content in originals.items():
        if read_source(repo, relative) != content:
            raise ValueError(f'Source changed during planning: {relative}')
    output.mkdir(parents=True, exist_ok=False)
    overlay = output / 'overlay'
    patch_parts = []
    manifest = {'increment': '01', 'authored_date': '2026-09-28', 'input_repository_modified': False, 'deployed': False, 'production_ready': False, 'files': [], 'remaining_scope': 'All unclosed backlog work; these seven task areas are partial candidates, not accepted production fixes.'}
    for relative, content in sorted(payloads.items()):
        destination = safe_path(overlay, relative)
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(content.encode('utf-8'))
        if relative.endswith('.sh'): destination.chmod(0o755)
        old = originals.get(relative, '')
        patch_parts.extend(difflib.unified_diff(old.splitlines(keepends=True), content.splitlines(keepends=True), fromfile=('a/' + relative) if relative in originals else '/dev/null', tofile='b/' + relative))
        manifest['files'].append({'path': relative, 'before_sha256': hashlib.sha256(old.encode()).hexdigest() if relative in originals else None, 'after_sha256': hashlib.sha256(content.encode()).hexdigest(), 'bytes': len(content.encode())})
    (output / 'changes.patch').write_bytes(''.join(patch_parts).encode('utf-8'))
    (output / 'MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    results = run_fixture_checks(overlay) if args.run_fixtures else []
    validation = {'tests_requested': args.run_fixtures, 'results': results, 'database_and_device_tests': 'not_run', 'production_ready': False}
    (output / 'VALIDATION.json').write_text(json.dumps(validation, indent=2) + '\n', encoding='utf-8')
    print(f'Generated {len(payloads)} candidate source/test files at {output}. Input repository unchanged.')
    print('Database migration, actual Auth/PostgREST, Flutter/device and provider acceptance remain required.')
    if args.run_fixtures and any(result['status'] != 'passed' for result in results):
        print('Fixture validation incomplete or failed; inspect VALIDATION.json.', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        print(f'NOT COMPLETED: {error}', file=sys.stderr)
        raise SystemExit(2)