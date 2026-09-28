// Actual TypeScript code under Node. Auth/database clients are explicit fixtures;
// this does not execute PostgreSQL, Supabase Auth, PostgREST, or the Deno SDK.
import test from 'node:test';
import assert from 'node:assert/strict';
globalThis.Deno={env:{get:()=>undefined}};
globalThis.fetch=async()=>{throw new Error('NETWORK_FORBIDDEN_IN_TEST');};
const {issuedSessionId,validateAdminLease,registerIssuedAdminLease}=await import('../../../supabase/functions/_shared/admin-lease.ts');
const {handleVerifyAdminOtp,ensureAdminUserSession}=await import('../../../supabase/functions/verify-otp/index.ts');
const {findAdminAuthUserByPhone}=await import('../../../supabase/functions/_shared/admin-whatsapp.ts');
const userId='11111111-1111-4111-8111-111111111111',sid='22222222-2222-4222-8222-222222222222';
const other='33333333-3333-4333-8333-333333333333',phone='+250700000019';
const claims={sub:userId,session_id:sid,role:'authenticated',is_anonymous:false,app_metadata:{provider:'admin_whatsapp_otp'}};
function jwt(c=claims){return `e30.${Buffer.from(JSON.stringify(c)).toString('base64url')}.fixture`;}
function lease(overrides={}){return {active:true,user_id:userId,session_id:sid,server_now:'2026-09-28T10:00:00Z',authenticated_at:'2026-09-28T10:00:00Z',idle_expires_at:'2026-09-28T10:15:00Z',absolute_expires_at:'2026-09-28T18:00:00Z',...overrides};}
test('issued Auth token has the expected owner and session binding',()=>assert.equal(issuedSessionId(jwt(),userId),sid));
for(const [name,override] of Object.entries({wrongOwner:{sub:other},missingSession:{session_id:null},invalidSession:{session_id:'invalid'},anonymous:{is_anonymous:true},missingAnonymous:{is_anonymous:undefined},wrongRole:{role:'anon'},wrongPurpose:{app_metadata:{provider:'whatsapp_cloud_otp'}},mutableOnly:{app_metadata:{},user_metadata:{provider:'admin_whatsapp_otp'}}})){
 test(`issued session rejects ${name}`,()=>assert.throws(()=>issuedSessionId(jwt({...claims,...override}),userId),/INVALID_ISSUED_SESSION/));
}
for(const token of ['', 'one','e30.!!!.sig','e30.bm90LWpzb24.sig','a'.repeat(17000)])test(`reject malformed issued token ${token.length}`,()=>assert.throws(()=>issuedSessionId(token,userId)));
test('valid server lease accepted',()=>assert.deepEqual(validateAdminLease(lease(),userId,sid),lease()));
for(const [name,override] of Object.entries({inactive:{active:false},owner:{user_id:other},session:{session_id:other},noClock:{server_now:null},badDate:{server_now:'bad'},idleExpired:{idle_expires_at:'2026-09-28T09:59:59Z'},zeroIdle:{idle_expires_at:'2026-09-28T10:00:00Z'},idleBeyondAbsolute:{absolute_expires_at:'2026-09-28T10:10:00Z'},futureAuth:{authenticated_at:'2026-09-28T10:00:01Z'},excessiveIdle:{idle_expires_at:'2026-09-28T10:31:00Z'},excessiveAbsolute:{absolute_expires_at:'2026-09-29T10:00:00Z'}})){
 test(`server lease rejects ${name}`,()=>assert.throws(()=>validateAdminLease(lease(override),userId,sid),/ADMIN_LEASE_REJECTED/));
}
test('registration sends only issued owner/session and consumed OTP reference',async()=>{
 const calls=[];const result=await registerIssuedAdminLease({rpc:async(n,a)=>{calls.push([n,a]);return {data:lease(),error:null};}},userId,jwt(),'otp-fixture');
 assert.equal(result.active,true);assert.deepEqual(calls,[['rpc_register_admin_session',{p_user_id:userId,p_session_id:sid,p_otp_id:'otp-fixture'}]]);
});
test('database failure does not disclose the raw provider error',async()=>{
 await assert.rejects(registerIssuedAdminLease({rpc:async()=>({data:null,error:new Error('SENSITIVE_PROVIDER_BODY')})},userId,jwt(),'otp'),/^Error: ADMIN_LEASE_UNAVAILABLE$/);
});
test('registration rejects another returned owner',async()=>assert.rejects(registerIssuedAdminLease({rpc:async()=>({data:lease({user_id:other}),error:null})},userId,jwt(),'otp'),/ADMIN_LEASE_REJECTED/));

