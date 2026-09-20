# Mobio full-system QA review and remediation plan

Created: 14 September 2026. Scope: the Mobio system in this repository. Execution status is maintained in `fullstack-qa-20260914/status.json`; creation of this plan is not completion of QA.


**Remaining-work update, 19 September 2026:** The execution goal now follows the complete [remaining-task addendum](fullstack-qa-20260914/remaining-tasks-20260919.md) and its [57-task register](fullstack-qa-20260914/remaining-tasks-20260919.csv), in addition to every original requirement below. Start with the unfinished notification compiler/behavior batch and source reconciliation, then continue all phases. Native goal status was observed as `usageLimited`; this documentation update neither resumes nor completes it. The original plan and prior registers are archived with their hashes.

**Integration update, 20 September 2026:** REM-002 is complete locally, with 28 focused checks, 670 full Flutter tests and clean analysis. Continue the other 56 packages in the [remaining register](fullstack-qa-20260914/remaining-tasks-20260919.md); all original acceptance gates remain open until their own evidence is complete. See [main integration](fullstack-qa-20260914/main-integration-20260920.md).

## Objective and execution order

Review every implemented Mobio surface and its supporting services, reproduce defects, repair failures within approved product scope, and deliver a traceable QA and readiness decision. Preserve Mobio's identity, routes, capabilities, data contracts and workflows while assessing fidelity to the selected Revolut visual system.

The sequence is **baseline → inventory and coverage → security/data → user journeys → visual/accessibility → platform/performance/recovery → remediation and regression → readiness report**. Address a reproduced critical defect as soon as its dependencies permit. Continue independent local work when an external prerequisite is unavailable.

This plan is saved before creating the execution goal. The goal follows this document and its evidence registers. There is no invented time or token budget, and no additional product or repository is silently included by “all apps.”

## Current facts to reconcile

| Item | Observed during planning | Consequence |
| --- | --- | --- |
| Working authority | `/Users/jeanbosco/Projects/Recovered-PRO-G40/Mobio`, branch `codex/recovered-pro-g40-2026-09-10`, HEAD `d94c4edb11a7496753a28f906b2f397fe06d6b12`, with substantial tracked and untracked work | Capture current file hashes and status; preserve recovered edits. HEAD alone does not identify the tested source. |
| Application structure | One Flutter app, Android/iOS/web hosts, shared Admin; static `landing/`; separate Kotlin Android utility `apps/momobio_sms_bridge/` | Test each runtime and audience separately even where code is shared. |
| Initial source inventory | 48 expanded router patterns from 45 path declarations; 10 feature directories; 16 Edge Function entrypoints; 96 migration files; 86 root Flutter test files; 10 Deno test files; four public HTML pages | These are inventory counts, not executed tests or a fixed final coverage denominator. Reconcile aliases, platform gates, overlays, package tests and generated route families. |
| Recovery limitations | The adjacent restoration report identifies six saved alternatives and fifteen incomplete historical file reconciliations | Inspect relevant conflicts; use current source and reproduction, not old reports, to decide closure. |
| Runtime configuration | Root `.env` absent; `android/key.properties` present | Locate legitimate runtime configuration and verify signing references without printing secrets. File presence does not prove usable credentials or signing. |
| Toolchain | Internal Flutter 3.44.4 / Dart 3.12.2 verified; repository `.flutter-version` is 3.44.3 | Record the mismatch; use the internal SDK for local triage and obtain exact pinned-version evidence before claiming CI/release equivalence. Do not restore damaged SSD paths or silently change the pin. |
| Packaging | `scripts/tests/pages_worker.test.mjs` imports missing `scripts/web/pages_worker.mjs` | Reproduce the failure; reconcile the intended implementation and packaging consumers. |
| Available space | Approximately 2.16 GiB free during planning | Recheck before resource-heavy work. Sequence builds and retain evidence; do not delete user files or start a large native/Docker build without sufficient headroom. |
| Prior QA | `fullstack-qa-uat-20260906.md` recorded a NO-GO; recovered hardening edits exist | Reopen QF-01–QF-07 as historical findings requiring current verification, not automatically current failures or passes. |

