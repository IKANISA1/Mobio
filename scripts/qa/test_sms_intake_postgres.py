#!/usr/bin/env python3
"""Execute actual body 07 in an EMPTY local PostgreSQL 17 test database.

Prerequisites are synthetic; the strict financial allocator is an explicit test
DOUBLE. This proves only the new queue component, not the complete Mobio schema.
No hosted URL, live customer data, migrations push or production execution.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from urllib.parse import urlsplit, unquote
ROOT = Path(__file__).resolve().parents[2]


def validate_dsn(dsn: str) -> str:
    parsed = urlsplit(dsn)
    if (parsed.scheme not in ('postgres','postgresql') or parsed.hostname not in ('localhost','127.0.0.1','::1')
            or parsed.query or parsed.fragment or not re.fullmatch(r'/mobio_intake_test_[a-z0-9_]+',unquote(parsed.path))):
        raise ValueError('Only an explicit local mobio_intake_test_* database without query options is allowed')
    return unquote(parsed.path)[1:]


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-tools',action='store_true')
    args=parser.parse_args()
    if not shutil.which('psql'):
        print('UNAVAILABLE: PostgreSQL/psql is required. SQL component and concurrency tests were NOT run.',file=sys.stderr)
        return 2
    if args.check_tools:
        print('psql found; this is NOT test execution.')
        return 0
    dsn=os.environ.get('MOBIO_INTAKE_TEST_DSN','')
    expected=validate_dsn(dsn)
    env={**os.environ,'PGDATABASE':dsn,'PGCONNECT_TIMEOUT':'5','PGOPTIONS':'-c statement_timeout=30000 -c lock_timeout=10000'}
    def run(sql: str | None=None, file: Path | None=None) -> str:
        # psql treats a URI in PGDATABASE as a literal database name.
        argv=['psql','--dbname',dsn,'-X','-A','-t','--set','ON_ERROR_STOP=1']
        argv+=['--file',str(file)] if file else ['--command',sql or '']
        completed=subprocess.run(argv,env=env,text=True,capture_output=True,timeout=60)
        if completed.returncode:
            # The fixture contains only synthetic data; never print the DSN.
            raise RuntimeError('PostgreSQL fixture failed: '+completed.stderr[-4000:])
        return completed.stdout.strip()
    if run('select current_database()')!=expected:
        raise RuntimeError('Database identity mismatch')
    version=int(run("select current_setting('server_version_num')"))
    if not 170000<=version<180000:
        raise RuntimeError('This acceptance lane requires PostgreSQL 17; do not silently substitute another major version')
    run(file=ROOT/'scripts/tests/sql/intake_fixture_bootstrap.sql')
    run(file=ROOT/'supabase/hardening/2026-09-28/07_durable_sms_intake.sql')
    run(file=ROOT/'scripts/tests/sql/intake_component.sql')
    claim="set request.jwt.claims='{\"role\":\"service_role\"}'; select public.rpc_claim_momobio_sms_intake()::text;"
    def claim_once(_:int):
        output=run(claim)
        lines=[line for line in output.splitlines() if line.startswith('{')]
        return json.loads(lines[-1]) if lines else None
    with ThreadPoolExecutor(max_workers=8) as executor:
        jobs=[job for job in executor.map(claim_once,range(8)) if job]
    if len(jobs)!=2 or len({job['id'] for job in jobs})!=2:
        raise AssertionError('Eight real sessions must claim exactly two distinct jobs under concurrency limit two')
    if run("select count(*) from public.momobio_sms_intake where status='processing'")!='2':
        raise AssertionError('Persisted in-flight count does not match claims')
    print(json.dumps({'status':'passed','lane':'PostgreSQL 17 queue component with synthetic prerequisites and allocator double',
      'separate_sessions':8,'distinct_claimed_jobs':2,'production_or_full_schema_acceptance':False}))
    return 0

if __name__=='__main__':
    try: sys.exit(main())
    except (ValueError,RuntimeError,AssertionError,subprocess.SubprocessError) as exc:
        print(str(exc),file=sys.stderr);sys.exit(1)
