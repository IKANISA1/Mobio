# Mobio — critical whole-system production-readiness review

**Review date:** 1 October 2026, Africa/Kigali. **Decision:** RED / NO-GO for unrestricted production release. **Purpose:** assess the current system and provide an actionable remediation and acceptance plan; this review does not authorize deployment or feature activation.

**Post-review continuation:** [The full implementation goal](mobio-readiness-review-2026-10-01/implementation-goal.md), [batch 01](mobio-readiness-review-2026-10-01/remediation-batch-01.md), [batch 02](mobio-readiness-review-2026-10-01/remediation-batch-02.md), [batch 03](mobio-readiness-review-2026-10-01/remediation-batch-03.md), [batch 04](mobio-readiness-review-2026-10-01/remediation-batch-04.md), [batch 05](mobio-readiness-review-2026-10-01/remediation-batch-05.md) and [batch 06](mobio-readiness-review-2026-10-01/remediation-batch-06.md) record subsequent local corrections, verification and remaining work. The findings and evidence below describe the original review snapshot.

## 1. Executive assessment

Mobio has a substantial implementation and meaningful recent hardening. It is beyond a prototype, but it is not a demonstrated clean, production-ready system. The strongest remaining problems concern effective server authorization, the store-review login boundary, iOS integration, administrative outcomes, privacy execution, independent CI/promotion controls, and full route/state acceptance. Several historical findings have been fixed locally; repeating them as current defects would obscure the remaining work.

The leading source finding is an organization-permission helper that accepts ordinary active membership without honoring the requested permission. A newer booking-confirmation RPC trusts that helper. Removing direct table writes therefore does not by itself prevent unauthorized paid-booking confirmation. A separate fixed store-review OTP issues an ordinary consumer session without a demonstrated isolated demo realm. Neither finding was exercised against production accounts or payments.

The recommended approach is a controlled remediation of the existing architecture. Preserve the Flutter feature boundaries, Riverpod composition, GoRouter routes, shared packages, approved product scope and sole design authority. Fix the authority and lifecycle defects first; then complete outcome and platform acceptance. A wholesale rewrite would increase regression risk without resolving the unverified external controls.

| Surface | Assessment | What prevents a production claim |
|---|---|---|
| Android consumer app | Substantial source and a current signed local APK | Full suite/visual acceptance, representative physical-device journeys, provider/store evidence and protected promotion |
| iOS consumer app | Shared implementation, platform integration gaps | Location permission compilation, unsolicited NFC session behavior, signed current archive, Firebase/APNs and physical-device acceptance |
| Consumer web/PWA | Current local bundle and strong worker fixtures | Actual deployed shell/access, real browser authentication, capability/permission behavior, installed offline/update/recovery acceptance |
| Public website | Pages and notices implemented; public HTTP checks succeed | Contradictory terms, loaded typography/licensing and full responsive/accessibility checks, live security headers and conversion/store evidence |
| Admin panel | Broad local operational implementation | Authorization/step-up coverage, latest-request ordering, truthful list totals/sorting, privilege-change review, authenticated deployed tasks |
| Supabase | 119 source migrations, newer hardening and passing local Deno checks | Remaining permission composition defects; hosted Auth/RLS/PostgREST readback and representative forward-upgrade rehearsal |
| Institutional SMS collector | Separate utility with durable ingestion controls | Dedicated-device acceptance, trustworthy receipt reconciliation, recovery, enrollment/revocation and operational sign-off |
| Optional Face-USSD | Approved bounded noncustodial implementation | Recipient moderation, real model/cohort acceptance, consent/deletion, deployment/capacity and physical operator handoff |
| Release and operations | Candidate manifests and approval validators are implemented | Hosted CI startup failures, unprotected `main`, no environment review rules, independently verified release receipts, restore/incident exercises |

These are separate results. A local test pass does not cancel an authorization defect; a signed APK does not establish store approval; an HTTP 200 does not establish a working authenticated application; a gallery does not establish visual fidelity.

## 2. Scope, source identity and evidence method

Reviewed workspace: `/Volumes/PRO-G40/Projects/Recovered-G-PRO/Mobio`. Local branch: `main`. HEAD and live remote `main` both read as `9aa98e8cf5173fe7e3565f52cae37b14b9560785`. The working tree contains pre-existing modified, deleted and untracked files, particularly current design, profile, BioPay, login, website and operator-app work. Those edits were preserved. The commit alone does not identify the reviewed candidate.

The current UI fingerprint is **771 files**, SHA-256 **`77d2b7b029e20ed2430eb7c3d06d91da7bd84ebd4050420c268babd3c87038fa`**. The source inventory covers **3,247 existing tracked/nonignored untracked files**, excluding sensitive-name configuration. It includes 286 files under `lib`, 50 under `packages`, 226 under `supabase`, 138 under `scripts`, 370 under `test`, 93 under `android`, 49 under `ios`, 63 under `apps`, 18 under `landing`, 10 under `cloudflare`, 17 under `services`, and 1,564 under `docs`. These counts include assets, tests, generated source and preserved historical snapshots; they are not counts of independently reviewed implementation units.

