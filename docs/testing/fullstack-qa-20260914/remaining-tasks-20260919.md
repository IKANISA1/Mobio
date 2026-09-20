# Mobio QA goal — all remaining work, 19 September 2026

**Overall status: incomplete / NO-GO. Native goal status observed: `usageLimited`.**

This is the remaining-work addendum to the [original full-system plan](../fullstack-qa-plan-20260914.md), which the existing Codex goal already references. It supplements every original phase and invariant; it does not replace the full objective or narrow success to this list. The native goal tool supports status updates only, so the literal native objective and usage limit were not edited or reset. Its referenced plan and execution registers are updated here.

The user requested this scope update. It does not independently authorize deployment, production data changes, store upload, external messages or paid provider/biometric work. Current authorizations and product boundaries remain in force.

**20 September update:** REM-002 is complete locally: the compiler error and a refresh callback assertion were repaired; 28 focused checks and 670 full Flutter tests pass. The register contains 57 packages, 56 still open. See [main integration](main-integration-20260920.md). The dated starting-point notes below are retained as history.

## Verified starting point and immediate order

- Current branch: `codex/recovered-pro-g40-2026-09-10`; HEAD: `a77efb1e0a78a22c092151a0153468a495adb060`. Source: 1,967 files; fingerprint `6ad4bb0e87fa30224bcb681d86574d42dd3e9bc31f251222e158b466487d30ec`. The checkout was clean before this documentation update.
- The last fully validated source was the 15 September chat-recovery checkpoint: 648 Flutter tests, clean analysis, and separately bound earlier backend/replay results. Five notification source/test files now differ; these older passes are not current-patch acceptance.
- The retained notification focused attempt has a compiler error: five `context:` arguments do not match the positional `AppExceptionMapper.mapAndLog` signature. The two behavioral suites did not execute in that attempt; six source-contract tests passed. Earlier service and screen reproductions remain preserved.
- First perform REM-001 through REM-006, then continue M1 through M7 in the original phase order, taking independent authorized work while dependencies are unavailable and prioritizing reproduced critical defects.
- FQA-035 remains an open P1 service dependency. FQA-023 is source-only verified; FQA-004 is diagnosed. No status is promoted by this documentation update.

## Ordered remaining work packages

The [CSV register](remaining-tasks-20260919.csv) contains the same 57 task IDs with owners, dependencies, completion evidence and linked cases. REM-002 is complete locally; the other 56 packages remain open and several contain multiple platform/role executions. Counts are not a completion percentage.

### M0 refresh

- [ ] **REM-001 — Reconcile the advanced checkout and resume prerequisites.** Record current HEAD, source/lockfile hashes, recovery conflicts, disk, SDK and actual live process/service ownership. Preserve recovered changes and old evidence. Use pinned internal Flutter 3.44.3 / Dart 3.12.2; do not rely on the old external SSD. Refresh expired isolated sessions only through actual Auth.
  Owner: QA / workspace owner. Dependencies: Native goal is usageLimited; only user/system controls resumption. Directly requested documentation work remains possible..

### M6 immediate

- [x] **REM-002 — Fix the unfinished notification patch compiler error.** Correct all five named context arguments to match AppExceptionMapper.mapAndLog; compile the two behavioral test files and obtain focused results. Retain the original compiler failure.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: notification-focused-green-attempt.log.

- [ ] **REM-003 — Finish truthful API errors, read-update confirmation and stale-account result protection.** Prove rejected inbox/unread/count/write calls report errors; valid retries succeed; single read updates target the current visible row and confirm affected rows; signed-out writes fail; late account/logout/dispose results cannot update current state. Qualify rapid A-B-A switching and token refresh separately.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: notification-service-red-v2.log.

- [ ] **REM-004 — Finish inbox error, retry and pending-action behavior.** Prove error differs from empty; failed writes retain the inbox; retry succeeds; failed mark-read cannot navigate; pending actions prevent duplicate writes; closing during a write is safe; refresh errors are handled; enlarged text can reach recovery.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: notification-screen-red.log;QA-UI-NOTIFY.

### M2 / M3

- [ ] **REM-005 — Reproduce and resolve notification subscription and unread-state lifecycle gaps.** Test initial join/reconnect catch-up, INSERT and read/visibility changes, missed/duplicate/out-of-order events, account switch/logout/disposal, native resume and web subscription activation. Verify Home badge and Admin alerts reconcile authoritative state. Treat current source observations as hypotheses until reproduced; use actual isolated service proof in addition to mocks.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-UI-NOTIFY;QA-DB-ISOLATION.

### M6 immediate

