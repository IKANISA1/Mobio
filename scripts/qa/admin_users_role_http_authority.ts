/** Actual local GoTrue/OTP/REST proof. No JWT claims are forged; tokens and
 * challenge codes stay in memory. The caller owns the disposable project. */
import { createClient } from "npm:@supabase/supabase-js@2";
import { hashOtpCode } from "../../supabase/functions/_shared/otp-security.ts";
import { authValidatedSessionId } from "../../supabase/functions/_shared/store-review-session.ts";

export type AdminRoleHttpActor = {
  id: string;
  sessionId: string;
  accessToken: string;
};
type Json = Record<string, any>;
type Reply = { status: number; body: Json };
type Row = {
  id: string;
  name: string;
  display_name: string | null;
  role: string;
  is_driver: boolean;
  is_online: boolean;
  created_at: string;
  role_revision: number;
};
export type AdminRoleHttpResult = {
  passed: boolean;
  checks: { name: string; passed: boolean }[];
  rpcAttempts: Record<string, number>;
  snapshotRows: number;
  lastPageValidation: {
    name: string;
    totalExact: number | null;
    rowCount: number | null;
    ttlMilliseconds: number | null;
    predicates: Record<string, boolean>;
  } | null;
  signedAuthAndRest: true;
  otpVerificationHandler: true;
  providerDelivery: false;
  productionAcceptance: false;
};
export type AdminRoleHttpFixture = {
  admin: AdminRoleHttpActor;
  consumer: AdminRoleHttpActor;
  sql: (statement: string) => Promise<string>;
  verifyAdminOtp: (body: {
    phone: string;
    countryCode: "RW";
    code: string;
  }) => Promise<Reply>;
  onCreatedActor: (id: string) => void;
  onObservation?: (result: AdminRoleHttpResult) => void;
};