function fixture(options={}){
 const events=[];
 const row={id:userId,phone:phone.slice(1),phone_confirmed_at:'2026-09-01T00:00:00Z',is_anonymous:false,user_metadata:{},app_metadata:{provider:'admin_whatsapp_otp'}};
 const client={
  rpc:async(name,args)=>{events.push(['rpc',name,args]);
   if(name==='rpc_register_admin_session')return {data:options.leaseData??lease(),error:options.leaseError??null};
   if(name==='rpc_lookup_verified_phone_owner')return {data:options.missingUser?null:userId,error:options.lookupError??null};
   throw new Error('UNEXPECTED_RPC');
  },
  auth:{admin:{
   getUserById:async(id)=>{events.push(['getUser',id]);return {data:{user:{...row,...options.authOverride}},error:options.authError??null};},
   updateUserById:async(id,payload)=>{events.push(['updateUser',id,payload]);return {error:null};},
   createUser:async(payload)=>{events.push(['createUser',payload]);return {data:{user:row},error:null};},
  }},
  from(table){
   const state={table,action:'read',filters:[]};
   const result=()=>{
    events.push(['table',structuredClone(state)]);
    if(table==='admin_whatsapp_numbers')return {data:options.allowlisted===false?null:{id:'allowlist-fixture',phone_e164:phone,country_code:'+250',display_name:'Fixture admin',is_active:true},error:null};
    if(table==='otp_codes'&&state.action==='update')return {data:options.claimed===false?[]:[{id:'otp-fixture'}],error:null};
    if(table==='otp_codes')return {data:options.noOtp?[]:[{id:'otp-fixture',code:'123456',code_hash:null,attempts:options.attempts??0,expires_at:'2099-01-01T00:00:00Z'}],error:null};
    if(table==='profiles')return {data:options.noProfile?null:{id:userId,name:'Own profile'},error:null};
    if(table==='platform_permissions')return {data:[{permission_key:'platform.admin'}],error:null};
    return {data:null,error:null};
   };
   const q={select(v){state.select=v;return q;},eq(k,v){state.filters.push([k,v]);return q;},gte(){return q;},gt(){return q;},order(){return q;},limit(){return q;},maybeSingle(){return Promise.resolve(result());},update(v){state.action='update';state.payload=v;return q;},upsert(v){state.action='upsert';state.payload=v;return q;},insert(v){state.action='insert';state.payload=v;return q;},then(a,b){return Promise.resolve(result()).then(a,b);}};return q;
  }
 };
 const session={access_token:options.token??jwt(),refresh_token:'REFRESH_TEST_ONLY',expires_in:3600,token_type:'bearer',user:row};
 const anon={auth:{signInWithPassword:async()=>{events.push(['signin']);return {data:{session},error:null};}}};
 const dependencies={createAdmin:()=>client,createAnon:()=>anon,
   createSession:async()=>{events.push(['issue']);return {userId,session};}};
 return {client,anon,events,dependencies};
}
function request(body={phone,code:'123456',countryCode:'+250'},method='POST'){
 return new Request('https://fixture.invalid/verify-otp',{method,...(method==='POST'?{headers:{'content-type':'application/json'},body:JSON.stringify(body)}:{})});
}
test('actual OTP handler commits lease before returning any credentials',async()=>{
 const f=fixture();const response=await handleVerifyAdminOtp(request(),f.dependencies);const body=await response.json();
 assert.equal(response.status,200);assert.equal(body.admin_lease.session_id,sid);assert.equal(body.session.refresh_token,'REFRESH_TEST_ONLY');
 const claim=f.events.findIndex(x=>x[0]==='table'&&x[1].table==='otp_codes'&&x[1].action==='update');
 const issue=f.events.findIndex(x=>x[0]==='issue');const register=f.events.findIndex(x=>x[1]==='rpc_register_admin_session');
 assert.ok(claim>=0&&claim<issue&&issue<register);
});
for(const [name,options,status] of [
 ['unapproved',{allowlisted:false},403],['missing OTP',{noOtp:true},400],['consumed OTP',{claimed:false},409],['locked OTP',{attempts:5},429],
 ['lease outage',{leaseError:{message:'SECRET_PROVIDER_BODY'}},500],['invalid issued token',{token:'bad'},500],['wrong returned lease',{leaseData:lease({session_id:other})},500],
])test(`actual handler fails closed for ${name}`,async()=>{
 const f=fixture(options);const response=await handleVerifyAdminOtp(request(),f.dependencies);const body=await response.text();
 assert.equal(response.status,status);assert.equal(body.includes('REFRESH_TEST_ONLY'),false);assert.equal(body.includes('SECRET_PROVIDER_BODY'),false);
 if(status!==500)assert.equal(f.events.some(e=>e[0]==='issue'),false);
});
test('incorrect code consumes an attempt but does not issue a session',async()=>{
 const f=fixture();const response=await handleVerifyAdminOtp(request({phone,code:'000000'}),f.dependencies);assert.equal(response.status,400);assert.equal(f.events.some(e=>e[0]==='issue'),false);
});
test('non POST is rejected',async()=>assert.equal((await handleVerifyAdminOtp(request(null,'GET'),fixture().dependencies)).status,405));
test('actual session provisioning reads only the canonical Auth-owned profile',async()=>{
 const f=fixture({noProfile:true});const result=await ensureAdminUserSession(f.client,f.anon,{id:'fixture',display_name:'Admin',country_code:'+250',is_active:true},phone);
 assert.equal(result.userId,userId);
 const reads=f.events.filter(e=>e[0]==='table'&&e[1].table==='profiles'&&e[1].action==='read');
 assert.equal(reads.length,1);assert.deepEqual(reads[0][1].filters,[['id',userId]]);
 assert.equal(f.events.some(e=>e[0]==='getUser'),true);
});
for(const [name,options] of [['wrong phone',{authOverride:{phone:'250700000020'}}],['unverified phone',{authOverride:{phone_confirmed_at:null}}],['anonymous user',{authOverride:{is_anonymous:true}}],['lookup outage',{lookupError:{}}],['Auth outage',{authError:{}}]]){
 test(`canonical admin lookup rejects ${name}`,async()=>{
  const f=fixture(options);await assert.rejects(findAdminAuthUserByPhone(f.client,phone));
  assert.equal(f.events.some(e=>e[0]==='updateUser'||e[0]==='createUser'),false);
 });
}
