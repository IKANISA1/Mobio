#!/usr/bin/env python3
"""Trigger one bounded notification-worker batch. No automatic local retry loop.

Set MOBIO_PUSH_WORKER_URL and MOBIO_PUSH_WORKER_SECRET in protected service
configuration. Secret/header data goes to curl stdin, never argv or stdout.
The result reports worker outcomes; provider acceptance is not device delivery.
"""
from __future__ import annotations
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from urllib.parse import urlsplit
COUNTERS=('claimed','accepted','retry','invalid_token','permanent','skipped','unacknowledged')

def validate_settings(url: str,secret: str,limit: int) -> None:
    parsed=urlsplit(url)
    if (parsed.scheme!='https' or not parsed.hostname or not parsed.hostname.endswith('.supabase.co')
        or parsed.username or parsed.password or parsed.port not in (None,443)
        or parsed.path!='/functions/v1/push-outbox-worker' or parsed.query or parsed.fragment
        or any(c.isspace() for c in url)):
        raise ValueError('Use the exact approved hosted Supabase push-worker URL')
    if not re.fullmatch(r'[A-Za-z0-9_-]{43,128}',secret):
        raise ValueError('Use a dedicated random base64url worker secret of at least 43 characters')
    if type(limit) is not int or not 1<=limit<=10:
        raise ValueError('Batch limit must be an integer from one to ten')

def trigger(url: str,secret: str,limit: int=10,runner=subprocess.run) -> dict:
    validate_settings(url,secret,limit)
    config='\n'.join(['url = '+json.dumps(url),
        'header = '+json.dumps('Authorization: Bearer '+secret),
        'header = "Content-Type: application/json"','request = "POST"',
        'data = '+json.dumps(json.dumps({'limit':limit}))])+'\n'
    result=runner(['curl','--disable','--silent','--proto','=https','--max-time','35',
        '--max-redirs','0','--max-filesize','8192','--write-out','\n%{http_code}','--config','-'],
        input=config,text=True,capture_output=True,timeout=40,check=False)
    if result.returncode or len(result.stdout)>9000:raise RuntimeError('Worker outcome unavailable')
    raw,separator,status=result.stdout.rpartition('\n')
    if not separator or status!='200':raise RuntimeError('Worker did not acknowledge a complete batch')
    try:data=json.loads(raw)
    except (TypeError,json.JSONDecodeError) as exc:raise RuntimeError('Invalid worker response') from exc
    if not isinstance(data,dict) or data.get('status')!='batch_finished':raise RuntimeError('Unexpected worker status')
    if any(type(data.get(key)) is not int or not 0<=data[key]<=limit for key in COUNTERS):
        raise RuntimeError('Invalid worker counters')
    if data['unacknowledged'] or sum(data[k] for k in COUNTERS if k!='claimed')!=data['claimed']:
        raise RuntimeError('Incomplete worker acknowledgement')
    return {'status':'batch_finished',**{key:data[key] for key in COUNTERS}}

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--limit',type=int,choices=range(1,11),default=10);args=parser.parse_args()
    if not shutil.which('curl'):
        print('UNAVAILABLE: curl absent; no push worker called.',file=sys.stderr);return 2
    result=trigger(os.environ.get('MOBIO_PUSH_WORKER_URL',''),os.environ.get('MOBIO_PUSH_WORKER_SECRET',''),args.limit)
    print(json.dumps(result));return 0

if __name__=='__main__':
    try:sys.exit(main())
    except (ValueError,RuntimeError,subprocess.SubprocessError):
        print('Push worker trigger unacknowledged; inspect protected configuration and delivery health.',file=sys.stderr)
        sys.exit(1)