The review combines complete repository/path inventory, instruction and scope reconciliation, risk-based semantic tracing of current first-party code, independent backend/mobile/design reviewers, existing source-bound screenshots and build records, fresh local checks, read-only GitHub state and public HTTP probes, and current official documentation. It is broad whole-system coverage, **not a line-by-line proof of every statement, a penetration-test certification, or acceptance of every route/state**. Historical archives were inventoried and assessed for provenance/cleanup; their contents were not independently re-audited as active runtime code. No dependency upgrade, production data mutation, deployment, provider payment, or store publication was performed.

The review uses these states:

- **Confirmed source defect:** current code establishes the problematic path; runtime exposure is stated separately.
- **Observed failure:** a current check or external readback returned failure; its scope is retained.
- **Partial evidence:** implementation or bounded tests exist, but the complete acceptance criterion is not proven.
- **Unverified gate:** required deployed, device, provider, legal/operational or independent-review evidence is unavailable.
- **Not applicable:** outside the approved product or the named platform, with a reason.

P1 means repair before enabling the affected surface or broad release. P2 means a material correctness, supportability or usability improvement. Optional disabled features have their own activation gates; their defects must not be represented as proof that every core marketplace journey is broken.

Detailed companion reviews and complete checklists are in [the report pack](mobio-readiness-review-2026-10-01/README.md). The raw command logs are under `build/qa/readiness-20261001/`; sanitized durable summaries are retained in the report pack.

## 3. Product and design constraints

The active product preserves nearby discovery, profile/vehicle browsing, WhatsApp handoff and chat, scheduled trip posts, and basic moderation. Dated approvals additionally govern current BioPay discovery, public transport and the institutional collector. The [20 September Face-USSD approval](../product/face-ussd-20260920/APPROVAL.md) supersedes older AWS/liveness requirements for that shortcut. Face recognition remains an optional receiving-account lookup followed by an external, amount-free operator handoff; it is not face-only login or evidence that a payment completed.

Do not add automatic dispatch, ride start/complete lifecycle, fare quotes, route ETA/distance, route polylines/matrices, trip-settlement ledgers or in-app ride payment execution. Keep `compute_route` unavailable. A transport remediation must remain inside its exact dated approved booking authority; it must not become a generalized ride-hailing refund or settlement project.

The external [revolut-design skill](</Volumes/PRO-G40/Application Data/Codex/Codex-Home/skills/revolut-design/SKILL.md>) and its bundled references remain the sole visual authority. Its selected typologies, full applicable colors, typography and states apply while preserving Mobio identity, tasks and capabilities. The audit uses its quality standard, operational checklist and all 100 design checks. No competing visual specification is introduced.

Current records acknowledge **766 baseline obligations / 2,170 declared platform pairs**, later theme expansion, an unresolved final applicability denominator, **zero complete accepted cases**, and **all 21 closure packages still open**. Zero accepted cases is an acceptance statement, not a claim of zero implementation quality. The privacy request screen is a pushed route outside the main router and must be explicitly included in that denominator.

## 4. Current verification and external readback

Fresh verification results are consolidated in [verification-summary.json](mobio-readiness-review-2026-10-01/verification-summary.json). Counts from overlapping historical or focused runs are not added together.

| Fresh check | Actual result | Evidence boundary |
|---|---|---|
| Pinned Dart analysis | Exit 0; 200 informational findings; no errors/warnings | Static analysis, not runtime/device acceptance |
| Full Flutter suite | **1,595 passed / 169 failed**, exit 1 | 163 reference golden mismatches, five payment-discovery golden mismatches, one obsolete AWS-copy source assertion |
| Python helper suite | **483 passed**, exit 0 | Includes local candidate, gate and fixture tests; does not certify referenced external evidence |
| Local backend verifier | **116 passed / 0 failed / 1 ignored**, checks and secret pattern scan pass | Linked security checks skipped; ignored paid-provider test remains unexecuted |
| Pages/admin worker fixtures | **69 passed** | Local HTTP/cache/recovery fixtures |
| Payment-link worker tests | **3 passed** | Local routing fixtures |
| Face-service worker fixtures | **7 passed**, independently run by backend reviewer | Fake/synthetic contracts, not real model/provider acceptance |
| Structure / design authority / migration manifest / Actions pins | Passed | Bounded repository controls; not actual hosted CI |
| Secret-history / whitespace | Passed | History check covers one forbidden path; whitespace is not semantic approval |
| Public-site source verifier | Passed | Source phrases/files/association shape; not complete browser/conversion/legal acceptance |

The one non-golden Flutter failure expects `AWS-backed face enrollment` in the iOS camera description (`test/release/scope_boundary_test.dart`). Current purpose text describes the actual optional face/QR use; the 20 September approval selects Cloudflare/OpenCV. This is an obsolete test-contract expectation to reconcile with approved scope, not evidence that AWS should be restored. The 168 golden mismatches remain unaccepted comparisons; they are neither automatically 168 independent runtime defects nor automatic permission to update baselines. No complete green Flutter result is claimed.

Existing build evidence was reused after checking changed inputs:

