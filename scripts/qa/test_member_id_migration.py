#!/usr/bin/env python3
"""Exercise the reviewed member-ID body against isolated PostgreSQL 17 data.

The table and accounts are synthetic; no linked database or real identifier is read.
"""
from __future__ import annotations

import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).resolve().parents[2]
BODY = ROOT / "supabase/hardening/2026-09-28/04_canonical_member_id.sql"
PREFLIGHT = ROOT / "supabase/hardening/2026-09-28/member_id_preflight.sql"


def command(args: list[str], source: str | None = None, *, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(args, input=source, text=True, capture_output=True, timeout=90)
    if check and result.returncode:
        raise RuntimeError(result.stderr[-3000:] or result.stdout[-1000:])
    return result


def main() -> int:
    image = os.environ.get("MOBIO_MEMBER_ID_POSTGRES_IMAGE", "")
    if not re.fullmatch(r"(?:docker\.io/library/)?postgres@sha256:[0-9a-f]{64}", image):
        raise ValueError("MOBIO_MEMBER_ID_POSTGRES_IMAGE must pin official PostgreSQL by digest")
    command(["docker", "image", "inspect", image])
    name = "mobio-member-id-qa-" + uuid.uuid4().hex[:12]
    started = False
    checks: list[str] = []

    def check(label: str, passed: bool) -> None:
        if not passed:
            raise AssertionError(label)
        checks.append(label)

    def sql(source: str, *, success: bool = True) -> subprocess.CompletedProcess[str]:
        return command(
            ["docker", "exec", "-i", name, "psql", "-X", "-q", "-A", "-t", "-F", "|",
             "-U", "postgres", "-v", "ON_ERROR_STOP=1"], source, check=success,
        )

    try:
        command([
            "docker", "run", "--detach", "--name", name, "--memory", "512m",
            "--read-only", "--tmpfs", "/var/lib/postgresql/data",
            "--tmpfs", "/var/run/postgresql", "--tmpfs", "/tmp",
            "-e", "POSTGRES_PASSWORD=synthetic-isolated-fixture", image,
        ])
        started = True
        for _ in range(100):
            try:
                logs = command(["docker", "logs", name])
                if "PostgreSQL init process complete" in logs.stdout and sql("select 1;").stdout.strip() == "1":
                    break
            except RuntimeError:
                pass
            time.sleep(0.2)
        else:
            raise RuntimeError("isolated PostgreSQL did not finish startup")
        version = int(sql("select current_setting('server_version_num');").stdout.strip())
        check("official PostgreSQL 17 runtime", 170000 <= version < 180000)
        sql("""
            create role anon nologin;
            create role authenticated nologin;
            create role service_role nologin;
            create function public.verified_app_user_id() returns uuid language sql stable as $$
              select nullif(current_setting('request.jwt.claim.sub', true),'')::uuid
            $$;
            create table public.profiles(
              id uuid primary key, created_at timestamptz, member_id text,
              name text, display_name text
            );
        """)

        sql("""
            insert into public.profiles(id,created_at,member_id) values
            ('00000000-0000-4000-8000-000000000001',now(),'123456'),
            ('00000000-0000-4000-8000-000000000002',now(),'123456');
        """)
        preflight = sql(PREFLIGHT.read_text()).stdout
        check("read-only preflight identifies duplicate without editing rows", "duplicate_values|1" in preflight)
        duplicate = sql(BODY.read_text(), success=False)
        check("duplicate historical ID fails closed", duplicate.returncode != 0
              and "MEMBER_ID_REMEDIATION_REQUIRED" in duplicate.stderr)
        check("duplicate failure preserves both account IDs and values", sql(
            "select count(*)=2 and count(distinct member_id)=1 from public.profiles;"
        ).stdout.strip() == "t")
        check("failed body leaves no new unique constraint", sql(
            "select to_regclass('public.profiles_member_id_unique') is null;"
        ).stdout.strip() == "t")

        sql("""
            truncate public.profiles;
            insert into public.profiles(id,created_at,member_id)
            values ('00000000-0000-4000-8000-000000000003',now(),'legacy-ABC');
        """)
        invalid = sql(BODY.read_text(), success=False)
        check("malformed historical ID fails closed", invalid.returncode != 0
              and "MEMBER_ID_REMEDIATION_REQUIRED" in invalid.stderr)
        check("invalid failure preserves original value", sql(
            "select member_id from public.profiles;"
        ).stdout.strip() == "legacy-ABC")

        sql("""
            truncate public.profiles;
            insert into public.profiles(id,created_at,member_id) values
            ('00000000-0000-4000-8000-000000000004',now(),'123456'),
            ('00000000-0000-4000-8000-000000000005',now(),'234567'),
            ('00000000-0000-4000-8000-000000000006',now(),null);
        """)
        sql(BODY.read_text())
        check("valid historical identifiers remain bound to original accounts", sql("""
            select count(*)=2 from public.profiles
            where (id='00000000-0000-4000-8000-000000000004' and member_id='123456')
               or (id='00000000-0000-4000-8000-000000000005' and member_id='234567');
        """).stdout.strip() == "t")
        check("null ID receives a unique six-digit server value", sql("""
            select count(*)=3 and count(distinct member_id)=3
              and bool_and(member_id ~ '^[0-9]{6}$')
            from public.profiles;
        """).stdout.strip() == "t")
        lookup = sql("""
            begin;
            set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000006';
            select public.rpc_lookup_wallet_transfer_recipient('123456')->>'member_id';
            commit;
        """)
        check("recipient lookup returns the exact canonical ID", "123456" in lookup.stdout)
        prefixed = sql("""
            begin;
            set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000006';
            select public.rpc_lookup_wallet_transfer_recipient('M123456');
            commit;
        """, success=False)
        check("recipient lookup rejects noncanonical prefixed ID", prefixed.returncode != 0
              and "INVALID_MEMBER_ID" in prefixed.stderr)
        self_lookup = sql("""
            begin;
            set local request.jwt.claim.sub='00000000-0000-4000-8000-000000000004';
            select public.rpc_lookup_wallet_transfer_recipient('123456');
            commit;
        """, success=False)
        check("recipient lookup rejects self transfer", self_lookup.returncode != 0
              and "SELF_TRANSFER_NOT_ALLOWED" in self_lookup.stderr)
        sql("""
            begin;
            set local request.jwt.claim.role='authenticated';
            insert into public.profiles(id,created_at,member_id)
            values ('00000000-0000-4000-8000-000000000007',now(),'caller-choice');
            commit;
        """)
        check("client-supplied member ID is replaced by a valid server value", sql("""
            select member_id ~ '^[0-9]{6}$' from public.profiles
            where id='00000000-0000-4000-8000-000000000007';
        """).stdout.strip() == "t")
        conflict = sql("""
            insert into public.profiles(id,created_at,member_id)
            values ('00000000-0000-4000-8000-000000000008',now(),'123456');
        """, success=False)
        check("unique index rejects later collision", conflict.returncode != 0
              and "duplicate key value" in conflict.stderr)
        barrier = threading.Barrier(2)

        def concurrent_client_insert(suffix: int) -> None:
            barrier.wait(timeout=5)
            sql(f"""
                begin;
                set local request.jwt.claim.role='authenticated';
                insert into public.profiles(id,created_at,member_id)
                values ('00000000-0000-4000-8000-{suffix:012d}',now(),'caller-choice');
                select pg_sleep(0.2);
                commit;
            """)

        with ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(concurrent_client_insert, (9, 10)))
        check("concurrent client allocations retain both distinct IDs", sql("""
            select count(*)=6 and count(distinct member_id)=6
              and bool_and(member_id ~ '^[0-9]{6}$') from public.profiles;
        """).stdout.strip() == "t")
        print(f"Member-ID migration rehearsal passed: {len(checks)} isolated PostgreSQL 17 checks; "
              "duplicate/invalid values fail closed, valid values persist, null/client IDs allocate safely and concurrently.")
        return 0
    finally:
        if started:
            subprocess.run(["docker", "rm", "-f", name], capture_output=True, timeout=20)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ValueError, RuntimeError, subprocess.TimeoutExpired, OSError) as error:
        print("NOT PASSED: " + str(error), file=sys.stderr)
        raise SystemExit(2)
