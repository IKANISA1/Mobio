import { boundedJson, record, uuid } from './push-http.ts';
import type { Fetcher } from './push-http.ts';
export type PushOutcome = {
  outcome: 'accepted' | 'retry' | 'invalid_token' | 'permanent';
  code: 'accepted' | 'unregistered' | 'rate_limited' | 'provider_unavailable' | 'network_unknown' |
    'provider_auth' | 'provider_rejected' | 'invalid_response' | 'oauth_unavailable' | 'worker_deadline';
  retryAfter: number;
};
export type PushTarget = { job_id: string; notification_id: string; binding_id: string;
  token: string; platform: 'android' | 'ios'; ttl_seconds: number };
export type FirebaseConfig = { projectId: string; clientEmail: string; privateKey: string };
const OAUTH = 'https://oauth2.googleapis.com/token';
export function readFirebaseConfig(env: (name: string) => string | undefined): FirebaseConfig {
  try {
    const raw = env('FIREBASE_SERVICE_ACCOUNT_JSON') ?? env('FCM_SERVICE_ACCOUNT_JSON');
    if (raw && raw.length > 20000) throw new Error();
    const parsed: unknown = raw ? JSON.parse(raw) : {
      project_id: env('FIREBASE_PROJECT_ID'), client_email: env('FIREBASE_CLIENT_EMAIL'), private_key: env('FIREBASE_PRIVATE_KEY'),
    };
    if (!record(parsed)) throw new Error();
    const { project_id, client_email, private_key } = parsed;
    if (typeof project_id !== 'string' || !/^[a-z][a-z0-9-]{4,61}[a-z0-9]$/.test(project_id) ||
      typeof client_email !== 'string' || client_email.length>320 || !/^[^\s@]+@[^\s@]+\.gserviceaccount\.com$/.test(client_email) ||
      typeof private_key !== 'string' || private_key.length<100 || private_key.length>12000) throw new Error();
    const key = private_key.replaceAll('\\n','\n').trim();
    if (!key.startsWith('-----BEGIN PRIVATE KEY-----') || !key.endsWith('-----END PRIVATE KEY-----')) throw new Error();
    return { projectId: project_id, clientEmail: client_email, privateKey: key };
  } catch { throw new Error('FIREBASE_CONFIGURATION_INVALID'); }
}
function b64(bytes: Uint8Array): string {
  let binary=''; for (const byte of bytes) binary+=String.fromCharCode(byte);
  return btoa(binary).replaceAll('+','-').replaceAll('/','_').replaceAll('=','');
}
function segment(value: unknown): string { return b64(new TextEncoder().encode(JSON.stringify(value))); }
export function retryAfterSeconds(value: string | null, nowMs: number): number {
  if (!value || value.length>128) return 60;
  const seconds=/^\d+$/.test(value.trim()) ? Number(value) : (Date.parse(value)-nowMs)/1000;
  return Number.isFinite(seconds) ? Math.max(60,Math.min(86400,Math.ceil(seconds))) : 60;
}
export function classifyFcm(status: number, body: unknown, retryAfter: string | null, nowMs: number, projectId: string): PushOutcome {
  if (status>=200 && status<300) {
    const name=record(body) ? body.name : null;
    return typeof name==='string' && name.startsWith(`projects/${projectId}/messages/`) &&
      name.length>`projects/${projectId}/messages/`.length && name.length<1024 && !/\s/.test(name)
      ? {outcome:'accepted',code:'accepted',retryAfter:0}
      : {outcome:'retry',code:'invalid_response',retryAfter:60};
  }
  const error=record(body) && record(body.error) ? body.error : {};
  const unregistered=Array.isArray(error.details) && error.details.some((d: unknown) =>
    record(d) && d['@type']==='type.googleapis.com/google.firebase.fcm.v1.FcmError' && d.errorCode==='UNREGISTERED');
  // A generic 404 or INVALID_ARGUMENT can be a project/payload error, not a bad token.
  if (status===404 && unregistered) return {outcome:'invalid_token',code:'unregistered',retryAfter:0};
  if (status===429) return {outcome:'retry',code:'rate_limited',retryAfter:retryAfterSeconds(retryAfter,nowMs)};
  if (status>=500) return {outcome:'retry',code:'provider_unavailable',retryAfter:retryAfterSeconds(retryAfter,nowMs)};
  if (status===401) return {outcome:'retry',code:'provider_auth',retryAfter:60};
  return {outcome:'permanent',code:status===403?'provider_auth':'provider_rejected',retryAfter:0};
}
export function validateTarget(value: unknown): PushTarget {
  if (!record(value) || !uuid(value.job_id) || !uuid(value.notification_id) || !uuid(value.binding_id) ||
    typeof value.token!=='string' || value.token.length<20 || value.token.length>4096 ||
    !/^[A-Za-z0-9_:.-]+$/.test(value.token) || !['android','ios'].includes(value.platform as string) ||
    !Number.isInteger(value.ttl_seconds) || Number(value.ttl_seconds)<1 || Number(value.ttl_seconds)>86400) {
    throw new Error('PUSH_TARGET_INVALID');
  }
  return value as PushTarget;
}
export function buildPushMessage(target: PushTarget, nowMs: number): Record<string, unknown> {
  validateTarget(target);
  // No sender, message, financial detail, phone, arbitrary route or raw metadata
  // enters an OS-visible payload. Resolve actual content through the authorized inbox.
  return { message: {
    token:target.token,
    notification:{title:'Mobio',body:'You have an update. Open Mobio to view it.'},
    data:{protocol:'mobio.push.v1',notification_id:target.notification_id,binding_id:target.binding_id,route:'/notifications'},
    android:{ttl:`${target.ttl_seconds}s`,notification:{tag:target.notification_id,channel_id:'mobio_default'}},
    apns:{headers:{'apns-collapse-id':target.notification_id,'apns-expiration':String(Math.floor(nowMs/1000)+target.ttl_seconds)},
      payload:{aps:{sound:'default'}}},
  } };
}
export class GooglePushProvider {
  private cached: { token: string; expiresAt: number } | undefined;
  private pending: Promise<string> | undefined;
  private key: Promise<CryptoKey> | undefined;
  private readonly config: FirebaseConfig;
  private readonly fetcher: Fetcher;
  private readonly now: () => number;
  private readonly timeoutMs: number;
  constructor(config: FirebaseConfig, fetcher: Fetcher = fetch,
    now: () => number = Date.now, timeoutMs = 4000) {
    this.config=config; this.fetcher=fetcher; this.now=now; this.timeoutMs=timeoutMs;
  }
  private async accessToken(signal?: AbortSignal): Promise<string> {
    if (this.cached && this.cached.expiresAt>this.now()+60000) return this.cached.token;
    if (this.pending) return this.pending;
    this.pending=this.issueToken(signal);
    try { return await this.pending; } finally { this.pending=undefined; }
  }
  private async issueToken(signal?: AbortSignal): Promise<string> {
    const raw=this.config.privateKey.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,'');
    this.key ??= crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(raw),c=>c.charCodeAt(0)),
      {name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign']);
    const now=Math.floor(this.now()/1000);
    const unsigned=`${segment({alg:'RS256',typ:'JWT'})}.${segment({iss:this.config.clientEmail,
      scope:'https://www.googleapis.com/auth/firebase.messaging',aud:OAUTH,iat:now,exp:now+3600})}`;
    const signature=await crypto.subtle.sign('RSASSA-PKCS1-v1_5',await this.key,new TextEncoder().encode(unsigned));
    const result=await boundedJson(this.fetcher,OAUTH,{method:'POST',headers:{'content-type':'application/x-www-form-urlencoded'},
      body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion:`${unsigned}.${b64(new Uint8Array(signature))}`})},
      {timeoutMs:this.timeoutMs,maxBytes:16384,signal});
    const body=result.body;
    if (result.status!==200 || !record(body) || typeof body.access_token!=='string' ||
      body.access_token.length<20 || body.access_token.length>4096 ||
      !Number.isInteger(body.expires_in) || Number(body.expires_in)<1 || Number(body.expires_in)>3600) {
      throw new Error('OAUTH_UNAVAILABLE');
    }
    this.cached={token:body.access_token,expiresAt:this.now()+Number(body.expires_in)*1000};
    return body.access_token;
  }
  async send(target: PushTarget, signal?: AbortSignal): Promise<PushOutcome> {
    let token: string;
    try { validateTarget(target); token=await this.accessToken(signal); }
    catch { return {outcome:'retry',code:'oauth_unavailable',retryAfter:60}; }
    try {
      const res=await boundedJson(this.fetcher,`https://fcm.googleapis.com/v1/projects/${this.config.projectId}/messages:send`,
        {method:'POST',headers:{authorization:`Bearer ${token}`,'content-type':'application/json'},
          body:JSON.stringify(buildPushMessage(target,this.now()))},
        {timeoutMs:this.timeoutMs,maxBytes:32768,signal});
      if (res.status===401 && this.cached?.token===token) this.cached=undefined;
      return classifyFcm(res.status,res.body,res.headers.get('retry-after'),this.now(),this.config.projectId);
    } catch { return {outcome:'retry',code:'network_unknown',retryAfter:60}; }
  }
}
