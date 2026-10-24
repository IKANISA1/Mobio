# CR10 effective erasure inventory: local catalogue and adapter selectors

Prepared 2026-10-02 for the continuing 2026-10-01 readiness programme. This closes
the installed-schema/FK catalogue gap identified in `cr10-plan.md`; it does not
enable erasure processing or change an approved retention decision.

## Result and exact input boundary

A unique PostgreSQL-only fixture replayed **128 actual primary-checkout
migrations**, copied into a frozen evidence snapshot before execution. The chain
runs from `20260324125000_initial_schema.sql` through
`20261002010000_push_current_session_authority.sql`. It includes the activated
Admin addition `20261002003000_admin_user_snapshots_role_operations.sql`
(`a1f90792b6aa37b34c83c2f044905256f2b168c2028527c1a7c80cbd386346f1`)
and current-session push admission
(`2f4083aea19f983cd60719652a73d3f02da93977faede91697375a004112c1ac`).
No staged overlay was needed. Every copied migration matched its source hash
after replay; there were no added/removed migrations at that check. HEAD is
recorded for context, but the per-file manifest binds the dirty checkout inputs.
The first replay, before the necessary snapshot-release/bounded-query extension,
is preserved with its original hashes and report under `pre-release-extension/`.
The current catalogue was refreshed once after the final server refreeze; the
earlier catalogue is historical evidence, not current-boundary acceptance.

The fixture used Supabase CLI 2.84.2 and the local PostgreSQL image
`public.ecr.aws/supabase/postgres@sha256:965e2dfb5a23a0d6541b6106541e777b303656ebabd4e878746b189d550c0a66`.
All application services were excluded. `cron.launch_active_jobs=off` was checked
before application migrations and again in the catalogue. Auth/Storage schema
facts describe this pinned local platform bootstrap plus the replayed Mobio
migrations; they are not a verified copy of a hosted platform version.

| Effective object scope | Count |
| --- | ---: |
| Public application tables | 87 |
| `mobio_private` application tables | 29 |
| Auth platform tables | 23 |
| Storage platform tables | 10 |
| All tables / additional sequences | 149 / 4 |
| Effective FK edges | 221 |
| FK deletion: CASCADE / SET NULL / RESTRICT / NO ACTION | 127 / 48 / 24 / 22 |
| Direct subject deletion blockers | 9 |
| Tables with proposed exact or joined enumeration predicates | 107 |
| Shared/configuration/indirect tables requiring further scope classification | 42 |

The earlier static 106-table candidate trace is superseded **for this input
boundary** by 116 effective application tables, plus the exported platform
relations. The full catalogue covers every relation in the four named schemas,
including columns, types/defaults, constraints, incoming/outgoing FK actions,
indexes, triggers, owners, RLS policies, schema/table/column/sequence privileges,
and routine owners/security-definer configuration/effective execution grants.
Classification and selector proposals are separate from these schema facts.

Evidence is retained at
`build/qa/readiness-20261001/goal/cr10-effective-inventory/`:

- `source-before.json`, `migration-snapshot/`, `source-after.json`: exact source
  inputs and stability, including the two additions named above.
- `catalogue.sql`, `catalogue.json`, `effective-schema.sql`: SQL query, actual
  installed-catalogue result and schema-only dump, preserving owners/ACLs.
- `foreign-keys.tsv`, `subject-edge-risks.json`, `catalogue-summary.json`: complete
  edges and the focused account-deletion hazards.
- `relation-selector-map.json`, `read-only-selectors.sql`: all-table field/edge
  coverage and bounded enumeration templates, with unclassified scope explicit.
- `fixture-row-counts.json`, `fixture.json`, `cleanup.json`, replay/start/stop
  logs and `artifact-hashes.json`: local context, data limits, cleanup and hashes.

Core retained SHA-256 bindings:

| Artifact | SHA-256 |
| --- | --- |
| `catalogue.json` | `bc12ea33c52899264252a3634adff25d67f083da13805194aa8f2dbaef6dca98` |
| `effective-schema.sql` | `f1acfc20e200990b5f92c6b39cf13c9de6f39d6590e20c1dd061de51e382da9f` |
| `catalogue.sql` | `a01d1e48834f77864cb58c03bd3bd3816ece2eccc36da3f4e1c107efff2bd2cc` |
| `source-before.json` | `6acd459dc54ace8ea7574a7f023ea54ff006e42a9d671646365d4e474320c56d` |

