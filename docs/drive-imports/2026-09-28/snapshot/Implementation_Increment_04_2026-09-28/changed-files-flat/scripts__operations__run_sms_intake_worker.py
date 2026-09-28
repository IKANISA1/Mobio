#!/usr/bin/env python3
"""Bounded server-side worker trigger. It does not enroll collectors or enable credit.

Configure MOMO_SMS_WORKER_URL and MOMO_SMS_WORKER_TOKEN through a protected
service environment. Never place the token in a URL, shell argument or repository.
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


def validate_settings(url: str, token: str) -> None:
    value=urlsplit(url)
    if (value.scheme!='https' or not value.hostname or not value.hostname.endswith('.supabase.co')
            or value.username or value.password or value.port not in (None,443)
            or value.path!='/functions/v1/momobio-sms-process' or value.query or value.fragment
            or any(c.isspace() for c in url)):
        raise ValueError('Use the exact HTTPS hosted Supabase worker URL; custom hosts require separate review')
    if not re.fullmatch(r'[A-Za-z0-9_-]{43,128}',token):
        raise ValueError('Set a dedicated base64url worker token of at least 43 characters')


def trigger(url: str, token: str, runner=subprocess.run) -> str:
    validate_settings(url,token)
    # Pass configuration via stdin: the token is absent from process arguments.
    config='\n'.join(['url = '+json.dumps(url),'header = '+json.dumps('Authorization: Bearer '+token),
                      'header = "Content-Type: application/json"','request = "POST"','data = "{}"'])+'\n'
    result=runner(['curl','--disable','--silent','--proto','=https','--max-time','50','--max-redirs','0','--max-filesize','8192',
                   '--write-out','\n%{http_code}','--config','-'],input=config,text=True,capture_output=True,timeout=55,check=False)
    if result.returncode or len(result.stdout)>9000:
        raise RuntimeError('Worker transport failed; no acknowledgement assumed')
    body,separator,status=result.stdout.rpartition('\n')
    if not separator or status!='200':
        raise RuntimeError('Worker did not return successful processing status')
    try: data=json.loads(body)
    except (TypeError,json.JSONDecodeError) as exc: raise RuntimeError('Invalid worker response') from exc
    if not isinstance(data,dict) or data.get('success') is not True or data.get('outcome') not in ('disabled','idle_or_limited','processed','review','retry','stale'):
        raise RuntimeError('Unexpected worker response')
    return data['outcome']


def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--calls',type=int,choices=(1,2),default=1);args=parser.parse_args()
    if not shutil.which('curl'):
        print('UNAVAILABLE: curl is required; no worker called',file=sys.stderr);return 2
    url=os.environ.get('MOMO_SMS_WORKER_URL','');token=os.environ.get('MOMO_SMS_WORKER_TOKEN','')
    for _ in range(args.calls):
        outcome=trigger(url,token)
        print(json.dumps({'outcome':outcome}))
        if outcome in ('disabled','idle_or_limited','retry'): break
    return 0

if __name__=='__main__':
    try: sys.exit(main())
    except (ValueError,RuntimeError,subprocess.SubprocessError):
        # Do not emit request/configuration/provider text which could contain a token.
        print('SMS worker trigger failed; inspect protected service configuration and intake health.',file=sys.stderr);sys.exit(1)
