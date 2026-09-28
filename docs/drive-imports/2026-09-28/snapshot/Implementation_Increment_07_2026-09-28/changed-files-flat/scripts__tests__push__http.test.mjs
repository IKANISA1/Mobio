import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {boundedJson} from '../../../supabase/functions/_shared/push-http.ts';
async function serverCase(handler,callback){
 const server=createServer(handler);server.listen(0,'127.0.0.1');await once(server,'listening');
 try{await callback(`http://127.0.0.1:${server.address().port}`);}finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
}
test('real local HTTP JSON response is read',async()=>serverCase((_,res)=>res.end('{"ok":true}'),async url=>{
 const result=await boundedJson(fetch,url,{});assert.deepEqual(result.body,{ok:true});assert.equal(result.status,200);
}));
test('real HTTP oversized streamed body is rejected without content-length trust',async()=>serverCase((_,res)=>{res.writeHead(200,{'transfer-encoding':'chunked'});res.write('x'.repeat(80));res.end('x'.repeat(80));},async url=>{
 await assert.rejects(boundedJson(fetch,url,{}, {maxBytes:100}),/PUSH_TRANSPORT_UNAVAILABLE/);
}));
test('declared oversized response rejected',async()=>{
 await assert.rejects(boundedJson(async()=>new Response('{}',{headers:{'content-length':'99999'}}),'https://fixture.invalid',{}, {maxBytes:100}));
});
test('real HTTP delayed response is aborted within deadline',async()=>serverCase((_,res)=>{const t=setTimeout(()=>res.end('{}'),300);res.on('close',()=>clearTimeout(t));},async url=>{
 const started=performance.now();await assert.rejects(boundedJson(fetch,url,{}, {timeoutMs:30}));assert.ok(performance.now()-started<500);
}));
test('real HTTP redirect cannot leak Authorization to a different endpoint',async()=>serverCase((_,res)=>{res.writeHead(302,{location:'http://127.0.0.1:1/other'});res.end();},async url=>{
 await assert.rejects(boundedJson(fetch,url,{headers:{authorization:'synthetic'}}));
}));
test('cancelled caller does not start a request',async()=>{
 const c=new AbortController();c.abort();let called=false;
 await assert.rejects(boundedJson(async()=>{called=true;return new Response('{}');},'https://fixture.invalid',{}, {signal:c.signal}));assert.equal(called,false);
});
test('malformed provider JSON is represented as null, not logged',async()=>{
 const result=await boundedJson(async()=>new Response('PRIVATE_BAD_JSON'),'https://fixture.invalid',{});
 assert.equal(result.body,null);
});
test('adapters ignoring cancellation are still deadline-bounded',async()=>{
 const start=performance.now();await assert.rejects(boundedJson(async()=>new Promise(()=>{}),'https://fixture.invalid',{}, {timeoutMs:20}));
 assert.ok(performance.now()-start<500);
});
