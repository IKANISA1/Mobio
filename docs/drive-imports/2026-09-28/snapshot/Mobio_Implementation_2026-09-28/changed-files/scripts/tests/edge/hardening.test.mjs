import test from 'node:test';
import assert from 'node:assert/strict';
import { boundedFetch } from '../../../supabase/functions/_shared/bounded-fetch.ts';
import { parseMomoSmsWithOpenAi } from '../../../supabase/functions/_shared/momo-sms.ts';
import { evaluateReceiptEvidence, receiptEvidencePolicy } from '../../../supabase/functions/_shared/momo-receipt-evidence.ts';
import { validateOtpDeliveryMode, sendWhatsappCloudOtp, whatsappCloudDeliveryErrorMetadata } from '../../../supabase/functions/_shared/whatsapp-cloud.ts';

// Only pure-module tests use this small env interface. This is NOT the Deno runtime.
const environment = new Map();
globalThis.Deno = { env: { get: key => environment.get(key) } };
const url = 'https://fixture.invalid/never-requested';
const responseOf = value => async () => Response.json(value);
const outputOf = value => responseOf({output_text: JSON.stringify(value)});
const parsed = {amount_rwf: 2000, reference_code: '123456-ABCDEFGH', member_id: '123456',
  momo_pay_code:'12345', provider_transaction_ref:'ABC123456', is_momo_payment:true,
  confidence:0.98, parser_source:'openai', parser_version:'fixture', openai_model:'fixture'};
const raw = 'You have received 2,000 RWF from 0780000000. Reference: 123456-ABCDEFGH. Merchant code: 12345. TxId: ABC123456.';
const policy = {enabled:true, allowedSenders:['MTN'], merchantCodes:['12345'], minConfidence:0.95};
const parse = value => parseMomoSmsWithOpenAi(raw, {apiKey:'fixture-not-a-secret', model:'fixture', fetcher:outputOf(value)});

test('bounded fetch preserves success body and status', async () => {
  const result = await boundedFetch(url, {}, {fetcher:async () => new Response('ok',{status:201})});
  assert.equal(result.status,201); assert.equal(await result.text(),'ok');
});
test('bounded fetch includes stalled headers in deadline', async () => {
  await assert.rejects(boundedFetch(url, {}, {fetcher:() => new Promise(()=>{}),timeoutMs:20}), e=>e.code==='TIMEOUT');
});
test('bounded fetch includes stalled body in deadline', async () => {
  const body = new ReadableStream({start(c){c.enqueue(new Uint8Array([1]));}});
  await assert.rejects(boundedFetch(url, {}, {fetcher:async()=>new Response(body), timeoutMs:20}),e=>e.code==='TIMEOUT');
});
test('bounded fetch cancels late response without an unhandled rejection', async () => {
  let canceled=false;
  await assert.rejects(boundedFetch(url, {}, {fetcher:async()=>{
    await new Promise(r=>setTimeout(r,30));
    return new Response(new ReadableStream({cancel(){canceled=true;}}));
  },timeoutMs:10}),e=>e.code==='TIMEOUT');
  await new Promise(r=>setTimeout(r,40)); assert.equal(canceled,true);
});
test('bounded fetch rejects declared oversized body',async()=>{
  await assert.rejects(boundedFetch(url, {}, {fetcher:async()=>new Response('x',{headers:{'content-length':'100'}}),maxResponseBytes:2}),e=>e.code==='RESPONSE_TOO_LARGE');
});
test('bounded fetch rejects actual oversized streamed body',async()=>{
  await assert.rejects(boundedFetch(url, {}, {fetcher:async()=>new Response('abc'),maxResponseBytes:2}),e=>e.code==='RESPONSE_TOO_LARGE');
});
test('bounded fetch preserves no-content response',async()=>{
  assert.equal((await boundedFetch(url,{}, {fetcher:async()=>new Response(null,{status:204})})).status,204);
});
test('bounded fetch removes obsolete compression header',async()=>{
  const r=await boundedFetch(url,{}, {fetcher:async()=>new Response('ok',{headers:{'content-encoding':'gzip'}})});
  assert.equal(r.headers.has('content-encoding'),false); assert.equal(r.headers.get('content-length'),'2');
});
test('bounded fetch rejects already-aborted parent without calling provider',async()=>{
  const a=new AbortController(); a.abort();let calls=0;
  await assert.rejects(boundedFetch(url,{signal:a.signal},{fetcher:async()=>{calls++;return new Response('x');}}),e=>e.code==='ABORTED');assert.equal(calls,0);
});
test('bounded fetch responds to in-flight parent abort',async()=>{
  const a=new AbortController();setTimeout(()=>a.abort(),10);
  await assert.rejects(boundedFetch(url,{signal:a.signal},{fetcher:()=>new Promise(()=>{}),timeoutMs:100}),e=>e.code==='ABORTED');
});
test('bounded fetch sanitizes network errors and never retries',async()=>{
  let calls=0;
  await assert.rejects(boundedFetch(url,{}, {fetcher:async()=>{calls++;throw new Error('private-url-and-password');}}),e=>e.code==='NETWORK_FAILURE' && !String(e).includes('private'));
  assert.equal(calls,1);
});
test('bounded fetch validates requested limits',async()=>{
  for (const limits of [{timeoutMs:0},{timeoutMs:60001},{maxResponseBytes:0},{maxResponseBytes:1.2}])
    await assert.rejects(boundedFetch(url,{},limits),RangeError);
});

