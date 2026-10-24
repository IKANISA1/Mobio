#!/usr/bin/env python3
"""Real SQL transactions in this task's owned container; no hosted/API/provider work."""
from concurrent.futures import ThreadPoolExecutor
import json
import os
import re
import subprocess
import sys
import time
import uuid

container=sys.argv[1]
if not re.fullmatch(r'supabase_db_mobio_(?:admin_role|replay)_\d+', container):
    raise SystemExit('Expected uniquely owned Admin role fixture')
docker=os.environ.get('DOCKER_BIN','/Volumes/PRO-G40/Applications/Docker.app/Contents/Resources/bin/docker')
argv=[docker,'exec','-i',container,'sh','-c',
      'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U postgres -d postgres -qAt -v ON_ERROR_STOP=1']
def sql(statement):
    p=subprocess.run(argv,input=statement,text=True,capture_output=True,timeout=45)
    if p.returncode: raise RuntimeError(p.stderr[-1800:])
    return p.stdout.strip().splitlines()
def last_json(lines): return next(json.loads(x) for x in reversed(lines) if x.startswith('{'))
def quote(value): return "'"+value.replace("'","''")+"'"
actor,other,target_a,target_b,sid,sid2,other_sid=[str(uuid.uuid4()) for _ in range(7)]
phones=['+25078'+str(uuid.uuid4().int%10000000).zfill(7) for _ in range(4)]
for i,(uid,session,provider,phone) in enumerate([(actor,sid,'admin_whatsapp_otp',phones[0]),
        (other,other_sid,'admin_whatsapp_otp',phones[1]),(target_a,None,'whatsapp_cloud_otp',phones[2]),
        (target_b,None,'whatsapp_cloud_otp',phones[3])]):
    role="'admin'" if i<2 else "'passenger'"
    sql(f"""begin;set request.jwt.claims='{{"role":"service_role"}}';
    insert into auth.users(id,phone,phone_confirmed_at,is_anonymous,raw_app_meta_data,raw_user_meta_data)
      values('{uid}','{phone}',now(),false,'{{"provider":"{provider}"}}','{{}}');
    update public.profiles set name='Role concurrency {i}',role={role} where id='{uid}';
    commit;""")
    if session:
        otp=str(uuid.uuid4())
        sql(f"""begin;set request.jwt.claims='{{"role":"service_role"}}';
        insert into auth.sessions(id,user_id,created_at,not_after) values('{session}','{uid}',now(),now()+interval '1 hour');
        insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active) values('{phone}','+250',true);
        insert into public.otp_codes(id,phone,profile_id,code,code_hash,purpose,verified,expires_at)
          values('{otp}','{phone}','{uid}','000000',repeat('a',64),'admin_login',true,now()+interval '5 minutes');
        select public.rpc_register_admin_session('{uid}','{session}','{otp}');commit;""")
def claims(who=actor,session=sid):
    return json.dumps(dict(sub=who,session_id=session,role='authenticated',is_anonymous=False,
                           app_metadata=dict(provider='admin_whatsapp_otp')))
def call(expression,*,session=sid,who=actor,app='mobio_role_call'):
    return last_json(sql(f"set application_name={quote(app)};begin;set request.jwt.claims={quote(claims(who,session))};set local role authenticated;select {expression};commit;"))
def targets(page,role):
    return [dict(target_id=r['id'],expected_role=r['role'],expected_revision=r['role_revision'],requested_role=role)
            for r in page['rows'] if r['id'] in (target_a,target_b)]
def reserve(page,token,role='driver',session=sid,app='mobio_role_reserve'):
    return call(f"public.rpc_admin_role_reserve('{token}','{page['snapshot_id']}',{quote(json.dumps(targets(page,role)))}::jsonb)",session=session,app=app)
def expect_error(fn,needle):
    try: fn()
    except RuntimeError as e: assert needle in str(e),(needle,str(e)); return
    raise AssertionError('Unexpected successful operation')
checks=[]
def record(label): checks.append(label); print('PASS: '+label,flush=True)
page=call('public.rpc_admin_users_page(p_page_size=>100)')
with ThreadPoolExecutor(max_workers=2) as pool:
    futures=[pool.submit(reserve,page,str(uuid.uuid4())) for _ in range(2)]
    winners=[];losers=[]
    for f in futures:
        try: winners.append(f.result())
        except RuntimeError as e: losers.append(str(e))
