#!/usr/bin/env python3
"""Execute privacy component SQL in an empty isolated PostgreSQL17 container.

No external database, mount, credential or DSN is accepted. Requires a reviewed
MOBIO_PRIVACY_POSTGRES_IMAGE=postgres@sha256:<actual digest>. Fixtures replace
Auth/identity dependencies explicitly. A component PASS is not full Supabase UAT.
"""
from __future__ import annotations
import argparse
from datetime import datetime,timezone,timedelta
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid
ROOT=Path(__file__).resolve().parents[2]
A='00000000-0000-4000-8000-000000000001';B='00000000-0000-4000-8000-000000000002'
SA='00000000-0000-4000-8000-000000000101';SB='00000000-0000-4000-8000-000000000102'
def validate_image(value:str)->str:
 if not re.fullmatch(r'(?:docker\.io/library/)?postgres@sha256:[0-9a-f]{64}',value):raise ValueError('REVIEWED_POSTGRES_DIGEST_REQUIRED')
 return value
def quote(value:str)->str:return "'"+value.replace("'","''")+"'"
def main()->int:
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--check-tools',action='store_true');args=parser.parse_args()
 if not shutil.which('docker'):
  print('UNAVAILABLE: Docker absent; privacy SQL tests NOT EXECUTED.',file=sys.stderr);return 2
 if args.check_tools:
  print('Docker executable present; SQL has not run.');return 0
 image=validate_image(os.environ.get('MOBIO_PRIVACY_POSTGRES_IMAGE',''));name='mobio-privacy-test-'+uuid.uuid4().hex;checks=[];started=False
 def command(argv,text=None):
  p=subprocess.run(argv,input=text,text=True,capture_output=True,timeout=90,check=False)
  if p.returncode:raise RuntimeError(p.stderr[-3000:])
  return p.stdout.strip()
 def sql(statement):return command(['docker','exec','-i',name,'psql','-X','-q','-A','-t','-U','postgres','--set','ON_ERROR_STOP=1'],statement)
 def call(statement,actor=A,role='authenticated'):
  if actor not in (A,B) or role not in ('authenticated','anon','service_role'):raise ValueError('SYNTHETIC_IDENTITY_ONLY')
  claims=json.dumps({'role':role,'sub':actor,'session_id':SA if actor==A else SB})
  output=sql(f'set role {role};set request.jwt.claims={quote(claims)};'+statement)
  return json.loads(output) if output else None
 def service(statement):return call(statement,role='service_role')
 def check(name,value):
  if not value:raise AssertionError(name)
  checks.append(name)
 def denied(label,statement,needle,actor=A,role='authenticated'):
  try:call(statement,actor,role)
  except RuntimeError as error:
   if needle not in str(error):raise AssertionError('Unexpected rejection: '+label) from error
   checks.append(label)
  else:raise AssertionError('Unexpected success: '+label)
 def submit(rid,actor=A):return call(f"select public.rpc_privacy_user('request','{rid}','v1',true);",actor)
 def action(rid,rev,kind,payload,aid=None):
  aid=aid or str(uuid.uuid4())
  return service(f"select public.rpc_privacy_fulfil('{rid}','{aid}',{rev},{quote(kind)},{quote(json.dumps(payload))}::jsonb,'fixture-operator');")
 try:
  command(['docker','pull','--quiet',image]);command(['docker','run','--detach','--rm','--name',name,'--network','none','--memory','512m','--cpus','1','--pids-limit','128','--read-only','--tmpfs','/var/lib/postgresql/data','--tmpfs','/var/run/postgresql','--tmpfs','/tmp','-e','POSTGRES_PASSWORD=synthetic-isolated-fixture',image]);started=True
  for _ in range(40):
   try:command(['docker','exec',name,'pg_isready','-U','postgres']);break
   except RuntimeError:time.sleep(.5)
  version=int(sql("select current_setting('server_version_num');"));check('actual PostgreSQL17',170000<=version<180000)
  check('fresh empty public schema',sql("select count(*) from pg_tables where schemaname='public';")=='0')
  sql((ROOT/'scripts/tests/sql/privacy_fixture_bootstrap.sql').read_text());sql((ROOT/'supabase/hardening/2026-09-28/12_privacy_request_workflow.sql').read_text())
  check('intake starts disabled',call("select public.rpc_privacy_user('policy');")['enabled'] is False)
  rid=str(uuid.uuid4());denied('disabled request rejected',f"select public.rpc_privacy_user('request','{rid}','v1',true);",'PRIVACY_INTAKE_DISABLED')
  denied('anonymous policy rejected',"select public.rpc_privacy_user('policy');",'permission denied',role='anon')
  denied('raw privacy metadata inaccessible','select * from mobio_private.privacy_requests;','permission denied')
  denied('client cannot enable intake',"select public.rpc_privacy_configure(true,true,'v1','"+'1'*64+"','fixture-approval');",'permission denied')
  service("select public.rpc_privacy_configure(true,true,'v1','"+'1'*64+"','fixture-approval');")
  denied('confirmation required',f"select public.rpc_privacy_user('request','{rid}','v1',false);",'INVALID_PRIVACY_CONFIRMATION')
  denied('notice version mismatch',f"select public.rpc_privacy_user('request','{rid}','v0',true);",'PRIVACY_POLICY_CHANGED')
  sql(f"update auth.sessions set created_at=clock_timestamp()-interval '1 day' where id='{SA}';")
  denied('old session cannot create request',f"select public.rpc_privacy_user('request','{rid}','v1',true);",'PRIVACY_REAUTHENTICATION_REQUIRED')
  sql(f"update auth.sessions set created_at=clock_timestamp() where id='{SA}';")
  with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(lambda _:submit(rid),range(2)))
  check('same-ID concurrent requests have one case',results[0]==results[1] and sql(f"select count(*) from mobio_private.privacy_requests where owner_id='{A}';")=='1')
  check('request does not erase Auth',sql(f"select count(*) from auth.users where id='{A}';")=='1')
  check('history is correctly typed',len(call("select public.rpc_privacy_user('list');")['requests'])==1)
  denied('other user cannot read request',f"select public.rpc_privacy_user('status','{rid}');",'PRIVACY_REQUEST_NOT_FOUND',actor=B)
  denied('other user cannot cancel request',f"select public.rpc_privacy_user('cancel','{rid}');",'PRIVACY_REQUEST_NOT_FOUND',actor=B)
  denied('second active request blocked',f"select public.rpc_privacy_user('request','{uuid.uuid4()}','v1',true);",'PRIVACY_ACTIVE_REQUEST_EXISTS')
  result=call(f"select public.rpc_privacy_user('cancel','{rid}');");check('cancel before processing',result['request']['status']=='cancelled')
  check('cancel replay idempotent',call(f"select public.rpc_privacy_user('cancel','{rid}');")==result)
  check('request retry never revives cancelled case',submit(rid)['request']['status']=='cancelled')
  rid=str(uuid.uuid4());submit(rid)
  started_payload={'plan_sha256':'2'*64,'inventory_sha256':'1'*64};aid=str(uuid.uuid4())
  start=action(rid,0,'start',started_payload,aid);check('service starts processing',start['request']['status']=='processing')
  check('start acknowledgement replay idempotent',action(rid,0,'start',started_payload,aid)['replayed'] is True)
  denied('cancel after start denied',f"select public.rpc_privacy_user('cancel','{rid}');",'PRIVACY_NOT_CANCELLABLE')
  denied('user cannot complete own request',f"select public.rpc_privacy_fulfil('{rid}','{uuid.uuid4()}',1,'complete','{{}}','fixture');",'permission denied')
  try:action(rid,1,'complete',{'manifest_sha256':'3'*64})
  except RuntimeError as error:check('completion requires all evidence','PRIVACY_EVIDENCE_INCOMPLETE' in str(error))
  else:raise AssertionError('Completion without evidence accepted')
  revision=1
  categories=['sessions','auth','profile_and_activity','financial_records','delivery_journals','storage','face_vectors','processors','backups','privacy_case_records']
  for category in categories:
   payload={'category':category,'outcome':'deleted','evidence_sha256':'4'*64}
   if category=='privacy_case_records':payload.update(outcome='retained',retention_until=(datetime.now(timezone.utc)+timedelta(days=30)).isoformat(),basis_reference='SYNTHETIC-TEST-ONLY')
   result=action(rid,revision,'evidence',payload);revision=result['applied_revision']
  try:action(rid,revision,'complete',{'manifest_sha256':'3'*64})
  except RuntimeError as error:check('live Auth blocks completion despite attestations','PRIVACY_AUTH_STILL_PRESENT' in str(error))
  else:raise AssertionError('Completion accepted while Auth present')
  # Auth deletion below is confined to synthetic fixtures inside this container.
  sql(f"delete from auth.sessions where user_id='{A}';delete from auth.users where id='{A}';")
  result=action(rid,revision,'complete',{'manifest_sha256':'3'*64});check('completion after all proofs and live probes',result['request']['status']=='completed_with_retention')
  check('retained receipt survives Auth fixture deletion',sql(f"select count(*) from mobio_private.privacy_requests where request_id='{rid}';")=='1')
  check('health truthful about automation',service('select public.rpc_privacy_health();')['automatic_erasure_implemented'] is False)
  print(json.dumps({'status':'PASS','executed_checks':len(checks),'checks':checks,'boundary':'isolated synthetic component; not full Auth/PostgREST or production'},indent=2));return 0
 finally:
  if started:subprocess.run(['docker','rm','-f',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30)
if __name__=='__main__':
 try:raise SystemExit(main())
 except (ValueError,RuntimeError,AssertionError,subprocess.TimeoutExpired) as error:
  print(f'NOT PASSED: {error}',file=sys.stderr);raise SystemExit(2)
