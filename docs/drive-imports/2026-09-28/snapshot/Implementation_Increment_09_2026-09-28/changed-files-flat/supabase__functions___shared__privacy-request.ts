/** User-scoped privacy intake gateway. No service-role credentials or erasure here. */
import { boundedJson, record, responseJson, type Fetcher } from './push-http.ts';
export const PRIVACY_PROTOCOL = 'mobio.privacy.v1';
const VERSION = /^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$/;
function uuid(value: unknown): value is string { return typeof value==='string' && value.length===36 && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value); }
function notice(value: string): boolean { return value===value.trim() && VERSION.test(value); }
const TOKEN = /^Bearer [A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/;
const STATES = new Set(['requested','processing','blocked','cancelled','completed','completed_with_retention']);
export type PrivacyAction =
  | { action: 'policy' | 'list' }
  | { action: 'status' | 'cancel'; request_id: string }
  | { action: 'request'; request_id: string; notice_version: string; confirmed: true };
export class PrivacyInputError extends Error {
  readonly code: string; readonly status: number;
  constructor(code = 'INVALID_REQUEST', status = 400) { super(code); this.code=code; this.status=status; }
}
export function validateAction(value: unknown): PrivacyAction {
  if (!record(value) || typeof value.action !== 'string') throw new PrivacyInputError();
  const keys = value.action === 'request' ? ['action','request_id','notice_version','confirmed'] :
    ['status','cancel'].includes(value.action) ? ['action','request_id'] : ['action'];
  if (Object.keys(value).length !== keys.length || Object.keys(value).some(k => !keys.includes(k))) throw new PrivacyInputError();
  if (value.action === 'policy' || value.action === 'list') return { action: value.action };
  if (!uuid(value.request_id)) throw new PrivacyInputError();
  if (value.action === 'status' || value.action === 'cancel') return { action: value.action, request_id: value.request_id.toLowerCase() };
  if (value.action !== 'request' || value.confirmed !== true || typeof value.notice_version !== 'string' || !notice(value.notice_version)) throw new PrivacyInputError();
  return { action: 'request', request_id: value.request_id.toLowerCase(), notice_version: value.notice_version, confirmed: true };
}
export function rpcInput(action: PrivacyAction): Record<string, unknown> {
  return { p_action: action.action, p_request_id: 'request_id' in action ? action.request_id : null,
    p_notice_version: 'notice_version' in action ? action.notice_version : null,
    p_confirmed: 'confirmed' in action && action.confirmed };
}
function timestamp(value: unknown): boolean {
  return typeof value === 'string' && value.length <= 40 && value===value.trim() && /(Z|[+-]\d\d:\d\d)$/.test(value) && Number.isFinite(Date.parse(value));
}
function requestRow(value: unknown): boolean {
  return record(value) && Object.keys(value).sort().join(',') === ['request_id','notice_version','status','revision','requested_at','updated_at','can_cancel','completion_evidence_recorded','retained_categories'].sort().join(',') && uuid(value.request_id) && typeof value.status === 'string' && STATES.has(value.status) &&
    Number.isSafeInteger(value.revision) && (value.revision as number) >= 0 &&
    typeof value.can_cancel === 'boolean' && (!value.can_cancel || value.status === 'requested' || value.status === 'blocked') && (value.status !== 'requested' || value.can_cancel) &&
    timestamp(value.requested_at) && timestamp(value.updated_at) &&
    typeof value.notice_version === 'string' && notice(value.notice_version) &&
    Array.isArray(value.retained_categories) && value.retained_categories.length <= 12 &&
    value.retained_categories.every(x => typeof x === 'string' && /^[a-z_]{1,40}$/.test(x)) &&
    typeof value.completion_evidence_recorded === 'boolean' &&
    value.completion_evidence_recorded === ['completed','completed_with_retention'].includes(value.status);
}
export function validateReply(value: unknown, action: PrivacyAction): asserts value is Record<string, unknown> {
  if (!record(value) || value.protocol !== PRIVACY_PROTOCOL || !uuid(value.owner_id)) throw new Error('INVALID_BACKEND_REPLY');
  const expected = action.action === 'policy' ? ['protocol','owner_id','enabled','notice_version','reauth_seconds','submission_means'] : action.action === 'list' ? ['protocol','owner_id','requests'] : ['protocol','owner_id','request'];
  if (Object.keys(value).sort().join(',') !== expected.sort().join(',')) throw new Error('INVALID_BACKEND_REPLY');
  if (action.action === 'policy') {
    if (typeof value.enabled !== 'boolean' || (value.notice_version !== null && (typeof value.notice_version !== 'string' || !notice(value.notice_version))) ||
        (value.enabled && value.notice_version === null) || !Number.isSafeInteger(value.reauth_seconds) ||
        (value.reauth_seconds as number) < 30 || (value.reauth_seconds as number) > 900 ||
        value.submission_means !== 'request_received_not_data_deleted') throw new Error('INVALID_BACKEND_REPLY');
  } else if (action.action === 'list') {
    if (!Array.isArray(value.requests) || value.requests.length > 20 || !value.requests.every(requestRow) ||
        new Set(value.requests.map(v => (v as Record<string,unknown>).request_id)).size !== value.requests.length) throw new Error('INVALID_BACKEND_REPLY');
  } else {
    if (!('request_id' in action) || !requestRow(value.request) || (value.request as Record<string,unknown>).request_id !== action.request_id) throw new Error('INVALID_BACKEND_REPLY');
  }
}
const PUBLIC_ERRORS: Record<string, [number,string]> = {
  AUTHENTICATION_REQUIRED: [401,'AUTHENTICATION_REQUIRED'],
  PRIVACY_REAUTHENTICATION_REQUIRED: [403,'REAUTHENTICATION_REQUIRED'],
  PRIVACY_INTAKE_DISABLED: [503,'INTAKE_UNAVAILABLE'],
  PRIVACY_POLICY_CHANGED: [409,'NOTICE_CHANGED'],
  PRIVACY_ACTIVE_REQUEST_EXISTS: [409,'ACTIVE_REQUEST_EXISTS'],
  PRIVACY_REQUEST_CONFLICT: [409,'REQUEST_CONFLICT'],
  PRIVACY_NOT_CANCELLABLE: [409,'NOT_CANCELLABLE'],
  PRIVACY_REQUEST_NOT_FOUND: [404,'REQUEST_NOT_FOUND'],
  PRIVACY_RATE_LIMITED: [429,'RATE_LIMITED'],
};
async function readBody(req: Request, timeoutMs: number): Promise<unknown> {
  if (req.headers.get('content-type')?.split(';')[0].trim().toLowerCase() !== 'application/json') throw new PrivacyInputError('JSON_REQUIRED',415);
  const declared = req.headers.get('content-length');
  if (declared && (!/^\d+$/.test(declared) || Number(declared) > 4096)) throw new PrivacyInputError('REQUEST_TOO_LARGE',413);
  const reader = req.body?.getReader();
  if (!reader) throw new PrivacyInputError();
  let timer: ReturnType<typeof setTimeout> | undefined;
  let done = false;
  try {
    return await Promise.race([
      (async () => {
        const chunks: Uint8Array[] = []; let length = 0;
        while (!done) {
          const chunk = await reader.read();
          if (done) throw new PrivacyInputError('REQUEST_TIMEOUT',408);
          if (chunk.done) break;
          length += chunk.value.byteLength;
          if (length > 4096) throw new PrivacyInputError('REQUEST_TOO_LARGE',413);
          chunks.push(chunk.value);
        }
        const all = new Uint8Array(length); let at = 0;
        for (const chunk of chunks) { all.set(chunk,at); at += chunk.byteLength; }
        try { return JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(all)); }
        catch { throw new PrivacyInputError(); }
      })(),
      new Promise<never>((_,reject) => { timer = setTimeout(() => reject(new PrivacyInputError('REQUEST_TIMEOUT',408)),timeoutMs); }),
    ]);
  } finally { done = true; if (timer) clearTimeout(timer); void reader.cancel().catch(() => {}); }
}
export type PrivacyEnvironment = { url: string; publicKey: string; allowedOrigins: readonly string[] };
export function createPrivacyHandler(options: {
  environment: () => PrivacyEnvironment; fetcher?: Fetcher; bodyTimeoutMs?: number; rpcTimeoutMs?: number;
}): (request: Request) => Promise<Response> {
  return async (req: Request) => {
    let origin: string | null = null;
    const reply = (body: unknown,status=200) => {
      const response = responseJson(body,status);
      response.headers.set('vary','Origin');
      if (origin) response.headers.set('access-control-allow-origin',origin);
      return response;
    };
    try {
      const env = options.environment();
      const target = new URL(env.url);
      if (target.protocol !== 'https:' || !/^[a-z0-9]{20}\.supabase\.co$/.test(target.hostname) ||
          target.username || target.password || target.port || target.search || target.hash || !['','/'].includes(target.pathname) ||
          !env.publicKey || /[\r\n]/.test(env.publicKey) || env.publicKey.startsWith('sb_secret_')) throw new Error('INVALID_ENVIRONMENT');
      const suppliedOrigin = req.headers.get('origin');
      if (suppliedOrigin && !env.allowedOrigins.includes(suppliedOrigin)) return reply({error:'ORIGIN_DENIED'},403);
      origin = suppliedOrigin;
      if (req.method === 'OPTIONS') {
        const response = reply(null,200);
        response.headers.set('access-control-allow-methods','POST, OPTIONS');
        response.headers.set('access-control-allow-headers','authorization, apikey, content-type, x-client-info');
        return response;
      }
      if (req.method !== 'POST') return reply({error:'METHOD_NOT_ALLOWED'},405);
      const bearer = req.headers.get('authorization') ?? '';
      if (bearer.length > 8192 || !TOKEN.test(bearer)) return reply({error:'AUTHENTICATION_REQUIRED'},401);
      const action = validateAction(await readBody(req,options.bodyTimeoutMs ?? 4000));
      let response;
      try {
        response = await boundedJson(options.fetcher ?? fetch,`${target.origin}/rest/v1/rpc/rpc_privacy_user`,{
          method:'POST', headers:{apikey:env.publicKey,authorization:bearer,'content-type':'application/json'},
          body:JSON.stringify(rpcInput(action)),
        },{timeoutMs:options.rpcTimeoutMs ?? 6000,maxBytes:32768,signal:req.signal});
      } catch { return reply({error:'BACKEND_UNAVAILABLE',outcome: ['request','cancel'].includes(action.action) ? 'unknown' : 'unavailable'},503); }
      if (response.status < 200 || response.status >= 300) {
        const message = record(response.body) && typeof response.body.message === 'string' ? response.body.message : '';
        const mapped = PUBLIC_ERRORS[message];
        if (mapped) return reply({error:mapped[1]},mapped[0]);
        // Do not leak SQL, names, tokens, provider response bodies, or identifiers.
        if (response.status === 401 || response.status === 403) return reply({error:'AUTHENTICATION_REQUIRED'},401);
        return reply({error:'BACKEND_UNAVAILABLE',outcome:['request','cancel'].includes(action.action)?'unknown':'unavailable'},503);
      }
      try { validateReply(response.body,action); }
      catch { return reply({error:'BACKEND_UNAVAILABLE',outcome:['request','cancel'].includes(action.action)?'unknown':'unavailable'},503); }
      return reply(response.body);
    } catch (error) {
      if (error instanceof PrivacyInputError) return reply({error:error.code},error.status);
      return reply({error:'SERVICE_UNAVAILABLE'},503);
    }
  };
}