assert len(winners)==len(losers)==1 and 'ADMIN_ROLE_BATCH_OPEN' in losers[0]
batch=winners[0];bid=batch['batch']['batch_id'];ops=batch['operations']
record('two actual concurrent reservations yield one immutable actor batch')
with ThreadPoolExecutor(max_workers=8) as pool:
    replies=list(pool.map(lambda _:call(f"public.rpc_admin_role_execute('{bid}','{ops[0]['operation_id']}')"),range(8)))
receipts=[r['operations'][0]['receipt'] for r in replies]
assert all(r==receipts[0] for r in receipts)
assert sql(f"select count(*) from public.admin_audit_log where details->>'operation_id'='{ops[0]['operation_id']}'")==['1']
record('eight actual duplicate executes produce one role change/audit/receipt')
def holder(statement,label):
    p=subprocess.Popen(argv,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    p.stdin.write(f"set application_name='{label}';begin;{statement};select 'HELD';\n");p.stdin.flush()
    wait_state(label,'idle in transaction')
    return p
def wait_state(label,state=None,locked=False):
    predicate=f"application_name='{label}'"+(f" and state='{state}'" if state else '')+(" and wait_event_type='Lock'" if locked else '')
    deadline=time.monotonic()+12
    while time.monotonic()<deadline:
        if sql(f"select exists(select 1 from pg_stat_activity where {predicate})")==['t']:return
        time.sleep(.025)
    raise AssertionError('Owned deterministic barrier not reached: '+label)
def release(p):
    p.stdin.write('commit;\n\\q\n');p.stdin.close();p.wait(timeout=10)
    assert p.returncode==0,p.stderr.read()
    p.stdout.close();p.stderr.close()
with ThreadPoolExecutor(max_workers=2) as pool:
    h=holder(f"select id from public.profiles where id='{ops[1]['target_id']}' for update",'mobio_role_target_hold')
    try:
        executing=pool.submit(call,f"public.rpc_admin_role_execute('{bid}','{ops[1]['operation_id']}')",app='mobio_role_blocked_execute')
        wait_state('mobio_role_blocked_execute',locked=True)
        sealing=pool.submit(call,f"public.rpc_admin_role_seal('{bid}')",app='mobio_role_blocked_seal')
        wait_state('mobio_role_blocked_seal',locked=True)
        release(h);h=None
        executed=executing.result();sealed=sealing.result()
    finally:
        if h: release(h)
assert sealed['reservation_state']=='sealed' and all(o['status']=='confirmed' for o in sealed['operations'])
assert executed['operations'][1]['receipt']==sealed['operations'][1]['receipt']
expect_error(lambda:call(f"public.rpc_admin_role_execute('{bid}','{ops[1]['operation_id']}')"),'ADMIN_ROLE_BATCH_SEALED')
confirmed_operations=sealed['operations']
record('seal waits for blocked in-flight target transaction and fences late execute')
page2=call('public.rpc_admin_users_page(p_page_size=>100)')
for seal_first in (False,True):
    token=str(uuid.uuid4());label='mobio_role_ordered_actor_hold'
    h=holder(f"select pg_advisory_xact_lock(hashtextextended('mobio.admin.role.actor:{actor}',0))",label)
    with ThreadPoolExecutor(max_workers=2) as pool:
        try:
            if seal_first:
                first=pool.submit(call,f"public.rpc_admin_role_seal(p_reservation_id=>'{token}')",app='mobio_role_queued_seal')
                wait_state('mobio_role_queued_seal',locked=True)
                second=pool.submit(reserve,page2,token,'passenger',sid,'mobio_role_queued_reserve')
                wait_state('mobio_role_queued_reserve',locked=True)
            else:
                first=pool.submit(reserve,page2,token,'passenger',sid,'mobio_role_queued_reserve')
                wait_state('mobio_role_queued_reserve',locked=True)
                second=pool.submit(call,f"public.rpc_admin_role_seal(p_reservation_id=>'{token}')",app='mobio_role_queued_seal')
                wait_state('mobio_role_queued_seal',locked=True)
            release(h);h=None
            result=first.result()
            if seal_first:
                assert result['reservation_state']=='sealed_before_reserve' and result['batch'] is None and result['operations']==[]
                expect_error(second.result,'ADMIN_ROLE_RESERVATION_SEALED')
            else:
                result=second.result()
                assert result['reservation_state']=='sealed' and all(o['status']=='not_started' for o in result['operations'])
        finally:
            if h: release(h)
    assert sql(f"select count(*) from public.profiles where id in('{target_a}','{target_b}') and role='driver'")==['2']
record('held actor transactions prove both delayed reservation/seal orderings with no unreviewed effect')
otp2=str(uuid.uuid4())
sql(f"""begin;set request.jwt.claims='{{"role":"service_role"}}';
insert into auth.sessions(id,user_id,created_at,not_after) values('{sid2}','{actor}',now(),now()+interval '1 hour');
insert into public.otp_codes(id,phone,profile_id,code,code_hash,purpose,verified,expires_at)
values('{otp2}','{phones[0]}','{actor}','000000',repeat('a',64),'admin_login',true,now()+interval '5 minutes');
select public.rpc_register_admin_session('{actor}','{sid2}','{otp2}');commit;""")
token=str(uuid.uuid4())
sealed=call(f"public.rpc_admin_role_seal(p_reservation_id=>'{token}')",session=sid2)
expect_error(lambda:reserve(page2,token,'passenger',sid),'ADMIN_ROLE_RESERVATION_SEALED')
expect_error(lambda:reserve(page2,token,'passenger',sid2),'ADMIN_ROLE_RESERVATION_SEALED')
recovered=call(f"public.rpc_admin_role_status('{bid}')",session=sid2)
assert recovered['operations']==confirmed_operations
expect_error(lambda:call(f"public.rpc_admin_role_execute('{bid}','{ops[0]['operation_id']}')",session=sid2),'ADMIN_ROLE_SESSION_CHANGED')
expect_error(lambda:call(f"public.rpc_admin_role_seal(p_reservation_id=>'{token}')",who=other,session=other_sid),'ADMIN_ROLE_BATCH_NOT_FOUND')
record('replacement SID recovers receipts/seals tokens but cannot execute origin plans; wrong owner denied')
before_counts=sql(f"select (select count(*) from mobio_private.admin_role_batches where actor_id='{actor}')||':'||(select count(*) from mobio_private.admin_role_reservations where actor_id='{actor}')||':'||(select count(*) from public.admin_audit_log where admin_id='{actor}')")
for kind,expression,denial in (
        ('reserve',f"public.rpc_admin_role_reserve('{uuid.uuid4()}','{page2['snapshot_id']}',{quote(json.dumps(targets(page2,'passenger')))}::jsonb)",'ADMIN_REAUTHENTICATION_REQUIRED'),
        ('execute',f"public.rpc_admin_role_execute('{bid}','{ops[0]['operation_id']}')",'ADMIN_REAUTHENTICATION_REQUIRED'),
        ('status',f"public.rpc_admin_role_status('{bid}')",'ADMIN_ROLE_MANAGE_REQUIRED'),
        ('seal',f"public.rpc_admin_role_seal(p_reservation_id=>'{uuid.uuid4()}')",'ADMIN_ROLE_MANAGE_REQUIRED'),
        ('page','public.rpc_admin_users_page(p_page_size=>100)','ADMIN_USERS_READ_REQUIRED'),
        ('release',f"public.rpc_admin_users_release_snapshot('{page2['snapshot_id']}')",'ADMIN_USERS_READ_REQUIRED')):
    label='mobio_role_revoked_wait_'+kind
    h=holder(f"select pg_advisory_xact_lock(hashtextextended('mobio.admin.role.actor:{actor}',0))",'mobio_role_revocation_hold')
    with ThreadPoolExecutor(max_workers=1) as pool:
        try:
            waiting=pool.submit(call,expression,session=sid2,app=label)
            wait_state(label,locked=True)
            sql(f"update mobio_private.admin_session_leases set revoked_at=clock_timestamp() where user_id='{actor}' and session_id='{sid2}'")
            release(h);h=None
            expect_error(waiting.result,denial)
        finally:
            if h: release(h)
            sql(f"update mobio_private.admin_session_leases set revoked_at=null where user_id='{actor}' and session_id='{sid2}'")
assert before_counts==sql(f"select (select count(*) from mobio_private.admin_role_batches where actor_id='{actor}')||':'||(select count(*) from mobio_private.admin_role_reservations where actor_id='{actor}')||':'||(select count(*) from public.admin_audit_log where admin_id='{actor}')")
record('six real actor-lock waits revalidate revoked base/recent authority before reads or effects')
print(json.dumps({'status':'PASS','executed_checks':len(checks),'checks':checks,
                  'boundary':'owned PostgreSQL SQL contexts; not signed JWT/OTP/provider/device acceptance'},indent=2))
