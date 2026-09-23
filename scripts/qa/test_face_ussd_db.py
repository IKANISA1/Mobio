#!/usr/bin/env python3
"""Real disposable PostgreSQL + PostgREST contract/behavior test; no live project."""
import base64, hashlib, hmac, json, os, pathlib, shutil, socket, subprocess, tempfile, time, urllib.request, urllib.error, uuid
ROOT=pathlib.Path(__file__).resolve().parents[2]
PG=pathlib.Path(os.environ.get('PG_BIN', pathlib.Path(shutil.which('initdb') or '/missing/initdb').parent))
REST=os.environ.get('POSTGREST_BIN',shutil.which('postgrest') or '/missing/postgrest')
def port():
    with socket.socket() as s: s.bind(('127.0.0.1',0));return s.getsockname()[1]
def jwt(secret):
    enc=lambda x:base64.urlsafe_b64encode(json.dumps(x,separators=(',',':')).encode()).rstrip(b'=')
    data=enc({'alg':'HS256','typ':'JWT'})+b'.'+enc({'role':'service_role','exp':int(time.time())+600})
    return (data+b'.'+base64.urlsafe_b64encode(hmac.new(secret.encode(),data,hashlib.sha256).digest()).rstrip(b'=')).decode()

def main():
    with tempfile.TemporaryDirectory(prefix='mobio-face-',dir='/tmp') as directory:
        d=pathlib.Path(directory);dbport=port();httpport=port(); proc=None; started=False
        log=(d/'db.log').open('w'); restlog=(d/'rest.log').open('w')
        def run(args,**kwargs):return subprocess.run(args,check=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,**kwargs).stdout
        def sql(text):return run([str(PG/'psql'),'-h',str(d),'-p',str(dbport),'-d','postgres','-At','-v','ON_ERROR_STOP=1'],input=text).strip()
        secret='disposable-fixture-secret-not-a-deployment-credential';token=jwt(secret)
        def rpc(name,data,expected=200):
            request=urllib.request.Request(f'http://127.0.0.1:{httpport}/rpc/{name}',data=json.dumps(data).encode(),headers={'Authorization':'Bearer '+token,'Content-Type':'application/json'})
            try:
                with urllib.request.urlopen(request,timeout=10) as r: status=r.status;value=json.load(r)
            except urllib.error.HTTPError as error:status=error.code;value=json.load(error)
            assert (status==expected if expected==200 else status>=400),(name,status,value)
            return value
        try:
            run([str(PG/'initdb'),'-D',str(d/'data'),'-A','trust','--no-locale'])
            run([str(PG/'pg_ctl'),'-D',str(d/'data'),'-l',str(d/'db.log'),'-o',f'-p {dbport} -k {d} -h 127.0.0.1','-w','start']);started=True
            fixture='''create role anon;create role authenticated;create role service_role;
create schema auth;create schema extensions;create extension pgcrypto with schema extensions;
create function auth.jwt() returns jsonb language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb$$;
create function auth.uid() returns uuid language sql stable as $$select coalesce(nullif(current_setting('request.jwt.claim.sub',true),''),auth.jwt()->>'sub')::uuid$$;
create function auth.role() returns text language sql stable as $$select auth.jwt()->>'role'$$;
create table auth.users(id uuid primary key,is_anonymous boolean default false,phone_confirmed_at timestamptz,raw_app_meta_data jsonb);
create table auth.sessions(id uuid primary key,user_id uuid,not_after timestamptz);
create table public.profiles(id uuid primary key,name text default '',display_name text default '',phone text default '',whatsapp text default '',member_id text,whatsapp_verified_at timestamptz,role text default 'passenger',momo_number text,momo_pay_code text);
create table public.admin_whatsapp_numbers(phone_e164 text,country_code text not null,is_active boolean);
create function public.fn_biopay_require_admin() returns void language plpgsql as $$begin null;end$$;
grant usage on schema public,auth to service_role,authenticated,anon;
'''
            legacy=(ROOT/'supabase/migrations/20260612133000_biopay_ussd_aws_reactivation.sql').read_text()
            fixture+=legacy[legacy.index('create table if not exists public.biopay_profiles'):legacy.index('alter table public.biopay_profiles enable')]
            sql(fixture)
            migrations=[ROOT/'supabase/migrations/20260906143000_biopay_provider_authority.sql',*sorted((ROOT/'supabase/migrations').glob('2026090809*.sql')),*sorted((ROOT/'supabase/migrations').glob('20260920150*.sql'))]
            for migration in migrations:sql(migration.read_text())
            sql('grant usage on schema public,auth to service_role;')
            config=d/'postgrest.conf'; user=os.environ.get('USER','jeanbosco')
            config.write_text(f'db-uri="postgresql://{user}@127.0.0.1:{dbport}/postgres"\ndb-schemas="public"\ndb-anon-role="anon"\njwt-secret="{secret}"\nserver-host="127.0.0.1"\nserver-port={httpport}\n')
            proc=subprocess.Popen([REST,str(config)],stdout=restlog,stderr=restlog,env={**os.environ,'DYLD_LIBRARY_PATH':str(PG.parent/'lib')})
            for _ in range(100):
                try:urllib.request.urlopen(f'http://127.0.0.1:{httpport}',timeout=.2);break
                except Exception:time.sleep(.1)
            a,b,c=[str(uuid.uuid4()) for _ in range(3)]; sa,sb,expired=[str(uuid.uuid4()) for _ in range(3)]
            m1,m2=[str(uuid.uuid4()) for _ in range(2)]
            sql(f"insert into profiles(id,phone,whatsapp) values('{a}','+250788000001','+250788000001'),('{b}','+250788000002','+250788000002'),('{c}','+250788000003','+250788000003'); insert into auth.users select id,false,now(),'{{\"provider\":\"whatsapp_cloud_otp\"}}' from profiles;insert into auth.sessions values('{sa}','{a}',now()+interval '1 hour'),('{sb}','{b}',now()+interval '1 hour'),('{expired}','{a}',now()-interval '1 second');insert into biopay_payment_methods(id,owner_id,provider,kind,identifier,label) values('{m1}','{b}','mtn_rw','mobileWallet','+250788767816','Receiving'),('{m2}','{b}','mtn_rw','mobileWallet','+250788000005','Second');")
            def reserve(user,session,action='resolve',key=None,digest='a'*64,expected=200):return rpc('rpc_reserve_biopay_provider_operation',dict(p_user_id=user,p_auth_session_id=session,p_action=action,p_idempotency_key=key or uuid.uuid4().hex,p_request_digest=digest),expected)
            def call(user,session,action,data=None,expected=200):return rpc('rpc_biopay_face_authority',dict(p_user_id=user,p_session_id=session,p_action=action,p_data=data or {}),expected)
            assert 'BIOPAY_SESSION_INVALID' in reserve(a,sb,expected=400)['message']
            assert 'BIOPAY_SESSION_INVALID' in reserve(a,expired,expected=400)['message']
            key=uuid.uuid4().hex;scan=reserve(a,sa,key=key);assert reserve(a,sa,key=key)==scan
            assert 'IDEMPOTENCY_CONFLICT' in reserve(a,sa,key=key,digest='b'*64,expected=400)['message']
            enrollment=reserve(b,sb,'enroll')
            def begin(op,method=m1):return call(b,sb,'begin_enroll',{'operation_id':op,'method_id':method,'consent':True,'consent_version':'face-discovery-v1'})
            assert 'CONSENT_REQUIRED' in call(b,sb,'begin_enroll',{'operation_id':enrollment,'method_id':m1,'consent':True},400)['message']
            assert 'RECEIVING_METHOD_REQUIRED' in call(b,sb,'begin_enroll',{'operation_id':enrollment,'method_id':str(uuid.uuid4()),'consent':True,'consent_version':'face-discovery-v1'},400)['message']
            revision=begin(enrollment);v=revision['vector_id'];assert begin(enrollment)['vector_id']==v
            assert call(b,sb,'status')['status']=='processing'
            call(b,sb,'activate',{'vector_id':v});assert call(b,sb,'status')['status']=='active'
            # Null evidence cannot enable recognition even with a timestamp and scores.
            try:
                sql("update biopay_face_policy set enabled=true,min_score=.8,min_margin=.08,accepted_at=now()")
                raise AssertionError('Unaccepted policy became enabled')
            except subprocess.CalledProcessError: pass
            assert call(a,sa,'resolve',{'operation_id':scan})['code']=='POLICY_NOT_ACCEPTED'
            # Controlled SQL policy fixtures test contract behavior, not measured face accuracy.
            sql("update biopay_face_policy set enabled=true,min_score=.8,min_margin=.08,acceptance_evidence='https://fixture.invalid/test-policy',accepted_at=now();update biopay_provider_routes set face_enabled=true,face_tested_at=now(),face_evidence_url='https://fixture.invalid/route',valid_until=now()+interval '1 day' where face_instruction_template is not null;")
            def resolve(op=scan,candidates=None):return call(a,sa,'resolve',{'operation_id':op,'model_version':revision['model_version'],'candidates':candidates or [{'id':v,'score':.91}]})
            sql("update biopay_provider_routes set face_enabled=false")
            assert resolve()['code']=='ROUTE_NOT_CONFIGURED'
            sql("update biopay_provider_routes set face_enabled=true where face_instruction_template is not null")
            result=resolve();assert result['ussd_code']=='*182*1*1*0788767816#',result
            assert result['receiving_method_id']==m1 and result['payee_id']==b and 'amount' not in result
            assert sql(f"select count(*) from biopay_profiles where user_id='{a}'")=='0'
            call(b,sb,'change_method',{'method_id':m2});assert resolve()['ussd_code'].endswith('0788000005#')
            sql(f"update biopay_payment_methods set identifier='+250788000006',version=version+1 where id='{m2}';")
            assert resolve()['ussd_code'].endswith('0788000006#') and resolve()['receiving_method_version']==2
            call(b,sb,'pause');assert resolve()['status']=='recipient_unavailable'
            call(b,sb,'resume');assert resolve()['status']=='dial_ready'
            sql(f"update biopay_payment_methods set active=false where id='{m2}'")
            assert resolve()['status']=='recipient_unavailable'
            assert call(b,sb,'status')['status']=='receiving_method_required'
            sql(f"update biopay_payment_methods set active=true where id='{m2}'")
            replacement=begin(reserve(b,sb,'enroll'),m2)
            assert resolve()['status']=='dial_ready' # old face retained while replacement pending
            call(b,sb,'activate',{'vector_id':replacement['vector_id']})
            assert resolve()['status']=='recipient_unavailable' # stale top must never select lower
            scan2=reserve(a,sa)
            assert resolve(scan2,[{'id':replacement['vector_id'],'score':.91},{'id':'f_'+'0'*32,'score':.9}])['status']=='ambiguous'
            scan3=reserve(a,sa)
            assert resolve(scan3,[{'id':replacement['vector_id'],'score':.91}])['status']=='dial_ready'
            call(a,sa,'handoff',{'operation_id':scan3});call(a,sa,'handoff',{'operation_id':scan3})
            assert sql("select count(*) from biopay_audit_events where action='biopay.face.dialer_opened'")=='1'
            assert sql('select count(*) from biopay_payment_requests')=='0'
            sql("update biopay_face_cleanup set not_before=now()-interval '1 second'")
            pending=rpc('rpc_biopay_face_maintenance',{'p_deleted_ids':[]})
            assert v in [x['vector_id'] for x in pending] and replacement['vector_id'] not in [x['vector_id'] for x in pending]
            rpc('rpc_biopay_face_maintenance',{'p_deleted_ids':[v,replacement['vector_id']]})
            assert sql(f"select deleted_at is null from biopay_face_cleanup where vector_id='{replacement['vector_id']}'")=='t'
            sql(f"update biopay_face_cleanup set deleted_at=now()-interval '2 days' where vector_id='{v}'")
            assert v in [x['vector_id'] for x in rpc('rpc_biopay_face_maintenance',{'p_deleted_ids':[]})]
            call(b,sb,'remove');assert resolve(scan3)['status']=='recipient_unavailable'
            assert sql("select has_function_privilege('authenticated','public.rpc_create_verified_biopay_face_match_request(uuid,integer,text)','EXECUTE')")=='f'
            assert rpc('rpc_biopay_face_readiness',{})['database_contract'] is True
            pending_revision=begin(reserve(b,sb,'enroll'))
            call(b,sb,'pause')
            assert call(b,sb,'activate',{'vector_id':pending_revision['vector_id']})['status']=='cancelled'
            expired_revision=begin(reserve(b,sb,'enroll'))
            sql(f"update biopay_face_revisions set expires_at=now()-interval '1 second' where vector_id='{expired_revision['vector_id']}'")
            assert call(b,sb,'status')['pending_vector_id'] is None
            assert call(b,sb,'status')['status']=='rejected'
            remaining=30-int(sql(f"select count(*) from biopay_provider_operations where user_id='{a}' and action='resolve'"))
            for _ in range(remaining):reserve(a,sa)
            assert 'BIOPAY_RATE_LIMIT' in reserve(a,sa,expected=400)['message']
            print('PASS: real PostgreSQL/PostgREST; session ownership/expiry, idempotency, A/B receiving binding, payer independence, updates, replacement, pause/remove, ambiguity, amount-free shortcut, handoff dedup, cleanup protection, legacy revocation.')
        except Exception:
            print((d/'rest.log').read_text()[-2000:])
            raise
        finally:
            if proc:proc.terminate();proc.wait(timeout=10)
            if started:run([str(PG/'pg_ctl'),'-D',str(d/'data'),'-m','immediate','stop'])
            log.close();restlog.close()
if __name__=='__main__':main()
