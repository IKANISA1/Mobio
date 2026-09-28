/** Session binding here reads ONLY a token freshly issued by the trusted Auth
 * client. It is not a signature verifier and must never authenticate input JWTs.
 * The registration RPC independently verifies auth.sessions, OTP and allowlist.
 */
export type AdminLease = {
  active: true; session_id: string; user_id: string; server_now: string;
  authenticated_at: string; idle_expires_at: string; absolute_expires_at: string;
};
export interface LeaseRpc {
  rpc(name: string, args: Record<string, unknown>): PromiseLike<{ data: unknown; error: unknown }>;
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function issuedSessionId(accessToken: string, expectedUser: string): string {
  if (!uuid.test(expectedUser) || accessToken.length > 16384) throw new Error('INVALID_ISSUED_SESSION');
  const pieces = accessToken.split('.');
  if (pieces.length !== 3 || !/^[A-Za-z0-9_-]+$/.test(pieces[1])) throw new Error('INVALID_ISSUED_SESSION');
  let claims: Record<string, unknown>;
  try {
    claims = JSON.parse(atob(pieces[1].replace(/-/g,'+').replace(/_/g,'/'))) as Record<string, unknown>;
  } catch { throw new Error('INVALID_ISSUED_SESSION'); }
  if (!claims || claims.sub !== expectedUser || typeof claims.session_id !== 'string'
      || !uuid.test(claims.session_id) || claims.role !== 'authenticated'
      || claims.is_anonymous !== false
      || typeof claims.app_metadata !== 'object' || claims.app_metadata === null
      || (claims.app_metadata as Record<string,unknown>).provider !== 'admin_whatsapp_otp') {
    throw new Error('INVALID_ISSUED_SESSION');
  }
  return claims.session_id;
}
export function validateAdminLease(value: unknown, userId: string, sessionId: string): AdminLease {
  if (typeof value !== 'object' || value === null) throw new Error('ADMIN_LEASE_REJECTED');
  const v = value as Record<string,unknown>;
  if (v.active !== true || v.user_id !== userId || v.session_id !== sessionId) throw new Error('ADMIN_LEASE_REJECTED');
  for (const key of ['server_now','authenticated_at','idle_expires_at','absolute_expires_at']) {
    if (typeof v[key] !== 'string' || !Number.isFinite(Date.parse(v[key] as string))) throw new Error('ADMIN_LEASE_REJECTED');
  }
  const now = Date.parse(v.server_now as string), idle = Date.parse(v.idle_expires_at as string);
  const absolute = Date.parse(v.absolute_expires_at as string), auth = Date.parse(v.authenticated_at as string);
  if (auth > now || idle <= now || absolute < idle || idle-now > 1800000 || absolute-auth > 43200000) {
    throw new Error('ADMIN_LEASE_REJECTED');
  }
  return v as AdminLease;
}
export async function registerIssuedAdminLease(client: LeaseRpc, userId: string,
    accessToken: string, otpId: string): Promise<AdminLease> {
  const sessionId = issuedSessionId(accessToken,userId);
  if (!otpId || otpId.length>128) throw new Error('INVALID_OTP_REFERENCE');
  const {data,error} = await client.rpc('rpc_register_admin_session', {
    p_user_id:userId, p_session_id:sessionId, p_otp_id:otpId,
  });
  if (error) throw new Error('ADMIN_LEASE_UNAVAILABLE');
  return validateAdminLease(data,userId,sessionId);
}
