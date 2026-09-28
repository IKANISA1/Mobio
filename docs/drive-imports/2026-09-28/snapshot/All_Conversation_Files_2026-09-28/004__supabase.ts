import { createClient } from "npm:@supabase/supabase-js@2";

function requireEnv(...names: string[]): string {
  for (const name of names) {
    const value = Deno.env.get(name)?.trim();
    if (value) {
      return value;
    }
  }

  throw new Error(`Missing environment variable: ${names.join(" or ")}`);
}

function getSupabaseUrl() {
  return requireEnv("SUPABASE_URL", "COOL_PROJECT_SUPABASE_URL");
}

function getSupabaseAnonKey() {
  return requireEnv(
    "SUPABASE_ANON_KEY",
    "COOL_PROJECT_SUPABASE_ANON_KEY",
  );
}

function getSupabaseServiceRoleKey() {
  return requireEnv(
    "SUPABASE_SERVICE_ROLE_KEY",
    "COOL_PROJECT_SUPABASE_SERVICE_ROLE_KEY",
  );
}

function boundedFetch(timeoutMs: number): typeof fetch {
  return (input, init) => {
    const inherited = init?.signal ??
      (input instanceof Request ? input.signal : undefined);
    const timeout = AbortSignal.timeout(timeoutMs);
    return fetch(input, {
      ...init,
      signal: inherited ? AbortSignal.any([inherited, timeout]) : timeout,
    });
  };
}

export function createAdminClient(timeoutMs?: number) {
  return createClient(
    getSupabaseUrl(),
    getSupabaseServiceRoleKey(),
    {
      ...(timeoutMs ? { global: { fetch: boundedFetch(timeoutMs) } } : {}),
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}

export function createAnonClient(timeoutMs?: number) {
  return createClient(
    getSupabaseUrl(),
    getSupabaseAnonKey(),
    {
      ...(timeoutMs ? { global: { fetch: boundedFetch(timeoutMs) } } : {}),
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}

export function createUserClient(authorization: string) {
  return createClient(
    getSupabaseUrl(),
    getSupabaseAnonKey(),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
      global: {
        headers: {
          Authorization: authorization,
        },
      },
    },
  );
}
