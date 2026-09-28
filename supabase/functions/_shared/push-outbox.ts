import { boundedJson, record, responseJson, uuid } from './push-http.ts';
import type { Fetcher } from './push-http.ts';
import { validateTarget } from './push-provider.ts';
import type { PushTarget, PushOutcome } from './push-provider.ts';
export type Lease = { job_id: string; lease_id: string };
export interface PushStore {
  claim(limit: number, signal?: AbortSignal): Promise<unknown>;
  authorize(lease: Lease, signal?: AbortSignal): Promise<unknown>;
  finish(lease: Lease, outcome: PushOutcome, signal?: AbortSignal): Promise<unknown>;
}
export interface PushProvider { send(target: PushTarget, signal?: AbortSignal): Promise<PushOutcome>; }
export type PushRuntime = { store: PushStore; provider: PushProvider };
export class RestPushStore implements PushStore {
  private readonly base: string;
  private readonly key: string;
  private readonly fetcher: Fetcher;
  private readonly timeoutMs: number;
  constructor(url: string, key: string, fetcher: Fetcher=fetch, timeoutMs=3000) {
    this.key=key; this.fetcher=fetcher; this.timeoutMs=timeoutMs;
    const parsed=new URL(url);
    if (parsed.protocol!=='https:' || parsed.username || parsed.password || parsed.search || parsed.hash ||
      (parsed.pathname!=='/' && parsed.pathname!=='') || !key || key.length>16384) throw new Error('PUSH_DATABASE_CONFIGURATION_INVALID');
    this.base=parsed.origin;
  }
  private async rpc(name: string, body: unknown, signal?: AbortSignal): Promise<unknown> {
    const headers: Record<string,string>={'content-type':'application/json',apikey:this.key};
    // New secret keys are API keys, not JWTs. Legacy service-role JWTs retain
    // their Authorization header. All operations still enforce database service authority.
    if (!this.key.startsWith('sb_secret_')) headers.authorization=`Bearer ${this.key}`;
    const result=await boundedJson(this.fetcher,`${this.base}/rest/v1/rpc/${name}`,
      {method:'POST',headers,body:JSON.stringify(body)},{timeoutMs:this.timeoutMs,maxBytes:65536,signal});
    if (result.status<200 || result.status>=300 || result.body===null) throw new Error('PUSH_DATABASE_UNAVAILABLE');
    return result.body;
  }
  claim(limit: number, signal?: AbortSignal) { return this.rpc('rpc_push_claim',{p_limit:limit},signal); }
  authorize(l: Lease, signal?: AbortSignal) { return this.rpc('rpc_push_authorize',{p_job_id:l.job_id,p_lease_id:l.lease_id},signal); }
  finish(l: Lease, o: PushOutcome, signal?: AbortSignal) {
    return this.rpc('rpc_push_finish',{p_job_id:l.job_id,p_lease_id:l.lease_id,p_outcome:o.outcome,p_code:o.code,p_retry_after:o.retryAfter},signal);
  }
}
export async function authorizeWorker(header: string | null, expected: string | undefined): Promise<boolean> {
  const token=/^Bearer ([A-Za-z0-9._~-]{32,256})$/.exec(header ?? '')?.[1];
  if (!token || !expected || !/^[A-Za-z0-9._~-]{32,256}$/.test(expected)) return false;
  const [a,b]=await Promise.all([token,expected].map(async v=>new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(v)))));
  let difference=0; for (let i=0;i<a.length;i++) difference|=a[i]^b[i];
  return difference===0;
}
async function readBatchLimit(request: Request): Promise<number> {
  if (!(request.headers.get('content-type') ?? '').toLowerCase().startsWith('application/json')) throw new Error();
  // Use the same bounded streaming reader for callers with absent/false length.
  const result=await boundedJson(async()=>new Response(request.body,{headers:request.headers}),'https://request.invalid/',{},
    {timeoutMs:2000,maxBytes:1024,signal:request.signal});
  const body=result.body;
  if (!record(body) || Object.keys(body).some(k=>k!=='limit')) throw new Error();
  const n=body.limit ?? 10;
  if (!Number.isInteger(n) || Number(n)<1 || Number(n)>10) throw new Error();
  return Number(n);
}
export async function runPushBatch(runtime: PushRuntime, limit: number, budgetMs=20000): Promise<Record<string,number>> {
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),budgetMs);
  const started=performance.now();
  const counts={claimed:0,accepted:0,retry:0,invalid_token:0,permanent:0,skipped:0,unacknowledged:0};
  try {
    const raw=await runtime.store.claim(limit,controller.signal);
    if (!Array.isArray(raw) || raw.length>limit || raw.some(l=>!record(l)||!uuid(l.job_id)||!uuid(l.lease_id)) ||
      new Set(raw.map(l=>l.job_id)).size!==raw.length) throw new Error('INVALID_CLAIM_RESPONSE');
    const leases=raw as Lease[]; counts.claimed=leases.length;
    let next=0;
    const consume=async()=>{
      while (next<leases.length) {
        const lease=leases[next++];
        try {
          let outcome: PushOutcome;
          if (controller.signal.aborted || performance.now()-started>budgetMs-8000) {
            outcome={outcome:'retry',code:'worker_deadline',retryAfter:60};
          } else {
            const auth=await runtime.store.authorize(lease,controller.signal);
            if (!record(auth) || typeof auth.allowed!=='boolean') throw new Error('INVALID_AUTHORIZATION_RESPONSE');
            if (!auth.allowed) { counts.skipped++; continue; }
            const target=validateTarget(auth);
            if (target.job_id!==lease.job_id) throw new Error('WRONG_JOB_AUTHORIZATION');
            outcome=await runtime.provider.send(target,controller.signal);
          }
          // Never retry the provider from here. Only the durable SQL queue decides retry.
          let done: unknown;
          for(let attempt=0;attempt<2;attempt++) {
            try { done=await runtime.store.finish(lease,outcome,controller.signal); break; }
            catch { if(attempt===1) throw new Error('ACKNOWLEDGEMENT_UNAVAILABLE'); }
          }
          if (!record(done) || done.applied!==true || done.outcome!==outcome.outcome ||
            (outcome.outcome==='accepted' && done.state!=='accepted')) { counts.unacknowledged++; continue; }
          counts[outcome.outcome]++;
        } catch { counts.unacknowledged++; }
      }
    };
    await Promise.all(Array.from({length:Math.min(3,leases.length)},()=>consume()));
    return counts;
  } finally { clearTimeout(timer); controller.abort(); }
}
export async function handlePushWorker(request: Request, secret: string | undefined, factory: ()=>PushRuntime): Promise<Response> {
  if (request.method!=='POST') return responseJson({error:'method_not_allowed'},405);
  if (!secret || !/^[A-Za-z0-9._~-]{32,256}$/.test(secret)) return responseJson({error:'worker_not_configured'},503);
  if (!await authorizeWorker(request.headers.get('authorization'),secret)) return responseJson({error:'unauthorized'},401);
  let limit: number;
  try { limit=await readBatchLimit(request); } catch { return responseJson({error:'invalid_batch_request'},400); }
  try {
    const counts=await runPushBatch(factory(),limit);
    return responseJson({status:counts.unacknowledged?'acknowledgement_incomplete':'batch_finished',...counts},counts.unacknowledged?503:200);
  } catch { return responseJson({error:'push_worker_unavailable'},503); }
}