test('OTP mode defaults to real delivery',()=>assert.equal(validateOtpDeliveryMode(()=>undefined),false));
for(const env of [undefined,'production','staging','unknown']){
  test(`OTP dry run denied for ${env??'missing'} environment`,()=>{
    assert.throws(()=>validateOtpDeliveryMode(k=>({WHATSAPP_CLOUD_DRY_RUN:'true',MOBIO_ENVIRONMENT:env})[k]),/OTP_DRY_RUN_FORBIDDEN/);
  });
}
test('OTP dry run is denied on deployed Edge even with test label',()=>{
  assert.throws(()=>validateOtpDeliveryMode(k=>({WHATSAPP_CLOUD_DRY_RUN:'true',MOBIO_ENVIRONMENT:'test',DENO_DEPLOYMENT_ID:'fixture-deployment'})[k]),/OTP_DRY_RUN_FORBIDDEN/);
});
test('OTP invalid setting rejected',()=>assert.throws(()=>validateOtpDeliveryMode(()=> 'yes'),/INVALID_OTP_DRY_RUN_SETTING/));
test('OTP fixture logging does not contain phone or OTP',async()=>{
  environment.set('WHATSAPP_CLOUD_DRY_RUN','true');environment.set('MOBIO_ENVIRONMENT','test');
  const logs=[];const original=console.log;console.log=(...x)=>logs.push(x.join(' '));
  try {await sendWhatsappCloudOtp({code:'834021',recipientPhone:'+250780000000'});} finally {console.log=original;environment.clear();}
  assert.equal(logs.length,1);assert.ok(!logs.join().includes('834021'));assert.ok(!logs.join().includes('250780000000'));
});
test('OTP input rejected before delivery',async()=>{
  await assert.rejects(sendWhatsappCloudOtp({code:'123',recipientPhone:'+250780000000'}),/INVALID_OTP_DELIVERY_INPUT/);
});
test('OTP generic errors do not leak arbitrary messages',()=>{
  assert.ok(!JSON.stringify(whatsappCloudDeliveryErrorMetadata(new Error('private OTP 834021'))).includes('834021'));
});
test('OTP provider errors retain codes, not echoed secrets',async()=>{
  Object.entries({WHATSAPP_CLOUD_ACCESS_TOKEN:'fixture',WHATSAPP_CLOUD_PHONE_NUMBER_ID:'fixture',WHATSAPP_CLOUD_OTP_TEMPLATE_NAME:'fixture'}).forEach(([k,v])=>environment.set(k,v));
  const original=globalThis.fetch;
  globalThis.fetch=async()=>Response.json({error:{message:'OTP 834021 phone 250780000000',code:132000}},{status:400});
  try {await assert.rejects(sendWhatsappCloudOtp({code:'834021',recipientPhone:'+250780000000'}),error=>{
    const m=whatsappCloudDeliveryErrorMetadata(error);assert.equal(m.error_code,132000);assert.ok(!JSON.stringify(m).includes('834021'));return true;
  });} finally {globalThis.fetch=original;environment.clear();}
});

test('parser preserves positive exact invoice facts',async()=>{
  const r=await parse(parsed);assert.equal(r.amount_rwf,2000);assert.equal(r.reference_code,parsed.reference_code);assert.equal(r.member_id,'123456');
});
for(const amount of [-2000,0,2.5,'2,000',Number.MAX_SAFE_INTEGER+1])
  test(`parser does not reinterpret invalid amount ${amount}`,async()=>assert.equal((await parse({...parsed,amount_rwf:amount})).amount_rwf,undefined));
