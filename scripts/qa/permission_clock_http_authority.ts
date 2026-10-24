/** Root-owned local API consumer probe. Real caller tokens come from the
 * parent OTP/GoTrue fixture; no claims, authority or provider receipt is forged.
 * Explicit fixture mutations stay inside its disposable database. */
import { createClient } from "npm:@supabase/supabase-js@2";

type Actor = { id: string; sessionId: string; accessToken: string };
type Fixture = {
  admin: Actor;
  consumer: Actor;
  review: Actor;
  sql: (statement: string) => Promise<string>;
  onObservation: (result: unknown) => void;
};

export async function verifyPermissionClockHttpAuthority(fixture: Fixture) {
  const origin = Deno.env.get("SUPABASE_URL") ?? "";
  const parsed = new URL(origin);
  if (
    parsed.protocol !== "http:" ||
    !["127.0.0.1", "localhost", "[::1]"].includes(parsed.hostname) ||
    !/^mobio_auth_\d+$/.test(Deno.env.get("MOBIO_AUTH_FIXTURE_PROJECT") ?? "")
  ) {
    throw new Error("PERMISSION_API_OWNED_FIXTURE_REQUIRED");
  }
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  if (!anonKey || !serviceKey) throw new Error("MEMORY_CREDENTIALS_REQUIRED");
  const service = createClient(origin, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  const uuid = (value: string) =>
    /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(value);
  if (
    ![fixture.admin.id, fixture.admin.sessionId, fixture.consumer.id].every(
      uuid,
    )
  ) {
    throw new Error("EXACT_FIXTURE_ACTOR_REQUIRED");
  }
  const adminId = fixture.admin.id, consumerId = fixture.consumer.id;
  const org = crypto.randomUUID();
  const key = "transport.bookings.manage";
  const backup = "mobio_private.qa_permission_api_" + org.replaceAll("-", "");
  const result = {
    passed: false,
    checks: [] as { name: string; passed: boolean }[],
    responses: [] as {
      name: string;
      method: string;
      status: number;
      code: string | null;
      milliseconds: number;
    }[],
    signedAuthAndRest: true,
    providerDelivery: false,
    productionAcceptance: false,
    scope:
      "four real permission RPC methods, GET table RLS and current grant deletion/deadline",
  };
  function check(name: string, value: unknown): asserts value {
    result.checks.push({ name, passed: value === true });
    fixture.onObservation(structuredClone(result));
    if (value !== true) throw new Error("PERMISSION_API: " + name);
  }
  const definitions = [
    {
      name: "has_platform_permission",
      args: { p_permission: key },
      expected: true,
    },
    {
      name: "rpc_has_platform_permission",
      args: { p_permission: key },
      expected: true,
    },
    { name: "is_platform_admin", args: {}, expected: false },
    {
      name: "can_access_organization",
      args: { p_organization_id: org, p_permission: key },
      expected: true,
    },
  ];
  async function request(
    name: string,
    actor: Actor,
    method: string,
    path: string,
    payload?: Record<string, unknown>,
  ) {
    const started = performance.now();
    const response = await fetch(origin + "/rest/v1/" + path, {
      method,
      headers: {
        apikey: anonKey,
        Authorization: "Bearer " + actor.accessToken,
        Accept: "application/json",
        ...(payload ? { "Content-Type": "application/json" } : {}),
      },
      body: payload ? JSON.stringify(payload) : undefined,
    });
    const text = await response.text();
    let body: any = null;
    if (text) {
      try {
        body = JSON.parse(text);
      } catch {
        throw new Error("JSON_RESPONSE_REQUIRED");
      }
    }
    result.responses.push({
      name,
      method,
      status: response.status,
      code: body?.code ?? null,
      milliseconds: Math.round((performance.now() - started) * 100) / 100,
    });
    fixture.onObservation(structuredClone(result));
    return { status: response.status, body };
  }
  async function snapshot() {
    return fixture.sql(`select encode(sha256(convert_to(jsonb_build_object(
      'profile',(select to_jsonb(p) from public.profiles p where id='${adminId}'::uuid),
      'grants',(select coalesce(jsonb_agg(to_jsonb(g) order by profile_id),'[]') from public.profile_platform_permissions g where profile_id in('${adminId}'::uuid,'${consumerId}'::uuid)),
      'members',(select coalesce(jsonb_agg(to_jsonb(m) order by profile_id),'[]') from public.organization_members m where organization_id='${org}'::uuid),
      'bookings',(select count(*) from public.bus_bookings),
      'payments',(select count(*) from public.bus_booking_payments))::text,'UTF8')),'hex')`);
  }
  let originalRole: string | null = null;
  let prepared = false;
  let bodySucceeded = false;
  try {
    for (
      const [name, actor] of [["Admin", fixture.admin], [
        "consumer",
        fixture.consumer,
      ]] as const
    ) {
      const auth = await service.auth.getUser(actor.accessToken);
      check(
        name + " live actual GoTrue identity",
        !auth.error && auth.data.user?.id === actor.id,
      );
      const proof = await request(
        name + " exact consumed OTP proof",
        actor,
        "POST",
        "rpc/rpc_verified_interactive_session",
        {},
      );
      check(
        name + " actual exact SID proof",
        proof.status === 200 && proof.body?.user_id === actor.id &&
          proof.body?.session_id === actor.sessionId,
      );
    }
    const role = await fixture.sql(
      `select role from public.profiles where id='${adminId}'::uuid`,
    );
    check(
      "owned Admin profile exists",
      ["admin", "passenger", "driver"].includes(role),
    );
    originalRole = role;
    const originalGrants = await fixture.sql(
      `select count(*) from public.profile_platform_permissions where profile_id in('${adminId}'::uuid,'${consumerId}'::uuid)`,
    );
    check("original owned grants counted", /^[0-9]+$/.test(originalGrants));
    // Real Admin OTP supplies default grants. Preserve the two exact owned
    // principals' complete rows before constructing a delegated fixture.
    await fixture.sql(
      `create table ${backup} as select * from public.profile_platform_permissions where profile_id in('${adminId}'::uuid,'${consumerId}'::uuid)`,
    );
    prepared = true;
    await fixture.sql(`begin;
      delete from public.profile_platform_permissions where profile_id in('${adminId}'::uuid,'${consumerId}'::uuid);
      update public.profiles set role='passenger' where id='${adminId}'::uuid;
      insert into public.profile_platform_permissions(profile_id,permission_key) values('${adminId}'::uuid,'${key}'),('${consumerId}'::uuid,'${key}');
      insert into public.organizations(id,slug,name,status) values('${org}'::uuid,'qa-permission-api-${org}','Synthetic permission API','active');
      insert into public.organization_members(organization_id,profile_id,org_role,status) values('${org}'::uuid,'${adminId}'::uuid,'owner','active'),('${org}'::uuid,'${consumerId}'::uuid,'owner','active');
      commit`);
    const before = await snapshot();
    for (const rpc of definitions) {
      const positive = await request(
        "delegated " + rpc.name,
        fixture.admin,
        "POST",
        "rpc/" + rpc.name,
        rpc.args,
      );
      check(
        rpc.name + " POST delegated healthy result",
        positive.status === 200 && positive.body === rpc.expected,
      );
      const consumer = await request(
        "consumer " + rpc.name,
        fixture.consumer,
        "POST",
        "rpc/" + rpc.name,
        rpc.args,
      );
      check(
        rpc.name + " consumer membership/grant cannot create Admin management",
        consumer.status === 200 && consumer.body === false,
      );
      for (const method of ["GET", "HEAD"]) {
        const query = new URLSearchParams(
          Object.entries(rpc.args).map(([k, v]) => [k, String(v)]),
        ).toString();
        const reply = await request(
          rpc.name + " volatile " + method,
          fixture.admin,
          method,
          "rpc/" + rpc.name + (query ? "?" + query : ""),
        );
        check(
          rpc.name + " " + method + " preserves pure read-only RPC behavior",
          reply.status === 200 &&
            (method === "HEAD"
              ? reply.body === null
              : reply.body === rpc.expected),
        );
      }
    }
    for (
      const [name, actor] of [["Admin", fixture.admin], [
        "consumer",
        fixture.consumer,
      ]] as const
    ) {
      const read = await request(
        name + " read-only organization RLS",
        actor,
        "GET",
        "organizations?id=eq." + org + "&select=id",
      );
      check(
        name + " table GET preserves pure read-only membership",
        read.status === 200 && Array.isArray(read.body) &&
          read.body.length === 1 && read.body[0].id === org,
      );
    }
    const review = await request(
      "reviewer ordinary permission admission",
      fixture.review,
      "POST",
      "rpc/rpc_has_platform_permission",
      { p_permission: key },
    );
    check(
      "reviewer cannot reach ordinary permission authority",
      review.status === 403,
    );
    check(
      "healthy RPC/method/RLS/review calls make no fixture state change",
      await snapshot() === before,
    );
    await fixture.sql(
      `update public.profile_platform_permissions set expires_at=clock_timestamp()+interval '2 seconds' where profile_id='${adminId}'::uuid and permission_key='${key}'`,
    );
    const live = await request(
      "current finite grant",
      fixture.admin,
      "POST",
      "rpc/rpc_has_platform_permission",
      { p_permission: key },
    );
    check(
      "finite future grant remains live",
      live.status === 200 && live.body === true,
    );
    // Wait against actual database time; do not rewrite the grant expiry.
    const budget = performance.now() + 10000;
    while (
      await fixture.sql(
        `select (expires_at<=clock_timestamp())::text from public.profile_platform_permissions where profile_id='${adminId}'::uuid and permission_key='${key}'`,
      ) !== "true"
    ) {
      if (performance.now() >= budget) {
        throw new Error("OWNED_EXPIRY_WAIT_BUDGET");
      }
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    const expiredSnapshot = await snapshot();
    for (const rpc of definitions) {
      const reply = await request(
        "expired " + rpc.name,
        fixture.admin,
        "POST",
        "rpc/" + rpc.name,
        rpc.args,
      );
      check(
        rpc.name + " current expired grant denied",
        reply.status === 200 && reply.body === false,
      );
      const query = new URLSearchParams(
        Object.entries(rpc.args).map(([k, v]) => [k, String(v)]),
      ).toString();
      for (const method of ["GET", "HEAD"]) {
        const read = await request(
          "expired " + method + " " + rpc.name,
          fixture.admin,
          method,
          "rpc/" + rpc.name + (query ? "?" + query : ""),
        );
        check(
          rpc.name + " expired " + method + " preserves read-only response",
          read.status === 200 &&
            (method === "HEAD" ? read.body === null : read.body === false),
        );
      }
    }
    check(
      "expired permission reads make no fixture state change",
      await snapshot() === expiredSnapshot,
    );
    await fixture.sql(
      `delete from public.profile_platform_permissions where profile_id='${adminId}'::uuid and permission_key='${key}'`,
    );
    const deleted = await request(
      "committed deleted grant",
      fixture.admin,
      "POST",
      "rpc/rpc_has_platform_permission",
      { p_permission: key },
    );
    check(
      "committed grant deletion remains denied",
      deleted.status === 200 && deleted.body === false,
    );
    bodySucceeded = true;
    return result;
  } finally {
    if (prepared) {
      await fixture.sql(`begin;
        delete from public.organizations where id='${org}'::uuid;
        delete from public.profile_platform_permissions where profile_id in('${adminId}'::uuid,'${consumerId}'::uuid);
        insert into public.profile_platform_permissions select * from ${backup};
        update public.profiles set role='${originalRole}' where id='${adminId}'::uuid;
        commit`);
      check(
        "owned organization absent, exact original grants/role restored",
        await fixture.sql(
          `select ((not exists(select 1 from public.organizations where id='${org}'::uuid)) and
        (not exists((select * from public.profile_platform_permissions where profile_id in('${adminId}'::uuid,'${consumerId}'::uuid) except select * from ${backup}) union all (select * from ${backup} except select * from public.profile_platform_permissions where profile_id in('${adminId}'::uuid,'${consumerId}'::uuid)))) and
        exists(select 1 from public.profiles where id='${adminId}'::uuid and role='${originalRole}'))::text`,
        ) === "true",
      );
      await fixture.sql(`drop table ${backup}`);
    }
    result.passed = bodySucceeded && result.checks.every((item) => item.passed);
    fixture.onObservation(structuredClone(result));
  }
}