- [ ] **REM-006 — Close the notification batch with focused and full verification.** After all related fixes: focused service/widget tests, Dart analysis, full Flutter suite, structure if needed, secret scan, git diff check and relevant guarded release scripts. Record any guard refusal as an unbuilt artifact. Bind results to final source and update cases/findings/inventories without overwriting red evidence.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: FQA-038 regression retained;QA-UI-NOTIFY.

### M1

- [ ] **REM-007 — Complete requirement-to-route/state/role/API/persistence/evidence coverage.** Reconcile all routes, aliases, generated families, redirects, overlays, menus, native handoffs, APIs/RPCs, tables/views/RLS/grants, buckets, publications, jobs, permissions, packages and delivery entrypoints. Classify active/compatibility/disabled/unverified paths; expand the 35 pending acceptance groups into real cases. Do not treat extracted counts or a Cartesian matrix as tested coverage.
  Owner: Codex / QA. Dependencies: None for local work.

### M1 / M2 / M6

- [ ] **REM-008 — Close the explicit QF-01 through QF-07 crosswalk on current evidence.** Map each historical finding to source, FQA repair if any, current tests and remaining deployed/native acceptance. QF-01 collector provenance; QF-02 provider authorization; QF-03 server-authoritative face enrollment; QF-04 actual Admin routing; QF-05 complete frozen backend tests/ignored-case rationale; QF-06 source-matched navigation; QF-07 compiled Home/tab proof harness. Preserve earlier results; no inferred closure.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QF-01;QF-02;QF-03;QF-04;QF-05;QF-06;QF-07.

### M1

- [ ] **REM-009 — Qualify legitimate app configuration and signing references.** Privately verify SUPABASE_URL, SUPABASE_ANON_KEY, PRIVACY_POLICY_URL and ACCOUNT_DELETION_URL; iOS also needs FIREBASE_IOS_APP_ID. Establish designated non-production environment and synthetic actors; check signing references without leaking values. Never substitute invented configuration.
  Owner: Release / integration owner. Dependencies: Pending approved QA configuration path or designated project; do not repeat an unanswered request.. Linked IDs: DEP-001.

- [ ] **REM-010 — Qualify the remaining test environment.** Check actual Android/iOS devices and supported browsers/install modes, controlled synthetic actors, service versions and resource headroom. Use matching Firefox runtime when available/capacity permits. Separate emulator/simulator, hardware and hosted parity; inspect rather than restart old handles blindly.
  Owner: QA environment owner. Dependencies: DEP-002;DEP-004;DEP-006;DEP-008.

### M2

- [ ] **REM-011 — Complete remaining Auth and OTP authority/recovery paths.** Exercise missing/malformed/expired/revoked tokens, anonymous bootstrap denials, app versus allowlisted Admin purpose, wrong/correct/concurrent/expired OTP, resend/rate/attempt limits, replay, safe redirects, refresh/logout and account transitions. Verify persisted effects; provider sends remain mocked until separately authorized.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-DB-OTP;QA-UI-LOGIN;QA-UI-ADMIN-AUTH.

- [ ] **REM-012 — Complete actor and argument authority matrix for active data paths.** Test actual passenger/driver/payee A/B, allowed/denied/revoked Admin and collector contexts across direct REST/RPC/Edge routes; ownership/IDOR, grant bypass, definer search_path, malformed/null/boundary arguments, transactions and concurrent edits. Identify uncalled compatibility helpers without restoring excluded features.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-DB-ISOLATION.

- [ ] **REM-013 — Complete server/provider authority and identity binding.** Unauthorized calls produce zero provider work; one-time liveness/enrollment belongs to the correct user/session/device where implemented; forged IDs/results, cross-user sessions, replay, revoked consent, duplicate identity and replacement are denied. Prove server persistence and grants with synthetic fixtures. Real biometric/provider acceptance requires its own authorization.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QF-02;QF-03;QA-UI-FACE.

- [ ] **REM-014 — Complete collector provenance, revocation and authoritative matching.** Verify enrolled/revoked device credentials, signature/body/timestamp/nonce binding, replay/rate/batch limits and denial before parsing/privileged work. Trace isolated synthetic receipt to exact deduplication/entitlement effects; duplicate, unmatched and ambiguous receipts cannot grant or extend incorrectly. No SMS ingestion activation.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QF-01;QA-NATIVE-COLLECTOR;QA-UI-WALLET.

- [ ] **REM-015 — Finish API robustness and service parity checks.** Cover schemas/input bounds, methods/CORS, safe errors, injection, abuse/rates, timeout/retry/idempotency, correlation/redaction and deprecated endpoints. Keep compute_route at 410; test approved Places/Geocoding/external Maps only. Distinguish exported Deno handler proof from hosted Edge runtime and deployed version verification.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-DB-ISOLATION;QA-UI-EV.