## Effective access and deletion hazards

Application tables are owned by `postgres`; the 23 Auth and ten Storage tables
are owned by their respective platform administrators. Of 149 tables, 142 have
RLS enabled and none force RLS. The seven without RLS are platform Auth OAuth
and WebAuthn tables; this is a bootstrap catalogue observation, not a test of
hosted/API exposure. Owner/security-definer and BYPASSRLS behavior must therefore
be evaluated separately from row policies. Effective grants do not imply an
authorized row, reachable API or safe physical deletion.

The new Admin tables, Maps counter, privacy tables and permanent review registry
have no direct anon/authenticated/service-role table privileges and no permissive
client policy. A service-role client's BYPASSRLS does not supply missing table
privileges. Future fixed adapters need reviewed server-only entry points; do not
grant a generic private-table deletion facility. The platform `storage.objects`
catalogue has broad table grants, 18 row policies and a `protect_objects_delete`
trigger. RLS does not govern TRUNCATE. Those grants are not erasure authority;
use scoped Storage operations and verify physical bytes, never blanket SQL
TRUNCATE or direct metadata deletion.

The final `rpc_admin_users_release_snapshot(uuid)` is owned by `postgres`, uses
an empty search path, and is executable by authenticated callers, not anon or
service-role callers. Its source requires exact existing actor/SID and base read
authority and removes only that actor's cache snapshot/rows, leaving durable
batches/operations/receipts. It supports reclaiming superseded actor-owned cache;
it is not a general erasure entry point for another actor's subject-bearing rows.

The nine direct blockers to removing an Auth/profile subject are:

| Referencing columns | Effective action | Required decision before implementation |
| --- | --- | --- |
| `mobio_private.wallet_operations.owner_id → auth.users.id` | RESTRICT | Preserve committed financial receipts/idempotency and unresolved operations; define a retained representation that permits Auth absence. |
| `campaign_approvals.requested_by`, `approved_by`, `sent_by → profiles.id` | RESTRICT (three edges) | Preserve shared campaign content/approval history; approve actor detachment or retained representation. |
| `biopay_provider_routes.tested_by`, `reviewed_by → profiles.id` | NO ACTION (two edges) | Preserve shared route/test evidence; approve actor representation without keeping an active account. |
| `momobio_collectors.enrolled_by`, `momobio_collector_events.actor_id → profiles.id` | NO ACTION (two edges) | Preserve collector custody/security and other payers' SMS evidence; decide operator attribution separately. |
| `token_redemption_requests.admin_profile_id → profiles.id` | RESTRICT | Preserve redemption/counterparty facts and cash reconciliation; approve retained Admin attribution. |

Further graph hazards confirmed in the effective catalogue:

- `profiles.id → auth.users.id` cascades. Profile deletion cascades into both
  sides of wallet transfers, the subject's ledger entries and redemptions,
  inviter referral events, bookings and their payment children, scheduled posts,
  chat conversations and messages, reports/blocks, subscriptions and entitlements.
  These are shared financial, safety, chat and booking facts, not a safe generic
  owner-only deletion tree. `token_redemption_requests.wallet_transfer_id` also
  restricts transfer deletion; multiple child paths can block or destroy evidence.
- Chat participant/creator and sender references cascade. Removing a subject
  can remove messages written by another participant through the conversation
  cascade. Inspect/redact the permitted subject content and preserve counterparties.
- `admin_audit_logs.admin_id` cascades from Auth, whereas
  `admin_audit_log.admin_id` is SET NULL from profiles. These similarly named
  tables require different handling. Admin role operations reference
  `admin_audit_log.id` with NO ACTION; deleting a referenced audit entry breaks
  durable receipt provenance.
- SET NULL on BioPay payer/payee/session-user references, agency driver,
  operational/auth audit actors and other fields leaves copied labels, phones,
  identifiers, JSON and free text. A NULL FK is not anonymization.
- Auth deletion cascades authority bindings/proofs, Admin leases, actor-owned
  Admin snapshots and the Maps account quota. Snapshot rows mentioning a subject
  **under another Admin actor's snapshot remain** unless explicitly found by
  `target_id`/frozen payload.