## Included surfaces and responsibilities

Responsibilities below describe work ownership, not appointed reviewers or delegated agents.

| Surface | Source and implemented coverage | Responsible role |
| --- | --- | --- |
| Android passenger/driver app | Root `lib/`, `android/`; Home, Trips, Nearby, profile, chat, notifications, EV chargers, BioPay and approved extensions | Mobile engineering / QA |
| iOS passenger/driver app | Same product with `ios/`; platform availability, permissions, deep links, lifecycle, camera and external handoffs verified independently | Mobile engineering / QA |
| Consumer web app | Root Flutter web host and consumer deployment paths; direct URL, history, session and browser-specific capabilities | Web engineering / QA |
| Admin panel | `lib/features/admin/`, `/admin*` and `/admin-auth`; users, trips, agencies, vehicles, chargers, subscriptions, reports, BioPay Ops/routes, audit, health and broadcast controls | Admin engineering / security / QA |
| Installed PWA modes | Each consumer/Admin mode actually supported by packaging and manifests; desktop and mobile installations recorded separately | Web / platform QA |
| Public website | `landing/` homepage, privacy, terms, deletion, downloads, support links, Business login and association files | Web / content / QA |
| Mo Mobio Android utility | `apps/momobio_sms_bridge/`; existing collector identity, queue, service, retry, boot/update recovery and server boundary | Android / backend security |
| Backend and integrations | `supabase/functions/`, migrations, RLS/RPCs, storage, realtime, jobs; WhatsApp OTP, FCM/APNs, Google Places/Geocoding, AWS face services and approved external USSD handoff | Backend / data / security |
| Delivery and operations | Shared packages, build scripts, CI, Cloudflare packaging, runtime configuration, signing, logs and release evidence | Release / operations |

Preserve approved BioPay discovery work in `docs/product/biopay-discovery-20260908/` and dated BioPay/public-transport approvals. Determine actual shipped versus planned public-transport, subscription and wallet-related capabilities from current source. Do not turn old proposal gaps into new feature implementation.

The existing SMS utility is included for inspection and containment testing. Its presence is not authorization to activate SMS ingestion. Any disagreement between historical documents and current workspace boundaries is recorded against the exact capability before changing it.

Permanent invariants: six numeric digits for user-facing IDs; Rwanda defaults; WhatsApp OTP with separate allowlisted Admin purpose; anonymous sessions are bootstrap only. Keep `maps-gateway compute_route` returning 410. Do not introduce route ETA, distance, polylines, route matrices, fare quotes, dispatch or trip settlement. Preserve Google Places/Geocoding and external Google Maps handoffs. BioPay must not collect PINs or imply settlement from a dialer return.

## Phase 0 — Establish a trustworthy baseline

1. Record source root, branch/HEAD, dirty-file list, relevant source and lockfile hashes, recovery conflicts, disk capacity, tools, available devices, public runtime configuration availability and evidence locations. Never put configuration values, signing passwords or private customer information in reports.
2. Compare recovery limitations to current files and references. Preserve existing changes and classify missing code, missing tests, obsolete references and missing historical evidence separately.
3. Read scripts before running them; distinguish local checks, linked read-only checks, state-changing fixture setup, provider calls and deployment. Identify hidden skips and commands that mutate lockfiles/generated output.
4. Run inexpensive structure, helper, web-worker, secret and source-integrity checks first. Run analysis and existing test suites using the verified SDK where capacity permits. Record actual failures and skips.
5. Establish a synthetic test environment and accounts: guest/anonymous bootstrap, passenger A/B, driver A/B, allowlisted Admin, denied/revoked Admin, payee A/B and enrolled/revoked collector. Keep all fixture writes isolated and removable. Check for network/provider side effects before executing tests.

Exit evidence: `baseline.json`, baseline logs, dependency register, and a source fingerprint. Known external constraints do not stop independent checks.

## Phase 1 — Build a complete, executable coverage inventory