- [ ] **REM-016 — Resolve FQA-035 concurrent private-object replacement.** Qualify the designated Storage version and an atomic service-level repair enforcing create conflicts and replacement ownership at final write. Repeat same-key cross-user create-only/upsert races, same-owner positive controls, bytes/ownership/read/delete checks. Ordinary RLS success does not close the race.
  Owner: Storage service owner / backend security. Dependencies: Designated Storage version and service repair qualification; no production mutation.. Linked IDs: FQA-035.

- [ ] **REM-017 — Complete Storage and asynchronous-job behavior beyond the local file backend.** Verify supported upload types/sizes, signed-link scope/expiry, deletion/retention, service cleanup, retries/dead letters, S3/CDN/transforms if deployed, revoked access and isolation. Preserve current four buckets/policies unless a reproduced authorized fix requires change.
  Owner: Backend / operations. Dependencies: Designated supported service configuration; isolated targets for mutations.. Linked IDs: QA-DB-ISOLATION.

### M2 / M5

- [ ] **REM-018 — Qualify general cold-start, reconnect and ordering behavior.** Reproduce the first-notification miss on a cold lazy tenant; establish actual readiness/delivery semantics. Test unsubscribe cleanup, rapid lifecycle, token/account changes, duplicates/out-of-order events, reconnect/resume and subscription loss across consumers. Chat history catch-up is retained proof only for its bounded behavior.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-DB-ISOLATION;QA-UI-CHAT;QA-UI-NOTIFY.

### M2

- [ ] **REM-019 — Finish data maintenance, concurrency, rollback and restore qualification.** Retain the 103-migration/10-suite rehearsal where inputs match; rerun only changed or unresolved paths. Verify constraints, idempotency, duplicate receipts, subscription activation, token/request expiry, cleanup jobs, migration compatibility and isolated backup/restore. Document actual rollback limits and operational health versus provider readiness.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-DB-REPLAY;QA-DB-OTP.

### M2 / M6

- [ ] **REM-020 — Complete security control and supply-chain review.** Record versioned ASVS/MASVS IDs; review frozen dependency/advisory exposure, client secret absence, logging/privacy, native exports/deep links, CI permissions/pinned actions and hidden skipped tests. Retain pinned versions and existing frameworks; review changes before any dependency update.
  Owner: Codex / QA. Dependencies: None for local work.

### M3

- [ ] **REM-021 — Execute configured passenger and driver login/discovery/profile journeys.** On each supported runtime verify WhatsApp OTP purpose and destination, logout/expiry, role/vehicle filters, Nearby privacy/blocking/visibility, location denial and stale/empty/error recovery, six-digit member IDs and Rwanda defaults; correlate screen outcomes to actual data.
  Owner: Mobile / web QA. Dependencies: Approved configured app environment; real external messages require separate authorization.. Linked IDs: QA-UI-LOGIN;QA-UI-HOME.

- [ ] **REM-022 — Execute implemented scheduling and transport journeys.** Create/view/edit/cancel once; test ownership with two users, recurring dates/timezones/past times, stale concurrent edits, catalog/agency/booking/entitlement boundaries, loading/cancel/error recovery and external Maps. Preserve approved extensions and distinguish planned/disabled features.
  Owner: Mobile / web / backend QA. Dependencies: Configured synthetic environment.. Linked IDs: QA-UI-TRIP.

- [ ] **REM-023 — Execute complete participant chat and moderation journeys.** Verify correct peer/context, Plus/block rules, ordering/drafts, send/cooldown/ack failures, read state, report/block/unblock, retry/reconnect/resume, keyboard and authorized notification routes. Reuse service recovery proof but run actual screens/participants; external WhatsApp/chat sends remain separately authorized.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-UI-CHAT;QA-UI-NOTIFY.

- [ ] **REM-024 — Execute account/preferences and EV discovery journeys.** Verify setup/edit/validation, long content, verified contact, saved addresses/data, theme/locale persistence, legal/support/deletion entry and relaunch; EV location denial/search/filter/details and approved external Maps. Test actual persistence and recovery.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-UI-PROFILE;QA-UI-EV.

- [ ] **REM-025 — Execute approved recipient-to-external-handoff journeys.** Recipient/method/amount/route/fee review, wrong or changed recipient, recents/templates, stale or unknown fees, inactive providers, explicit handoff/cancellation/resume and truthful unknown outcome. No PIN collection, settlement claim, payment ledger or new in-app payment API.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-UI-BIOPAY.

- [ ] **REM-026 — Execute request, QR and deep-link lifecycles.** Create/cancel/request expiry and activity ownership; valid/malformed/wrong-account/revoked payloads, scanner denial, cold/warm links, retry/cancel and safe external return. No executable untrusted USSD embedded through unvalidated input.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-UI-REQUEST;QA-UI-QR.

