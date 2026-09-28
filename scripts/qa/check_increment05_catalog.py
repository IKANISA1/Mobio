#!/usr/bin/env python3
"""Read-only local PostgreSQL17 catalogue probes; never applies migrations."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import urlsplit,parse_qs

def validate_target(value):
 try: u=urlsplit(value); port=u.port
 except ValueError: raise ValueError('Invalid DSN') from None
 if u.scheme not in ('postgres','postgresql') or u.hostname not in ('127.0.0.1','localhost','::1'):
  raise ValueError('Only explicit loopback PostgreSQL targets are allowed')
 if not u.path.startswith('/mobio_test_') or not port or u.query or u.fragment:
  raise ValueError('Use explicit port and mobio_test_* database; no query overrides')
 return value

def main(argv=None):
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--dsn',required=True);a=p.parse_args(argv)
 try: validate_target(a.dsn)
 except ValueError as e: print(str(e),file=sys.stderr);return 2
 exe=shutil.which('psql')
 if not exe: print('UNAVAILABLE: psql; no database checks executed',file=sys.stderr);return 2
 sql=Path(__file__).resolve().parents[2]/'supabase/hardening/2026-09-28/increment05_catalog_assertions.sql'
 # No shell and no DSN print. Prefer a credential-free DSN + locally protected
 # pgpass; OS process listings can expose any password embedded by the operator.
 try:
  version=subprocess.run([exe,a.dsn,'-XAt','-v','ON_ERROR_STOP=1','-c','show server_version_num'],capture_output=True,text=True,timeout=15)
  if version.returncode or not version.stdout.strip().isdigit() or not 170000<=int(version.stdout.strip())<180000:
   print('UNAVAILABLE: require PostgreSQL17 test database',file=sys.stderr);return 2
  return subprocess.run([exe,a.dsn,'-X','-v','ON_ERROR_STOP=1','-f',str(sql)],timeout=30).returncode
 except (OSError,subprocess.TimeoutExpired):print('UNAVAILABLE: local database probe failed',file=sys.stderr);return 2
if __name__=='__main__':raise SystemExit(main())