- Durable Admin role batches/reservations/operations and privacy cases have no
  cascading subject/SID/target FKs. That deliberately preserves recovery and
  evidence, but means deletion needs explicit selectors and approved treatment.
- `store_review_principals` has no Auth FK and triggers rejecting UPDATE, DELETE
  and TRUNCATE. Preserve its permanent UUID deny tombstone. Erasure must never
  restore production authority to a previously registered review UUID.
- Storage object ownership has no cascading Auth/profile relationship. Profile
  deletion cannot remove metadata or physical objects. Face cleanup similarly
  requires an explicit captured vector-ID set before source rows disappear.

## Fixed adapter selectors and fields

Capture a subject manifest **before** removing Auth/profile source rows: exact
UUID; all verified historical Auth SIDs; verified current/historical phone/email
aliases with provenance; member ID; related conversation, booking, request,
operation and object IDs; exact vector/model/provider IDs; and available device
or processor identities. Use bound values, not names as identity. Phone/member
matches can be historical or recycled and require provenance review.

`read-only-selectors.sql` contains enumeration templates only. Its parameters are
subject UUID, verified phone aliases, captured member ID, captured Auth SIDs,
verified email aliases and captured face vector IDs. They were derived from the
exported column/edge catalogue; this task did not execute them against real
subjects or implement a deletion adapter. The JSON map records every table's
text/JSON fields, exact predicates where available and remaining classification.