- [ ] **REM-027 — Execute hardware and provider-dependent BioPay cases when authorized.** NFC unsupported/denied/read/write/revoke/interruption/resume; face consent/guided capture/cancel/denied/rejected/stale/replaced-session outcomes and correct payee confirmation. Keep synthetic negative proof distinct from actual hardware/provider acceptance.
  Owner: Native / integration QA. Dependencies: Supported physical devices; approved configuration; separate approval for paid provider or biometric actions.. Linked IDs: QA-UI-FACE;QA-UI-NFC.

- [ ] **REM-028 — Qualify implemented balance/plan/entitlement outcomes.** Empty/real server values, Rwanda currency precision, plan confirmation, duplicate/unmatched receipts, refresh and once-only activation; preserve /ledger unavailable behavior and non-custodial scope. Do not interpret retained wallet UI as authorization for payment execution.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-UI-WALLET.

- [ ] **REM-029 — Execute configured Admin entry, session and routing journeys.** Allowlisted Admin purpose success and denied/revoked/non-admin cases, refresh/logout/direct privileged URL, shell role context, expired sessions and actual Business login/deep routes. Check server permission independently of visible routing.
  Owner: Admin / security QA. Dependencies: Designated allowlisted synthetic Admin; read-only deployed identity when available.. Linked IDs: QA-UI-ADMIN-AUTH;QF-04.

- [ ] **REM-030 — Execute users/trips/reports/audit/health/broadcast controls end to end.** Search/filter/sort/page/details, loading/empty/errors, moderation, busy/duplicate actions, partial bulk outcomes, concurrent edits, real persistence and audit. Health labels must distinguish configured from functioning services. Broadcast delivery uses mocks unless separately authorized.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-UI-ADMIN-OPS.

- [ ] **REM-031 — Execute implemented catalog and operational configuration journeys.** Vehicle types, agencies, chargers, subscriptions: create/edit/toggle/archive, uploads, validation/conflicts/cleanup. BioPay discoverability, route order/availability, expired/revoked identity and legacy /admin/finance alias. Confirm actual roles and data effects.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-UI-ADMIN-CATALOG;QA-UI-ADMIN-BIOPAY.

- [ ] **REM-032 — Execute compiled web/native routing and error-state journeys.** Direct URLs/reload/history/query/fragment preservation, deferred loads/retry, Home compatibility, unsupported/unknown/config-error routes and safe back/home recovery. Run the compiled proof harness through Home and every tab without console exceptions; label synthetic auth separately.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-UI-ERROR;QF-07.

### M3 / M5

- [ ] **REM-033 — Close operational Android receiver/worker/service recovery.** Controlled synthetic new receipt, durable queue, authenticated batch/dedup result; actual broadcast completion and scheduling, WorkManager retries, concurrent uploader/service/receiver, offline/reconnect, process kill/reboot, different-version update, power/permission/notification denial, device revocation/removal, no inbox-history scan. Distinguish emulator proof from physical device acceptance.
  Owner: Android collector / backend QA. Dependencies: Isolated synthetic-only Android fixture; no real SMS collection or ingestion activation.. Linked IDs: FQA-023;QA-NATIVE-COLLECTOR.

- [ ] **REM-034 — Finish all five page and conversion acceptance groups.** Homepage, privacy, terms, deletion and review utility page: direct routes/assets, mobile/desktop navigation, actual download/support/legal/Business destinations, own identity/content/metadata/media accessibility. Read back deployed artifact/header/cache identity when available. Do not expose owner review credentials.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: QA-SITE-JOURNEY-HOME;QA-SITE-JOURNEY-PRIVACY;QA-SITE-JOURNEY-TERMS;QA-SITE-JOURNEY-DELETION;QA-SITE-JOURNEY-REVIEW.

### M4

- [ ] **REM-035 — Complete actual comparator access and route/state reference mapping.** Open/hash selected skill references; record cohort/platform/theme/region/date/version/viewport and missing evidence; resolve inaccessible website comparator. Preserve native Dark Glow/onboarding/website/Business cohorts and distinguish direct/component/adaptation mappings.
  Owner: Design QA. Dependencies: DEP-007 for inaccessible website source; other available references can proceed..

- [ ] **REM-036 — Complete all applicable R001–R100 reviews on actual rendered states.** Review full colour system, per-route gradients/surfaces, loaded fonts/typography, geometry/density/spacing/shape, own logo/assets, motion, overlays and focus/selected/disabled/error states. Compare matching source/target viewport/role/state/theme and annotate justified adaptations. Golden stability alone is not fidelity.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: R001–R100;FQA-004;QF-06.

