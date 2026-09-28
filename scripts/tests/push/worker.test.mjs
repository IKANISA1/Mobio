import test from 'node:test';
import assert from 'node:assert/strict';
import {handlePushWorker,runPushBatch,authorizeWorker,RestPushStore} from '../../../supabase/functions/_shared/push-outbox.ts';
import {handleSendPushRequest} from '../../../supabase/functions/send-push/index.ts';
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const secret='synthetic-worker-test-only-secret-32-chars';
const lease={job_id:id(1),lease_id:id(2)};
const target={allowed:true,job_id:id(1),notification_id:id(3),binding_id:id(4),token:'synthetic-registration-token',platform:'android',ttl_seconds:300};
const accepted={outcome:'accepted',code:'accepted',retryAfter:0};
function fixture(overrides={}){
 const calls={claim:0,authorize:0,send:0,finish:0};
 const store={claim:async()=>{calls.claim++;return [lease];},authorize:async()=>{calls.authorize++;return target;},finish:async()=>{calls.finish++;return {applied:true,state:'accepted',outcome:'accepted'};},...overrides};
 return {calls,runtime:{store,provider:{send:async()=>{calls.send++;return accepted;}}}};
}
const request=(body={},auth=`Bearer ${secret}`,headers={})=>new Request('https://example.invalid/push-outbox-worker',{method:'POST',headers:{authorization:auth,'content-type':'application/json',...headers},body:JSON.stringify(body)});
for(const header of [null,'Bearer short','Basic '+secret,'Bearer '+secret+'x']) {
 test(`unauthorized worker header ${header?.slice(0,12)}`,async()=>assert.equal(await authorizeWorker(header,secret),false));
}
test('valid dedicated worker secret accepted',async()=>assert.equal(await authorizeWorker(`Bearer ${secret}`,secret),true));
test('unauthorized request cannot initialize dependencies or read privileged data',async()=>{
 let called=false;const result=await handlePushWorker(request({},'Bearer wrong'),secret,()=>{called=true;throw new Error();});
 assert.equal(result.status,401);assert.equal(called,false);
});
test('missing config and wrong method have explicit non-pass status',async()=>{
 assert.equal((await handlePushWorker(request(),undefined,()=>{throw new Error();})).status,503);
 assert.equal((await handlePushWorker(new Request('https://example.invalid/'),secret,()=>{throw new Error();})).status,405);
});
for(const body of [{limit:0},{limit:11},{limit:1.1},{limit:'3'},{notification_id:id(1)},{user_id:id(1)},[],null,{'payload':'x'.repeat(2048)}]) {
 test(`reject invalid worker body ${JSON.stringify(body).slice(0,45)}`,async()=>{
  let called=false;const res=await handlePushWorker(request(body),secret,()=>{called=true;throw new Error();});
  assert.equal(res.status,400);assert.equal(called,false);
 });
}
test('worker accepts only JSON media type',async()=>{
 assert.equal((await handlePushWorker(request({},`Bearer ${secret}`,{'content-type':'text/plain'}),secret,()=>{throw new Error();})).status,400);
});
test('successful batch records provider acceptance after durable acknowledgement',async()=>{
 const f=fixture();const res=await handlePushWorker(request(),secret,()=>f.runtime);
 assert.equal(res.status,200);const json=await res.json();assert.equal(json.accepted,1);assert.equal(json.unacknowledged,0);
 assert.deepEqual(f.calls,{claim:1,authorize:1,send:1,finish:1});assert.ok(!JSON.stringify(json).includes(id(1)));
});
test('paused or revoked authorization never calls the provider',async()=>{
 const f=fixture({authorize:async()=>({allowed:false,reason:'consent_revoked'})});
 const result=await runPushBatch(f.runtime,10);assert.equal(result.skipped,1);assert.equal(f.calls.send,0);
});
for(const bad of [[lease,lease],[{job_id:'bad',lease_id:id(2)}],{},null]) {
 test(`invalid claim response ${JSON.stringify(bad).slice(0,45)}`,async()=>{
  const f=fixture({claim:async()=>bad});await assert.rejects(runPushBatch(f.runtime,10),/INVALID_CLAIM_RESPONSE/);assert.equal(f.calls.send,0);
 });
}
test('claim larger than requested is rejected as protocol violation',async()=>{
 const f=fixture({claim:async()=>[lease,{job_id:id(6),lease_id:id(7)}]});
 await assert.rejects(runPushBatch(f.runtime,1));assert.equal(f.calls.send,0);
});
test('mismatched authorization job cannot dispatch',async()=>{
 const f=fixture({authorize:async()=>({...target,job_id:id(999)})});
 assert.equal((await runPushBatch(f.runtime,10)).unacknowledged,1);assert.equal(f.calls.send,0);
});
test('acknowledgement loss retries acknowledgement, never provider send',async()=>{
 let finish=0;const f=fixture({finish:async()=>{finish++;if(finish===1)throw new Error('lost response');return {applied:true,state:'accepted',outcome:'accepted'};}});
 const res=await runPushBatch(f.runtime,10);assert.equal(res.accepted,1);assert.equal(f.calls.send,1);assert.equal(finish,2);
});
test('stale lease acknowledgement cannot be counted as accepted',async()=>{
 const f=fixture({finish:async()=>({applied:false})});
 const res=await handlePushWorker(request(),secret,()=>f.runtime);assert.equal(res.status,503);
 const json=await res.json();assert.equal(json.accepted,0);assert.equal(json.unacknowledged,1);
});
test('database error yields sanitized unavailable response',async()=>{
 const f=fixture({claim:async()=>{throw new Error('secret token PRIVATE');}});
 const res=await handlePushWorker(request(),secret,()=>f.runtime);assert.equal(res.status,503);assert.ok(!(await res.text()).includes('PRIVATE'));
});
test('batch deadline defers unstarted work without contacting FCM',async()=>{
 let outcome;const f=fixture({finish:async(_,o)=>{outcome=o;return {applied:true,state:'queued',outcome:'retry'};}});
 const counts=await runPushBatch(f.runtime,10,10);
 assert.equal(counts.retry,1);assert.equal(outcome.code,'worker_deadline');assert.equal(f.calls.send,0);
});
test('concurrency is bounded to three providers per worker',async()=>{
 let active=0,max=0;
 const jobs=Array.from({length:10},(_,i)=>({job_id:id(i+20),lease_id:id(i+40)}));
 const f=fixture({claim:async()=>jobs,authorize:async l=>({...target,job_id:l.job_id})});
 f.runtime.provider.send=async()=>{active++;max=Math.max(max,active);await new Promise(r=>setTimeout(r,5));active--;return accepted;};
 assert.equal((await runPushBatch(f.runtime,10)).accepted,10);assert.equal(max,3);
});
test('REST adapter bounds RPC names and uses captured server credentials',async()=>{
 const requests=[];const store=new RestPushStore('https://example.supabase.co','synthetic-legacy-key',async(url,init)=>{
  requests.push({url,init});return new Response(JSON.stringify(url.endsWith('claim')?[]:{applied:true}));
 });
 await store.claim(4);await store.finish(lease,accepted);
 assert.equal(requests[0].url,'https://example.supabase.co/rest/v1/rpc/rpc_push_claim');
 assert.equal(requests[0].init.headers.authorization,'Bearer synthetic-legacy-key');
 assert.equal(requests[0].init.redirect,'error');
 assert.deepEqual(JSON.parse(requests[1].init.body),{p_job_id:id(1),p_lease_id:id(2),p_outcome:'accepted',p_code:'accepted',p_retry_after:0});
});
test('new secret API key is not falsely sent as a JWT',async()=>{
 let headers;const store=new RestPushStore('https://example.supabase.co','sb_secret_synthetic',async(_,i)=>{headers=i.headers;return new Response('[]');});
 await store.claim(1);assert.equal(headers.apikey,'sb_secret_synthetic');assert.equal(headers.authorization,undefined);
});
test('REST adapter rejects credential-bearing or insecure endpoints',()=>{
 for(const url of ['http://example.com','https://user:pass@example.com','https://example.com/?next=x','https://example.com/path','https://example.com/#x']){
  assert.throws(()=>new RestPushStore(url,'key'));
 }
});
test('legacy dispatcher stays retired without database or provider dependencies',async()=>{
 for(const method of ['GET','POST','OPTIONS']) {
  assert.equal(handleSendPushRequest(new Request('https://example.invalid/send-push',{method})).status,410);
 }
});

test('different terminal state cannot masquerade as accepted acknowledgement',async()=>{
 const f=fixture({finish:async()=>({applied:true,state:'expired',outcome:'accepted'})});
 const result=await runPushBatch(f.runtime,10);assert.equal(result.accepted,0);assert.equal(result.unacknowledged,1);
});
test('different recorded outcome cannot masquerade as current acknowledgement',async()=>{
 const f=fixture({finish:async()=>({applied:true,state:'accepted',outcome:'retry'})});
 const result=await runPushBatch(f.runtime,10);assert.equal(result.accepted,0);assert.equal(result.unacknowledged,1);
});
