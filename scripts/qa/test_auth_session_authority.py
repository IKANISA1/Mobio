#!/usr/bin/env python3
"""Real local Auth-issued JWT proof. Never print HTTP bodies or credentials."""
import argparse,json,os,secrets,time,urllib.request,urllib.error,urllib.parse,uuid
from pathlib import Path

def main():
 p=argparse.ArgumentParser();p.add_argument('--credentials',required=True);p.add_argument('--output',required=True);p.add_argument('--mode',choices=['baseline','corrected'],required=True);a=p.parse_args()
 keys=json.loads(Path(a.credentials).read_text()); origin=keys['API_URL'].rstrip('/')
 assert urllib.parse.urlsplit(origin).hostname in ('localhost','127.0.0.1')
 anon=keys['ANON_KEY'];service=keys['SERVICE_ROLE_KEY'];checks=[];last_http={}
 def call(path,body=None,token=None,method=None):
  request=urllib.request.Request(origin+path,data=None if body is None else json.dumps(body).encode(),method=method or ('POST' if body is not None else 'GET'),headers={'apikey':anon,'Authorization':'Bearer '+(token or anon),'Content-Type':'application/json'})
  try:
   with urllib.request.urlopen(request,timeout=15) as r:
    result=json.loads(r.read() or b'null');last_http.update({'path':path,'status':r.status,'error_code':None,'sqlstate':None});return r.status,result
  except urllib.error.HTTPError as e:
   try:result=json.loads(e.read())
   except Exception:result={}
   last_http.update({'path':path,'status':e.code,'error_code':result.get('error_code'),'sqlstate':result.get('code')});return e.code,result
 def check(name,ok):
  checks.append({'name':name,'passed':bool(ok)})
  if not ok:
   Path(a.output).write_text(json.dumps({'mode':a.mode,'passed':False,'checks':checks,'last_http':last_http},indent=2)+'\n')
   raise AssertionError(name)
 health=call('/auth/v1/health')[1];settings=call('/auth/v1/settings')[1]
 password=secrets.token_urlsafe(32); chosen=secrets.token_urlsafe(32)
 phone='250700'+str(secrets.randbelow(900000)+100000);phone2='250700'+str(secrets.randbelow(900000)+100000)
 email=str(uuid.uuid4())+'@auth-fixture.invalid'
 code,created=call('/auth/v1/admin/users',{'phone':phone,'phone_confirm':True,'email':email,'email_confirm':True,'password':password,'app_metadata':{'provider':'whatsapp_cloud_otp','role':'passenger'}},service)
 check('real Auth admin fixture account created',code==200 and bool(created.get('id')));uid=created['id']
 try:
  identifier={'email':email} if settings.get('external',{}).get('email') or os.environ.get('MOBIO_AUTH_USE_EMAIL_EXCHANGE')=='1' else {'phone':phone}
  status,initial=call('/auth/v1/token?grant_type=password',{**identifier,'password':password})
  if status!=200 and a.mode=='baseline':
   Path(a.output).write_text(json.dumps({'mode':a.mode,'auth_version':health.get('version'),'baseline_internal_exchange_blocked':True,'http_status':status,'error_code':initial.get('error_code'),'checks':checks,'signed_auth_http':False,'provider_delivery':False},indent=2)+'\n')
   print('baseline: repository Auth configuration blocks its own internal password exchange');return
  check('server internal password exchange works',status==200)
  bearer=initial['access_token']
  if a.mode=='corrected':
   import base64,hashlib
   sid=json.loads(base64.urlsafe_b64decode(bearer.split('.')[1]+'=='))['session_id'];otp=str(uuid.uuid4())
   status,_=call('/rest/v1/otp_codes',{'id':otp,'phone':'+'+phone,'purpose':'app_login','code':'000000','code_hash':hashlib.sha256(secrets.token_bytes(32)).hexdigest(),'verified':True,'expires_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(time.time()+300))},service)
   check('trusted consumed OTP fixture inserted',status==201)
   status,proof=call('/rest/v1/rpc/rpc_register_app_whatsapp_session',{'p_user_id':uid,'p_session_id':sid,'p_otp_reference':otp},service)
   check('real issued SID registers exact OTP proof',status==200 and proof=={'user_id':uid,'session_id':sid})
   status,proof=call('/rest/v1/rpc/rpc_verified_interactive_session',{},bearer)
   check('real proven bearer cold restore matches user and SID',status==200 and proof=={'user_id':uid,'session_id':sid})
   status,fresh=call('/auth/v1/token?grant_type=refresh_token',{'refresh_token':initial['refresh_token']})
   check('same SID refresh retains real consumed OTP proof',status==200)
   bearer=fresh['access_token'];status,proof=call('/rest/v1/rpc/rpc_verified_interactive_session',{},bearer)
   check('refreshed real bearer retains exact SID proof',status==200 and proof=={'user_id':uid,'session_id':sid})
  status,_=call('/auth/v1/signup',{'email':str(uuid.uuid4())+'@auth-fixture.invalid','password':chosen});check('baseline direct signup disabled',status>=400)
  status,_=call('/auth/v1/signup',{});check('baseline anonymous signup disabled',status>=400)
  status,_=call('/auth/v1/user',{'password':chosen},bearer,'PUT');check('authenticated caller can select password',status==200)
  status,new=call('/auth/v1/token?grant_type=password',{**identifier,'password':chosen});check('direct chosen password issues real session',status==200)
  token=new['access_token'];status,actor=call('/rest/v1/rpc/verified_app_user_id',{},token)
  if a.mode=='baseline':check('REPRODUCED direct password session obtains app authority',status==200 and actor==uid)
  else:check('corrected direct password session has no app authority',status==403)
  status,_=call('/auth/v1/user',{'phone':phone2},token,'PUT');check('direct phone mutation succeeds without WhatsApp',status==200)
  status,user=call('/auth/v1/user',token=token);check('phone mutation is Auth-confirmed',status==200 and user.get('phone')==phone2 and bool(user.get('phone_confirmed_at')))
  status,owner=call('/rest/v1/rpc/rpc_lookup_verified_phone_owner',{'p_phone':'+'+phone2},service)
  if a.mode=='baseline':check('REPRODUCED changed phone becomes verified directory owner',status==200 and owner==uid)
  else:check('corrected changed phone directory fails closed',status>=400)
  status,refreshed=call('/auth/v1/token?grant_type=refresh_token',{'refresh_token':new['refresh_token']});check('real Auth refresh works',status==200)
  status,actor=call('/rest/v1/rpc/verified_app_user_id',{},refreshed['access_token'])
  check('refresh authority follows proof rather than durable metadata',(status==200 and actor==uid) if a.mode=='baseline' else status==403)
  status,_=call('/auth/v1/user',{'app_metadata':{'provider':'admin_whatsapp_otp'}},refreshed['access_token'],'PUT');check('caller app metadata mutation denied',status>=400)
  status,email_change=call('/auth/v1/user',{'email':str(uuid.uuid4())+'@changed-auth-fixture.invalid'},bearer,'PUT')
  check('direct email update uses Auth confirmation rather than WhatsApp',status==200 and email_change.get('email')==email)
  status,recovery=call('/auth/v1/admin/generate_link',{'type':'recovery','email':email},service)
  check('local real Auth generates recovery challenge',status==200 and bool(recovery.get('hashed_token')))
  status,recovered=call('/auth/v1/verify',{'type':'recovery','token_hash':recovery['hashed_token']})
  check('recovery issues independent real Auth transport',status==200 and bool(recovered.get('access_token')))
  status,recovery_actor=call('/rest/v1/rpc/verified_app_user_id',{},recovered['access_token'])
  check('recovery authority follows actual session admission',status==200 if a.mode=='baseline' else status==403)
 finally:
  call('/auth/v1/admin/users/'+uid,token=service,method='DELETE')
 Path(a.output).write_text(json.dumps({'mode':a.mode,'auth_version':health.get('version'),'settings':{k:v for k,v in settings.items() if k in ['disable_signup','external','phone_autoconfirm','mail_autoconfirm']},'checks':checks,'passed':all(x['passed'] for x in checks),'signed_auth_http':True,'provider_delivery':False},indent=2)+'\n')
 print(f"{a.mode}: {len(checks)} real Auth/REST assertions passed")

if __name__=='__main__':
 try:main()
 except Exception as error:
  # Assertion names are authored safe strings; network errors/bodies stay private.
  print('Auth authority fixture failed: '+(str(error) if isinstance(error,AssertionError) else type(error).__name__))
  raise SystemExit(1)
