import test from 'node:test';
import assert from 'node:assert/strict';
globalThis.Deno={env:{get:()=>undefined}};
globalThis.fetch=async()=>{throw new Error('Live provider access is forbidden in fixtures');};
const {handleMomoBioSmsIngest}=await import('../../../supabase/functions/momobio-sms-ingest/index.ts');
const {handleMomoBioSmsProcess}=await import('../../../supabase/functions/momobio-sms-process/index.ts');
const {sha256Hex,collectorSigningPayload}=await import('../../../supabase/functions/_shared/sms-collector.ts');
const {normalizeIntakeBatch,validateAdmissionResponse,databaseIntakeError}=await import('../../../supabase/functions/_shared/momobio-intake.ts');
const {validateIntakeJob,workerFailureCode,completionPayload}=await import('../../../supabase/functions/_shared/momobio-worker.ts');
const {HttpError}=await import('../../../supabase/functions/_shared/validation.ts');
const id='11111111-1111-4111-8111-111111111111';
const raw='You have received 2,000 RWF. Reference: 123456-ABCDEFGH. Merchant code: 12345. TxId: ABC123456.';
const policy={enabled:true,allowedSenders:['MTN'],merchantCodes:['12345'],minConfidence:0.95};
const parsed={amount_rwf:2000,reference_code:'123456-ABCDEFGH',momo_pay_code:'12345',provider_transaction_ref:'ABC123456',is_momo_payment:true,confidence:0.98,parser_source:'openai',openai_model:'fixture',parser_version:'fixture'};
const stamp=Date.now()-1000;
const envelope=(override={})=>({sender:'MTN',body:raw,received_at_millis:stamp,message_hash:'a'.repeat(64),...override});
const keys=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
const jwk=await crypto.subtle.exportKey('jwk',keys.publicKey);
async function request(payload={messages:[envelope()]},bodyReplacement){
  const body=typeof payload==='string'?payload:JSON.stringify(payload),timestamp=String(Date.now()),nonce=crypto.randomUUID();
  const hash=await sha256Hex(new TextEncoder().encode(body));
  const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',keys.privateKey,new TextEncoder().encode(collectorSigningPayload(id,timestamp,nonce,hash)));
  return new Request('https://fixture.invalid/momobio-sms-ingest',{method:'POST',body:bodyReplacement??body,headers:{
    'x-mobio-collector-id':id,'x-mobio-timestamp':timestamp,'x-mobio-nonce':nonce,'x-mobio-signature':Buffer.from(signature).toString('base64url')}});
}
// This is an explicit RPC fixture, NOT an execution of the PostgreSQL migration.
function intake(options={}){
  const calls=[],claims=[];const rows=new Map();
  const registry={load:async()=>({public_key_jwk:jwk,public_key_fingerprint:'fixture',expires_at:new Date(Date.now()+60000).toISOString(),revoked_at:options.revoked?'2026-01-01T00:00:00Z':null}),
    claim:async(...args)=>{claims.push(args);if(options.claimError)throw options.claimError;}};
  const admin={rpc:async(name,args)=>{
    calls.push({name,args});
    if(options.error)return {data:null,error:{message:options.error}};
    if(name==='rpc_momobio_sms_intake_health')return {error:null,data:{version:'momobio-intake-v1',automatic_allocation_enabled:true,worker_recent:false,queued_count:2,review_count:1,...options.health}};
    assert.equal(name,'rpc_admit_momobio_sms_batch');assert.equal(args.p_collector_id,id);
    const results=[];
    for(const message of args.p_messages){
      const saved=rows.get(message.message_hash);
      if(saved && JSON.stringify(saved.message)!==JSON.stringify(message))return {data:null,error:{message:'INTAKE_HASH_CONFLICT'}};
      const record=saved??{message,id:crypto.randomUUID(),review:!args.p_edge_processing_enabled||message.sender!=='MTN'};
      rows.set(message.message_hash,record);
      results.push({message_hash:message.message_hash,status:saved?'duplicate':'accepted',admission_id:record.id,
        admission_status:record.review?'review':'queued',review_required:record.review});
    }
    const data={version:'momobio-intake-v1',results};return {data:options.mutateAck?options.mutateAck(data):data,error:null};
  }};
  return {calls,claims,rows,deps:{admin,registry,policy:{...policy,...options.policy}}};
}