1. Extract all routes, generated families, aliases, redirects, deferred routes, dialogs, sheets, menus, pickers and platform handoffs. Cross-check against navigation and feature sources; the current 48-pattern extract is the starting point.
2. Inventory APIs, callable RPCs, tables/views, RLS/grants, storage buckets, realtime subscriptions, background jobs, native permissions, build/deployment surfaces and provider boundaries. Classify each as active, compatibility-only, disabled/retired, or unverified.
3. Trace **requirement → route/state/role → API/RPC → persistence/authorization → test → evidence → finding/closure**. Source-string tests remain contract checks; add behavioral tests when the outcome is not proven.
4. Assign every applicable operational checklist procedure F/V/A/M/W/S/P and the relevant R001–R100 checks. Skill-maintenance K checks are not Mobio product tests; bundle integrity is a provenance check only.
5. Define expected results, reproducible steps, test data, platform, comparator, severity and owner before running each case. Document non-applicability with a product reason and evidence. Do not generate a superficial Cartesian matrix or call listed rows tested.

Exit evidence: versioned `routes.csv`, `cases.csv`, `backend-inventory.csv` and `reference-map.csv`, with reviewed scope and explicit gaps.

## Phase 2 — Verify security, APIs and data integrity

Prioritize the historical collector, provider, face-enrollment and Admin trust-boundary findings. Use local tests and dedicated fixtures before live integration work.

| Area | Required verification |
| --- | --- |
| Authentication | Missing/malformed/expired/revoked sessions; anonymous bootstrap denied on protected work; OTP expiry, resend, replay, attempt/rate limits and app-versus-Admin purpose separation; safe redirects and logout. |
| Authorization and isolation | Passenger/driver ownership, denied and revoked Admin roles, direct RPC bypass attempts, IDOR/cross-user reads/writes, storage/realtime isolation, least privilege and security-definer search paths/grants. |
| BioPay provider authority | Reject unauthorized calls before AWS work; bind one-time liveness/enrollment sessions to the user and device where applicable; reject forged provider IDs/results, cross-user sessions, replay, revoked consent and duplicate identity association. Mocked negative tests must show zero provider calls. |
| Collector authority | Registered/revocable device identity, signatures/timestamps/nonces as implemented, replay resistance, batch limits and authenticated receipt provenance. A parsed SMS is not proof of payment. Reject unauthorized work before parsing or privileged RPCs. |
| Database correctness | Replay all available migrations in a disposable database; distinguish fixture prerequisites from a genuinely clean replay; test constraints, transactions, concurrency, duplicate receipts, subscription activation idempotency, token/request expiry and cleanup. Never reset a linked database. |
| API behavior | Schema/input limits, safe errors, methods, CORS, abuse/rate handling, injection and request validation, controlled timeouts/retries, idempotency, logging redaction and deprecated endpoint denial. |
| Storage/realtime/jobs | Upload type/size/access, signed URL scope, deletion/retention behavior, subscription cleanup, reconnect ordering, duplicate/out-of-order events, job retries/dead letters where implemented. |
| Dependency and delivery security | Frozen dependency reproducibility, available vulnerability/advisory review, secret scanning, platform exports/deep-link validation, no privileged key in client bundles, workflow permissions and pinned actions. |
| Operational integrity | Health is distinguished from provider readiness; errors have useful correlation without sensitive payloads; inspect existing monitoring, backup/restore evidence and documented rollback compatibility. Exercise restoration only in an isolated target. |