- The current sanctioned APK record identifies `rw.mobi.app`, version code 17, target SDK 36, a verified release signature and the current UI source fingerprint. The retained APK's actual SHA-256 matches **`3cd9ed58ba0652a8d33f0c08149bcce5a032e8b23de89327a8a7fadde60a75b5`**. This review rehashed the binary; it did not repeat its signature/device review.
- The current sanctioned web record is bound to the same UI source. Its actual retained file hashes were read back. It explicitly leaves browser visual acceptance unverified.
- All four required public build values are currently present in the private root configuration. Values were not copied into this report. Earlier reports saying they were absent describe a prior state.
- Android and collector source now target API 36. The old API-35 gap must not be carried forward. Current Play guidance requires API 36 for new/update submissions from 31 August 2026, subject to the console's actual extension state. Source/API compliance alone does not prove an upload was accepted. [Google Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en).

Live GitHub readback confirms `main` is **unprotected**. Branch-protection/ruleset endpoints return a plan-related 403, and both `Mobio` and `SUPABASE_URL` environments have empty protection-rule lists and permit administrator bypass. The exact HEAD has eleven listed workflow runs, all `startup_failure`, including its push run [36751487014](https://github.com/IKANISA1/Mobio/actions/runs/36751487014). Recent newer dependency-PR runs also show startup failures; the newest queried PR run has zero jobs. The cause was not established. Workflow YAML, action pins and local validators are useful controls but are not successful hosted CI.

Plugin Management identified installed GitHub and Supabase integrations. The GitHub connector returned 404 for this private repository; the existing authorized GitHub CLI provided the successful read-only evidence. The connected Supabase account did not list the configured Mobio project, and no local linked-project reference exists. Hosted migration/Auth/RLS assertions therefore remain unverified; a different accessible project was not used as a substitute.

Public HTTP checks returned 200 for the website, privacy/deletion pages and Android/iOS association documents. App/admin probes returned 403/503 depending on path/request context. These probes did not establish authenticated browser access or the deployed artifact identity. `/app/` and `/client/` are not canonical consumer routes in the current worker and must not be cited as failed app routes; the canonical `/home` and `/admin-auth` probes are retained separately. Sampled public responses had `nosniff`, frame denial and referrer policy but lacked CSP and HSTS. The report treats this as a live delivery/hardening observation, without assuming that a TLS hostname is compromised or that an authenticated admin session was exposed.

## 5. Prioritized findings and acceptance

The finding identifiers below are local to this review and cross-reference existing M/G controls rather than replacing the 95-item register. Exact line anchors, source excerpts, uncertainty and detailed acceptance cases are in the specialist companion reviews.

### CR01 — Organization membership is substituted for permission authority — P1, confirmed source defect

`can_access_organization(uuid,text)` in `20260501090000_tenant_permissions_storage_realtime_hardening.sql` has a membership branch that ignores `p_permission` and membership role; its separate platform-permission branch does evaluate the requested permission. Historical profile seeding creates active memberships for ordinary users. The newer `rpc_confirm_bus_booking` in `20260929215434_mobio_hardening_transport_hold_receipt_integrity.sql` trusts that helper and is callable by `authenticated`. It can accept caller-supplied provider/reference and persist paid state for an accessible organization. The recent direct-table-write fix does not close this RPC path.

**Action/owner:** backend/security owner; introduce explicit organization-role/permission evaluation for trusted confirmation and related administration. Retain service-only/provider-authoritative confirmation where required. Audit every caller of the helper. **Acceptance:** actual full-schema PostgREST tests deny member/viewer/driver cross-role and cross-organization confirmation, deny invented payment evidence, allow only authorized server/operator transitions, and preserve seat/receipt concurrency invariants. Map to M004/M015/M024/M079 and G03. Hosted exploitability and deployed data were not tested.

### CR02 — Fixed review OTP uses ordinary consumer authority — P1, confirmed boundary gap

`_shared/play-review-login.ts`, `send-login-otp` and `verify-login-otp` implement a fixed store-review identity/code with no demonstrated environment/expiry control or isolated data realm. The branch skips normal delivery/integrity/rate-limit checks and reaches regular Auth session/profile creation. A public review page also documents the bypass. Store review access is legitimate; ordinary production authority attached to publicly known review access is the risk.

**Action/owner:** auth/security and release owner; supply an isolated synthetic review account/mode with server-enforced permissions, denial of real-user transactions/communications/privilege changes, controlled enablement and rotation. Do not publish the code in general documentation. **Acceptance:** the review session can complete the declared store-review tasks but cannot reach real-user private data, change grants, confirm payments, send real broadcasts or mutate production records; rotation/disablement invalidates further access. Map to M003/M012/M052/G01. P0 escalation would require evidence of sensitive real authority/exposure; that was not established here. [Apple review access guidance](https://developer.apple.com/app-store/review/).

### CR03 — Recent admin authentication is defined but not enforced at sensitive callers — P1, confirmed coverage gap

The recent-auth helper exists, but the backend reviewer found no production callers. Role/allowlist/financial administration therefore does not gain a step-up check merely because the helper is present.

**Action/owner:** backend/security; enumerate privileged mutations and attach freshness/lease checks at their server boundaries. **Acceptance:** stale/expired/revoked admin sessions fail every sensitive mutation; fresh authorized sessions succeed; lower roles fail regardless of the UI. Map to M004/M014/M079.

### CR04 — iOS location permissions are not compiled into the configured permission plugin — P1 for iOS, confirmed configuration defect

The Podfile supplies no `PERMISSION_LOCATION` definition. The locked permission-handler Apple implementation defaults its location feature macros to disabled. The app's permission service requests location through that plugin, so the current configuration cannot provide the intended iOS permission strategy even though usage strings exist.

**Action/owner:** iOS/mobile; enable only required permission strategies and reconcile usage descriptions/entitlements with actual behavior. **Acceptance:** signed iOS install demonstrates first request, denial, restricted/permanently denied recovery, approximate location, Settings return, nearby discovery and driver sharing on the supported iOS versions. Map to M046/M048/G07. No physical iOS reproduction was performed in this review.

### CR05 — Foreground NFC listener can start iOS system scanning without user intent — P1 for iOS, confirmed source path

The global listener wraps all routes and starts its poll loop on initialization/resume. iOS polling uses a visible Core NFC reader session. This path is not limited to an explicit NFC scan task.

**Action/owner:** mobile platform owner; keep platform-specific passive Android behavior separate from explicit iOS reader sessions. **Acceptance:** launch/Home/login/resume never opens an unsolicited iOS NFC sheet; explicit supported scan works, cancel/timeout/background stops it, and account replacement cannot receive a previous operation's result. Map to M048/M054/M055/G07.

### CR06 — Optional Firebase timeout loses later push/analytics installation — P2, confirmed lifecycle defect

Startup gives optional services a six-second budget while Remote Config can wait longer. A timeout can permanently bypass push-handler setup even if initialization later succeeds. Router observers are also captured before analytics attaches and are not replaced on the retained router.

**Action/owner:** mobile infrastructure; decouple bounded first-frame startup from idempotent eventual installation of messaging/crash/analytics observers. **Acceptance:** delayed configuration, offline startup then recovery, token refresh, cold notification tap and account replacement install each handler once and produce one correctly scoped route observation. Map to M009/M054/M055/M092.

### CR07 — Admin lists can show stale query results — P2, confirmed concurrency defect

Reports and trips loaders bind account context but lack the request-revision ordering already used by the audit-log view. Rapid filtering/search can let an older response overwrite a newer result in the same session.

**Action/owner:** admin frontend; reuse latest-request revision/cancellation semantics. **Acceptance:** deterministic out-of-order responses preserve the newest filter/page; old errors cannot replace current success; account replacement clears private rows. Map to M053/M055.

### CR08 — Admin list sorting/counts overstate the query result — P2, confirmed outcome defect

Users sorting happens after a server-limited page is fetched while labels imply global ordering. The displayed matching-member total is a lower bound, not a demonstrated exact query count.

**Action/owner:** admin/data owner; move sort/filter/count into a stable server query or label the bounded-page result accurately. **Acceptance:** records beyond the first page produce correct ordering/count labels with stable pagination under concurrent writes. Map to M053/M063/M093.

### CR09 — Bulk role changes lack a reviewed privilege-change step — P1 for privileged operations, confirmed UX/control gap

The role selection immediately starts parallel role RPCs without a confirmation showing recipients, old/new privileges or expected effect. Server authorization still matters independently; this finding concerns preventable operator error and partial outcomes.

**Action/owner:** admin/security; require a review step for privilege escalation and show per-user partial failure/reconciliation, with server freshness and authorization. **Acceptance:** selecting an option cannot silently grant roles; cancel leaves state unchanged; partial/unknown outcomes cannot be represented as a single success. Map to M004/M014/M053.

### CR10 — Privacy request intake is not demonstrated erasure — P1 release gate, partial implementation

In-app privacy request intake exists. The newer workflow migration explicitly leaves processing disabled and does not provide an erasure executor. Requests, operator states and admin health are valuable but do not establish deletion from Auth, SQL, objects, vector/inference, notifications, analytics and other processors.

**Action/owner:** privacy/backend/operations; implement or document a controlled, verified fulfillment workflow with retention exceptions, authorization, idempotency, retries, processor requests and completion receipts. Manual fulfillment may be appropriate if it is accountable and tested; intake-only status must remain truthful. **Acceptance:** one representative account can request deletion, authorized operators fulfill it across every in-scope store, private access is revoked, exceptions are disclosed, and duplicate/retry/restore cases cannot silently resurrect usable personal data. Map to M065–M070/G02. Google requires an in-app deletion path and a usable web request resource; Apple requires initiation within the app and account/data removal subject to lawful retention. [Google deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en), [Apple deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/).

### CR11 — Face recipient eligibility and SQL session policy are incomplete — P1 before Face enablement

Recipient resolution checks receiving profile/method state but does not demonstrate that the recipient Auth account is eligible after bans/deletion. The face SQL session helper also omits checks present in the common live-identity helper, and does not enforce the separate admin-session lease policy. Upstream Auth `getUser` already checks requester bans and sessions, so this review does **not** claim a definite banned-requester bypass at the hosted Edge API. SQL/direct maintenance paths, expired admin leases and recipient policy still need explicit tests.

**Action/owner:** backend/face/security; align recipient and session eligibility with the approved common live authority. **Acceptance:** banned/deleted recipient, removed consent/method, expired lease/session, late upsert and replacement enrollment fail closed without selecting a stale operator destination. Retain the no-liveness/amount-free approved shortcut. Map to M003/M035/M039/M043/G05.

### CR12 — Maps admission accepts bootstrap Auth users and has isolate-local limiting — P2 abuse/cost risk

Maps gateway's `getUser` admission does not require the verified WhatsApp identity contract, and its rate map is process-local. Anonymous/bootstrap identities and isolate churn therefore do not have a demonstrated global quota boundary.

**Action/owner:** backend; use the intended verified-session policy and durable limits for expensive place/geocoding calls. **Acceptance:** anonymous/unverified/expired sessions cannot consume protected budget; concurrent isolates obey shared quotas; provider outages are bounded; `compute_route` continues returning 410. Map to M010/M012/M094.

### CR13 — Terms describe the wrong authentication contract — P2, confirmed public-content defect

`landing/terms-and-conditions.html` still describes anonymous authentication with an optional phone number. That conflicts with mandatory WhatsApp OTP and the current product explanation.

**Action/owner:** product/privacy; reconcile notices against actual identity, location, optional face and collector data flows. **Acceptance:** terms/privacy/onboarding/store declarations agree and the public-site checks validate behavior/meaning rather than only required phrases. Map to M065/M066/M090.

### CR14 — Design acceptance denominator and platform evidence remain incomplete — P1 acceptance gate

There are current screenshots, themes, fixture improvements and scoped Android captures, but no accepted complete cases. The pushed privacy task is not explicitly represented; full-scroll tasks, current role/state/theme matrices, real readers/keyboard, installed PWA recovery and authenticated admin remain open.

**Action/owner:** design QA/product/mobile/admin owners; finish applicability and comparator selection, then accept complete tasks under the sole design skill. **Acceptance:** every declared reachable task/state has an actual comparator or reviewed adaptation, matching source/build/platform evidence, recovery outcome and independent disposition. Review genuine mismatches before updating baselines. Map to M058/M060/M076 and the 21 design packages. A checklist score must not be called pixel fidelity or WCAG conformance.

### CR15 — Hosted CI and organizational promotion controls fail the release gate — P1, live observed failure

The current GitHub state described in section 4 has no working independent CI evidence for HEAD, no protected main branch, and no environment reviewer protection. Candidate/HMAC receipts cannot establish separation if one actor controls source, evidence, approval key and publication.

**Action/owner:** repository/release owner; determine the cause of startup failures, obtain an exact-candidate CI run and configure an enforceable protection/control model for this private repository. Keep repository privacy; do not make source public to bypass a plan restriction. **Acceptance:** required jobs really execute, failing/skipped jobs block promotion, independent reviewers and restricted deployment authority are demonstrated, emergency bypass is audited. Current GitHub documents distinguish private-repository plan support from public-repository reviewer features; buying a plan without validating the required features is not closure. [GitHub deployment controls](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments).

### CR16 — Deployed app/admin identity and availability are unverified — P1 delivery gate

Local current bundles exist, but external app/admin routes were not usable through the review's probes, and deployed release identity was not proven. The 503 fail-closed shell response may be intended when the configured bundle is absent/invalid; a 403 may reflect access/WAF policy. Neither should be replaced by a misleading marketing page to obtain an HTTP pass.

**Action/owner:** hosting/release/QA; inspect the authorized deployed release/branch/host and browser access policy. **Acceptance:** the intended public consumer and authenticated admin entrypoints load the exact approved bundle, apply surface-specific capabilities/security/cache headers, preserve deep links, deny unauthorized operations and complete real tasks. Map to M075/M077/M080/M081/G08.

### CR17 — Operations, privacy governance and physical acceptance are not established — P1 gates

Source and synthetic tests do not provide observed backup restoration, Storage recovery, incident/credential revocation, cost/capacity budgets, named on-call responsibility, operator reconciliation, representative hardware or provider/store acceptance. Existing runbooks should be completed and exercised rather than replaced by generic checklists.

**Action/owner:** operations/privacy/release with feature owners; collect the acceptance records identified in the whole-system checklist. **Acceptance:** named people, target environments, actual recovery/failure measurements and exact candidate receipts exist. Rwanda's regulator classifies biometrics as sensitive personal data and publishes rules for processing, international sharing/storage and retention. Validate actual processing locations/contracts/registration and legal applicability with the responsible owner; international standards do not automatically make GDPR applicable to every Rwanda-only user. [Rwanda DPO general provisions](https://dpo.gov.rw/dpp-law/general-provisions), [DPO transfer/storage/retention rules](https://dpo.gov.rw/dpp-law/sharing-transferstorage-and-retention-of-personal-data).

### CR18 — Repository and documentation need controlled consolidation — P2 maintainability finding

The architecture is substantially organized, but large orchestration files and preserved snapshot code complicate current-state discovery. `wallet_screen.dart` is about 2,044 lines, broadcasts about 1,510, shared BioPay flows about 1,481, chat about 1,317 and subscriptions about 1,243. Size alone does not prove a bug; it identifies where state/authority/lifecycle changes are harder to review. The architecture feature table also needs the implemented privacy owner. Historical release summaries sometimes point to older scope/status documents.

**Action/owner:** architecture/documentation; extract bounded coordinators and typed repositories from touched risk zones while keeping existing public contracts. Add one current release/status entrypoint and explicit historical banners/links. Hash-preserve unique source/evidence before considering deletion of snapshot duplicates. **Acceptance:** retained behavior/race tests pass; structure checks stay green; every removed duplicate has verified identical retained bytes/provenance; current docs never instruct deletion of approved features. Map to M063/M082/M090.

### CR19 — Native deep-link ownership and iOS scene compatibility are unresolved — P1 for link-dependent iOS tasks

The locked `app_links` 6.4.1 callback integration does not supply scene forwarding while the iOS plist selects FlutterSceneDelegate. Flutter's default native link handler is also active beside the third-party plugin. NFC/referral consumers subscribe through that plugin; invite navigation needs deliberate handling. The mismatch is source-confirmed, while exact device loss/duplication remains unexecuted.

**Action/owner:** mobile platform; establish one validated arrival owner and supported scene callback integration before changing handler flags. **Acceptance:** signed cold/warm/resumed invite/payment/NFC arrivals, expired auth and duplicate deliveries reach exactly one correct destination. Do not turn off the current fallback before proving the replacement receives events. See MOB-M03 and M048/M049/G07. [Flutter deep-link guidance](https://docs.flutter.dev/ui/navigation/deep-linking).

### CR20 — Permission availability and location freshness can be misrepresented — P2, confirmed source defects

Missing/unimplemented permission channels return `granted` in the shared permission service. Separately, an OS last-known position is remembered with the current time rather than its original fix timestamp, allowing stale location to appear fresh. OS enforcement and live driver acquisition remain separate and reduce the scope of the claim.

**Action/owner:** mobile/location; expose unavailable permission explicitly and validate fix age/accuracy/skew. **Acceptance:** missing plugin never means granted; old/future/inaccurate positions cannot silently become fresh discovery biases. See MOB-M07/M08 and M048/M054/M056.

### CR21 — Completed SMS payloads consume permanent intake capacity — P1 before institutional activation

The durable intake migration caps rows and payload bytes but counts completed entries as well as pending entries. No completed-payload archive/retention executor reclaims that budget. Eventual saturation therefore remains possible despite successful processing. Raising limits only postpones it; deleting evidence indiscriminately can break replay-safe deduplication.

**Action/owner:** SMS/backend/operations; implement approved retention/archival with durable deduplication tombstones and backpressure/alerts. **Acceptance:** fill/drain/reclaim tests resume intake, preserve uncertain evidence and prevent old receipts crediting again after retries/restoration. Also fix the collector's missing total network-request deadline (MOB-M09). See BK-07 and M016/M020/M023/M027/M030/G04.

### CR22 — Transport departure and numbered-seat rules are incomplete — P2, confirmed optional-feature correctness gaps

The hold transaction accepts a scheduled/boarding schedule with an absent/future cutoff without requiring future departure. Caller-provided seat numbers are not validated for count/range/exclusivity. This is a defect if numbered assignments are offered; an unassigned-seat product should reject unsupported assignments rather than create that feature. Deployment of the service-restricted expiry sweeper is also unverified.

**Action/owner:** transport/backend; enforce the approved timing/assignment model and bind expiry to an owned scheduler. **Acceptance:** past-departure, null-cutoff, mismatched/overlapping seats and hold/confirm/cancel/expire concurrency conserve approved inventory. See BK-09 and M017/M018/M022/M024/G03. No unapproved in-app settlement/refund system is recommended.

### CR23 — Direct Auth password/phone operations need a WhatsApp-proof acceptance test — P1 unverified authority gate

The OTP implementation issues password-based Auth sessions and stores durable WhatsApp-provider account metadata. The verified identity helper recognizes that metadata, while direct Auth user mutation/password sign-in are independent service paths. Local configuration is not evidence of actual hosted Auth settings.

**Action/owner:** auth/security; use synthetic accounts against the exact Auth version/settings to test password selection/sign-in, phone changes, alternate methods and recovery. **Acceptance:** none can manufacture a newly trusted application session or reassign verified phone authority without the required WhatsApp proof. If reproduced, attach supported server-owned session proof/hooks; do not call the source hypothesis a hosted exploit. See BK-03 and M003/M005/M012/G01. [Supabase authenticated user update](https://supabase.com/docs/reference/javascript/auth-updateuser).

### CR24 — Declared languages are incompletely connected to the UI — P2 product gap

EN/FR/RW localization files and locale declarations exist, but many discovery, booking, navigation, privacy and admin labels/errors remain English. The localized payment helper does not cover all supported product tasks.

**Action/owner:** product/localization/mobile; define the launch language promise and wire the applicable copy, validation, recovery, plurals/dates/numbers and accessibility labels through the existing localization source. **Acceptance:** native-language review of complete tasks and long/enlarged strings for the declared launch languages. See MOB-M06 and M059/M060.

### CR25 — Required Flutter verification remains red — P1 observed acceptance failure

The fresh run has 1,595 passing tests and 169 failures as classified in section 4. This prevents a green required suite regardless of the current signed local build. The obsolete AWS phrase requires a scope-correct test change; the 168 golden comparisons require visual investigation and explicit disposition under the sole authority.

**Action/owner:** mobile/design QA; repair justified discrepancies and stale contracts, then execute the required full suite on the frozen resulting candidate. **Acceptance:** no functional/contract failure, accepted current visual comparisons, no weakened gates or unreviewed baseline updates. See M076/G08 and the full failure list in the evidence pack.

## 6. Architecture, refactoring and restructuring plan

The current root Flutter app, shared design/types packages, separate operator utility, static landing site, Supabase backend and optional face service are sensible boundaries. Avoid creating placeholder apps/admin packages or restoring retired theme/model/provider wrappers.

| Work boundary | Concrete recommended change | Dependency and proof |
|---|---|---|
| Server authority | Consolidate effective verified identity, tenant permission and recent-admin checks behind existing server boundaries; inspect every security-definer function's grants/search path and callers | CR01–CR03 first; real role/JWT/PostgREST negative tests, not string assertions alone |
| Payment-adjacent adapters | Separate external handoff, user claims, signed collector delivery and independently reconciled payment evidence in typed results | Preserve noncustodial scope; prove unknown/retry/duplicate/cross-owner cases |
| Mobile bootstrap | Separate critical render configuration from eventual optional-service installation | CR06; idempotent delayed-start/offline/notification tests plus devices |
| Platform hardware | Give NFC/camera/location one task/lifecycle owner per platform | CR04–CR05; explicit user intent, background/logout/timeout cleanup and actual hardware |
| Admin queries | Centralize query revision, stable filters/sort/cursor/count and actionable row/bulk outcomes | CR07–CR09; out-of-order/error/partial-write tests and role-specific browser tasks |
| Privacy | Treat fulfillment as a controlled application/server workflow with audit receipts and retention policy | CR10; cross-store deletion and restore behavior |
| Large presentation files | Extract only touched workflow coordinators, typed projections and independently reusable UI sections | Preserve route/provider identities; no broad formatting rewrite or speculative class splitting |
| Source generation | Continue generation inside the owning package, verify deterministic output in a clean checkout | Structure/bootstrap checks; no imports into retired paths |
| Test strategy | Keep local component fixtures, actual Deno handlers, full-schema SQL, real PostgREST and signed/device acceptance distinct | Tests that inspect source strings cannot prove effective authorization or races |
| Documentation | One current scope/status/index linking existing M001–M095, G01–G10 and 21 design closure packages | Avoid a second competing backlog; this report's CR IDs are a review crosswalk |

Do not optimize by adding a new global service locator, replacing Riverpod/GoRouter, splitting the monorepo without delivery need, or weakening golden/security gates. Flutter's official guidance supports localizing rebuilds and breaking overly large widgets along encapsulated state changes; performance changes should follow measured release/profile behavior. [Flutter performance guidance](https://docs.flutter.dev/perf/best-practices).

## 7. Clean-up and supply-chain recommendations

The measured preserved documentation directories are approximately 24 MiB of Drive imports, 78 MiB of release evidence and 14 MiB of reports. They contain provenance and historical evidence, not 116 MiB of automatically disposable duplicate code. `build`, `.dart_tool`, native build caches and model/runtime outputs are separate from authored source.

1. Identify executable active source versus snapshots, generated outputs, third-party code and approved evidence. Make the current entrypoint/index explicit.
2. Preserve unique archival material and its origin/hash before moving it to a controlled archive. Permanently remove only verified duplicates, with manifests and direct absence verification. Do not remove migration history, golden baselines, licenses, signing evidence or dated approvals because an older report appears redundant.
3. Keep `.env`, keys, keystores and service-role credentials out of commits. Current pattern scanning and the single-path secret-history gate pass locally; they do not certify all Git history, Drive children, provider revocation or credential provenance. M001–M002 require fresh named access/provenance evidence.
4. Dependency update coverage already includes pub, Actions, both Gradle apps, npm, Python and Docker. Recent Dependabot startup failures mean configured monitoring is not observed monitoring. Audit current resolved dependencies/advisories and optional face model licenses; avoid broad unrequested upgrades.
5. Pin complete release toolchain identities where required; Deno `v2.x` and hosted moving runner images are not exact reproducibility. Produce an SBOM/license notice and provenance for the accepted artifact; keep debug symbols/source maps under governed retention. An artifact hash or custom candidate manifest is not automatically a SLSA level. [GitHub secure Actions use](https://docs.github.com/en/actions/reference/security/secure-use), [SLSA security levels](https://slsa.dev/spec/v1.0/levels).

No source deletion, cleanup, refactor, dependency installation or application repair was performed as part of this report.

## 8. Whole-system checklist and research framework

The companion [whole-system checklist](mobio-readiness-review-2026-10-01/whole-system-checklist.md) covers product scope, architecture, dependencies, authentication, authorization, data/migrations, API/integrations, monetary evidence, privacy, mobile/native, website/PWA, admin, UI/accessibility/localization, tests, performance/capacity/cost, CI/release, infrastructure, resilience, operations/support and governance. The [design review](mobio-readiness-review-2026-10-01/design-review.md) additionally maps all R001–R100 design checks and operational criteria, with actual evidence and closure actions.

Security assessment uses OWASP ASVS for server/web authority and MASVS for mobile storage, cryptography, authentication, networking, platform, code, resilience and privacy. These are check frameworks; this review grants no certification. [OWASP ASVS](https://owasp.org/projects/asvs), [OWASP MASVS](https://mas.owasp.org/MASVS/).

Web accessibility acceptance should use the applicable WCAG 2.2 AA criteria, including reflow, focus, names/roles/values, error association, accessible authentication and pointer targets. Native task acceptance also needs VoiceOver/TalkBack and physical input tests. Automated semantics checks and screenshots cover only a subset. Do not confuse the 24 CSS-pixel WCAG minimum (with exceptions) with the project's larger native target conventions. [WCAG 2.2](https://www.w3.org/TR/WCAG22/).

Measure native startup/frame/camera/memory/battery on representative release devices and web performance on the actual launch network/device. Use observed budgets instead of a source-derived readiness percentage. Core Web Vitals' good thresholds are LCP ≤2.5s, INP ≤200ms and CLS ≤0.1 at the 75th percentile; a local screenshot or test fixture does not establish those field metrics. [Google Web Vitals](https://web.dev/articles/vitals).

Backup readiness must include independently retained object assets and cross-service state as well as database recovery. Supabase database backups do not include Storage object bytes; verify actual object backups and a restoration exercise. [Supabase backup scope](https://supabase.com/docs/guides/platform/backups).

Before store submission, classify each subscription/token/paid entitlement under the actual Apple/Google rules and launch region. Physical transport and digital app benefits may have different billing requirements; the repository's noncustodial description does not by itself settle store policy. Record the owner/store decision for the enabled capabilities. [Google Play payments policy](https://support.google.com/googleplay/android-developer/answer/9858738?hl=en), [Apple review guidelines](https://developer.apple.com/app-store/review/guidelines/).

## 9. Remediation sequence and closure gates

| Milestone | Work | Required closure evidence |
|---|---|---|
| A — Restore authority | CR01–CR03, review-account isolation, recipient/session policy and protected map admission | Full-schema actual-role/JWT/PostgREST denials, correct allowed operations, provider evidence boundaries |
| B — Correct native/admin outcomes | CR04–CR09, current legal copy, privacy fulfillment and missing task inventory | Deterministic concurrency/lifecycle tests, signed platform runs, truthful admin outcomes and deletion receipts |
| C — Accept the current design candidate | Finish all applicable 21 packages and R001–R100/operational criteria | Complete tasks/source comparisons, actual supported platforms/readers/zoom, reviewed golden dispositions and a full passing required suite |
| D — Prove deployment and upgrades | Exact linked DB/Edge/Auth/Storage state, sanitized forward upgrade, deployed web/admin identity | Readback of effective definitions/configuration, concurrency/upgrade/recovery records, real authenticated journeys |
| E — Prove operations and promotion | Working independent CI, effective repository/release authority, trusted secrets/access, capacity/cost and restore/incident/support | Named owners, measured objectives, rehearsals, independently verified exact candidate receipts |
| F — Platform/store decision | Separate Android/iOS and optional transport/SMS/face gates | Current signed AAB/archive, representative hardware, real provider/store acceptance and independent approval |

Assign named accountable people to the existing M tasks and G gates. The supplied workbook's earlier unassigned/evidence-open cells must be updated from actual observations, not inferred from this report. Each owner should record environment, source/artifact identity, preconditions, command/task, observed result, failure/recovery behavior, evidence and independent acceptance.

A minimum core launch must still satisfy G01/G02, its selected Android/iOS gates, protected promotion, effective backend controls, privacy and operations. Paid transport, institutional SMS and Face-USSD require G03/G04/G05 when enabled. Disabling an optional feature only narrows its activation gate if server routes, grants and client entrypoints enforce that disablement; hiding a tab is insufficient.

**Release acceptance:** no unresolved affected P1 authority or lifecycle defects; every required child check actually passed; accepted complete task coverage for the declared launch surface; verified deployed schema/services/configuration and representative upgrade; correct signed artifact and physical/provider/store evidence; tested operations/restore/privacy; independently authorized exact-candidate promotion. Do not regenerate baselines, sign receipts or enable a feature merely to make the register green.

## 10. Report pack and limits

- [Backend/security detailed review](mobio-readiness-review-2026-10-01/backend-review.md)
- [Mobile/platform/architecture detailed review](mobio-readiness-review-2026-10-01/mobile-review.md)
- [Product/design/admin/website detailed review and full design checklist](mobio-readiness-review-2026-10-01/design-review.md)
- [Whole-system checklist](mobio-readiness-review-2026-10-01/whole-system-checklist.md)
- [Verification and external readback summaries](mobio-readiness-review-2026-10-01/verification-summary.json)
- [Machine-readable source inventory](mobio-readiness-review-2026-10-01/repository-file-inventory.tsv)

Official web sources were consulted on 1 October 2026. Their use is limited to the cited requirements/recommendations; source existence does not establish Mobio compliance. Current test logs, private-account connector limits and external HTTP state are point-in-time observations. Production data, actual payment flows, physical iOS/Android journeys, independent human accessibility outcomes and provider/store decisions were not exercised in this review. The complete acceptance result remains **NO-GO**.