test('RSA-verified admission calls one durable RPC; no financial RPC or AI in request',async()=>{
  const f=intake();const response=await handleMomoBioSmsIngest(await request(),f.deps);
  assert.equal(response.status,202);assert.equal(f.claims.length,1);assert.equal(f.calls.length,1);
  assert.equal(f.calls[0].name,'rpc_admit_momobio_sms_batch');
  const body=await response.json();assert.equal(body.kind,'durable_receipt_admission');assert.equal(body.results[0].status,'accepted');
  assert.equal(response.headers.get('cache-control'),'no-store');
});
test('50 receipts use one atomic admission call',async()=>{
  const f=intake();const rows=Array.from({length:50},(_,i)=>envelope({message_hash:i.toString(16).padStart(64,'0')}));
  const r=await handleMomoBioSmsIngest(await request({messages:rows}),f.deps);assert.equal(r.status,202);assert.equal(f.calls.length,1);assert.equal((await r.json()).results.length,50);
});
test('a bad final envelope prevents admission of the entire batch',async()=>{
  const f=intake();const r=await handleMomoBioSmsIngest(await request({messages:[envelope(),envelope({sender:''})]}),f.deps);assert.equal(r.status,400);assert.equal(f.calls.length,0);
});
test('re-delivered envelope keeps same admission ID and is marked duplicate',async()=>{
  const f=intake();const a=await (await handleMomoBioSmsIngest(await request(),f.deps)).json();const b=await (await handleMomoBioSmsIngest(await request(),f.deps)).json();
  assert.equal(a.results[0].admission_id,b.results[0].admission_id);assert.equal(b.results[0].status,'duplicate');assert.equal(f.rows.size,1);
});
test('same key with a different retained payload is an explicit conflict',async()=>{
  const f=intake();await handleMomoBioSmsIngest(await request(),f.deps);
  const r=await handleMomoBioSmsIngest(await request({messages:[envelope({body:'Changed content'})]}),f.deps);assert.equal(r.status,409);assert.equal(f.rows.size,1);
});
for(const message of ['database unavailable','INTAKE_CAPACITY','opaque error with SMS +250123456789']){
  test(`admission storage failure is not acknowledged: ${message.split(' ')[0]}`,async()=>{
    const f=intake({error:message});const r=await handleMomoBioSmsIngest(await request(),f.deps);
    assert.equal(r.status,503);assert.equal(r.headers.get('retry-after'),'60');const b=await r.text();assert.equal(b.includes('results'),false);assert.equal(b.includes('+250'),false);
  });
}
for(const [name,mutateAck] of [
  ['missing results',d=>({...d,results:[]})],['wrong hash',d=>({...d,results:[{...d.results[0],message_hash:'b'.repeat(64)}]})],
  ['unknown schema',d=>({...d,version:'old'})],['invalid ID',d=>({...d,results:[{...d.results[0],admission_id:'bogus'}]})],
  ['unknown result state',d=>({...d,results:[{...d.results[0],admission_status:'credited'}]})],
  ['missing review flag',d=>({...d,results:[{...d.results[0],review_required:null}]})],
])test(`malformed database acknowledgement fails closed: ${name}`,async()=>{
  const f=intake({mutateAck});assert.equal((await handleMomoBioSmsIngest(await request(),f.deps)).status,503);
});
test('unsigned intake cannot reach the database',async()=>{
  const f=intake();const r=await handleMomoBioSmsIngest(new Request('https://fixture.invalid',{method:'POST',body:'{}'}),f.deps);assert.equal(r.status,401);assert.equal(f.calls.length,0);
});
test('modified signed payload fails real RSA verification',async()=>{
  const f=intake();const r=await handleMomoBioSmsIngest(await request({},'{"modified":true}'),f.deps);assert.equal(r.status,401);assert.equal(f.claims.length,0);assert.equal(f.calls.length,0);
});
test('revoked collector cannot admit receipts',async()=>{const f=intake({revoked:true});assert.equal((await handleMomoBioSmsIngest(await request(),f.deps)).status,403);assert.equal(f.calls.length,0);});
for(const status of [409,429,503])test(`replay/rate/auth-store rejection ${status} cannot be acknowledged`,async()=>{
  const f=intake({claimError:new HttpError('fixture',status)});assert.equal((await handleMomoBioSmsIngest(await request(),f.deps)).status,status);assert.equal(f.calls.length,0);
});
test('invalid signed JSON has no storage side effect',async()=>{const f=intake();assert.equal((await handleMomoBioSmsIngest(await request('invalid'),f.deps)).status,400);assert.equal(f.calls.length,0);});
test('signed request over 512 KiB is rejected before replay claim',async()=>{const f=intake();assert.equal((await handleMomoBioSmsIngest(await request('x'.repeat(524289)),f.deps)).status,413);assert.equal(f.claims.length,0);});
test('health uses database readiness rather than an empty local queue',async()=>{
  const f=intake();const r=await handleMomoBioSmsIngest(await request({action:'health'}),f.deps);assert.equal(r.status,200);const b=await r.json();assert.equal(b.worker_recent,false);assert.equal(b.queued_count,2);assert.equal(b.durable_intake_ready,true);assert.equal(f.calls[0].name,'rpc_momobio_sms_intake_health');
});
test('failed health query cannot advertise readiness',async()=>{const f=intake({error:'offline'});assert.equal((await handleMomoBioSmsIngest(await request({action:'health'}),f.deps)).status,503);});
test('health rejects receipt fields rather than ignoring possible data',async()=>{const f=intake();assert.equal((await handleMomoBioSmsIngest(await request({action:'health',messages:[]}),f.deps)).status,400);assert.equal(f.calls.length,0);});
for(const [name,p] of [['disabled',{enabled:false}],['no merchants',{merchantCodes:[]}],['no senders',{allowedSenders:[]}]])test(`edge policy ${name} cannot advertise automatic allocation`,async()=>{
  const f=intake({policy:p});assert.equal((await (await handleMomoBioSmsIngest(await request({action:'health'}),f.deps)).json()).automatic_allocation_enabled,false);
  const r=await handleMomoBioSmsIngest(await request(),f.deps);assert.equal(r.status,202);assert.equal(f.calls.at(-1).args.p_edge_processing_enabled,false);
});
test('unapproved sender is durably reviewable, not falsely reported as a payment',async()=>{
  const f=intake();const r=await handleMomoBioSmsIngest(await request({messages:[envelope({sender:'OTHER'})]}),f.deps);const b=await r.json();assert.equal(b.results[0].status,'accepted');assert.equal(b.results[0].review_required,true);
});
for(const [name,input] of [
  ['null',null],['array',[]],['empty',{}],['no rows',{messages:[]}],['oversized batch',{messages:Array(51).fill(envelope())}],
  ['nonarray messages',{messages:{}}],['unknown action',{action:'approve'}],['missing sender',envelope({sender:null})],
  ['long sender',envelope({sender:'x'.repeat(101)})],['NUL sender',envelope({sender:'M\0TN'})],['long SMS',envelope({body:'x'.repeat(10001)})],
  ['NUL SMS',envelope({body:'a\0b'})],['invalid hash',envelope({message_hash:'bad'})],['uppercase hash',envelope({message_hash:'A'.repeat(64)})],
  ['numeric string timestamp',envelope({received_at_millis:String(stamp)})],['future timestamp',envelope({received_at_millis:Date.now()+600000})],
  ['zero timestamp',envelope({received_at_millis:0})],['NaN timestamp',envelope({received_at_millis:NaN})],
  ['timezone-free timestamp',envelope({received_at_millis:null,received_at:'2026-09-01T00:00:00'})],
])test(`batch normalization rejects ${name}`,()=>assert.throws(()=>normalizeIntakeBatch(input)));
test('ISO offset and milliseconds normalize to the same UTC receipt',()=>{
  const a=normalizeIntakeBatch(envelope({received_at_millis:null,received_at:'2026-09-01T02:00:00+02:00'}))[0];
  assert.equal(a.received_at,'2026-09-01T00:00:00.000Z');
});
test('hash conflict within one batch is rejected before database work',()=>assert.throws(()=>normalizeIntakeBatch({messages:[envelope(),envelope({body:'other'})]}),e=>e.status===409));
test('acknowledgement whitelists fields and does not forward arbitrary database payload',()=>{
  const messages=normalizeIntakeBatch(envelope());const row={message_hash:'a'.repeat(64),status:'accepted',admission_id:id,admission_status:'queued',review_required:false,raw_sms:'not for return'};
  assert.equal(Object.hasOwn(validateAdmissionResponse({version:'momobio-intake-v1',results:[row]},messages)[0],'raw_sms'),false);
});