Use versioned [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/) requirements as the web/API security crosswalk and applicable [OWASP MASVS](https://mas.owasp.org/MASVS/) controls for native storage, authentication, network, platform and privacy. Record the exact versions/IDs used; this review does not claim certification from checklist coverage.

Exit evidence: executed security cases, local database replay/behavior results, dependency findings and deployed-state verification gaps. A skipped linked check cannot count as a backend release pass.

## Phase 3 — Run complete product journeys

For each journey exercise success, cancellation, empty/no-result, invalid input, loading, duplicate tap, timeout, server failure, permission denial, session expiry, interruption and recovery wherever applicable. Verify the actual outcome and persisted state, not just the final screen.

| Journey | Observable completion and critical negative paths |
| --- | --- |
| App/Admin login | Correct purpose/role enters the intended authorized destination; denied/expired flows recover without bypass or cross-purpose OTP replay. |
| Discovery and profiles | Passenger/driver and vehicle filters show appropriate records; privacy/blocking/visibility and location denial hold; user-facing IDs and Rwanda defaults remain correct. |
| Scheduled trips | Create → view → edit → cancel persists once; two-user ownership, recurring dates, timezone, invalid past time and stale edits are handled; Maps opens externally. |
| Chat, reports and notifications | Correct participants and ordering; safe resend/reconnect; blocked users and reported content follow backend rules; notification tap reaches an authorized destination. Outbound delivery uses mocks until explicitly authorized. |
| Profile and preferences | Setup/edit, long content, verified contact, account deletion entry, theme/locale, saved data and device relaunch remain coherent. |
| BioPay discovery and handoff | Recipient → method/amount → route/fee review → explicit external handoff; wrong/changed recipient, stale fee information, unknown fees, inactive providers and return-with-unknown-outcome remain truthful. |
| QR, links, requests and NFC | Valid/invalid/expired/revoked payloads, cold/warm deep links, wrong account, unavailable scanner/NFC, retry/cancel and sharing work without embedding executable untrusted USSD. |
| Face enrollment/scan | Consent → guided capture → provider-verified result → correct payee → user-confirmed handoff; rejected match, cancellation, denial, stale session and replacement cannot create false identity/payment success. |
| Approved transport/subscription extensions | Test each implemented agency/catalog/booking/entitlement operation and its authoritative data boundary; distinguish planned features and disabled capabilities from shipping ones. |
| Admin operations | Correct role/context; search/filter/sort/page, details, empty/error states, moderation, audit, operational health, route configuration and concurrent edits. Test bulk/partial-failure behavior only where supported. |
| Website conversion | Mobile/desktop navigation → actual download, support, legal/deletion or Business login destination; correct page identity and working assets after direct deep links. |
| Existing Android collector | Controlled synthetic receipt → persistent local queue → authenticated upload → authoritative deduplication outcome; offline/reboot/update/revocation behavior and no inbox-history scan. |

## Phase 4 — Review Revolut fidelity and accessibility

The selected [revolut-design skill](/Users/jeanbosco/.codex/skills/revolut-design/SKILL.md) is the design authority. Repository `design.md`, tokens, screenshots and acceptance records are product adapters/evidence and cannot override it. Update conflicting adapter wording only when required for the implementation under review.

Keep source cohorts separate: September 2026 iOS Dark · Glow for native overview/task patterns; selected blue-indigo onboarding references for WhatsApp login; the dated UK public website cohort for marketing; official Business imagery for Admin hierarchy with explicit table adaptations. Existing Mobio mappings are Home blue, BioPay teal, Trips/Nearby purple, wallet-related overview muted blue-violet, Profile/Plus vivid violet and quiet neutral detail/utility surfaces. These examples do not limit the full colour-role review.

1. Verify skill bundle integrity, then open each actual comparator used. Record its hash, cohort, platform, theme, region, date/build/viewport where known and visible-region limitations. Missing images stay unverified.
2. Audit all applicable colours, gradients, typography, density, spacing, icons, own-logo treatment, overlays, focused/selected/disabled/error states and responsive variants through shared tokens and actual consumers.
3. Capture matching target viewport, scroll position, role, state and theme. Inspect source and target together. Keep direct comparator, component comparator and explicit adaptation distinct. Golden updates require visual review; a fixture gallery does not prove production navigation.
4. Test keyboard/focus, modal containment/return, names/roles/states, screen-reader task traversal, status/error announcements, actual hit regions, contrast, reduced motion, text enlargement and unsupported-feature explanations.
5. Assess applicable [WCAG 2.2 A/AA criteria](https://www.w3.org/TR/WCAG22/) on web surfaces, including 320 CSS-pixel reflow and 200% text enlargement. Include actual 400% browser zoom where it provides the reflow case; retain legitimate two-dimensional table exceptions. Native accessibility uses real platform behavior, separately from browser semantics.
6. Apply all ten `MOBILE-DESIGN-100` criterion IDs without renaming/removing them: reference_fidelity, hierarchy_density, typography, colour_elevation, spacing_shape, icons_assets, copy_annotations, interaction_states, responsive_keyboard, accessibility_native.

For mobile release acceptance, implement or repair the product adapter if absent: authority/reference/source/artifact hashes, complete governed case inventory, installed artifact identity, current comparison evidence and distinct implementer, independent visual reviewer and owner decisions. Never manufacture those decisions. Full fidelity is unverified until its required evidence exists; a checklist percentage is not pixel equivalence.

## Phase 5 — Test platforms, performance and resilience

| Dimension | Required envelope |
| --- | --- |
| Native | Android and iOS independently; compact and large phones, supported tablet/foldable/orientation cases, default/enlarged text, supported themes, keyboard and reduced motion. Emulator/simulator, physical device and signed release evidence are separate. |
| Web/Admin/website | Chromium, Safari/WebKit and Firefox where supported; 320, 390, 768 and 1440 CSS-pixel samples plus actual breakpoint boundaries; touch, pointer, keyboard and long/large datasets. |
| Installed PWA | Actual browser/OS/install mode; cold/warm/deep-link launch; offline/reconnect; session expiry/account switch; quota/storage loss; active-task update, old tab and compatible rollback. A shortcut is not WebAPK proof. |
| Data/content | Every supported locale, long names/translations, RWF precision, zero/large values, empty/large lists and correct date/time boundaries. Test RTL only if supported. |
| Native performance | Repeated cold/warm startup, scroll and transitions, memory growth, lower-powered hardware and relevant background work; record device/network conditions and establish explicit app budgets before assessing results. |
| Web/API performance | Measure initial usable screen, dense-route interactions, bundle/cache behavior and representative API/query latency; inspect indexes/query plans in an isolated dataset. Use bounded load only on a designated test target. |

Report [Core Web Vitals](https://web.dev/articles/defining-core-web-vitals-thresholds) field results separately from lab runs: good thresholds are LCP ≤2.5 seconds, INP ≤200 ms and CLS ≤0.1 at the 75th percentile. Missing field data is unverified; no build duration or single Lighthouse score substitutes for runtime evidence.

Use existing `scripts/perf/`, browser/native tools and repository tests. Do not install another test framework merely to produce more checks. Use actual test outcomes to choose meaningful additional integration tests.

## Phase 6 — Repair and prove closure

Triage P0 critical, P1 high, P2 medium and P3 low by reproduced impact. Fix local P0/P1 defects in approved scope first, then material P2 defects. Every finding records evidence, expected/actual behavior, reproduction, affected surface, owner, fix and retest; a missing prerequisite is separately identified rather than mislabelled a product defect.

Batch active user review notes and any pending unverified changes before rebuilding a web preview. Implement the entire batch, run focused checks, rebuild once, then inspect affected screens once. Correct the behavior before updating snapshots. Keep recovery edits and unrelated work intact.

After routing/auth/config/BioPay/platform/generated/package changes, run matching Dart analysis, Flutter tests and the relevant guarded release script. Run structural checks after structural changes and the secret scan before release changes. Reuse the existing CI entrypoints and make missing test coverage/skips visible rather than weakening gates.

Repeat tests only for changed behavior or unresolved failures; after a stable batch, run the appropriate whole-suite regression and final impacted journeys. Rebind artifacts/screenshots to the final source fingerprint.

## Phase 7 — Deliver the review and readiness decision

Deliver a self-contained `report.md`, evidence index and findings/closure registers with a per-surface verdict for functional correctness, security/data integrity, source fidelity, accessibility, performance and runtime resilience. Also report local tests, CI, packaging, installation, deployment, provider validation, store status and human acceptance separately.

The review is complete only after every in-scope case has an actual result or a precise unverified dependency, all executable planned work is done, reproduced in-scope P0/P1 defects that can be corrected locally are fixed and retested, and remaining work has an owner, exact next action and evidence requirement. Recording a case or blocker alone does not complete work that remains executable. The goal must remain active while meaningful authorized execution remains.

A release is **NO-GO** with an open P0/P1 product defect or a required unverified gate. A reviewed or built artifact is not deployed, a deployment is not provider/device proof, and neither is owner acceptance or public store availability. Medium/low residuals stay visible and cannot be silently accepted by the implementer.

## Execution commands and boundaries

Use explicit runtime paths. Node exists at `/Users/jeanbosco/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node`; Deno is available locally. Supabase CLI availability and Docker capacity must be established before database replay. Dependencies stay pinned; inspect bootstrap-generated changes before accepting them.

```bash
# Existing local analysis and tests; run sequentially for the shared Flutter cache.
FLUTTER_BIN=/Users/jeanbosco/Developer/flutter/bin/flutter scripts/ci/verify_flutter.sh

# Backend local checks, without accidentally selecting linked credentials.
env -u SUPABASE_ACCESS_TOKEN -u SUPABASE_DB_PASSWORD -u SUPABASE_PROJECT_REF \
  -u SUPABASE_WORKDIR REQUIRE_LINKED_SUPABASE=false scripts/ci/verify_backend.sh

# The full Deno tree must also be covered; enumerate permissions before execution.
deno test --frozen --lock=deno.lock --allow-env supabase/functions

python3 scripts/ci/check_repository_structure.py
python3 -m unittest discover -s scripts/tests -v
/Users/jeanbosco/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node --test scripts/tests/*.test.mjs
scripts/web/verify_public_site.sh
scripts/qa/scan_secrets.sh
git diff --check
```

Use existing database behavior/replay scripts only after confirming they target disposable local databases. Run both current helper/contract checks and actual RLS/concurrency behavior; synthetic fixtures do not prove deployed migrations.

For Android use `FLUTTER_BIN=/Users/jeanbosco/Developer/flutter/bin/flutter scripts/release/build_android_release.sh apk` and the `appbundle` variant only after runtime configuration, signing and space checks. For iOS use `scripts/ci/verify_ios_release.sh` with the explicit Flutter path. Inspect `prepare_pwa_bundles.sh`, `verify_pwa_bundles.sh` and the Cloudflare build wrapper before one complete web/Admin build. Build commands must carry **all four** public defines: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PRIVACY_POLICY_URL`, `ACCOUNT_DELETION_URL`; use the shared runtime parser. Never run bare Flutter build/run commands or copy privileged credentials into clients. Report missing values without substituting production-looking placeholders.

Authorized execution includes local code fixes/tests, synthetic fixtures, evidence capture and read-only verification of the identified deployment. Production migrations/deployment, store uploads, live biometric enrollment, paid provider actions and messages to people are not implied by this QA plan. Prepare concrete reviewable changes first if a separate authorization is needed. Outbound OTP/chat/push/broadcast tests use mocks until explicit authorization and designated recipients are available.

## Evidence files and status model

Keep review documents and compact synthetic registers under `docs/testing/fullstack-qa-20260914/`; logs, screenshots, traces and large artifacts under ignored `build/qa/fullstack-qa-20260914/`. Private source captures stay in their original reference archive. Store hashes and safe paths, not copied private pixels, OTPs, biometrics or customer identifiers.

Required registers: `status.json`, `baseline.json`, `routes.csv`, `cases.csv`, `backend-inventory.csv`, `reference-map.csv`, `findings.csv`, `dependencies.csv`, `evidence.json`, and final `report.md`. Create/populate each when its phase starts; empty headers are not completed deliverables. Use stable case/finding IDs and link historical QF IDs without overwriting old reports.

Case fields: ID, surface, route/component, role, state, platform/version, viewport/theme/locale, requirement/checklist IDs, preconditions, steps, expected/actual, status, command/test name, source/artifact/reference/evidence hashes, date, reviewer, finding IDs and closure action. Results are **pass**, **mismatch**, **unverified**, or **not_applicable with reason/evidence**. Execution state is separately planned/running/completed/blocked. If coverage is quantified, state numerator, denominator, exclusions and method.

Milestones: M0 baseline established; M1 inventory and test environment ready; M2 trust boundaries reviewed; M3 journeys executed; M4 visual/accessibility reviewed; M5 platform/performance/recovery executed; M6 remediations regressed; M7 report and remaining acceptance handoff delivered. Update the status file after each meaningful batch and keep the execution goal aligned with the actual remaining work.