- [ ] **REM-037 — Complete actual web and native accessibility task checks.** Versioned WCAG 2.2 A/AA crosswalk; names/roles/values/order, TalkBack/VoiceOver and web-reader traversal, keyboard/focus/modal return, errors/status/OTP assistance, actual hit areas, contrast, pointer/gesture alternatives, motion/media preferences, 200% text and 320px reflow/actual 400% browser zoom; evidence for legitimate table exceptions.
  Owner: Accessibility QA. Dependencies: Actual configured runtimes and appropriate assistive technologies for final acceptance.. Linked IDs: A01–A10.

### M4 / M7

- [ ] **REM-038 — Complete the governed mobile acceptance adapter and decisions.** Every unchanged criterion ID has governed case inventory, reference/source/artifact/install hashes, current comparison evidence, implementer assessment, independent visual reviewer decision and owner decision. Do not invent either human decision or convert checklist totals into pixel fidelity.
  Owner: Design implementer / independent reviewer / owner. Dependencies: Final installed artifacts; independent reviewer and owner.. Linked IDs: DEP-005.

### M5

- [ ] **REM-039 — Build, install and exercise configured passenger/driver artifacts separately.** Use guarded scripts with all mandatory public defines; record signing/artifact/install identity. Compact/large phones and supported tablets/foldables/orientations, themes/text/keyboard/reduced motion, permissions/deep links/camera/QR/NFC/external handoffs/session restore/background/resume. Separate debug/release, emulator/simulator and physical devices.
  Owner: Native / release QA. Dependencies: DEP-001;DEP-002;DEP-004; appropriate signing..

- [ ] **REM-040 — Complete real-browser responsive and persistence coverage.** Chromium, Safari/WebKit and supported Firefox; 320/390/768/1440 CSS pixels plus breakpoints, pointer/touch/keyboard, long/large datasets, history/reload/direct links/session/account isolation and complete configured UI/data journeys.
  Owner: Web / Admin QA. Dependencies: DEP-001;DEP-006.

- [ ] **REM-041 — Verify actual install identity and launches.** Record browser/OS/install kind and artifact; consumer/Admin icons/names/scope/start URL, cold/warm launch. Distinguish browser shortcut, standalone and WebAPK modes.
  Owner: PWA QA. Dependencies: Configured artifacts and actual supported installations.. Linked IDs: QA-PWA-P01.

- [ ] **REM-042 — Verify deep links and external-app return.** Cold/warm authorized deep-link launch and external Maps/dialer/WhatsApp return preserve route/account/task context.
  Owner: PWA QA. Dependencies: Actual installed supported modes.. Linked IDs: QA-PWA-P02.

- [ ] **REM-043 — Verify offline, stale data and reconnect.** Offline cold/warm/navigation/action states are truthful; retry/reconnect reconciles state without loss, duplicate action or false success.
  Owner: PWA QA. Dependencies: Actual installed supported modes.. Linked IDs: QA-PWA-P03.

- [ ] **REM-044 — Verify account switch, logout and cache boundaries.** No prior account data or authority survives logout/account transition through UI/cache/requests/subscriptions; shared-device cases verified.
  Owner: PWA / security QA. Dependencies: Actual installed synthetic accounts.. Linked IDs: QA-PWA-P04.

- [ ] **REM-045 — Verify expiry and unfinished draft recovery.** Session expiry/re-auth during real tasks preserves or safely discards drafts with accurate messaging and no authorization bypass.
  Owner: PWA QA. Dependencies: Actual installed supported modes.. Linked IDs: QA-PWA-P05.

- [ ] **REM-046 — Verify update during active work, old tabs and compatible rollback.** Exercise two known versions without clearing browser data; cache/header/update behavior and active-task recovery are measured, including old-tab coexistence and supported rollback.
  Owner: PWA / release QA. Dependencies: Two legitimate isolated configured artifacts; no deployment implied.. Linked IDs: QA-PWA-P06.

- [ ] **REM-047 — Verify storage loss, quotas and restricted environments.** Local storage deletion/quota/denial/private or restricted browsing recovers safely and communicates lost state; no stale authenticated data appears.
  Owner: PWA QA. Dependencies: Actual supported environments.. Linked IDs: QA-PWA-P07.

- [ ] **REM-048 — Qualify the actual capability matrix.** Record notifications/scanner/NFC/other implemented capabilities by platform; unsupported states have clear alternatives; provider/device proof remains separate.
  Owner: PWA / native QA. Dependencies: Actual supported modes; separately authorized external provider actions.. Linked IDs: QA-PWA-P08.

- [ ] **REM-049 — Complete supported locale, theme and data-boundary testing.** Long names/translations, RWF precision, zero/large values, empty/large lists and date/time boundaries across surfaces; RTL only where supported; correct theme/preference persistence and no loss of task meaning.
  Owner: Codex / QA. Dependencies: None for local work.

