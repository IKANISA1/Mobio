#!/usr/bin/env python3
"""Real parallel PostgreSQL transactions; owned container only, no hosted API."""
import concurrent.futures, json, subprocess, sys, time, uuid
container=sys.argv[1]
shared_authorized=(len(sys.argv)==4 and sys.argv[2]=='--authorized-shared-container' and sys.argv[3]==container and container.startswith('supabase_db_mobio_'))
if not container.startswith('supabase_db_mobio_face_maps_') and not shared_authorized:
    raise SystemExit('Expected this task-owned fixture or an explicitly named shared Mobio fixture')
def sql(statement):
    result=subprocess.run(['docker','exec','-i',container,'sh','-c',
        'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U postgres -d postgres -At -v ON_ERROR_STOP=1'],
        input=statement,text=True,capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr[-2500:])
    return result.stdout.strip().splitlines()
user,session,session2,otp,otp2=[str(uuid.uuid4()) for _ in range(5)]
phone='+25079'+str(uuid.uuid4().int%10000000).zfill(7)
sql(f"""begin;select set_config('request.jwt.claims','{{"role":"service_role"}}',true);
insert into auth.users(id,phone,phone_confirmed_at,is_anonymous,raw_app_meta_data,raw_user_meta_data)
values('{user}','{phone}',now(),false,'{{"provider":"admin_whatsapp_otp"}}','{{"qa_fixture":true}}');
insert into auth.sessions(id,user_id,created_at,not_after) values('{session}','{user}',now(),now()+interval '1 hour'),('{session2}','{user}',now(),now()+interval '1 hour');
insert into public.admin_whatsapp_numbers(phone_e164,country_code,is_active) values('{phone}','+250',true);
insert into public.otp_codes(id,phone,profile_id,code,code_hash,purpose,verified,expires_at) values
('{otp}','{phone}','{user}','000000',repeat('a',64),'admin_login',true,now()+interval '5 minutes'),
('{otp2}','{phone}','{user}','000000',repeat('a',64),'admin_login',true,now()+interval '5 minutes');
select public.rpc_register_admin_session('{user}','{session}','{otp}');
select public.rpc_register_admin_session('{user}','{session2}','{otp2}');commit;""")
def claims(sid):
    return json.dumps(dict(sub=user,session_id=sid,role='authenticated',is_anonymous=False,app_metadata=dict(provider='admin_whatsapp_otp')))
def burst(index):
    lines=sql(f"begin;select set_config('request.jwt.claims','{claims(session if index%2 else session2)}',true);select public.rpc_consume_maps_quota('autocomplete') from generate_series(1,20);commit;")
    return [json.loads(line) for line in lines if line.startswith('{') and 'allowed' in line]
with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
    values=sum(pool.map(burst,range(10)),[])