export async function verifyAdminUsersRoleHttpAuthority(
  fixture: AdminRoleHttpFixture,
): Promise<AdminRoleHttpResult> {
  const origin = Deno.env.get("SUPABASE_URL") ?? "";
  const parsed = new URL(origin);
  if (
    !["127.0.0.1", "localhost", "[::1]"].includes(parsed.hostname) ||
    parsed.protocol !== "http:" ||
    !/^mobio_auth_\d+$/.test(Deno.env.get("MOBIO_AUTH_FIXTURE_PROJECT") ?? "")
  ) throw new Error("ADMIN_HTTP_OWNED_LOCAL_FIXTURE_REQUIRED");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!anonKey || !serviceKey || !Deno.env.get("OTP_HASH_SECRET")) {
    throw new Error("ADMIN_HTTP_MEMORY_CREDENTIALS_REQUIRED");
  }
  const service = createClient(origin, serviceKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
      detectSessionInUrl: false,
    },
  });
  const result: AdminRoleHttpResult = {
    passed: false,
    checks: [],
    rpcAttempts: {},
    snapshotRows: 0,
    lastPageValidation: null,
    signedAuthAndRest: true,
    otpVerificationHandler: true,
    providerDelivery: false,
    productionAcceptance: false,
  };
  function observe() {
    fixture.onObservation?.(structuredClone(result));
  }
  function check(name: string, ok: unknown): asserts ok {
    result.checks.push({ name, passed: ok === true });
    observe();
    if (ok !== true) throw new Error("ADMIN_HTTP: " + name);
  }
  const uuid = (value: unknown): value is string =>
    typeof value === "string" &&
    /^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(value);
  const quote = (value: string) => "'" + value.replaceAll("'", "''") + "'";
  const equal = (a: unknown, b: unknown) =>
    JSON.stringify(a) === JSON.stringify(b);
  function actorIsValid(actor: AdminRoleHttpActor) {
    return uuid(actor.id) && uuid(actor.sessionId) &&
      typeof actor.accessToken === "string" && actor.accessToken.length > 50;
  }
  check(
    "provided actors have distinct valid identities",
    actorIsValid(fixture.admin) && actorIsValid(fixture.consumer) &&
      fixture.admin.id !== fixture.consumer.id,
  );
  async function rpc(
    caller: AdminRoleHttpActor,
    name: string,
    args: Json = {},
    dropResponse = false,
  ): Promise<Reply> {
    result.rpcAttempts[name] = (result.rpcAttempts[name] ?? 0) + 1;
    let response: Response;
    try {
      response = await fetch(origin + "/rest/v1/rpc/" + name, {
        method: "POST",
        headers: {
          apikey: anonKey!,
          authorization: "Bearer " + caller.accessToken,
          "content-type": "application/json",
        },
        body: JSON.stringify(args),
      });
    } catch {
      throw new Error("ADMIN_HTTP_LOCAL_TRANSPORT_FAILED");
    }
    if (dropResponse) {
      // Headers arrive after the real SQL transaction committed. The client
      // deliberately receives no body/receipt and must reconcile, never replay.
      await response.body?.cancel();
      throw new Error("ADMIN_HTTP_SIMULATED_RESPONSE_LOSS");
    }
    let body: Json;
    try {
      body = await response.json();
    } catch {
      throw new Error("ADMIN_HTTP_RPC_JSON_REQUIRED");
    }
    return { status: response.status, body };
  }
  function success(name: string, reply: Reply, caller: AdminRoleHttpActor) {
    check(
      name,
      reply.status === 200 &&
        reply.body.protocol === "mobio.admin-users.v1" &&
        reply.body.actor_id === caller.id &&
        reply.body.session_id === caller.sessionId &&
        Number.isFinite(Date.parse(reply.body.server_now)),
    );
    return reply.body;
  }
  function denied(
    name: string,
    reply: Reply,
    code: string,
    message: string,
    status: number,
  ) {
    check(
      name,
      reply.status === status && reply.body.code === code &&
        reply.body.message === message,
    );
  }
  async function live(name: string, caller: AdminRoleHttpActor) {
    const user = await service.auth.getUser(caller.accessToken);
    check(
      name + " actual GoTrue getUser",
      !user.error && user.data.user?.id === caller.id,
    );
    const proof = await rpc(caller, "rpc_verified_interactive_session");
    check(
      name + " actual exact-session REST proof",
      proof.status === 200 && proof.body.user_id === caller.id &&
        proof.body.session_id === caller.sessionId,
    );
  }
  async function issueAdmin(phone: string): Promise<AdminRoleHttpActor> {
    const code = String(
      100000 + crypto.getRandomValues(new Uint32Array(1))[0] % 900000,
    );
    const hash = await hashOtpCode(code, { phone, purpose: "admin_login" });
    const challenge = await service.from("otp_codes").insert({
      phone,
      purpose: "admin_login",
      code: "000000",
      code_hash: hash,
      verified: false,
      expires_at: new Date(Date.now() + 300000).toISOString(),
    });
    check(
      "module Admin challenge is contextual and unconsumed",
      !challenge.error,
    );
    const issued = await fixture.verifyAdminOtp({
      phone,
      countryCode: "RW",
      code,
    });
    check(
      "module Admin actual OTP HTTP handler issues transport",
      issued.status === 200,
    );
    const token = issued.body.session?.access_token;
    check(
      "module Admin issued token stays in memory",
      typeof token === "string" && uuid(issued.body.userId),
    );
    const created = {
      id: issued.body.userId,
      sessionId: authValidatedSessionId(
        token,
        issued.body.userId,
        "admin_whatsapp_otp",
      ),
      accessToken: token,
    };
    fixture.onCreatedActor(created.id);
    check(
      "module Admin actual exact SID lease is active",
      issued.body.admin_lease?.active === true &&
        issued.body.admin_lease?.user_id === created.id &&
        issued.body.admin_lease?.session_id === created.sessionId,
    );
    await live("module Admin", created);
    return created;
  }
  const label = (row: Row) =>
    row.display_name?.trim()
      ? row.display_name
      : row.name.trim()
      ? row.name
      : "Unnamed member";
  const cmp = (a: string, b: string) => a < b ? -1 : a > b ? 1 : 0;
  function sorted(rows: Row[], sort: string) {
    return [...rows].sort((a, b) => {
      let first = 0;
      if (sort === "online") {
        first = Number(b.is_online) - Number(a.is_online) ||
          cmp(a.role, b.role);
      } else if (sort === "role") first = cmp(a.role, b.role);
      else if (sort === "newest") {
        first = Date.parse(b.created_at) - Date.parse(a.created_at);
      }
      const names = cmp(label(a).toLowerCase(), label(b).toLowerCase());
      return first || (sort === "name_desc" ? -names : names) ||
        cmp(a.id, b.id);
    });
  }
  function target(row: Row, requestedRole = "driver") {
    return {
      target_id: row.id,
      expected_role: row.role,
      expected_revision: row.role_revision,
      requested_role: requestedRole,
    };
  }
  function planArgs(reservation: string, snapshot: string, rows: Row[]) {
    return {
      p_reservation_id: reservation,
      p_snapshot_id: snapshot,
      p_targets: rows.map((row) => target(row)),
    };
  }
  function validatePage(name: string, body: Json, sort: string, count: number) {
    const ttl = Date.parse(body.expires_at) - Date.parse(body.as_of);
    const predicates = {
      snapshotIdValid: uuid(body.snapshot_id),
      countMatches: body.total_exact === count,
      pageSizeMatches: body.page_size === 2,
      sortMatches: body.sort === sort,
      rowsBounded: Array.isArray(body.rows) && body.rows.length <= 2,
      offsetValid: Number.isInteger(body.offset) && body.offset >= 0,
      hasNextMatches: body.has_next_page === (body.offset + 2 < count),
      ttlExactlyTenMinutes: ttl === 600000,
      serverNowAfterAsOf: Date.parse(body.server_now) >= Date.parse(body.as_of),
      rowIdentityAndRevisionValid: Array.isArray(body.rows) &&
        body.rows.every((row: Row) =>
          uuid(row.id) && Number.isSafeInteger(row.role_revision) &&
          row.role_revision >= 0
        ),
    };
    // Only authored predicate labels and numeric counts leave the fixture.
    // Returned identities, names, phones, credentials and full bodies do not.
    result.lastPageValidation = {
      name,
      totalExact: Number.isSafeInteger(body.total_exact)
        ? body.total_exact
        : null,
      rowCount: Array.isArray(body.rows) ? body.rows.length : null,
      ttlMilliseconds: Number.isFinite(ttl) ? ttl : null,
      predicates,
    };
    check(name, Object.values(predicates).every((passed) => passed === true));
  }
  async function pageAll(
    caller: AdminRoleHttpActor,
    args: Json,
    expected: Row[],
  ) {
    const first = success(
      "fresh sorted query returns bound envelope",
      await rpc(caller, "rpc_admin_users_page", args),
      caller,
    );
    validatePage(
      "fresh sorted query has exact bounded count and TTL",
      first,
      args.p_sort,
      expected.length,
    );
    const collected: Row[] = [...first.rows];
    for (let offset = 2; offset < expected.length; offset += 2) {
      const next = success(
        "later sorted page returns same owner/session",
        await rpc(caller, "rpc_admin_users_page", {
          ...args,
          p_snapshot_id: first.snapshot_id,
          p_offset: offset,
        }),
        caller,
      );
      validatePage(
        "later page retains exact snapshot count",
        next,
        args.p_sort,
        expected.length,
      );
      check(
        "later page retains exact snapshot binding and as_of",
        next.snapshot_id === first.snapshot_id && next.as_of === first.as_of &&
          next.expires_at === first.expires_at && next.offset === offset &&
          next.search === first.search &&
          next.role_filter === first.role_filter &&
          next.has_next_page === (offset + 2 < expected.length),
      );
      collected.push(...next.rows);
    }
    check(
      "server global order matches displayed name and UUID tie break",
      equal(collected.map((r) => r.id), expected.map((r) => r.id)),
    );
    return { first, rows: collected };
  }
  async function releaseSnapshot(
    caller: AdminRoleHttpActor,
    snapshot: string,
    name: string,
    alreadyAbsent = false,
  ) {
    const body = success(
      name,
      await rpc(caller, "rpc_admin_users_release_snapshot", {
        p_snapshot_id: snapshot,
      }),
      caller,
    );
    check(
      name + " exact handle and authoritative flags",
      body.snapshot_id === snapshot &&
        body.released === !alreadyAbsent &&
        body.already_absent === alreadyAbsent,
    );
    return body;
  }
  let admin: AdminRoleHttpActor | undefined;
  let leaseBackup: string | undefined;
  async function restoreLease() {
    if (!leaseBackup || !admin) return;
    await fixture.sql(
      `delete from mobio_private.admin_session_leases where session_id=${
        quote(admin.sessionId)
      }::uuid;` +
        `insert into mobio_private.admin_session_leases select * from jsonb_populate_record(null::mobio_private.admin_session_leases,${
          quote(leaseBackup)
        }::jsonb);`,
    );
  }
  try {
    await live("provided Admin", fixture.admin);
    await live("provided consumer", fixture.consumer);
    const adminPhone = "+25078" +
      String(crypto.getRandomValues(new Uint32Array(1))[0] % 10000000).padStart(
        7,
        "0",
      );
    const allow = await service.from("admin_whatsapp_numbers").insert({
      phone_e164: adminPhone,
      country_code: "+250",
      is_active: true,
    });
    check("module-owned Admin fixture phone is allowlisted", !allow.error);
    admin = await issueAdmin(adminPhone);
    check(
      "module Admin is independent of supplied actors",
      admin.id !== fixture.admin.id && admin.id !== fixture.consumer.id,
    );
    const group = String(
      1000 + crypto.getRandomValues(new Uint32Array(1))[0] % 9000,
    );
    const prefix = "+25079" + group;
    const seeded: Row[] = [];
    const names = [
      "raw Zulu",
      "raw Alpha",
      "Name fallback",
      "Aardvark raw name",
      "raw Bravo 1",
      "raw Bravo 2",
      "",
    ];
    const displays = ["Zulu", "Alpha", "  ", "Mike", "Bravo", "Bravo", ""];
    for (let i = 0; i < 7; i++) {
      const phone = prefix + String(i).padStart(3, "0");
      const created = await service.auth.admin.createUser({
        phone,
        phone_confirm: true,
        app_metadata: { provider: "whatsapp_cloud_otp" },
        user_metadata: { name: names[i] },
      });
      check(
        "synthetic query target Auth fixture created",
        !created.error && uuid(created.data.user?.id),
      );
      const id = created.data.user!.id;
      fixture.onCreatedActor(id);
      const role = i === 2 || i === 4 ? "driver" : "passenger";
      const changed = await service.from("profiles").update({
        // GoTrue's phone representation may omit '+'. Production OTP handlers
        // explicitly materialize normalized profile.phone; match that contract
        // before using the canonical fixture prefix as the query selector.
        phone,
        name: names[i],
        display_name: displays[i],
        role,
        is_driver: role === "driver",
        is_online: i % 2 === 0,
        created_at: new Date(1790900000000 + i * 1000).toISOString(),
      }).eq("id", id);
      check(
        "synthetic target display/sort fields are service-owned",
        !changed.error,
      );
      const current = await service.from("profiles").select(
        "id,phone,name,display_name,role,is_driver,is_online,created_at",
      ).eq("id", id).single();
      check(
        "synthetic target source row is available",
        !current.error && !!current.data,
      );
      check(
        "synthetic target query selector is canonically materialized",
        current.data!.phone === phone,
      );
      const revision = await fixture.sql(
        `select revision from mobio_private.admin_user_role_versions where user_id=${
          quote(id)
        }::uuid`,
      );
      seeded.push({ ...current.data!, role_revision: Number(revision) } as Row);
    }
    const query = { p_search: prefix, p_sort: "name_asc", p_page_size: 2 };
    denied(
      "fresh HTTP query rejects aligned later offset",
      await rpc(admin, "rpc_admin_users_page", { ...query, p_offset: 2 }),
      "22023",
      "ADMIN_USERS_QUERY_INVALID",
      400,
    );
    const first = success(
      "first actual server snapshot page",
      await rpc(admin, "rpc_admin_users_page", {
        ...query,
        p_search: " " + prefix + " ",
      }),
      admin,
    );
    validatePage(
      "first snapshot exact seven rows/ten-minute TTL",
      first,
      "name_asc",
      7,
    );
    result.snapshotRows = first.total_exact;
    check(
      "query search is normalized by server",
      first.search === prefix && first.role_filter === null &&
        first.offset === 0 && first.has_next_page === true,
    );
    const frozenRows: Row[] = [...first.rows];
    const mutation = await service.from("profiles").update({
      display_name: "Before Alpha live edit",
      role: "driver",
      is_driver: true,
    }).eq("id", seeded[0].id);
    check(
      "real upstream profile mutation occurs between HTTP pages",
      !mutation.error,
    );
    for (let offset = 2; offset < 7; offset += 2) {
      const page = success(
        "page after source mutation retains owner/session",
        await rpc(admin, "rpc_admin_users_page", {
          ...query,
          p_snapshot_id: first.snapshot_id,
          p_offset: offset,
        }),
        admin,
      );
      validatePage(
        "page after mutation retains exact count/TTL",
        page,
        "name_asc",
        7,
      );
      check(
        "snapshot membership/binding remains immutable between pages",
        page.snapshot_id === first.snapshot_id && page.as_of === first.as_of &&
          page.expires_at === first.expires_at && page.offset === offset &&
          page.search === prefix && page.has_next_page === (offset + 2 < 7),
      );
      frozenRows.push(...page.rows);
    }
    const expectedFrozen = sorted(seeded, "name_asc");
    check(
      "four actual pages globally use visible name/UUID order",
      equal(frozenRows.map((r) => r.id), expectedFrozen.map((r) => r.id)),
    );
    check(
      "frozen rows retain reviewed pre-mutation roles and names",
      frozenRows.find((r) => r.id === seeded[0].id)?.display_name === "Zulu" &&
        frozenRows.find((r) => r.id === seeded[0].id)?.role === "passenger",
    );
    const repeated = success(
      "same session repeats exact frozen first page",
      await rpc(admin, "rpc_admin_users_page", {
        ...query,
        p_snapshot_id: first.snapshot_id,
      }),
      admin,
    );
    check(
      "same-SID repeat keeps frozen first page",
      equal(repeated.rows, first.rows),
    );
    const liveRows = seeded.map((row, i) =>
      i === 0
        ? {
          ...row,
          display_name: "Before Alpha live edit",
          role: "driver",
          is_driver: true,
          role_revision: row.role_revision + 1,
        }
        : row
    );
    for (const sort of ["name_desc", "role", "online", "newest"]) {
      const pages = await pageAll(
        admin,
        { ...query, p_sort: sort },
        sorted(liveRows, sort),
      );
      await releaseSnapshot(
        admin,
        pages.first.snapshot_id,
        "superseded query releases through actual REST",
      );
    }
    const drivers = sorted(
      liveRows.filter((row) => row.role === "driver"),
      "name_asc",
    );
    const filtered = await pageAll(
      admin,
      { ...query, p_role: " driver " },
      drivers,
    );
    check(
      "role filter is normalized and count is exact",
      filtered.first.role_filter === "driver" && filtered.rows.every((row) =>
        row.role === "driver"
      ) && filtered.first.total_exact === 3,
    );
    await releaseSnapshot(
      admin,
      filtered.first.snapshot_id,
      "filtered query releases through actual REST",
    );
    await releaseSnapshot(
      admin,
      filtered.first.snapshot_id,
      "repeat release reports authoritative absence",
      true,
    );
    denied(
      "snapshot cannot change search binding",
      await rpc(admin, "rpc_admin_users_page", {
        ...query,
        p_search: prefix + "x",
        p_snapshot_id: first.snapshot_id,
      }),
      "P0001",
      "ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH",
      400,
    );
    const reviewed = [seeded[1], seeded[3], seeded[6]];
    const token = crypto.randomUUID();
    const args = {
      p_reservation_id: token,
      p_snapshot_id: first.snapshot_id,
      p_targets: [
        target(reviewed[0]),
        target(reviewed[1]),
        target(reviewed[2], "passenger"),
      ],
    };
    const reserved = success(
      "reviewed actual HTTP reservation",
      await rpc(admin, "rpc_admin_role_reserve", args),
      admin,
    );
    check(
      "server reservation binds immutable reviewed order and origin",
      reserved.reservation_id === token &&
        reserved.reservation_state === "reserved" &&
        uuid(reserved.batch?.batch_id) &&
        reserved.batch.origin_session_id === admin.sessionId &&
        reserved.batch.snapshot_id === first.snapshot_id &&
        /^[0-9a-f]{64}$/.test(reserved.batch.input_sha256) &&
        reserved.operations.length === 3 &&
        reserved.operations.every((op: Json, i: number) =>
          uuid(op.operation_id) && op.ordinal === i + 1 &&
          op.target_id === reviewed[i].id &&
          op.expected_role === reviewed[i].role &&
          op.expected_revision === reviewed[i].role_revision &&
          op.expected_is_driver === reviewed[i].is_driver &&
          op.requested_role === args.p_targets[i].requested_role &&
          op.requested_is_driver ===
            (args.p_targets[i].requested_role === "driver") &&
          op.display_label === label(reviewed[i])
        ) && reserved.operations[2].status === "skipped" &&
        reserved.operations[2].skip_reason === "same_role",
    );
    const replayReserve = success(
      "same token reads same reserved tuples",
      await rpc(admin, "rpc_admin_role_reserve", args),
      admin,
    );
    check(
      "reservation transport retry cannot create a new plan",
      equal(replayReserve.batch, reserved.batch) &&
        equal(replayReserve.operations, reserved.operations),
    );
    denied(
      "other tab cannot overlap open batch",
      await rpc(admin, "rpc_admin_role_reserve", {
        ...args,
        p_reservation_id: crypto.randomUUID(),
      }),
      "P0001",
      "ADMIN_ROLE_BATCH_OPEN",
      400,
    );
    const bid = reserved.batch.batch_id;
    const op = reserved.operations[0];
    const executeBefore = result.rpcAttempts.rpc_admin_role_execute ?? 0;
    let lost = false;
    try {
      await rpc(admin, "rpc_admin_role_execute", {
        p_batch_id: bid,
        p_operation_id: op.operation_id,
      }, true);
    } catch (error) {
      lost = error instanceof Error &&
        error.message === "ADMIN_HTTP_SIMULATED_RESPONSE_LOSS";
    }
    check("post-commit transport response was intentionally lost", lost);
    const recovered = success(
      "unknown delivery reconciles actual durable status",
      await rpc(admin, "rpc_admin_role_status", { p_batch_id: bid }),
      admin,
    );
    const receipt = recovered.operations[0].receipt;
    check(
      "status confirms receipt without execute replay",
      (result.rpcAttempts.rpc_admin_role_execute ?? 0) === executeBefore + 1 &&
        recovered.operations[0].status === "confirmed" &&
        receipt?.actor_id === admin.id &&
        receipt.session_id === admin.sessionId && receipt.batch_id === bid &&
        receipt.operation_id === op.operation_id &&
        receipt.target_id === op.target_id &&
        receipt.before_role === op.expected_role &&
        receipt.after_role === "driver" &&
        receipt.before_revision === op.expected_revision &&
        receipt.after_revision > receipt.before_revision &&
        receipt.before_is_driver === op.expected_is_driver &&
        receipt.after_is_driver === op.requested_is_driver &&
        uuid(receipt.audit_id) &&
        Number.isFinite(Date.parse(receipt.committed_at)),
    );
    const audit = JSON.parse(
      await fixture.sql(
        `select row_to_json(a)::text from public.admin_audit_log a where id=${
          quote(receipt.audit_id)
        }::uuid`,
      ),
    );
    const auditCount = await fixture.sql(
      `select count(*) from public.admin_audit_log where details->>'operation_id'=${
        quote(op.operation_id)
      }`,
    );
    check(
      "one existing actual audit matches committed receipt",
      auditCount === "1" && audit.admin_id === admin.id &&
        audit.action === "update_role" && audit.target_type === "profile" &&
        audit.target_id === op.target_id && audit.details.batch_id === bid &&
        audit.details.operation_id === op.operation_id &&
        audit.details.before_revision === receipt.before_revision &&
        audit.details.after_revision === receipt.after_revision,
    );
    const early = crypto.randomUUID();
    const absent = success(
      "absent reservation status remains unknown",
      await rpc(admin, "rpc_admin_role_status", { p_reservation_id: early }),
      admin,
    );
    check(
      "absent status echoes token with no rejection inference",
      absent.reservation_id === early &&
        absent.reservation_state === "absent" && absent.batch === null &&
        equal(absent.operations, []),
    );
    const earlySeal = success(
      "explicit seal before reservation",
      await rpc(admin, "rpc_admin_role_seal", { p_reservation_id: early }),
      admin,
    );
    check(
      "early seal is exact durable token fence",
      earlySeal.reservation_id === early &&
        earlySeal.reservation_state === "sealed_before_reserve" &&
        earlySeal.batch === null && equal(earlySeal.operations, []),
    );
    denied(
      "sealed absent token rejects later actual reserve",
      await rpc(admin, "rpc_admin_role_reserve", {
        ...args,
        p_reservation_id: early,
      }),
      "P0001",
      "ADMIN_ROLE_RESERVATION_SEALED",
      400,
    );
    const staleReleasePage = success(
      "extra superseded handle created for base release",
      await rpc(admin, "rpc_admin_users_page", query),
      admin,
    );
    leaseBackup = await fixture.sql(
      `select row_to_json(l)::text from mobio_private.admin_session_leases l where session_id=${
        quote(admin.sessionId)
      }::uuid`,
    );
    check("module-owned lease backup stays in memory", leaseBackup.length > 0);
    await fixture.sql(
      `update mobio_private.admin_session_leases set authenticated_at=clock_timestamp()-interval '6 minutes' where session_id=${
        quote(admin.sessionId)
      }::uuid`,
    );
    success(
      "stale recent authentication permits protected snapshot read",
      await rpc(admin, "rpc_admin_users_page", {
        ...query,
        p_snapshot_id: first.snapshot_id,
      }),
      admin,
    );
    success(
      "stale recent authentication permits protected receipt recovery",
      await rpc(admin, "rpc_admin_role_status", { p_batch_id: bid }),
      admin,
    );
    await releaseSnapshot(
      admin,
      staleReleasePage.snapshot_id,
      "stale recent authentication permits cache release",
    );
    denied(
      "stale reserve requires reauth before null arguments",
      await rpc(admin, "rpc_admin_role_reserve", {
        p_reservation_id: null,
        p_snapshot_id: null,
        p_targets: null,
      }),
      "42501",
      "ADMIN_REAUTHENTICATION_REQUIRED",
      403,
    );
    denied(
      "stale execute requires reauth before null arguments",
      await rpc(admin, "rpc_admin_role_execute", {
        p_batch_id: null,
        p_operation_id: null,
      }),
      "42501",
      "ADMIN_REAUTHENTICATION_REQUIRED",
      403,
    );
    const staleSeal = success(
      "stale recent authentication permits base-authority seal",
      await rpc(admin, "rpc_admin_role_seal", { p_batch_id: bid }),
      admin,
    );
    check(
      "stale seal retains confirmed receipt and fences undispatched only",
      equal(staleSeal.operations[0].receipt, receipt) &&
        staleSeal.operations[1].status === "not_started" &&
        staleSeal.operations[2].status === "skipped",
    );
    await restoreLease();
    const pendingArgs = planArgs(crypto.randomUUID(), first.snapshot_id, [
      seeded[3],
    ]);
    const pending = success(
      "new reviewed plan reserved after explicit close",
      await rpc(admin, "rpc_admin_role_reserve", pendingArgs),
      admin,
    );
    const effectSnapshot = () =>
      fixture.sql(
        `select jsonb_build_object('batches',(select coalesce(jsonb_agg(to_jsonb(b) order by batch_id),'[]') from mobio_private.admin_role_batches b where actor_id=${
          quote(admin!.id)
        }::uuid),'tokens',(select coalesce(jsonb_agg(to_jsonb(r) order by reservation_id),'[]') from mobio_private.admin_role_reservations r where actor_id=${
          quote(admin!.id)
        }::uuid),'operations',(select coalesce(jsonb_agg(to_jsonb(o) order by operation_id),'[]') from mobio_private.admin_role_operations o join mobio_private.admin_role_batches b using(batch_id) where b.actor_id=${
          quote(admin!.id)
        }::uuid),'audit',(select coalesce(jsonb_agg(to_jsonb(a) order by id),'[]') from public.admin_audit_log a where admin_id=${
          quote(admin!.id)
        }::uuid),'snapshots',(select coalesce(jsonb_agg(to_jsonb(s) order by snapshot_id),'[]') from mobio_private.admin_user_snapshots s where actor_id=${
          quote(admin!.id)
        }::uuid),'cache_rows',(select coalesce(jsonb_agg(to_jsonb(r) order by r.snapshot_id,r.ordinal),'[]') from mobio_private.admin_user_snapshot_rows r join mobio_private.admin_user_snapshots s using(snapshot_id) where s.actor_id=${
          quote(admin!.id)
        }::uuid),'profiles',(select coalesce(jsonb_agg(to_jsonb(p) order by id),'[]') from public.profiles p where id in(${
          seeded.map((r) => quote(r.id) + "::uuid").join(",")
        })))::text`,
      );
    for (const state of ["missing", "future", "revoked", "idle", "absolute"]) {
      await restoreLease();
      const before = await effectSnapshot();
      const where = `where session_id=${quote(admin.sessionId)}::uuid`;
      if (state === "missing") {
        await fixture.sql(
          `delete from mobio_private.admin_session_leases ${where}`,
        );
      } else if (state === "future") {
        await fixture.sql(
          `with stamp as(select clock_timestamp()+interval '1 minute' value) update mobio_private.admin_session_leases set authenticated_at=stamp.value,last_activity_at=stamp.value from stamp ${where}`,
        );
      } else if (state === "revoked") {
        await fixture.sql(
          `update mobio_private.admin_session_leases set revoked_at=clock_timestamp() ${where}`,
        );
      } else if (state === "idle") {
        await fixture.sql(
          `update mobio_private.admin_session_leases set idle_expires_at=clock_timestamp()-interval '1 second' ${where}`,
        );
      } else {await fixture.sql(
          `with stamp as(select clock_timestamp() value) update mobio_private.admin_session_leases set idle_expires_at=stamp.value-interval '2 seconds',absolute_expires_at=stamp.value-interval '1 second' from stamp ${where}`,
        );}
      try {
        for (
          const [name, payload] of [
            ["rpc_admin_users_page", {
              ...query,
              p_snapshot_id: first.snapshot_id,
            }],
            ["rpc_admin_users_release_snapshot", {
              p_snapshot_id: first.snapshot_id,
            }],
            ["rpc_admin_role_status", { p_batch_id: pending.batch.batch_id }],
            ["rpc_admin_role_seal", { p_batch_id: pending.batch.batch_id }],
            ["rpc_admin_role_reserve", {
              p_reservation_id: null,
              p_snapshot_id: null,
              p_targets: null,
            }],
            ["rpc_admin_role_execute", {
              p_batch_id: null,
              p_operation_id: null,
            }],
          ] as [string, Json][]
        ) {
          denied(
            state + " Admin REST front door: " + name,
            await rpc(admin, name, payload),
            "42501",
            "ADMIN_REAUTHENTICATION_REQUIRED",
            403,
          );
        }
        check(
          state + " Admin denial has no target/audit/token/operation effects",
          before === await effectSnapshot(),
        );
      } finally {
        await restoreLease();
      }
    }
    leaseBackup = undefined;
    const foreign = success(
      "wrong-owner status hides plan",
      await rpc(fixture.admin, "rpc_admin_role_status", {
        p_batch_id: pending.batch.batch_id,
      }),
      fixture.admin,
    );
    check(
      "wrong-owner status returns no tuples or receipt",
      foreign.reservation_state === "absent" && foreign.batch === null &&
        equal(foreign.operations, []),
    );
    denied(
      "wrong owner cannot release existing snapshot",
      await rpc(fixture.admin, "rpc_admin_users_release_snapshot", {
        p_snapshot_id: first.snapshot_id,
      }),
      "42501",
      "ADMIN_USERS_SNAPSHOT_BINDING_MISMATCH",
      403,
    );
    denied(
      "wrong owner cannot execute existing plan",
      await rpc(fixture.admin, "rpc_admin_role_execute", {
        p_batch_id: pending.batch.batch_id,
        p_operation_id: pending.operations[0].operation_id,
      }),
      "P0001",
      "ADMIN_ROLE_BATCH_NOT_FOUND",
      400,
    );
    denied(
      "wrong owner cannot seal reservation",
      await rpc(fixture.admin, "rpc_admin_role_seal", {
        p_reservation_id: pending.reservation_id,
      }),
      "P0001",
      "ADMIN_ROLE_BATCH_NOT_FOUND",
      400,
    );
    denied(
      "wrong owner cannot reserve foreign snapshot",
      await rpc(fixture.admin, "rpc_admin_role_reserve", {
        ...pendingArgs,
        p_reservation_id: crypto.randomUUID(),
      }),
      "P0001",
      "ADMIN_USERS_SNAPSHOT_NOT_FOUND",
      400,
    );
    denied(
      "verified consumer cannot read Admin user queries",
      await rpc(fixture.consumer, "rpc_admin_users_page", query),
      "42501",
      "ADMIN_USERS_READ_REQUIRED",
      403,
    );
    denied(
      "verified consumer cannot release Admin snapshot",
      await rpc(fixture.consumer, "rpc_admin_users_release_snapshot", {
        p_snapshot_id: first.snapshot_id,
      }),
      "42501",
      "ADMIN_USERS_READ_REQUIRED",
      403,
    );
    for (
      const [name, payload] of [
        ["rpc_admin_role_status", { p_batch_id: pending.batch.batch_id }],
        ["rpc_admin_role_seal", { p_batch_id: pending.batch.batch_id }],
        ["rpc_admin_role_reserve", pendingArgs],
        ["rpc_admin_role_execute", {
          p_batch_id: pending.batch.batch_id,
          p_operation_id: pending.operations[0].operation_id,
        }],
      ] as [string, Json][]
    ) {
      denied(
        "verified consumer denied role authority: " + name,
        await rpc(fixture.consumer, name, payload),
        "42501",
        "ADMIN_ROLE_MANAGE_REQUIRED",
        403,
      );
    }
    await releaseSnapshot(
      admin,
      first.snapshot_id,
      "owner releases cache with immutable batch provenance",
    );
    const afterRelease = success(
      "released cache preserves outstanding reviewed tuples",
      await rpc(admin, "rpc_admin_role_status", {
        p_batch_id: pending.batch.batch_id,
      }),
      admin,
    );
    check(
      "release does not delete operation or change immutable plan",
      equal(afterRelease.batch, pending.batch) &&
        equal(afterRelease.operations, pending.operations),
    );
    const receiptAfterRelease = success(
      "released cache preserves matched receipt",
      await rpc(admin, "rpc_admin_role_status", { p_batch_id: bid }),
      admin,
    );
    check(
      "release cannot erase role audit receipt",
      equal(receiptAfterRelease.operations[0].receipt, receipt),
    );
    const original = admin;
    admin = await issueAdmin(adminPhone);
    check(
      "replacement Admin OTP retains owner and creates independent real SID",
      admin.id === original.id && admin.sessionId !== original.sessionId,
    );
    const previousAuth = await service.auth.getUser(original.accessToken);
    check(
      "canonical replacement revokes original GoTrue SID",
      !!previousAuth.error && !previousAuth.data.user,
    );
    const originalAttempt = await rpc(original, "rpc_admin_role_execute", {
      p_batch_id: pending.batch.batch_id,
      p_operation_id: pending.operations[0].operation_id,
    });
    check(
      "revoked original SID has no REST role authority",
      originalAttempt.status === 401 || originalAttempt.status === 403,
    );
    const replaced = success(
      "replacement SID discovers unresolved owned review",
      await rpc(admin, "rpc_admin_role_status"),
      admin,
    );
    check(
      "replacement discovery preserves immutable origin tuples",
      replaced.batch.batch_id === pending.batch.batch_id &&
        replaced.batch.origin_session_id === original.sessionId &&
        equal(replaced.operations, pending.operations),
    );
    const historical = success(
      "replacement SID reads old matched receipt",
      await rpc(admin, "rpc_admin_role_status", { p_batch_id: bid }),
      admin,
    );
    check(
      "receipt origin SID remains immutable after replacement",
      equal(historical.operations[0].receipt, receipt),
    );
    denied(
      "replacement SID cannot execute old reviewed plan",
      await rpc(admin, "rpc_admin_role_execute", {
        p_batch_id: pending.batch.batch_id,
        p_operation_id: pending.operations[0].operation_id,
      }),
      "42501",
      "ADMIN_ROLE_SESSION_CHANGED",
      403,
    );
    const closed = success(
      "replacement SID explicitly seals old review",
      await rpc(admin, "rpc_admin_role_seal", {
        p_batch_id: pending.batch.batch_id,
      }),
      admin,
    );
    check(
      "replacement seal proves prepared operation not started",
      closed.reservation_state === "sealed" &&
        closed.operations[0].status === "not_started" &&
        closed.operations[0].receipt === null,
    );
    const currentPage = success(
      "replacement SID creates newly bound snapshot",
      await rpc(admin, "rpc_admin_users_page", query),
      admin,
    );
    const currentRows: Row[] = [...currentPage.rows];
    for (let offset = 2; offset < 7; offset += 2) {
      const next = success(
        "replacement SID reads newly bound later page",
        await rpc(admin, "rpc_admin_users_page", {
          ...query,
          p_snapshot_id: currentPage.snapshot_id,
          p_offset: offset,
        }),
        admin,
      );
      currentRows.push(...next.rows);
    }
    const currentTarget = currentRows.find((row) => row.id === seeded[3].id)!;
    denied(
      "early reservation fence survives actual SID replacement",
      await rpc(
        admin,
        "rpc_admin_role_reserve",
        planArgs(early, currentPage.snapshot_id, [currentTarget]),
      ),
      "P0001",
      "ADMIN_ROLE_RESERVATION_SEALED",
      400,
    );
    check(
      "pending target remained unchanged through denial/recovery",
      currentTarget.role === seeded[3].role &&
        currentTarget.role_revision === seeded[3].role_revision,
    );
    result.passed = true;
    observe();
    return structuredClone(result);
  } finally {
    await restoreLease();
    await service.removeAllChannels();
  }
}