- [ ] **REM-050 — Establish and test explicit native performance budgets.** Repeated cold/warm startup, scrolling/transitions, memory growth/leaks, lower-powered hardware, background work and relevant haptics; record device/network/repetition conditions and diagnose outliers.
  Owner: Native performance QA. Dependencies: Configured installed native artifacts and representative devices..

- [ ] **REM-051 — Complete controlled browser/API performance and resilience.** Initial usable screen, dense-route interactions, bundles/caches, network/font loading, API/query latency/index plans and bounded isolated load. Investigate deletion-page CLS 0.100195. Report lab runs separately from p75 field LCP/INP/CLS; missing field data stays unverified.
  Owner: Web / backend performance QA. Dependencies: Designated test target for load; actual field data if available..

### M6

- [ ] **REM-052 — Retest every executable in-scope remediation and unresolved failure.** Prioritize P0/P1 then material P2; keep FQA-035 open until atomic-service proof, FQA-023 source-only until OS behavior proof, and FQA-004 diagnosed until evidence classification is resolved. Reconcile 35 local fixes to final sources and impacted actual journeys. Batch active user review notes before one preview rebuild.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: FQA-001–FQA-038;new notification findings after qualified reproduction.

- [ ] **REM-053 — Complete final appropriate regression and reproducibility checks.** Use pinned existing Dart/Flutter/package, full frozen Deno, Node worker and Python helper suites plus relevant migration/SQL/Kotlin/runtime tests. Explain ignored/skipped checks. Run guarded Android/iOS/PWA/website packaging, headers/cache/routes/source identity and secret scans where prerequisites permit; rerun only for changed inputs or unresolved concerns.
  Owner: Codex / QA. Dependencies: None for local work.

### M6 / M7

- [ ] **REM-054 — Refresh source/artifact/reference bindings and reconcile register drift.** Archive old registers and original failures; correct stale counts/line references/fingerprints such as older migration/Flutter summaries without rewriting history. Preserve exact source and log hashes for each result; recapture affected screenshots after code/media changes; record cleanup and private-data exclusion. Do not count overlapping suite rows as whole-system coverage.
  Owner: Codex / QA. Dependencies: None for local work.

### M7

- [ ] **REM-055 — Deliver the complete per-surface report and GO/NO-GO decision.** Create report.md plus evidence/finding/closure/dependency handoff. Separate Android passenger/driver, iOS passenger/driver, consumer web, Admin, every installed PWA mode, website, collector, backend/integrations and delivery. For each give functional, security/data, visual, accessibility, performance and recovery verdict; precise residual owners/next actions/evidence.
  Owner: Codex / QA. Dependencies: None for local work. Linked IDs: M7;report.md.

- [ ] **REM-056 — Record independent acceptance and every external release gate separately.** Distinguish local tests, artifact build/install, hosted CI, deployment/readback, device/provider validation, signing, store review/public availability and independent/owner acceptance. Prepare concrete packets and record exact missing dependencies. No deployment, production writes, store upload, paid provider/biometric action or message is authorized by this update.
  Owner: Release / integration / independent reviewer / owner. Dependencies: Appropriate external availability and separate explicit authorization where required; named independent/owner decisions..

- [ ] **REM-057 — Audit the entire original goal before completion.** Every original requirement, numbered item, named surface/artifact/command/gate and applicable procedure/design criterion has direct evidence or an exact legitimate unverified dependency; all executable work and locally correctable P0/P1 remediations are done. Keep NO-GO for open P0/P1 or required unverified gates. Do not finish merely because tests are green or usage is limited.
  Owner: Codex / QA. Dependencies: None for local work.

## Exact pending acceptance groups

All 35 existing unverified groups remain in [cases.csv](cases.csv). The seven failed Storage race executions remain failed historical evidence for FQA-035. Do not promote either category based on documentation or lower-level tests.

