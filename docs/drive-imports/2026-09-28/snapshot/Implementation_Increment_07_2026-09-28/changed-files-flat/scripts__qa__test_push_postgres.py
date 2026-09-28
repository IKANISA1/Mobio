#!/usr/bin/env python3
"""Execute body11 in an isolated, resource-bounded official PostgreSQL17 container.

This accepts NO database URL, linked project, live credentials or host mounts.
A reviewed immutable image is required in MOBIO_PUSH_POSTGRES_IMAGE. Identity,
Auth, catalog and consent prerequisites are explicitly synthetic. A passing
run is component SQL/concurrency evidence, NOT actual Supabase acceptance.
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
import time
import uuid
ROOT = Path(__file__).resolve().parents[2]
A='00000000-0000-4000-8000-000000000001'; B='00000000-0000-4000-8000-000000000002'
SA='00000000-0000-4000-8000-000000000101'; SB='00000000-0000-4000-8000-000000000102'
ORG='00000000-0000-4000-8000-000000000900'
TOKEN='synthetic-device-registration-token-only'

def validate_image(image: str) -> str:
    if not re.fullmatch(r'(?:docker\.io/library/)?postgres@sha256:[0-9a-f]{64}',image):
        raise ValueError('Require a reviewed official postgres image pinned to its full sha256 digest')
    return image

def quote(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-tools',action='store_true'); args=parser.parse_args()
    if not shutil.which('docker'):
        print('UNAVAILABLE: Docker absent; PostgreSQL push tests NOT EXECUTED.',file=sys.stderr);return 2
    if args.check_tools:
        print('Docker executable present only; database tests have not run.');return 0
    image=validate_image(os.environ.get('MOBIO_PUSH_POSTGRES_IMAGE',''))
    name='mobio-push-test-'+uuid.uuid4().hex; checks=[]; started=False
    def command(argv: list[str], text: str | None=None) -> str:
        result=subprocess.run(argv,input=text,text=True,capture_output=True,timeout=90,check=False)
        if result.returncode: raise RuntimeError(result.stderr[-3000:])
        return result.stdout.strip()
    def sql(statement: str) -> str:
        return command(['docker','exec','-i',name,'psql','-X','-q','-A','-t','-U','postgres',
                        '--set','ON_ERROR_STOP=1'],statement)
    def call(statement: str,actor: str=A,role: str='authenticated') -> object:
        if actor not in (A,B) or role not in ('authenticated','anon','service_role'):
            raise ValueError('Synthetic fixture identity only')
        claims=json.dumps({'role':role,'sub':actor,'session_id':SA if actor==A else SB})
        result=sql(f'set role {role}; set request.jwt.claims={quote(claims)};\n'+statement)
        return (result=='t') if result in ('t','f') else (json.loads(result) if result else None)
    def service(statement: str) -> object: return call(statement,role='service_role')
    def check(label: str,condition: bool):
        if not condition: raise AssertionError(label)
        checks.append(label)
    def denied(label: str,statement: str,needle: str,actor: str=A,role: str='authenticated'):
        try: call(statement,actor,role)
        except RuntimeError as exc:
            if needle not in str(exc): raise AssertionError('Unexpected denial: '+label) from exc
            checks.append(label)
        else: raise AssertionError('Unexpected success: '+label)
    def register(actor: str=A,token: str=TOKEN) -> dict:
        return call(f"select public.rpc_push_register({quote(token)},'android','{SA if actor==A else SB}');",actor)
    def notification(kind: str='chat_message',metadata: dict | None=None,owner: str=A) -> str:
        nid=str(uuid.uuid4());meta=json.dumps(metadata if metadata is not None else {})
        sql(f"insert into public.notifications(id,user_id,type,metadata,organization_id) values('{nid}','{owner}',{quote(kind)},{quote(meta)}::jsonb,'{ORG}');")
        return nid
    def claim(limit: int=10): return service(f'select public.rpc_push_claim({limit});')
    def authorize(l: dict): return service(f"select public.rpc_push_authorize('{l['job_id']}','{l['lease_id']}');")
    def finish(l: dict,outcome: str='accepted',code: str='accepted',retry: int=0):
        return service(f"select public.rpc_push_finish('{l['job_id']}','{l['lease_id']}',{quote(outcome)},{quote(code)},{retry});")
    def reset_jobs():
        sql('truncate mobio_private.push_jobs,mobio_private.push_events; delete from mobio_private.push_hour_budget;')
    try:
        command(['docker','pull','--quiet',image])
        command(['docker','run','--detach','--rm','--name',name,'--network','none','--memory','512m',
                 '--cpus','1','--pids-limit','128','--read-only','--tmpfs','/var/lib/postgresql/data',
                 '--tmpfs','/var/run/postgresql','--tmpfs','/tmp',
                 '-e','POSTGRES_PASSWORD=synthetic-isolated-fixture',image]);started=True
        for _ in range(40):
            try: command(['docker','exec',name,'pg_isready','-U','postgres']);break
            except RuntimeError:time.sleep(.5)
        version=int(sql("select current_setting('server_version_num');"))
        check('official image resolves to PostgreSQL17',170000<=version<180000)
        check('isolated database starts empty',sql("select count(*) from pg_tables where schemaname='public';")=='0')
        sql((ROOT/'scripts/tests/sql/push_fixture_bootstrap.sql').read_text())
        sql((ROOT/'supabase/hardening/2026-09-28/11_notification_outbox.sql').read_text())
        sql((ROOT/'supabase/hardening/2026-09-28/increment07_catalog_assertions.sql').read_text())
        checks.append('catalog grants/RLS/trigger assertions executed')
        b=register();check('registration binds verified owner and session',b['owner_id']==A and b['session_id']==SA)
        check('same session registration preserves binding',register()==b)
        denied('wrong session registration rejected',f"select public.rpc_push_register('{TOKEN}','android','{SB}');",'VERIFIED_SESSION_REQUIRED')
        denied('anonymous registration denied',f"select public.rpc_push_register('{TOKEN}','android','{SA}');",'permission denied',role='anon')
        denied('raw token table read denied','select count(*) from public.fcm_tokens;','permission denied')
        check('historical column grant removed',sql("select has_column_privilege('authenticated','public.fcm_tokens','user_id','UPDATE');")=='f')
        check('private jobs inaccessible to clients',sql("select has_table_privilege('authenticated','mobio_private.push_jobs','SELECT');")=='f')
        denied('worker claim inaccessible to ordinary user','select public.rpc_push_claim(1);','permission denied')
        denied('health requires admin lease','select public.rpc_push_health();','ADMIN_SESSION_REQUIRED')
        nid=notification();check('notification and outbox admitted together',sql(f"select count(*) from mobio_private.push_jobs where notification_id='{nid}';")=='1')
        sql(f"update public.notifications set title='changed' where id='{nid}';")
        check('notification updates do not enqueue again',sql(f"select count(*) from mobio_private.push_jobs where notification_id='{nid}';")=='1')
        check('dispatch defaults off',claim()==[])
        denied('ordinary user cannot enable worker',"select public.rpc_push_set_enabled(true,'fixture-enable');",'permission denied')
        service("select public.rpc_push_set_enabled(true,'fixture-enable');")
        l=claim(1)[0];target=authorize(l)
        check('lease authorizes frozen binding',target['allowed'] is True and target['binding_id']==b['binding_id'])
        check('dispatch authorization single use',authorize(l)['reason']=='already_authorized')
        receipt=finish(l);check('durable provider acceptance',receipt['state']=='accepted' and receipt['outcome']=='accepted')
        check('acknowledgement retry idempotent',finish(l)==receipt)
        check('conflicting acknowledgement not accepted',finish(l,'retry','network_unknown')['applied'] is False)
        h=service('select public.rpc_push_health();')
        check('health never equates acceptance to delivery',h['accepted_means']=='provider_accepted_not_device_delivered')
        reset_jobs()
        for kind,meta,state,owner in [('promo',{},'consent_denied',A),('unknown',{},'unknown_type',A),
            ('chat_message',{'channels':[]},'not_requested',A),('chat_message',{'channels':'push'},'invalid_channels',A),
            ('chat_message',{},'no_targets',B)]:
            n=notification(kind,meta,owner)
            check('admission reason '+state,sql(f"select state from mobio_private.push_events where notification_id='{n}';")==state)
        sql("update public.notification_type_catalog set requires_promotional_consent=false where type='promo';")
        n=notification('promo');check('literal promo cannot bypass consent through catalog drift',sql(f"select state from mobio_private.push_events where notification_id='{n}';")=='consent_denied')
        sql(f"insert into public.notification_consents values('{A}','{ORG}','promotional','push','granted');")
        notification('promo');l=claim(1)[0]
        sql("update public.notification_consents set status='revoked';")
        check('consent rechecked immediately before provider',authorize(l)['reason']=='consent_revoked')
        reset_jobs();notification();l=claim(1)[0];authorize(l)
        newer=register(B)
        check('takeover rotates binding',newer['binding_id']!=b['binding_id'])
        finish(l,'invalid_token','unregistered')
        check('old result cannot revoke new owner token',sql(f"select revoked_at is null from public.fcm_tokens where id='{b['token_id']}';")=='t')
        check('old logout cannot revoke new owner binding',call(f"select public.rpc_push_unregister('{b['binding_id']}','{SA}');") is False)
        b=register(A);reset_jobs();notification();l=claim(1)[0]
        call(f"select public.rpc_push_unregister('{b['binding_id']}','{SA}');")
        check('logout before authorization suppresses job',authorize(l)['reason']=='binding_inactive')
        b=register();reset_jobs();notification();l=claim(1)[0]
        service("select public.rpc_push_set_enabled(false,'fixture-pause');")
        check('pause before authorization suppresses network',authorize(l)['reason']=='paused')
        check('pause does not consume a send attempt',sql(f"select attempts from mobio_private.push_jobs where id='{l['job_id']}';")=='0')
        service("select public.rpc_push_set_enabled(true,'fixture-resume');");reset_jobs()
        notification();l=claim(1)[0];authorize(l);r=finish(l,'retry','provider_unavailable',120)
        check('retry retained durably',r['state']=='queued')
        check('lost retry acknowledgement idempotent',finish(l,'retry','provider_unavailable',120)==r)
        check('retry-after minimum honored',float(sql(f"select extract(epoch from available_at-updated_at) from mobio_private.push_jobs where id='{l['job_id']}';"))>=120)
        sql(f"update mobio_private.push_jobs set available_at=clock_timestamp()-interval '1 second' where id='{l['job_id']}';")
        newlease=claim(1)[0];check('reclaim rotates lease',newlease['lease_id']!=l['lease_id'])
        check('stale previous lease cannot acknowledge',finish(l)['applied'] is False)
        sql(f"update mobio_private.push_jobs set lease_until=clock_timestamp()-interval '1 second' where id='{newlease['job_id']}';")
        claim();check('crash recovery returns to bounded retry',sql(f"select state from mobio_private.push_jobs where id='{newlease['job_id']}';")=='queued')
        reset_jobs();n=notification();sql('update mobio_private.push_jobs set expires_at=clock_timestamp()-interval \'1 second\';')
        claim();check('TTL expiration prevents dispatch',sql(f"select state from mobio_private.push_jobs where notification_id='{n}';")=='expired')
        reset_jobs();sql('update mobio_private.push_policy set hourly_send_budget=1;')
        notification();notification();jobs=claim(2);authorize(jobs[0])
        check('budget denies second dispatch',authorize(jobs[1])['reason']=='budget_exhausted')
        check('budget denial refunds attempt',sql(f"select attempts from mobio_private.push_jobs where id='{jobs[1]['job_id']}';")=='0')
        finish(jobs[0],'retry','rate_limited',86400)
        check('retry beyond TTL expires instead of sending early',sql(f"select state from mobio_private.push_jobs where id='{jobs[0]['job_id']}';")=='expired')
        reset_jobs();sql('update mobio_private.push_policy set hourly_send_budget=10000;')
        for _ in range(8):notification()
        with ThreadPoolExecutor(max_workers=4) as pool: groups=list(pool.map(lambda _:claim(2),range(4)))
        leases=[x for group in groups for x in group]
        check('four concurrent sessions claim disjoint jobs',len(leases)==8 and len({x['job_id'] for x in leases})==8)
        reset_jobs();notification();l=claim(1)[0]
        sql(f"delete from auth.sessions where id='{SA}';")
        check('deleted Auth session suppresses outstanding push',authorize(l)['reason']=='binding_inactive')
        print(json.dumps({'status':'PASS','postgres_version_num':version,'component_checks':len(checks),'checks':checks,
            'scope':'body11 with synthetic prerequisites; NOT full schema or actual Auth/PostgREST'},indent=2))
        return 0
    finally:
        if started:
            subprocess.run(['docker','rm','--force',name],capture_output=True,text=True,timeout=30,check=False)

if __name__=='__main__':
    try: sys.exit(main())
    except (ValueError,RuntimeError,AssertionError,subprocess.SubprocessError) as exc:
        print('FAIL: isolated push component test: '+str(exc),file=sys.stderr);sys.exit(1)
