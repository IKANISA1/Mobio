import test from 'node:test';
import assert from 'node:assert/strict';
import {GooglePushProvider,readFirebaseConfig,classifyFcm,retryAfterSeconds,buildPushMessage,validateTarget} from '../../../supabase/functions/_shared/push-provider.ts';
const id=n=>`00000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const target={job_id:id(1),notification_id:id(2),binding_id:id(3),token:'synthetic-registration-token-only',platform:'android',ttl_seconds:3600};
const ok={name:'projects/mobio-fixture/messages/synthetic:receipt'};
const unregistered={error:{details:[{'@type':'type.googleapis.com/google.firebase.fcm.v1.FcmError',errorCode:'UNREGISTERED'}]}};
const keyPair=await crypto.subtle.generateKey({name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
const pem='-----BEGIN PRIVATE KEY-----\n'+Buffer.from(await crypto.subtle.exportKey('pkcs8',keyPair.privateKey)).toString('base64')+'\n-----END PRIVATE KEY-----';
const config={projectId:'mobio-fixture',clientEmail:'fixture@mobio-fixture.iam.gserviceaccount.com',privateKey:pem};
const response=(body,status=200,headers={})=>new Response(JSON.stringify(body),{status,headers});
test('construct generic envelope with stable collapse identifiers and TTL',()=>{
 const payload=buildPushMessage({...target,title:'PRIVATE',body:'PRIVATE',metadata:{phone:'PRIVATE'}},0);
 assert.equal(payload.message.notification.title,'Mobio');
 assert.equal(payload.message.data.binding_id,id(3));
 assert.equal(payload.message.data.route,'/notifications');
 assert.equal(payload.message.android.notification.tag,id(2));
 assert.equal(payload.message.android.ttl,'3600s');
 assert.equal(payload.message.apns.headers['apns-collapse-id'],id(2));
 assert.equal(payload.message.apns.headers['apns-expiration'],'3600');
 assert.ok(!JSON.stringify(payload).includes('PRIVATE'));
});
for(const [label,patch] of [['foreign job',{job_id:'invalid'}],['missing binding',{binding_id:null}],['oversized token',{token:'a'.repeat(4097)}],['unsupported platform',{platform:'web'}],['zero TTL',{ttl_seconds:0}],['fractional TTL',{ttl_seconds:1.5}],['whitespace token',{token:'synthetic token with spaces'}]]) {
 test(`target validation rejects ${label}`,()=>assert.throws(()=>validateTarget({...target,...patch}),/PUSH_TARGET_INVALID/));
}
for(const [status,body,outcome,code] of [
 [200,ok,'accepted','accepted'],[200,{},'retry','invalid_response'],[200,{name:'projects/wrong/messages/x'},'retry','invalid_response'],
 [404,unregistered,'invalid_token','unregistered'],[404,{error:{status:'NOT_FOUND'}},'permanent','provider_rejected'],
 [400,{error:{status:'INVALID_ARGUMENT',message:'registration token'}},'permanent','provider_rejected'],
 [401,{},'retry','provider_auth'],[403,{},'permanent','provider_auth'],[429,{},'retry','rate_limited'],[503,{},'retry','provider_unavailable'],
])test(`FCM ${status} ${code} ${JSON.stringify(body).slice(0,25)}`,()=>{
 const result=classifyFcm(status,body,'120',0,config.projectId);
 assert.equal(result.outcome,outcome);assert.equal(result.code,code);
});
test('Retry-After respects delta, HTTP date, minimum and bounded long deferral',()=>{
 assert.equal(retryAfterSeconds('300',0),300);
 assert.equal(retryAfterSeconds('Thu, 01 Jan 1970 00:05:00 GMT',0),300);
 assert.equal(retryAfterSeconds('0',0),60);assert.equal(retryAfterSeconds('not a date',0),60);
 assert.equal(retryAfterSeconds('999999999999',0),86400);
});
test('structured UNREGISTERED must have the correct detail type',()=>{
 assert.equal(classifyFcm(404,{error:{details:[{errorCode:'UNREGISTERED'}]}},null,0,config.projectId).outcome,'permanent');
});
test('configuration accepts existing service account env and rejects unsafe identifiers',()=>{
 const env=n=>n==='FIREBASE_SERVICE_ACCOUNT_JSON'?JSON.stringify({project_id:config.projectId,client_email:config.clientEmail,private_key:pem}):undefined;
 assert.deepEqual(readFirebaseConfig(env),config);
 assert.throws(()=>readFirebaseConfig(()=>undefined),/CONFIGURATION_INVALID/);
 assert.throws(()=>readFirebaseConfig(n=>n==='FIREBASE_SERVICE_ACCOUNT_JSON'?'bad-sensitive-secret':undefined),/CONFIGURATION_INVALID/);
 assert.throws(()=>readFirebaseConfig(n=>n==='FIREBASE_SERVICE_ACCOUNT_JSON'?JSON.stringify({project_id:'../../other',client_email:config.clientEmail,private_key:pem}):undefined),/CONFIGURATION_INVALID/);
});
test('real RSA JWT signing and single-flight OAuth cache serve concurrent jobs',async()=>{
 let oauth=0,sends=0;
 const provider=new GooglePushProvider(config,async(url,init)=>{
  if(url==='https://oauth2.googleapis.com/token'){
   oauth++;
   const assertion=new URLSearchParams(init.body).get('assertion');const [header,claims,signature]=assertion.split('.');
   assert.equal(JSON.parse(Buffer.from(header,'base64url')).alg,'RS256');
   const payload=JSON.parse(Buffer.from(claims,'base64url'));
   assert.equal(payload.iss,config.clientEmail);assert.equal(payload.aud,url);assert.equal(payload.exp-payload.iat,3600);
   assert.ok(await crypto.subtle.verify('RSASSA-PKCS1-v1_5',keyPair.publicKey,Buffer.from(signature,'base64url'),new TextEncoder().encode(`${header}.${claims}`)));
   return response({access_token:'synthetic-oauth-access-token',expires_in:3600});
  }
  sends++;assert.equal(init.redirect,'error');assert.equal(init.headers.authorization,'Bearer synthetic-oauth-access-token');
  assert.equal(JSON.parse(init.body).message.token,target.token);return response(ok);
 });
 const results=await Promise.all([provider.send(target),provider.send(target),provider.send(target)]);
 assert.equal(oauth,1);assert.equal(sends,3);assert.ok(results.every(x=>x.outcome==='accepted'));
});
test('expired OAuth cache is refreshed rather than used indefinitely',async()=>{
 let now=0,oauth=0;
 const provider=new GooglePushProvider(config,async(url)=>url.includes('oauth2')?(oauth++,response({access_token:'synthetic-oauth-access-token',expires_in:120})):response(ok),()=>now);
 await provider.send(target);now=61000;await provider.send(target);assert.equal(oauth,2);
});
test('provider 401 invalidates only the cached credential and never resends immediately',async()=>{
 let oauth=0,sends=0;
 const provider=new GooglePushProvider(config,async(url)=>{
  if(url.includes('oauth2')){oauth++;return response({access_token:'synthetic-oauth-access-token',expires_in:3600});}
  sends++;return response({},401);
 });
 assert.equal((await provider.send(target)).code,'provider_auth');assert.equal(sends,1);
 await provider.send(target);assert.equal(sends,2);assert.equal(oauth,2);
});
test('OAuth failure never reaches FCM or exposes its raw error',async()=>{
 let calls=0;const provider=new GooglePushProvider(config,async()=>{calls++;return response({error:'PRIVATE_SECRET'},503);});
 const result=await provider.send(target);assert.equal(result.code,'oauth_unavailable');assert.equal(calls,1);assert.ok(!JSON.stringify(result).includes('PRIVATE'));
});
test('network timeout is unknown delivery, not token invalidity',async()=>{
 const provider=new GooglePushProvider(config,async(url)=>url.includes('oauth2')?response({access_token:'synthetic-oauth-access-token',expires_in:3600}):new Promise(()=>{}),Date.now,20);
 const start=performance.now();const result=await provider.send(target);
 assert.equal(result.code,'network_unknown');assert.equal(result.outcome,'retry');assert.ok(performance.now()-start<1000);
});