| Existing case | Required state / journey | Remaining tasks |
| --- | --- | --- |
| QA-UI-LOGIN | phone validation, OTP send/verify/resend/expiry/replay; redirect and logout | REM-011, REM-021 |
| QA-UI-HOME | role toggle, Nearby filters, denied location, stale/empty/error recovery | REM-021 |
| QA-UI-TRIP | create, time validation, edit, cancel, unavailable/cross-owner and concurrent update | REM-022 |
| QA-UI-CHAT | open recipient, draft, keyboard, retry, reconnect, report and external WhatsApp | REM-018, REM-023 |
| QA-UI-EV | permission denial, search/filter, place details, external Maps | REM-015, REM-024 |
| QA-UI-PROFILE | setup, edit validation, theme persistence, legal/support/deletion path | REM-024 |
| QA-UI-BIOPAY | methods, search, amount, resume, network handoff and cancellation | REM-025 |
| QA-UI-REQUEST | create, cancel, expired/revoked/malformed token and activity isolation | REM-026 |
| QA-UI-QR | self QR, scanner permission, wrong/malformed payload and return | REM-026 |
| QA-UI-FACE | camera, liveness, one-time session, enrollment, cross-user and revoked consent | REM-013, REM-027 |
| QA-UI-NFC | unsupported platform, permission/read/write/revoke, cancel and app resume | REM-027 |
| QA-UI-WALLET | empty/server values, plan confirmation, duplicate/unmatched receipt and refresh | REM-014, REM-028 |
| QA-UI-NOTIFY | permission, preferences, read state, deep link and resume | REM-004, REM-005, REM-006, REM-018, REM-023 |
| QA-UI-ADMIN-AUTH | login purpose, refresh/logout, direct privileged URL and revocation | REM-011, REM-029 |
| QA-UI-ADMIN-OPS | search/filter/pagination, detail modal, bulk partial failure, concurrency and audit | REM-030 |
| QA-UI-ADMIN-CATALOG | create/edit/toggle/archive, uploads, validation, conflicts and cleanup | REM-031 |
| QA-UI-ADMIN-BIOPAY | discoverability, route availability/order, expired/revoked identity and legacy alias | REM-031 |
| QA-UI-ERROR | missing config, invalid URL, retry and home return | REM-032 |
| QA-DB-REPLAY | clean replay versus fixture-assisted replay; rollback and repeated execution | REM-019 |
| QA-DB-ISOLATION | cross-user reads/writes, definer grants, search_path, publication and storage scope | REM-005, REM-012, REM-015, REM-017, REM-018 |
| QA-DB-OTP | concurrent correct/wrong verification and expiry under row locks | REM-011, REM-019 |
| QA-NATIVE-COLLECTOR | new SMS only; local queue; offline/reboot/update; signature replay; removal | REM-014, REM-033 |
| QA-PWA-P01 | state: actual install identity and cold/warm launch | REM-041 |
| QA-PWA-P02 | state: deep links and external return | REM-042 |
| QA-PWA-P03 | state: offline, stale data and reconnect | REM-043 |
| QA-PWA-P04 | state: account switch, logout and cached data | REM-044 |
| QA-PWA-P05 | state: session expiry and unsaved draft | REM-045 |
| QA-PWA-P06 | state: update during an active task and old-tab rollback | REM-046 |
| QA-PWA-P07 | state: storage loss, quota and restricted environment | REM-047 |
| QA-PWA-P08 | state: supported platform capability matrix | REM-048 |
| QA-SITE-JOURNEY-HOME | deployed artifact, actual zoom/reader, full source fidelity and destination acceptance | REM-034 |
| QA-SITE-JOURNEY-PRIVACY | deployed artifact, actual zoom/reader, full source fidelity and destination acceptance | REM-034 |
| QA-SITE-JOURNEY-TERMS | deployed artifact, actual zoom/reader, full source fidelity and destination acceptance | REM-034 |
| QA-SITE-JOURNEY-DELETION | deployed artifact, actual zoom/reader, full source fidelity and destination acceptance | REM-034 |
| QA-SITE-JOURNEY-REVIEW | deployed artifact, actual zoom/reader, full source fidelity and destination acceptance | REM-034 |

## Complete procedure and design acceptance obligations

All 52 product procedures below remain overall unverified. Their exact test and acceptance instructions, cross-surface obligations and R-rule mappings remain in [procedure-coverage.csv](procedure-coverage.csv). A bounded local test is not procedure closure. The eight K skill-maintenance procedures remain not applicable to product QA.

| Procedure | Required criterion |
| --- | --- |
| F01 | Product and task scope |
| F02 | Evidence provenance |
| F03 | Task completion and recovery |
| F04 | Information architecture and discoverability |
| F05 | Content and financial comprehension |
| F06 | Localisation and data extremes |
| F07 | User outcome evidence |
| F08 | Issue closure and honest status |
| V01 | Geometry and hierarchy |
| V02 | Typography and loaded fonts |
| V03 | Semantic tokens and themes |
| V04 | Own identity and source-matched logo behavior |
| V05 | Component states |
| V06 | Density and overflow |
| V07 | Motion and interruption |
| V08 | Image comparison boundaries |
| A01 | Text and non-text contrast |
| A02 | Reflow and text enlargement |
| A03 | Keyboard, focus and overlays |
| A04 | Names, roles, values and reading order |
| A05 | Actual target hit regions |
| A06 | Authentication assistance |
| A07 | Labels, errors and redundant entry |
| A08 | Motion, media and preference alternatives |
| A09 | Pointer and gesture alternatives |
| A10 | Conformance claim boundary |
| M01 | Navigation, reach and safe areas |
| M02 | Platform and adaptive coverage |
| M03 | Permissions and interrupted tasks |
| M04 | Full money and account states |
| M05 | Theme and preference persistence |
| M06 | Native performance and haptics |
| W01 | Authenticated shell and workspace |
| W02 | Tables and accessible data density |
| W03 | Bulk actions and partial failures |
| W04 | URL and navigation persistence |
| W05 | Permissions and concurrent edits |
| W06 | Web responsiveness and performance |
| S01 | Proposition and real conversion path |
| S02 | Responsive editorial composition |
| S03 | Navigation and content architecture |
| S04 | Trust, terms and honest controls |
| S05 | Discoverability and metadata |
| S06 | Media and experience performance |
| P01 | Install identity and launch modes |
| P02 | Deep links and external return |
| P03 | Offline, stale and reconnect states |
| P04 | Account data and cache boundaries |
| P05 | Session expiry and draft recovery |
| P06 | Update with active work |
| P07 | Storage loss and restricted environments |
| P08 | Platform capability matrix |

