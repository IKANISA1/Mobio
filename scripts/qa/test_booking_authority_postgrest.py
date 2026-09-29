#!/usr/bin/env python3
"""Exercise body 01 through real PostgreSQL 17 and PostgREST in isolated containers.

The booking table, JWTs and trusted RPC are synthetic. This proves the direct
write boundary of the forward SQL body, not the complete migration chain or a
hosted Mobio deployment. No external database, mounts or credentials are used.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import http.client
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
BOOKING = "00000000-0000-4000-8000-000000000010"
OWNER = "00000000-0000-4000-8000-000000000001"
JWT_SECRET = "synthetic-booking-authority-fixture-secret-2026"


def official_pg_image(value: str) -> str:
    if not re.fullmatch(r"(?:docker\.io/library/)?postgres@sha256:[0-9a-f]{64}", value):
        raise ValueError("MOBIO_BOOKING_POSTGRES_IMAGE must pin official postgres by digest")
    return value


def postgrest_image(value: str) -> str:
    if not re.fullmatch(r"public\.ecr\.aws/supabase/postgrest@sha256:[0-9a-f]{64}", value):
        raise ValueError("MOBIO_BOOKING_POSTGREST_IMAGE must pin the reviewed PostgREST image")
    return value


def jwt(role: str) -> str:
    if role not in ("authenticated", "service_role"):
        raise ValueError("fixture roles only")

    def encode(value: dict[str, object]) -> str:
        raw = json.dumps(value, separators=(",", ":")).encode()
        return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()

    data = encode({"alg": "HS256", "typ": "JWT"}) + "." + encode(
        {"role": role, "sub": OWNER, "exp": 2_200_000_000}
    )
    signature = hmac.new(JWT_SECRET.encode(), data.encode(), hashlib.sha256).digest()
    return data + "." + base64.urlsafe_b64encode(signature).rstrip(b"=").decode()


def command(args: list[str], source: str | None = None) -> str:
    result = subprocess.run(args, input=source, text=True, capture_output=True, timeout=90)
    if result.returncode:
        raise RuntimeError(result.stderr[-3000:] or result.stdout[-1000:])
    return result.stdout.strip()


def main() -> int:
    pg = official_pg_image(os.environ.get("MOBIO_BOOKING_POSTGRES_IMAGE", ""))
    rest = postgrest_image(os.environ.get("MOBIO_BOOKING_POSTGREST_IMAGE", ""))
    # Use only images already reviewed and present locally; no floating-tag pull.
    command(["docker", "image", "inspect", pg])
    command(["docker", "image", "inspect", rest])
    suffix = uuid.uuid4().hex[:12]
    network = "mobio-booking-qa-" + suffix
    db_name = "mobio-booking-db-" + suffix
    rest_name = "mobio-booking-rest-" + suffix
    network_created = False
    started: list[str] = []
    checks: list[str] = []

    def check(label: str, condition: bool) -> None:
        if not condition:
            raise AssertionError(label)
        checks.append(label)

    def sql(source: str) -> str:
        return command(
            ["docker", "exec", "-i", db_name, "psql", "-X", "-q", "-A", "-t", "-U", "postgres", "-v", "ON_ERROR_STOP=1"],
            source,
        )

    def request(port: int, method: str, path: str, role: str, payload: dict | None = None) -> tuple[int, str]:
        conn = http.client.HTTPConnection("127.0.0.1", port, timeout=5)
        body = json.dumps(payload) if payload is not None else None
        headers = {"Authorization": "Bearer " + jwt(role), "Accept": "application/json"}
        if body is not None:
            headers["Content-Type"] = "application/json"
            headers["Prefer"] = "return=representation"
        try:
            conn.request(method, path, body=body, headers=headers)
            response = conn.getresponse()
            return response.status, response.read(50_000).decode("utf-8", "replace")
        finally:
            conn.close()

    try:
        command(["docker", "network", "create", "--driver", "bridge", network])
        network_created = True
        command([
            "docker", "run", "--detach", "--name", db_name, "--network", network,
            "--memory", "512m", "--read-only", "--tmpfs", "/var/lib/postgresql/data",
            "--tmpfs", "/var/run/postgresql", "--tmpfs", "/tmp",
            "-e", "POSTGRES_PASSWORD=synthetic-isolated-fixture", pg,
        ])
        started.append(db_name)
        for _ in range(100):
            try:
                logs = subprocess.run(["docker", "logs", db_name], capture_output=True, text=True, timeout=10)
                # The official entrypoint first opens a temporary bootstrap
                # server, then stops it and starts the final server.
                if "PostgreSQL init process complete" in logs.stdout and sql("select 1;") == "1":
                    break
            except RuntimeError:
                pass
            time.sleep(0.2)
        else:
            raise RuntimeError("isolated PostgreSQL did not finish startup")
        check("PostgreSQL 17", 170000 <= int(sql("select current_setting('server_version_num');")) < 180000)
        check("empty isolated public schema", sql("select count(*) from pg_tables where schemaname='public';") == "0")
        sql(f"""
            create role anon nologin;
            create role authenticated nologin;
            create role service_role nologin;
            create role authenticator login password 'synthetic-postgrest-fixture';
            grant anon,authenticated,service_role to authenticator;
            grant usage on schema public to anon,authenticated,service_role;
            create table public.bus_bookings(
                id uuid primary key, passenger_id uuid not null, status text not null,
                paid_at timestamptz, receipt_ref text, price numeric, route_id uuid, seat_count integer not null
            );
            insert into public.bus_bookings(id,passenger_id,status,seat_count)
              values('{BOOKING}','{OWNER}','held',1);
            alter table public.bus_bookings enable row level security;
            create policy bus_bookings_select_fixture on public.bus_bookings
              for select to authenticated using(true);
            create policy bus_bookings_update_owner_hold_or_agency on public.bus_bookings
              for update to authenticated using(true) with check(true);
            create policy bus_bookings_insert_fixture on public.bus_bookings
              for insert to authenticated with check(true);
            create policy bus_bookings_delete_fixture on public.bus_bookings
              for delete to authenticated using(true);
            grant select,insert,update,delete,truncate on public.bus_bookings to authenticated;
            grant all on public.bus_bookings to service_role;
            create function public.rpc_fixture_confirm_booking(p_id uuid)
            returns jsonb language plpgsql security definer set search_path='' as $func$
            declare v public.bus_bookings%rowtype;
            begin
              update public.bus_bookings set status='confirmed',paid_at=clock_timestamp(),
                receipt_ref='fixture-trusted',price=1000,seat_count=1
                where id=p_id returning * into v;
              return to_jsonb(v);
            end $func$;
            revoke all on function public.rpc_fixture_confirm_booking(uuid) from public,anon,authenticated;
            grant execute on function public.rpc_fixture_confirm_booking(uuid) to service_role;
        """)
        command([
            "docker", "run", "--detach", "--name", rest_name, "--network", network,
            "--publish", "127.0.0.1::3000", "--memory", "256m",
            "-e", f"PGRST_DB_URI=postgres://authenticator:synthetic-postgrest-fixture@{db_name}:5432/postgres",
            "-e", "PGRST_DB_SCHEMAS=public", "-e", "PGRST_DB_ANON_ROLE=anon",
            "-e", "PGRST_JWT_SECRET=" + JWT_SECRET, rest,
        ])
        started.append(rest_name)
        try:
            port_line = command(["docker", "port", rest_name, "3000/tcp"])
        except RuntimeError as error:
            logs = subprocess.run(["docker", "logs", rest_name], capture_output=True, text=True, timeout=10)
            raise RuntimeError(f"PostgREST did not publish a local port: {error}; {logs.stderr[-1500:]}") from error
        port = int(port_line.rsplit(":", 1)[-1])
        status = 0
        for _ in range(50):
            try:
                status, _ = request(port, "GET", f"/bus_bookings?id=eq.{BOOKING}", "authenticated")
                if status == 200:
                    break
            except (OSError, http.client.HTTPException):
                pass
            time.sleep(0.2)
        else:
            raise RuntimeError("isolated PostgREST did not become ready")
        check("PostgREST table read reaches fixture", status == 200)
        status, _ = request(port, "PATCH", f"/bus_bookings?id=eq.{BOOKING}", "authenticated", {"status": "paid"})
        check("fixture reproduces vulnerable direct owner write before body 01", status == 200)
        sql(f"update public.bus_bookings set status='held' where id='{BOOKING}';")
        sql((ROOT / "supabase/hardening/2026-09-28/01_booking_write_authority.sql").read_text())
        check("effective authenticated table writes revoked", sql(
            "select has_table_privilege('authenticated','public.bus_bookings','INSERT,UPDATE,DELETE,TRUNCATE');"
        ) == "f")
        for column, value in (
            ("status", "paid"), ("paid_at", "2026-09-29T12:00:00Z"),
            ("receipt_ref", "forged"), ("price", 1),
            ("route_id", OWNER), ("seat_count", 99),
        ):
            status, _ = request(port, "PATCH", f"/bus_bookings?id=eq.{BOOKING}", "authenticated", {column: value})
            check("passenger direct write denied: " + column, status in (401, 403))
        status, _ = request(port, "POST", "/bus_bookings", "authenticated", {
            "id": str(uuid.uuid4()), "passenger_id": OWNER, "status": "paid", "seat_count": 1,
        })
        check("passenger direct insert denied", status in (401, 403))
        status, _ = request(port, "DELETE", f"/bus_bookings?id=eq.{BOOKING}", "authenticated")
        check("passenger direct delete denied", status in (401, 403))
        status, body = request(port, "GET", f"/bus_bookings?id=eq.{BOOKING}", "authenticated")
        check("passenger read retained and row unchanged", status == 200 and json.loads(body)[0]["status"] == "held")
        status, _ = request(port, "POST", "/rpc/rpc_fixture_confirm_booking", "authenticated", {"p_id": BOOKING})
        check("passenger cannot call trusted fixture RPC", status in (401, 403))
        status, body = request(port, "POST", "/rpc/rpc_fixture_confirm_booking", "service_role", {"p_id": BOOKING})
        check("trusted fixture RPC can still transition", status == 200 and json.loads(body)["status"] == "confirmed")
        print(json.dumps({"status": "PASS", "checks": checks, "count": len(checks),
                          "scope": "body01 + synthetic table/RPC through real PostgreSQL/PostgREST; not full Mobio schema or hosted acceptance"}, indent=2))
        return 0
    finally:
        for name in reversed(started):
            subprocess.run(["docker", "rm", "-f", name], capture_output=True, timeout=20)
        if network_created:
            subprocess.run(["docker", "network", "rm", network], capture_output=True, timeout=20)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, ValueError, RuntimeError, subprocess.TimeoutExpired, OSError, http.client.HTTPException) as error:
        print("NOT PASSED: " + str(error), file=sys.stderr)
        raise SystemExit(2)