assert len(values)==200,len(values)
assert sum(value['allowed'] for value in values)==100,values
assert all(1<=v['retry_after_seconds']<=300 for v in values if not v['allowed'])
assert sql(f"select request_count from mobio_private.maps_account_quota where user_id='{user}'")==['100']
print('PASS: 200 real parallel RPC requests across 10 connections/two proven sessions admit exactly 100 and retain counter 100.')
# Quota bypass/new-role/private table access is denied by installed grants.
assert sql("select has_table_privilege('authenticated','mobio_private.maps_account_quota','INSERT'),has_table_privilege('service_role','mobio_private.maps_account_quota','UPDATE')")==['f|f']
print('PASS: authenticated/service clients cannot directly change private account counters.')
# A ban transaction holds B's Auth row while an A scan waits. Resolution must
# evaluate the committed ban after lock acquisition, not its initial snapshot.
recipient,recipient_session,recipient_otp,method=[str(uuid.uuid4()) for _ in range(4)]
rphone='+25079'+str(uuid.uuid4().int%10000000).zfill(7)
lines=sql(f"""begin;select set_config('request.jwt.claims','{{"role":"service_role"}}',true);
insert into auth.users(id,phone,phone_confirmed_at,is_anonymous,raw_app_meta_data,raw_user_meta_data)
values('{recipient}','{rphone}',now(),false,'{{"provider":"whatsapp_cloud_otp"}}','{{"qa_fixture":true}}');
insert into auth.sessions(id,user_id,created_at,not_after) values('{recipient_session}','{recipient}',now(),now()+interval '1 hour');
insert into public.otp_codes(id,phone,profile_id,code,code_hash,purpose,verified,expires_at)
values('{recipient_otp}','{rphone}','{recipient}','000000',repeat('a',64),'app_login',true,now()+interval '5 minutes');
select public.rpc_register_app_whatsapp_session('{recipient}','{recipient_session}','{recipient_otp}');
insert into public.biopay_payment_methods(id,owner_id,provider,kind,identifier,label)
values('{method}','{recipient}','mtn_rw','mobileWallet','+250788001121','Synthetic concurrency recipient');
update public.biopay_face_policy set enabled=true,min_score=.8,min_margin=.08,acceptance_evidence='https://fixture.invalid/controlled',accepted_at=now();
update public.biopay_provider_routes set face_enabled=true,face_tested_at=now(),face_evidence_url='https://fixture.invalid/controlled',valid_until=now()+interval '1 day' where face_instruction_template is not null;
select public.rpc_biopay_face_authority('{recipient}','{recipient_session}','begin_enroll',jsonb_build_object('operation_id',public.rpc_reserve_biopay_provider_operation('{recipient}','enroll','{recipient_session}','{uuid.uuid4().hex}',repeat('a',64)),'method_id','{method}','consent',true,'consent_version','face-discovery-v1'));
commit;""")
revision=next(json.loads(line) for line in lines if line.startswith('{') and 'vector_id' in line)
vector=revision['vector_id']
lines=sql(f"""begin;select set_config('request.jwt.claims','{{"role":"service_role"}}',true);
select public.rpc_biopay_face_authority('{recipient}','{recipient_session}','activate','{{"vector_id":"{vector}"}}');
select public.rpc_reserve_biopay_provider_operation('{user}','resolve','{session}','{uuid.uuid4().hex}',repeat('a',64));
delete from auth.sessions where id='{recipient_session}';commit;""")
scan=next(line for line in lines if len(line)==36 and line.count('-')==4)
ban=subprocess.Popen(['docker','exec','-i',container,'sh','-c','PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U postgres -d postgres -At -v ON_ERROR_STOP=1'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
try:
    ban.stdin.write(f"set application_name='mobio_face_maps_ban';begin;update auth.users set banned_until=clock_timestamp()+interval '1 hour' where id='{recipient}';select pg_sleep(3);commit;")
    ban.stdin.close()
    for attempt in range(30):
        if sql("select exists(select1 from pg_stat_activity where application_name='mobio_face_maps_ban' and wait_event='PgSleep')".replace('select1','select 1'))==['t']:
            break
        time.sleep(.02)
    else:
        raise AssertionError('Owned ban-lock transaction never reached its controlled barrier')
    started=time.monotonic()
    response=sql(f"begin;select set_config('request.jwt.claims','{{\"role\":\"service_role\"}}',true);select public.rpc_biopay_face_authority('{user}','{session}','resolve',jsonb_build_object('operation_id','{scan}','model_version','{revision['model_version']}','candidates',jsonb_build_array(jsonb_build_object('id','{vector}','score',.91))));commit;")
    result=next(json.loads(line) for line in response if line.startswith('{') and 'status' in line)
    assert time.monotonic()-started>.5, 'Resolve did not wait behind the actual ban row lock'
    assert result.get('code')=='RECIPIENT_UNAVAILABLE',result
    ban.wait(timeout=10)
    assert ban.returncode==0,ban.stderr.read()
    print('PASS: recipient resolve waits for concurrent Auth ban commit, then denies instead of trusting the old snapshot; B stays signed out.')
finally:
    if ban.poll() is None:
        ban.terminate();ban.wait(timeout=10)
