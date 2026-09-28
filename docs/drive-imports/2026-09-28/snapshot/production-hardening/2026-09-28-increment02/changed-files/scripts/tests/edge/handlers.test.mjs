import test from 'node:test';
import assert from 'node:assert/strict';
globalThis.Deno={env:{get:()=>undefined}};
globalThis.fetch=async()=>{throw new Error('Live provider calls are forbidden in fixture tests');};
const {handleMomoBioSmsIngest}=await import('../../../supabase/functions/momobio-sms-ingest/index.ts');
const {handleRetiredSmsIngest}=await import('../../../supabase/functions/parse-sms/index.ts');
const {handleRetiredSmsIngest:otherLegacy}=await import('../../../supabase/functions/reconcile-momo-sms/index.ts');
const {ensureAppUserSession}=await import('../../../supabase/functions/verify-login-otp/index.ts');
const {sha256Hex,collectorSigningPayload}=await import('../../../supabase/functions/_shared/sms-collector.ts');
const id='11111111-1111-4111-8111-111111111111';
const phone='+250780000000';
const raw='You have received 2,000 RWF. Reference: 123456-ABCDEFGH. Merchant code: 12345. TxId: ABC123456.';
const parsed={amount_rwf:2000,reference_code:'123456-ABCDEFGH',momo_pay_code:'12345',provider_transaction_ref:'ABC123456',is_momo_payment:true,confidence:0.98,parser_source:'openai',openai_model:'fixture',parser_version:'fixture'};
const policy={enabled:true,allowedSenders:['MTN'],merchantCodes:['12345'],minConfidence:0.95};
const keys=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
const jwk=await crypto.subtle.exportKey('jwk',keys.publicKey);
async function request(){
  const body=JSON.stringify({messages:[{sender:'MTN',body:raw,received_at_millis:Date.now(),message_hash:'a'.repeat(64)}]});
  const timestamp=String(Date.now()),nonce=crypto.randomUUID();
  const hash=await sha256Hex(new TextEncoder().encode(body));
  const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',keys.privateKey,new TextEncoder().encode(collectorSigningPayload(id,timestamp,nonce,hash)));
  return new Request('https://fixture.invalid/momobio-sms-ingest',{method:'POST',body,headers:{
    'x-mobio-collector-id':id,'x-mobio-timestamp':timestamp,'x-mobio-nonce':nonce,
    'x-mobio-signature':Buffer.from(signature).toString('base64url'),
  }});
}
function intake({classification=parsed,writeError=false,storedStatus=null}={}){
  let allocations=0,admissions=0,claims=0,parseCalls=0;const rows=new Map();
  const admin={rpc:async(name)=>{assert.equal(name,'rpc_ingest_driver_subscription_momo_sms');allocations++;return {data:{status:'matched'},error:null};},
    from:(table)=>{assert.equal(table,'driver_subscription_momo_sms_receipts');return {
      upsert:async(row,options)=>{admissions++;assert.equal(options.ignoreDuplicates,true);
        if(writeError)return {error:{message:'fixture write failure'}};
        if(!rows.has(row.sms_hash))rows.set(row.sms_hash,storedStatus?{status:storedStatus,metadata:{}}:row);
        return {error:null};},
      select:()=>({eq:(_field,hash)=>({maybeSingle:async()=>({data:rows.get(hash),error:null})})}),
    };}};
  const registry={load:async()=>({public_key_jwk:jwk,public_key_fingerprint:'fixture',expires_at:new Date(Date.now()+60000).toISOString(),revoked_at:null}),claim:async()=>{claims++;}};
  return {deps:{admin,registry,parse:async()=>{parseCalls++;return classification;},policy},stats:()=>({allocations,admissions,claims,parseCalls})};
}
test('actual intake verifies fixture RSA signature and allocates only eligible receipt',async()=>{
  const f=intake();const r=await handleMomoBioSmsIngest(await request(),f.deps);assert.equal(r.status,202);assert.equal(f.stats().claims,1);assert.equal(f.stats().allocations,1);
});
test('actual intake persists nonpayment without allocation',async()=>{
  const f=intake({classification:{...parsed,is_momo_payment:false,confidence:0}});const r=await handleMomoBioSmsIngest(await request(),f.deps);
  assert.equal(r.status,202);assert.equal(f.stats().admissions,1);assert.equal(f.stats().allocations,0);assert.equal((await r.json()).results[0].review_required,true);
});
test('disabled policy retains review and never credits',async()=>{
  const f=intake();f.deps.policy={...policy,enabled:false};const r=await handleMomoBioSmsIngest(await request(),f.deps);assert.equal(r.status,202);assert.equal(f.stats().allocations,0);
});
test('failed review persistence is not acknowledged',async()=>{
  const f=intake({writeError:true,classification:{...parsed,is_momo_payment:false}});const r=await handleMomoBioSmsIngest(await request(),f.deps);assert.equal(r.status,503);assert.equal(f.stats().allocations,0);
});
test('retry cannot overwrite prior matched receipt or misreport it as unmatched',async()=>{
  const f=intake({storedStatus:'matched',classification:{...parsed,is_momo_payment:false}});const r=await handleMomoBioSmsIngest(await request(),f.deps);assert.equal((await r.json()).results[0].status,'matched');assert.equal(f.stats().allocations,0);
});
test('unsigned intake does not parse or store',async()=>{
  const f=intake();const r=await handleMomoBioSmsIngest(new Request('https://fixture.invalid',{method:'POST',body:'{}'}),f.deps);assert.equal(r.status,401);assert.equal(f.stats().parseCalls,0);
});
test('revoked collector is denied before parsing',async()=>{
  const f=intake();f.deps.registry.load=async()=>({public_key_jwk:jwk,public_key_fingerprint:'fixture',expires_at:new Date(Date.now()+60000).toISOString(),revoked_at:new Date().toISOString()});
  const r=await handleMomoBioSmsIngest(await request(),f.deps);assert.equal(r.status,403);assert.equal(f.stats().parseCalls,0);
});
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