| Fixed adapter / exact row selectors | Content and counterparty treatment to decide |
| --- | --- |
| Auth/authority: `auth.users.id`; `sessions.user_id`; identities/factors/OAuth consents/authorizations/one-time tokens/WebAuthn by `user_id`; MFA challenges by factor IDs and AMR claims by SIDs; `refresh_tokens.user_id = UUID::text` or captured SID; flow state `user_id` **or** `linking_target_id` | Capture identifiers, revoke eligibility and pending work first; remove through supported Auth authority and independently probe Auth/session absence and old-token denial. Flow/linking state and Auth audit JSON do not all have owner FKs. Global OAuth/SSO/provider config is shared, never delete it by creator inference. |
| App/Admin authentication: `whatsapp_identity_bindings.user_id`, `consumer_session_proofs.user_id/session_id`, `admin_session_leases.user_id/session_id`; `otp_codes.profile_id OR phone = verified aliases`; app/access attempts and allowlist by exact phone | Include canonical phone, OTP reference, code/hash fields, attempt metadata and display name. Preserve shared security controls. OTP phone buckets are salted hashes of `otp:{app_login|admin_login}:{phone_resend|phone_hour}:{phone}:{secret}`; compute exact keys only inside the existing privileged secret boundary. Source/IP/App Check/user-agent and global buckets are shared; do not account-delete them. |
| Review registry: `store_review_principals.user_id`; settings/changes/challenges/leases by user and captured SIDs | Permanent principal tombstone remains. Challenges retain phone/code hashes and settings/change records can contain identifying free-text references. Approve their classification without weakening the permanent guard or inventing a retention duration. |
| New Maps counter: `mobio_private.maps_account_quota.user_id` | Actual fields are UUID, window start and request count, not stored Maps queries/coordinates. Auth cascade removes this local row. The five-minute quota window is behavior, not an approved retention period or Google-log deletion proof. |
| Admin snapshot cache: `admin_user_snapshots.actor_id/session_id`; rows by `target_id`, `row_payload->>'id'`, or actor-owned snapshot IDs | Frozen payload includes name/display name/phone/member ID and profile fields; actor search text may contain another person's identity. Expire/invalidate affected handles before purging subject-bearing cache rows so frozen totals/reviews do not silently change. Existing ten-minute expiry and bounded cron sweep are cache behavior, not durable receipt retention approval. |
| Admin durable role records: batches by `actor_id/origin_session_id`; reservations by actor; operations by target or actor-owned batch; receipt `actor_id`, `target_id`, `session_id` | Include `display_label`, `member_id`, expected/requested role and driver state, revisions, audit ID, operation/reservation IDs and receipt JSON. Reconcile and explicitly seal outstanding reservations before clearing device pointers; preserve the no-replay/late-reserve fence. Any approved redaction/detachment requires a reviewed receipt/validation representation, not ad hoc edits that invalidate immutable tuples/hashes. |
| Profile/discovery: `profiles.id`, driver locations by `driver_id`, vehicles by `owner_id`, saved/favorite addresses by owner/profile, trips by `author_id`, membership/permissions by `profile_id` | Include names, phone/WhatsApp/MoMo identifiers, plate/model, avatar URL, location coordinates, address text/IDs, authored copied name, route labels and note/description. Actor fields on shared reference records are separate. Cancel eligible future posts through existing scheduled-post semantics; do not invent ride lifecycle or routing capabilities. |
| Chat/safety: conversations where participant-low/high/creator UUID matches; messages where sender matches **or** conversation is in that captured set; delivery operations and send clock by owner | Scope both authored content and shared conversation preview/metadata. Include report/block sides, reviewed-by actor, details/resolution notes and trip/conversation edges. Fence pending delivery, preserve other participants' messages and approved safety evidence. A body/name match alone is not deletion authority. |
| Wallet/referral/subscription: exact sender/receiver, ledger profile/counterparty, requester/Admin, inviter/invitee and subscription/request profile keys; private operation owner **or** `request.receiver_id/receiver_member_id` | Include wallet notes, ledger metadata/reference, redemption MoMo/Admin-member IDs and notes, referral install/device hashes, payment/SMS references and receipts. Retain shared balances, totals and uniqueness/reconciliation facts under a still-unapproved representation. Account deletion must not replay, refund or fabricate a financial settlement. |
| Public transport: bookings by passenger; payments via selected booking IDs; agency bus current-driver and location events via that bus | Include passenger name/phone, ticket/payment/provider reference and metadata. Driver-attribution joins describe current association, not historical ownership of every bus heartbeat; examine trusted-source metadata/history. Preserve other tickets, seats, schedules, fleet and counters. Seat holds and legal holds are distinct. |
| BioPay discovery/handoff: methods/drafts/links/shortcuts/templates/quotes by owner; method grants by grantee or owned method; payer/payee requests and child USSD/audit rows by captured request IDs | Include receiving/login identifiers, recipient lookup/nickname, label/purpose/reference, reviewed snapshot and draft/input/options/template JSON. Another owner's shortcut may contain the subject's phone/handle without FK: exact verified lookup tokens are candidate discovery only until semantics/provenance are confirmed. Preserve counterparties' handoff/confirmation facts. |
| Face: BioPay profile user, session/provider-operation user or request, face revision owner; cleanup by captured `vector_id` | Union current `provider_subject_id`, `pending_vector_id`, revision vector IDs and provider operation/session/face/collection IDs **before** cascades. Preserve model/provider namespace. Reuse scoped Vectorize `/delete` then `/absent`; retain durable cleanup against late upserts. No index/collection-wide deletion. Historical AWS identifiers require the actual legacy account/region/collection and separate evidence. |
| Push/notifications: token `user_id/session_id/binding_id`, consent/profile, notification/delivery-attempt user and linked token/notification; private events/jobs owner | Fence queued/leased work and verify final current-session admission. Include registration metadata/device label, audience/body/route metadata, provider errors/receipts. The added push admission migration prevents stale-session dispatch but cannot retract requests already authorized/dispatched. Shared campaigns/content/approvals are separate. |
| Collector/SMS: parsed receipts/transactions by exact payer phone or subject-owned payment/subscription IDs; intake via selected `receipt_id`; collector operator/event by enrolled/actor UUID | Raw SMS, payer name/phone/reference and parsed metadata can identify a subject without owner FK. Unparsed/unmatched intake requires a reviewed content/reference scan; a collector ID is custody, not exclusive payer ownership. Preserve other payers' receipts, allocation controls and unresolved money evidence. |
| Audit/privacy: Admin actor and profile-typed target/entity; health `user_id` or profile/user-typed `subject_id`; privacy request owner and actions/evidence via request IDs | Include actor reference, copied JSON/text, notes and identifiers after SET NULL. Other polymorphic target/subject types require their captured typed IDs, never blind UUID matching. Privacy case records intentionally survive; existing completion requires an approved explicit retained exception. |
| Storage: objects `owner = UUID`, `owner_id = UUID::text`, plus avatars whose first folder equals UUID; ticket ownership and captured reference URLs; multipart upload owner/key prefix and parts via upload ID | Join known profile/avatar, QR/ticket/media output paths to bucket/object IDs, include metadata/user metadata and versions, and resolve mismatched/legacy owner/path records. Inventory multipart sessions before removing references. Admin-created media/promo assets and buckets are shared. Platform vector/analytics/iceberg relations are not user-owned merely because the schema exists. |