All 100 individually enumerated rules in [design-rule-crosswalk.csv](design-rule-crosswalk.csv), R001 through R100, remain governed by the selected Revolut authority. Review applicable rules on every relevant actual surface/state; document genuine non-applicability with evidence. Do not collapse them into a generic colour or golden check.

All ten unchanged MOBILE-DESIGN-100 IDs remain unverified in [mobile-design-100-status.csv](mobile-design-100-status.csv): `reference_fidelity`, `hierarchy_density`, `typography`, `colour_elevation`, `spacing_shape`, `icons_assets`, `copy_annotations`, `interaction_states`, `responsive_keyboard`, `accessibility_native`.

## Dependencies carried forward

| Dependency | Current recorded condition | Next action |
| --- | --- | --- |
| DEP-001 | All four public build values absent; iOS also lacks FIREBASE_IOS_APP_ID. Android/iOS/PWA guarded scripts stopped before building. | Recover verified public configuration privately; rerun guarded build scripts |
| DEP-002 | Free space measured1.2GiB during this batch;101 Deno and643 Flutter passes completed using cached dependencies. Monitor current headroom before native builds or additional images. | Check current headroom before each resource-heavy run; use bounded sequential work and preserve existing evidence |
| DEP-003 | Internal Flutter 3.44.3 / Dart 3.12.2 executed successfully; revision matches repository release script | Run final source regression with this pinned SDK and retain exact version evidence |
| DEP-004 | Fresh Android16/API36/arm64 collector emulator passed6 isolated checks across3 runs and was removed. Docker is available and PostgreSQL fixtures ran. Physical-device, operational app/collector, iOS and provider acceptance remain unverified. Supabase cloud discovery again returned no project. | inspect available devices/environments and use designated synthetic accounts |
| DEP-005 | No new review or acceptance has occurred | prepare final artifact-bound comparison and UAT packet before requesting review |
| DEP-006 | Installed Playwright 1.62.1 expects Firefox build 1538; only older build 1511 found. Chromium 151 and WebKit 26.5 ran. | Use matching existing Firefox/browser runtime or explicitly provision one when storage permits |
| DEP-007 | Live official reference browser returned HTTP 403 security-check page. Those captures are excluded from comparison. Dated skill observations are available, original homepage frame is not. | Obtain an accessible approved source capture; keep current source fidelity unverified |
| DEP-008 | Selected actual Auth/PostgREST/Storage/Realtime and Deno handlers qualified locally. Driver discovery FQA-037 repaired. Storage1.68.10 concurrency FQA-035 remains open; initial Realtime cold-start miss, reconnect/client lifecycle, hosted versions/Edge parity/jobs and configured integration remain pending. | Continue Admin-purpose/session and remaining API/service qualification in the isolated namespace; use approved QA configuration when supplied |

Dependency observations above retain their historical dates and must be rechecked before execution. In particular, old disk capacity and service/session availability are not current measurements. The approved-configuration request remains pending; no credential values are included.

## Evidence and completion discipline

Archive prior evidence; preserve recovered work and original failures. Reuse pinned tools and existing frameworks. Every new result records actual command, version, source/artifact/reference hashes, case/role/state and limits. Only actual evidence closes a requirement. Record prerequisites separately from product defects, use no fabricated credentials/results/approvals, and keep device/provider/deployed/human acceptance distinct.

The original 14 September plan is preserved byte-for-byte in `build/qa/fullstack-qa-20260914/goal-refresh-20260919-original-plan.md`; its SHA-256 is `a76d44557724f4e045aed993afc386c02c744cd6735da3ae7a9998587d971263`. All 34 prior registers are archived alongside it. The 19 September update changed documentation only, not application code or a QA result.
