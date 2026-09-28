// Synchronous ingestion tests were superseded by intake.test.mjs (Increment04).
import test from 'node:test';
import assert from 'node:assert/strict';
globalThis.Deno={env:{get:()=>undefined}};
globalThis.fetch=async()=>{throw new Error('Live provider calls are forbidden in fixture tests');};
const {handleRetiredSmsIngest}=await import('../../../supabase/functions/parse-sms/index.ts');
const {handleRetiredSmsIngest:otherLegacy}=await import('../../../supabase/functions/reconcile-momo-sms/index.ts');
const {ensureAppUserSession}=await import('../../../supabase/functions/verify-login-otp/index.ts');
const id='11111111-1111-4111-8111-111111111111';
const phone='+250780000000';
for(const [name,handler] of [['parse-sms',handleRetiredSmsIngest],['reconcile-momo-sms',otherLegacy]]){
  test(`${name} returns explicit retirement for POST`,async()=>{
    const r=handler(new Request('https://fixture.invalid',{method:'POST',body:'{}'}));assert.equal(r.status,410);assert.equal((await r.json()).code,'LEGACY_SMS_INGEST_RETIRED');
  });
}
function authFixture({existing=true,override={},lookupError=null,loadError=null}={}){
  const calls={mutations:[],profileLookups:[],signins:[],creates:[]};
  const user={id,phone:'250780000000',phone_confirmed_at:'2026-09-01T00:00:00Z',is_anonymous:false,app_metadata:{role:'passenger'},user_metadata:{},...override};
  const admin={rpc:async(name,args)=>{assert.equal(name,'rpc_lookup_verified_phone_owner');assert.equal(args.p_phone,phone);return {data:existing?id:null,error:lookupError};},auth:{admin:{
    getUserById:async()=>({data:{user},error:loadError}),
    createUser:async(values)=>{calls.creates.push(values);return {data:{user},error:null};},
    updateUserById:async(owner,values)=>{calls.mutations.push({owner,values});return {error:null};},
  }},from:(table)=>{assert.equal(table,'profiles');return {
    select:()=>({eq:(field,value)=>{calls.profileLookups.push({field,value});return {maybeSingle:async()=>({data:{id,role:'passenger',name:'Fixture'},error:null})};}}),
    upsert:async()=>({error:null}),
  };}};
  const anon={auth:{signInWithPassword:async(values)=>{calls.signins.push(values);return {data:{session:{user,access_token:'fixture-not-a-token'}},error:null};}}};
  return {admin,anon,calls};
}
test('actual existing-user login uses Auth owner and never reassigns phone/email',async()=>{
  const f=authFixture();const result=await ensureAppUserSession(f.admin,f.anon,'passenger',phone,'RW');
  assert.equal(result.userId,id);assert.deepEqual(f.calls.profileLookups,[{field:'id',value:id}]);
  const values=f.calls.mutations[0].values;assert.equal(Object.hasOwn(values,'phone'),false);assert.equal(Object.hasOwn(values,'email'),false);assert.equal(Object.hasOwn(values,'phone_confirm'),false);
  assert.equal(f.calls.signins[0].phone,phone);
});
test('actual login rejects wrong Auth phone before mutation',async()=>{
  const f=authFixture({override:{phone:'250790000000'}});await assert.rejects(ensureAppUserSession(f.admin,f.anon,'passenger',phone,'RW'));
  assert.equal(f.calls.mutations.length,0);assert.equal(f.calls.creates.length,0);
});
test('actual login fails closed on directory outage',async()=>{
  const f=authFixture({lookupError:{message:'fixture'}});await assert.rejects(ensureAppUserSession(f.admin,f.anon,'passenger',phone,'RW'),/PHONE_DIRECTORY_UNAVAILABLE/);assert.equal(f.calls.creates.length,0);
});
test('actual login fails closed on Auth lookup failure',async()=>{
  const f=authFixture({loadError:{message:'fixture'}});await assert.rejects(ensureAppUserSession(f.admin,f.anon,'passenger',phone,'RW'),/PHONE_IDENTITY_UNAVAILABLE/);assert.equal(f.calls.creates.length,0);
});
test('actual new-user login never inspects an alias-matched profile',async()=>{
  const f=authFixture({existing:false});await ensureAppUserSession(f.admin,f.anon,'passenger',phone,'RW');assert.equal(f.calls.creates.length,1);assert.equal(f.calls.profileLookups.length,0);
});