JSON equality scans in the retained SQL use exact UUID leaf values with bound
variables and named, catalogue-confirmed JSON columns. These are **candidate
discovery**, not typed ownership or authorization. Known selectors include
wallet `request.receiver_id`, Admin frozen `row_payload.id`, and role receipt
`actor_id/target_id/session_id`; other metadata/draft/audience/Auth audit shapes
need reviewed key semantics. The map lists all 149 tables' JSON/text fields,
including shared/configuration relations, so absence of a direct FK never becomes
`not_applicable` by inference.

Free-text handling is scoped to enumerated rows and approved fields: chat
`body/last_message_preview`, trips `author_name/whatsapp/note/description`, report
`details/resolution_notes`, wallet `note/admin_note`, campaign `body/approval_notes`,
notification `title/body`, operational `message`, raw SMS and actor/change refs.
Residual mentions in another owner's rows or shared metadata need controlled
candidate review. Names and substring phone searches produce false positives;
do not automate global text deletion from them. Late writes and previously
detached records require a future write fence and actual data reconciliation.

## Device, physical Storage and external selectors

| Store | Concrete lookup/boundary | Evidence still required |
| --- | --- | --- |
| Native Auth session | `rw.mobi.app/secure_session` namespace = SHA-256 of normalized Supabase origin; session-persistence issuer/UUID/SID binding; legacy `sb-<project>-auth-token` and SDK session constant | Use acknowledged `lockAndClear`/native completion tail and scoped legacy-key removal. Actual device/keychain/keystore absence and late-write rejection are untested here. Web/non-mobile current storage is memory; that does not erase older browser records. |
| Chat/device wallet | `mobio.chat.pending.v1.<owner>.<conversation>`; `mobio.wallet.operation.v2.<owner>` | Clear only verified owner pointers after canonical closure. Unowned legacy `mobio.pending.wallet-transfer:`/`wallet-redeem:` keys cannot be attributed safely from a new session. Offline devices need separate acknowledgment. |
| BioPay draft / new Admin journal | `biopay.draft.<userId>:<sessionId>`; `mobio.admin.role-recovery.v1.<base64url(hostIdentity)>.<actorId>` | Enumerate verified historical sessions/project identities; serialize clears against pending persistence. Admin pointer contains reservation/SID/generation, not frozen recipients, and must not be cleared to evade unresolved server recovery. |
| Face/QR files and gallery | Capture code deletes the exact temporary camera path in `finally`; QR share writes `<temporary-directory>/<fileName>` and save uses native gallery channel | Verify real file cleanup and deletion receipts. There is no catalogue-derived subject file index for older exported QR/gallery/shared copies. Retain captured path/asset IDs and distinguish owned cache from user exports/recipients' copies. |
| Collector device | `momobio_receipts.db`: `receipts`/`overflow_receipts` payloads selected by captured message hash and verified payer/reference context; refusal/acknowledgment records separately | The SQLite queue deliberately preserves unresolved money evidence and quarantines expiry instead of discarding it. Actual enrolled collector/device custody, legacy queue copies, subject matching and approved shared-financial treatment remain open. No remote wipe or whole-DB deletion. |
| Supabase Storage/CDN | Captured `(bucket,id,name,version)` and multipart upload IDs, plus known public URLs | Storage API byte deletion, multipart cancellation, fresh listing and URL/cache probes. This fixture has no Storage API/blob backend. Removing SQL metadata or a profile cannot prove byte/CDN erasure. |
| Cloudflare face/inference | Captured vector IDs in exact model/index binding; separate AWS collection/face/session IDs if present | Scoped provider call, independent absence probe, cleanup of late writes and account binding. Stateless/no-image-log source behavior is not proof of deployed infrastructure logs or historical data absence. |
| Firebase/Google | Supabase UUID Analytics user ID; separately captured anonymous Firebase UID, app instance/installation/FCM token and linked exports | Analytics `setUserId(null)` only detaches future context; historical Analytics/Crashlytics/FCM/Maps/provider records require actual project/export linkage and supported deletion/manual evidence. Parallel optional Firebase anonymous identity is not automatically the Supabase UUID. |
| WhatsApp/OpenAI/support/other processors | Exact OTP/provider message IDs, phone, raw-SMS request/processor identifiers, promo output/job IDs, support case IDs | Verify actual account/contract/capability and obtain scoped response/probe or an approved exception. OpenAI `store:false` in raw-SMS parsing is a request flag, not independent erasure/retention evidence. External dialer/WhatsApp recipient records are not remotely controlled by SQL erasure. |
| Backups/logs/exports | Actual database/PITR/Storage backup IDs, log stream/tenant and export/case manifest identifiers | Inventory actual copies, access and restored-data safeguards with accountable approval. No backup was examined and no retention schedule or erasure date is asserted. |

