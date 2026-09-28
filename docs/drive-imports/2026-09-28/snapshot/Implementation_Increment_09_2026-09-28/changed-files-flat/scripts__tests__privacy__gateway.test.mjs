import test from 'node:test';
import assert from 'node:assert/strict';
import { createPrivacyHandler, validateAction, validateReply, rpcInput } from '../../../supabase/functions/_shared/privacy-request.ts';
const UID='00000000-0000-4000-8000-000000000001';
const RID='00000000-0000-4000-8000-000000000010';
const OTHER='00000000-0000-4000-8000-000000000011';
const AUTH='Bearer synthetic.claims.signature';
const NOW='2026-09-28T12:00:00Z';
const ENV={url:'https://abcdefghijklmnopqrst.supabase.co',publicKey:'sb_publishable_synthetic',allowedOrigins:['https://app.example.test']};
const policy=()=>({protocol:'mobio.privacy.v1',owner_id:UID,enabled:true,notice_version:'notice-v1',reauth_seconds:300,submission_means:'request_received_not_data_deleted'});
const row=()=>({request_id:RID,notice_version:'notice-v1',status:'requested',revision:0,requested_at:NOW,updated_at:NOW,can_cancel:true,retained_categories:[],completion_evidence_recorded:false});
const envelope=()=>({protocol:'mobio.privacy.v1',owner_id:UID,request:row()});
const requestAction={action:'request',request_id:RID,notice_version:'notice-v1',confirmed:true};
function req(body={action:'policy'},options={}){
 const {headers:extra,...rest}=options;
 return new Request('https://edge.example.test/privacy-requests',{method:'POST',headers:{authorization:AUTH,'content-type':'application/json',...extra},body:JSON.stringify(body),...rest});
}
function harness(result=policy(),status=200,extra={}){
 const calls=[]; const h=createPrivacyHandler({environment:()=>ENV,fetcher:async(url,init)=>{
  calls.push({url,init});return new Response(JSON.stringify(result),{status,headers:{'content-type':'application/json'}});
 },...extra});return {h,calls};
}
for(const action of [{action:'policy'},{action:'list'},{action:'status',request_id:RID},{action:'cancel',request_id:RID},requestAction]){
 test('valid action '+action.action,()=>assert.deepEqual(validateAction(action),action));
}
for(const [name,value] of [
 ['null',null],['array',[]],['missing action',{}],['unknown action',{action:'delete_everything'}],
 ['foreign subject',{action:'policy',owner_id:UID}],['table injection',{...requestAction,table:'auth.users'}],
 ['unconfirmed',{...requestAction,confirmed:false}],['string true',{...requestAction,confirmed:'true'}],
 ['bad id',{action:'cancel',request_id:'not-a-uuid'}],['notice too long',{...requestAction,notice_version:'x'.repeat(65)}],
 ['newline notice',{...requestAction,notice_version:'v1\n'}],['newline uuid',{action:'cancel',request_id:RID+'\n'}],
 ['HTML notice',{...requestAction,notice_version:'<script>'}],['extra policy arguments',{action:'policy',request_id:RID}],
 ['missing confirm',{action:'request',request_id:RID,notice_version:'v1'}],
])test('rejects '+name,()=>assert.throws(()=>validateAction(value)));
test('RPC cannot receive a subject supplied by the client',()=>{
 const p=rpcInput(requestAction);assert.deepEqual(Object.keys(p).sort(),['p_action','p_confirmed','p_notice_version','p_request_id']);
 assert.equal(p.p_request_id,RID);
});
test('gateway forwards exact bearer and fixed caller-scoped RPC',async()=>{
 const {h,calls}=harness();const res=await h(req());assert.equal(res.status,200);
 assert.deepEqual(await res.json(),policy());assert.equal(calls.length,1);
 assert.equal(calls[0].url,ENV.url+'/rest/v1/rpc/rpc_privacy_user');
 assert.equal(calls[0].init.headers.authorization,AUTH);assert.equal(calls[0].init.headers.apikey,ENV.publicKey);
 assert.equal(calls[0].init.redirect,'error');assert.equal(res.headers.get('cache-control'),'no-store');
});
test('request success is receipt only, not erasure',async()=>{
 const {h}=harness(envelope());const res=await h(req(requestAction));assert.equal(res.status,200);
 assert.equal((await res.json()).request.completion_evidence_recorded,false);
});
for(const bearer of ['', 'Bearer plain','Bearer a.b','Basic secret','Bearer a.b.c extra'])test('unauthenticated rejected before RPC '+bearer,async()=>{
 const {h,calls}=harness();assert.equal((await h(req(undefined,{headers:{authorization:bearer}}))).status,401);assert.equal(calls.length,0);
});
test('forbidden Origin rejected before RPC',async()=>{const {h,calls}=harness();assert.equal((await h(req(undefined,{headers:{origin:'https://attacker.test'}}))).status,403);assert.equal(calls.length,0);});
test('allowed Origin is echoed exactly',async()=>{const {h}=harness();assert.equal((await h(req(undefined,{headers:{origin:'https://app.example.test'}}))).headers.get('access-control-allow-origin'),'https://app.example.test');});
test('CORS preflight is bounded and does not call database',async()=>{
 const {h,calls}=harness();const res=await h(new Request('https://edge.test/',{method:'OPTIONS',headers:{origin:'https://app.example.test'}}));
 assert.equal(res.status,200);assert.equal(res.headers.get('access-control-allow-methods'),'POST, OPTIONS');assert.equal(calls.length,0);
});
test('GET cannot mutate or enumerate',async()=>{const {h,calls}=harness();assert.equal((await h(new Request('https://edge.test/',{headers:{authorization:AUTH}}))).status,405);assert.equal(calls.length,0);});
test('wrong content type',async()=>{const {h,calls}=harness();assert.equal((await h(req(undefined,{headers:{'content-type':'text/plain'}}))).status,415);assert.equal(calls.length,0);});
test('declared oversized request rejected',async()=>{const {h,calls}=harness();assert.equal((await h(req(undefined,{headers:{'content-length':'99999'}}))).status,413);assert.equal(calls.length,0);});
test('streamed oversized request rejected without content length',async()=>{const {h,calls}=harness();assert.equal((await h(req({action:'policy',extra:'x'.repeat(5000)}))).status,413);assert.equal(calls.length,0);});
test('malformed JSON rejected',async()=>{const {h,calls}=harness();assert.equal((await h(req(undefined,{body:'{'}))).status,400);assert.equal(calls.length,0);});
test('slow body stops waiting and cancels reader',async()=>{
 let cancelled=false;const stream=new ReadableStream({pull:()=>new Promise(()=>{}),cancel(){cancelled=true;}});
 const {h,calls}=harness(undefined,200,{bodyTimeoutMs:10});
 const res=await h(req(undefined,{body:stream,duplex:'half'}));assert.equal(res.status,408);assert.equal(calls.length,0);
 await new Promise(r=>setTimeout(r,1));assert.equal(cancelled,true);
});
for(const [source,code,status] of [
 ['AUTHENTICATION_REQUIRED','AUTHENTICATION_REQUIRED',401],['PRIVACY_REAUTHENTICATION_REQUIRED','REAUTHENTICATION_REQUIRED',403],
 ['PRIVACY_INTAKE_DISABLED','INTAKE_UNAVAILABLE',503],['PRIVACY_POLICY_CHANGED','NOTICE_CHANGED',409],
 ['PRIVACY_ACTIVE_REQUEST_EXISTS','ACTIVE_REQUEST_EXISTS',409],['PRIVACY_REQUEST_CONFLICT','REQUEST_CONFLICT',409],
 ['PRIVACY_NOT_CANCELLABLE','NOT_CANCELLABLE',409],['PRIVACY_REQUEST_NOT_FOUND','REQUEST_NOT_FOUND',404],['PRIVACY_RATE_LIMITED','RATE_LIMITED',429],
])test('maps server code '+source,async()=>{const {h}=harness({message:source,details:'must not be exposed'},400);const res=await h(req(requestAction));assert.equal(res.status,status);assert.deepEqual(await res.json(),{error:code});});
test('unknown database error never leaks table/user/token details',async()=>{
 const {h}=harness({message:'secret auth.users user 123',details:'private'},500);const res=await h(req(requestAction));
 assert.deepEqual(await res.json(),{error:'BACKEND_UNAVAILABLE',outcome:'unknown'});
});
test('network loss after write preserves unknown outcome',async()=>{
 const {h}=harness(null,200,{fetcher:async()=>{throw new Error('private-token');}});
 const res=await h(req(requestAction));assert.equal(res.status,503);assert.equal((await res.json()).outcome,'unknown');
});
test('RPC adapter ignoring AbortSignal is deadline bounded',async()=>{
 const {h}=harness(null,200,{fetcher:()=>new Promise(()=>{}),rpcTimeoutMs:10});const res=await h(req(requestAction));assert.equal(res.status,503);assert.equal((await res.json()).outcome,'unknown');
});
for(const [name,mutate] of [
 ['wrong protocol',v=>v.protocol='other'],['missing owner',v=>delete v.owner_id],['unexpected private field',v=>v.internal_secret='secret'],
 ['fake deletion',v=>v.request.completion_evidence_recorded=true],['negative revision',v=>v.request.revision=-1],
 ['wrong request ID',v=>v.request.request_id=OTHER],['unknown state',v=>v.request.status='fully_erased'],
 ['cancel processing',v=>v.request.status='processing'],['invalid timestamp',v=>v.request.requested_at='yesterday'],
 ['oversized categories',v=>v.request.retained_categories=Array(13).fill('storage')],
])test('reply rejects '+name,async()=>{const value=envelope();mutate(value);const {h}=harness(value);const res=await h(req(requestAction));assert.equal(res.status,503);assert.equal((await res.json()).outcome,'unknown');});
test('blocked after start is not cancellable',()=>{const value=envelope();value.request.status='blocked';value.request.can_cancel=false;assert.doesNotThrow(()=>validateReply(value,requestAction));});
test('empty history is valid',()=>assert.doesNotThrow(()=>validateReply({protocol:'mobio.privacy.v1',owner_id:UID,requests:[]},{action:'list'})));
test('duplicate history rejected',()=>assert.throws(()=>validateReply({protocol:'mobio.privacy.v1',owner_id:UID,requests:[row(),row()]},{action:'list'})));
test('oversized history rejected',()=>assert.throws(()=>validateReply({protocol:'mobio.privacy.v1',owner_id:UID,requests:Array(21).fill(row())},{action:'list'})));
test('disabled intake remains a policy result',()=>{const value=policy();value.enabled=false;value.notice_version=null;assert.doesNotThrow(()=>validateReply(value,{action:'policy'}));});
for(const url of ['http://abcdefghijklmnopqrst.supabase.co','https://attacker.test','https://abcdefghijklmnopqrst.supabase.co/path','https://user:pass@abcdefghijklmnopqrst.supabase.co','https://abcdefghijklmnopqrst.supabase.co?x=y'])test('rejects unsafe project endpoint '+url,async()=>{
 const {h,calls}=harness(null,200,{environment:()=>({...ENV,url})});assert.equal((await h(req())).status,503);assert.equal(calls.length,0);
});
test('response payload limit enforced',async()=>{const {h}=harness({message:'x'.repeat(40000)});assert.equal((await h(req(requestAction))).status,503);});