const token='w'.repeat(64);
const makeJob=(override={})=>({id:crypto.randomUUID(),lease_token:crypto.randomUUID(),collector_id:id,raw_sms:raw,sender:'MTN',received_at:new Date(stamp).toISOString(),attempt_count:1,policy,...override});
function worker(options={}){
  const calls=[],parses=[];const job=makeJob(options.job);
  const admin={rpc:async(name,args)=>{
    calls.push({name,args});
    if(name==='rpc_claim_momobio_sms_intake')return {data:options.idle?null:job,error:options.claimError?{message:'private DB detail'}:null};
    if(name==='rpc_complete_momobio_sms_intake')return {data:options.complete??{status:'processed'},error:options.completeError?{message:'unknown commit'}:null};
    if(name==='rpc_retry_momobio_sms_intake')return {data:options.retry??{status:'retry'},error:options.retryError?{message:'unavailable'}:null};
    assert.fail('Unexpected RPC');
  }};
  const env=k=>({'MOMO_SMS_WORKER_TOKEN':token,'MOMO_AUTO_ALLOCATION_ENABLED':'true','MOMO_RECEIPT_ALLOWED_SENDERS':'MTN','MOMO_RECEIVING_MERCHANT_CODES':'12345',...options.env})[k];
  return {calls,parses,job,deps:{admin,env,parse:async(...args)=>{parses.push(args);if(options.parseError)throw options.parseError;return options.parsed??parsed;}}};
}
const workerRequest=(authorization=`Bearer ${token}`,headers={})=>new Request('https://fixture.invalid/momobio-sms-process',{method:'POST',headers:{...(authorization?{authorization}:{}),...headers},body:'{"collector_id":"attacker-chosen"}'});
test('worker binds completion to a claimed job, not request body identity',async()=>{
  const f=worker();const r=await handleMomoBioSmsProcess(workerRequest(),f.deps);assert.equal(r.status,200);assert.equal(f.parses.length,1);
  const args=f.calls[1].args;assert.equal(args.p_id,f.job.id);assert.equal(args.p_lease_token,f.job.lease_token);assert.equal(args.p_parsed.verified_collector_id,id);
  assert.equal(args.p_parsed.allocation_eligible,true);assert.deepEqual(args.p_review_reasons,[]);assert.equal(f.calls[1].name,'rpc_complete_momobio_sms_intake');
});
for(const auth of [null,'Bearer short',`Bearer ${'b'.repeat(64)}`,`Basic ${token}`])test(`worker rejects missing/wrong credential ${auth?.slice(0,12)??'missing'}`,async()=>{
  const f=worker();assert.equal((await handleMomoBioSmsProcess(workerRequest(auth),f.deps)).status,401);assert.equal(f.calls.length,0);
});
test('worker fails closed when secret is absent',async()=>{const f=worker({env:{MOMO_SMS_WORKER_TOKEN:undefined}});assert.equal((await handleMomoBioSmsProcess(workerRequest(),f.deps)).status,503);assert.equal(f.calls.length,0);});
test('browser-origin worker request is forbidden even with token',async()=>{const f=worker();assert.equal((await handleMomoBioSmsProcess(workerRequest(undefined,{origin:'https://fixture.invalid'}),f.deps)).status,403);assert.equal(f.calls.length,0);});
test('worker rejects GET',async()=>{const f=worker();assert.equal((await handleMomoBioSmsProcess(new Request('https://fixture.invalid'),f.deps)).status,405);});
test('environment kill switch avoids claim and AI',async()=>{const f=worker({env:{MOMO_AUTO_ALLOCATION_ENABLED:'false'}});const r=await handleMomoBioSmsProcess(workerRequest(),f.deps);assert.equal((await r.json()).outcome,'disabled');assert.equal(f.calls.length,0);});
test('empty or globally limited queue does not invoke parser',async()=>{const f=worker({idle:true});const r=await handleMomoBioSmsProcess(workerRequest(),f.deps);assert.equal((await r.json()).outcome,'idle_or_limited');assert.equal(f.parses.length,0);});
test('claim failure cannot invoke parser',async()=>{const f=worker({claimError:true});assert.equal((await handleMomoBioSmsProcess(workerRequest(),f.deps)).status,503);assert.equal(f.parses.length,0);});
for(const [name,job] of [['wrong ID',{id:'bad'}],['missing lease',{lease_token:null}],['wrong sender',{sender:'OTHER'}],['disabled policy',{policy:{...policy,enabled:false}}],['bad confidence',{policy:{...policy,minConfidence:0.5}}]])test(`malformed claimed job ${name} is not parsed`,async()=>{
  const f=worker({job});assert.equal((await handleMomoBioSmsProcess(workerRequest(),f.deps)).status,503);assert.equal(f.parses.length,0);
});
test('nonpayment classification completes review with no allocation eligibility',async()=>{
  const f=worker({parsed:{...parsed,is_momo_payment:false},complete:{status:'review'}});const r=await handleMomoBioSmsProcess(workerRequest(),f.deps);assert.equal((await r.json()).outcome,'review');assert.deepEqual(f.calls[1].args.p_parsed,{});assert.ok(f.calls[1].args.p_review_reasons.includes('not_classified_as_payment'));
});
test('model-selected collector cannot replace the admitted collector',()=>{
  const job=makeJob();assert.equal(completionPayload(job,{...parsed,verified_collector_id:crypto.randomUUID()}).p_parsed.verified_collector_id,id);
});
for(const [message,code] of [['OPENAI_API_KEY_REQUIRED','parser_configuration_missing'],['OPENAI_PARSE_FAILED_429','parser_rate_limited'],['OPENAI_PARSE_FAILED_503','parser_unavailable'],['OPENAI_PARSE_FAILED_400','parser_request_rejected'],['TIMEOUT','parser_timeout'],['ABORTED','parser_timeout'],['private SMS +250123456789','parser_failed']]){
  test(`parser failure persists sanitized code ${code}: ${message.slice(0,12)}`,async()=>{
    const f=worker({parseError:new Error(message)});const r=await handleMomoBioSmsProcess(workerRequest(),f.deps);assert.equal((await r.json()).outcome,'retry');assert.equal(f.calls[1].name,'rpc_retry_momobio_sms_intake');assert.equal(f.calls[1].args.p_error_code,code);assert.equal(f.calls.length,2);
  });
}
test('unknown completion commit outcome is not retried in the same invocation',async()=>{
  const f=worker({completeError:true});const r=await handleMomoBioSmsProcess(workerRequest(),f.deps);assert.equal(r.status,503);assert.equal(f.calls.length,2);assert.equal(f.calls.filter(x=>x.name.includes('retry')).length,0);
});
test('stale lease completion is returned without attempting another write',async()=>{const f=worker({complete:{status:'stale'}});const r=await handleMomoBioSmsProcess(workerRequest(),f.deps);assert.equal((await r.json()).outcome,'stale');assert.equal(f.calls.length,2);});
test('failure to persist retry is an explicit service error',async()=>{const f=worker({parseError:new Error('TIMEOUT'),retryError:true});assert.equal((await handleMomoBioSmsProcess(workerRequest(),f.deps)).status,503);});
test('unknown completion status is never promoted to success',async()=>{const f=worker({complete:{status:'unknown'}});assert.equal((await handleMomoBioSmsProcess(workerRequest(),f.deps)).status,503);});
test('terminal provider failure can be moved to review by SQL',async()=>{const f=worker({parseError:new Error('OPENAI_API_KEY_REQUIRED'),retry:{status:'review'}});const r=await handleMomoBioSmsProcess(workerRequest(),f.deps);assert.equal((await r.json()).outcome,'review');});
test('provider error object never becomes a raw stored exception',()=>assert.equal(workerFailureCode({message:'private receipt'}),'parser_failed'));
test('known collector denial maps to forbidden without raw SQL text',()=>{const e=databaseIntakeError({message:'COLLECTOR_DENIED internal details'});assert.equal(e.status,403);assert.equal(e.message.includes('internal'),false);});

for (const [key,value] of [['MOMO_RECEIPT_ALLOWED_SENDERS','OTHER'],['MOMO_RECEIVING_MERCHANT_CODES','99999']]) {
  test(`worker intersects database policy with ${key} before model disclosure`,async()=>{
    const f=worker({env:{[key]:value},complete:{status:'review'}});
    const response=await handleMomoBioSmsProcess(workerRequest(),f.deps);
    assert.equal((await response.json()).outcome,'review');assert.equal(f.parses.length,0);
    assert.deepEqual(f.calls[1].args.p_review_reasons,['edge_policy_not_approved']);assert.deepEqual(f.calls[1].args.p_parsed,{});
  });
}
test('worker missing global merchant list does not claim or parse',async()=>{
  const f=worker({env:{MOMO_RECEIVING_MERCHANT_CODES:''}});const r=await handleMomoBioSmsProcess(workerRequest(),f.deps);
  assert.equal((await r.json()).outcome,'disabled');assert.equal(f.calls.length,0);
});