test('parser never pads or truncates identifiers',async()=>{
  const r=await parse({...parsed,reference_code:'3456-ABCDEFGH',member_id:'ABC123456789'});assert.equal(r.reference_code,undefined);assert.equal(r.member_id,undefined);
});
test('parser rejects malformed structured output',async()=>{
  for(const value of [null,[],false,'text']) await assert.rejects(parse(value),/INVALID_SMS_PARSE_OUTPUT/);
});
test('parser rejects empty or oversized SMS before API',async()=>{
  for(const text of ['', 'x'.repeat(10001)])await assert.rejects(parseMomoSmsWithOpenAi(text,{apiKey:'fixture'}),/INVALID_SMS_BODY/);
});
test('parser errors do not contain provider response',async()=>{
  await assert.rejects(parseMomoSmsWithOpenAi(raw,{apiKey:'fixture',fetcher:async()=>new Response('private full SMS',{status:401})}),e=>e.message==='OPENAI_PARSE_FAILED_401');
});
test('nonpayment classification remains nonpayment and cannot allocate',async()=>{
  const r=await parse({...parsed,is_momo_payment:false,confidence:0});assert.equal(r.is_momo_payment,false);
  assert.equal(evaluateReceiptEvidence(raw,'MTN',r,policy).eligible,false);
});
test('receipt policy is disabled by default',()=>assert.equal(receiptEvidencePolicy(()=>undefined).enabled,false));
test('only fully supported fixture with explicit policy is eligible',()=>assert.equal(evaluateReceiptEvidence(raw,'MTN',parsed,policy).eligible,true));
for(const [name,changed] of Object.entries({nonpayment:{is_momo_payment:false},lowConfidence:{confidence:0},nanConfidence:{confidence:NaN},missingInvoice:{reference_code:undefined},missingProvider:{provider_transaction_ref:undefined},wrongMerchant:{momo_pay_code:'99999'},missingMerchant:{momo_pay_code:undefined},negative:{amount_rwf:-2000},wrongAmount:{amount_rwf:3000}}))
  test(`receipt allocation denies ${name}`,()=>assert.equal(evaluateReceiptEvidence(raw,'MTN',{...parsed,...changed},policy).eligible,false));
for(const [name,sms] of Object.entries({USD:raw.replace('RWF','USD'),debit:raw.replace('You have received','You have sent'),missingRawMerchant:raw.replace('Merchant code: 12345.',''),missingRawInvoice:raw.replace('Reference: 123456-ABCDEFGH.',''),duplicateRawInvoice:raw+' Reference: 123456-ABCDEFGH',wrongRawProvider:raw.replace('ABC123456','ABC654321'),suffixOnly:'Payment 2000 RWF from 000'}))
  test(`receipt allocation denies ${name}`,()=>assert.equal(evaluateReceiptEvidence(sms,'MTN',parsed,policy).eligible,false));
test('receipt allocation denies unapproved sender or unconfigured merchant',()=>{
  assert.equal(evaluateReceiptEvidence(raw,'Unrelated',parsed,policy).eligible,false);
  assert.equal(evaluateReceiptEvidence(raw,'MTN',parsed,{...policy,merchantCodes:[]}).eligible,false);
});
test('receipt allocation cannot lower engineering minimum confidence',()=>{
  assert.equal(evaluateReceiptEvidence(raw,'MTN',parsed,{...policy,minConfidence:0}).eligible,false);
});

const {resolveVerifiedPhoneUser, canonicalVerifiedPhone}=await import('../../../supabase/functions/_shared/verified-phone-identity.ts');
const owner='11111111-1111-4111-8111-111111111111';
const authUser={id:owner,phone:'250780000000',phone_confirmed_at:'2026-09-01T00:00:00Z',is_anonymous:false,app_metadata:{role:'passenger'}};
const directory = user => ({lookupOwner:async()=>owner,getUser:async()=>user});
test('identity resolves confirmed Auth owner, not profile alias',async()=>{
  const result=await resolveVerifiedPhoneUser(directory(authUser),'+250780000000');assert.equal(result.id,owner);
});
test('no verified owner permits explicit provisioning path',async()=>{
  assert.equal(await resolveVerifiedPhoneUser({lookupOwner:async()=>null,getUser:async()=>{throw new Error('must not call');}},'+250780000000'),null);
});
test('identity lookup error cannot become new-user provisioning',async()=>{
  await assert.rejects(resolveVerifiedPhoneUser({lookupOwner:async()=>{throw new Error('unavailable');},getUser:async()=>authUser},'+250780000000'),/unavailable/);
});
test('identity load error cannot become new-user provisioning',async()=>{
  await assert.rejects(resolveVerifiedPhoneUser({lookupOwner:async()=>owner,getUser:async()=>{throw new Error('unavailable');}},'+250780000000'),/unavailable/);
});
for (const [name,patch] of Object.entries({wrongOwner:{id:'22222222-2222-4222-8222-222222222222'},wrongPhone:{phone:'250790000000'},unconfirmed:{phone_confirmed_at:undefined},invalidConfirmation:{phone_confirmed_at:'not-a-date'},anonymous:{is_anonymous:true},admin:{app_metadata:{role:'admin'}}})) {
  test(`identity rejects ${name}`,async()=>{await assert.rejects(resolveVerifiedPhoneUser(directory({...authUser,...patch}),'+250780000000'));});
}
test('identity rejects malformed directory result',async()=>{
  await assert.rejects(resolveVerifiedPhoneUser({lookupOwner:async()=>'not-uuid',getUser:async()=>authUser},'+250780000000'),/INVALID_PHONE_DIRECTORY_RESULT/);
});
test('phone canonicalization never guesses missing country code',()=>{
  assert.equal(canonicalVerifiedPhone('250780000000'),'+250780000000');
  for(const input of ['0780000000','+250 780000000','++250780000000','invalid'])assert.throws(()=>canonicalVerifiedPhone(input));
});