The Admin service worker currently avoids caching application/API data and
returns a no-store offline response. Its code deliberately preserves clients'
legacy caches/sessions/drafts. This source fact does not establish cleanup of an
offline browser, earlier worker cache, exported file or another device.

## Implementation-ready decisions and remaining gates

Reuse the existing privacy request/evidence/action state machine and its fixed
ten categories: `sessions`, `auth`, `profile_and_activity`, `financial_records`,
`delivery_journals`, `storage`, `face_vectors`, `processors`, `backups`, and
`privacy_case_records`. The effective catalogue does not introduce an automatic
processor, execution-task/worker-lease or legal-hold implementation.

Required decisions before enabling processing are concrete:

1. Approve owned-content erasure versus shared financial/chat/booking/safety
   retention or redaction, with accountable basis and duration where required by
   the existing workflow. Preserve permanent reviewer UUID deny semantics.
2. Approve retained/detached representations and forward constraints for the
   nine direct blockers, other shared cascade paths and durable Admin receipts.
   Keep immutable/idempotency/reconciliation semantics; do not retain an active
   Auth row to bypass the Auth-absence completion check.
3. Approve actual subject-manifest/typed selectors, unmatched SMS and free-text
   review, shared reference/configuration treatment and any historical identifiers
   discovered in real data. The 42 unclassified reference/indirect relations are
   enumerated explicitly in `relation-selector-map.json`; they are not omitted or
   declared not applicable.
4. Implement bounded server-only adapters with future-write fencing, canonical
   recovery/seal behavior, operation receipts, leases and cancellation/unknown
   handling. Fixed selectors must not become arbitrary SQL/bucket/provider calls.
5. Obtain actual Storage/vector/provider/device/backup evidence and approved
   exceptions, then bind independently verified results to the existing request,
   subject, action/revision, inventory/plan hashes and category evidence. Preserve
   `auth/sessions = deleted` and `privacy_case_records = retained` requirements.

No retention period or legal-hold determination is supplied by this inventory.
The dated approved BioPay/USSD and public-transport scope documents remain the
product boundary; this work does not remove their supported capabilities or add
ride dispatch, routing, automatic settlement or refund machinery. Their older
implementation-gap prose is not treated as current catalogue evidence.

## Evidence limits and cleanup

Auth users, Auth sessions and Storage objects were all **zero** in this local
fixture; four Storage bucket metadata rows were seeded by migrations. Counts for
all 149 tables are retained and explicitly marked synthetic replay data. There
was no real subject sample, hosted SQL/Auth/Storage operation or deletion,
processor/provider call, physical blob inspection, backup examination, Flutter
test/build or runtime/migration change as part of the catalogue work.

The final owned project `mobio_cr10_9e24839e6d69` was stopped without backup. Exact
checks confirmed its containers, volumes and network absent, and its unique
temporary workdir removed. Only the evidence snapshot/artifacts and this new
report remain. Existing `cr10-plan.md`, `docs/compliance/data-inventory.md` and
original review were not edited. Separately authorized CR08/09 query-control
integration updated the owned users screen and its presentation tests while
this final schema replay ran; those changes are outside the CR10 evidence scope.

**Closed:** effective schema/columns/FKs/deletion actions/owners/RLS/grants
catalogue for the frozen boundary, including new authority/review, Maps and Admin
records. **Open:** actual data/physical/external coverage, policy approvals,
retained representation changes, execution adapters and independently verified
completion. Local catalogue export is not production erasure readiness.
