# Mobio whole-system production checklist — 1 October 2026

This checklist complements the 100 design criteria and 60 operational procedures in [design-review.md](design-review.md). It assesses the current repository, tests and available external evidence. It is not a list of 100 passing production tests. Preserve existing M001–M095/G01–G10 owners and dependencies; use the CR findings in the [main review](../mobio-production-readiness-critical-review-2026-10-01.md) as a crosswalk.

**States:** VL = verified locally for the named bounded check; PART = implementation/partial evidence; FAIL = observed failure or confirmed source defect; UV = production outcome unverified; NA = outside the declared scope. “Closure” is future acceptance work, not a claim it has run. Exact file/line evidence and detailed test cases reside in the three specialist reviews. [verification-summary.json](verification-summary.json) preserves command results and live readback.

## Product, ownership and architecture

| ID | Criterion | Result / actual evidence | Closure and responsible owner |
|---|---|---|---|
| SYS001 | Approved capability and audience boundaries | PART: AGENTS, current scope and dated BioPay/transport/Face approvals read | Product: publish one exact enabled-feature/platform/role matrix; reconcile stale scope prose |
| SYS002 | No out-of-scope dispatch, fare or route computation | PART: protected scope and current boundary tests/source reviewed | Backend/product: retain 410 compute_route and deny inactive legacy mutations in deployed state |
| SYS003 | Complete route and non-router task census | FAIL: 47 render routes indexed; privacy request pushed page omitted | Design/app: include pushed pages, sheets, fallbacks, permissions and material states, resolve denominator |
| SYS004 | Named accountable feature/release owners | UV: workbook earlier lists assigned-person cells unassigned | Product/release: assign people and escalation authority to M/G tasks; record independent acceptance |
| SYS005 | Enforced dependency direction and source boundaries | VL: mobile reviewer ran repository structure checker successfully | Architecture: retain core/domain/shared package rules after refactoring; check structural changes |
| SYS006 | One canonical consumer per active workflow | PART: newer payment routes coexist with orphan screens/tests | Mobile: preserve unique behavior, move acceptance to routed implementation, remove only proven orphan duplicates |
| SYS007 | Typed data, identity and money contracts | PART: recent M063 typed projections and response guards exist | Feature/backend: malformed/missing/wrong-owner/version/state responses fail safely at real consumers |
| SYS008 | Bounded presentation and operation ownership | PART: large wallet/chat/admin/BioPay orchestration files measured | Architecture: extract touched coordinators without losing epoch, generation, idempotency or route semantics |

## Authentication and authorization

| ID | Criterion | Result / actual evidence | Closure and responsible owner |
|---|---|---|---|
| SYS009 | Verified identity originates on server | PART: new verified-phone authority migration; old mutable-profile report is historical | Auth: deployed real OTP identity, alias-change and recipient-resolution negative tests |
| SYS010 | Store-review access is isolated | FAIL: fixed review branch creates ordinary sessions; CR02 | Auth/release: isolated synthetic realm, scoped authority, rotation/disablement and denial of real data/mutations |
| SYS011 | WhatsApp proof is enforced per intended session | UV: durable provider metadata/password-session composition needs real Auth acceptance | Auth: test password/phone change, token refresh, bootstrap and alternative provider paths against actual configuration |
| SYS012 | OTP expiry, single-use and shared abuse limits | PART: Deno verification and DB rate-limit source tests | Auth: real concurrent replay/brute force/delivery loss and provider outage; review branch must not escape policy |
| SYS013 | Tenant object and property permissions | FAIL: organization helper membership branch ignores requested permission/role; CR01 | Backend/security: full-schema cross-tenant and member/viewer/driver negative RPC/PostgREST matrix |
| SYS014 | Admin allowlist, lease and revocation | PART: admin lease hardening and client invalidation exist | Security: expired/revoked/deactivated permission tested at every deployed server mutation |
| SYS015 | Fresh proof before sensitive changes | FAIL: recent admin helper has no production callers; CR03 | Backend/security: enforce server step-up on grants, allowlists and monetary administration |
| SYS016 | Deep links cannot bypass session/role policy | PART: route guards and token validation; native link ownership gap | Mobile/security: cold/warm/resume/malformed/expired/duplicate arrivals and denied role transitions |
| SYS017 | Session storage and account replacement | PART: native encrypted storage, epochs and many race tests | Mobile/security: inspect signed package backup/storage; same-owner relogin, logout/replacement and real revocation |
| SYS018 | Network and server credentials stay separate | VL: local credential-pattern scan passes; service-role limited to server source | Security: artifact contents, CI scope, provider rotation/provenance and broader full-history/Drive access review |

## Database, API and integration correctness

| ID | Criterion | Result / actual evidence | Closure and responsible owner |
|---|---|---|---|
| SYS019 | Ordered reviewed migration sources | VL: 119 source migrations; current hardening manifest/order checks pass | Database: preserve immutable history and source hashes; stage forward fixes instead of rewriting deployed migrations |
| SYS020 | Clean full-schema replay | PART: 30 September report records successful disposable 119-migration replay | Database: exact candidate clean replay with actual extensions, assertions and retained environment identity |
| SYS021 | Representative upgrade and rollback compatibility | UV: clean install is not sanitized production upgrade | Database/release: populated forward rehearsal, lock/runtime duration, backfill invariants and app-version compatibility |
| SYS022 | Actual Auth/JWT/PostgREST role behavior | UV: component fixture evidence; connected account cannot access configured project | Backend/security: effective grants/functions/RLS readback and real role/session concurrency matrix |
| SYS023 | Security-definer grants/search paths | PART: hardening revokes/grants exist; helper composition defect found | Database/security: audit all callers/roles/ownership/search paths and default privileges on effective schema |
| SYS024 | Storage ownership and upload/delete races | UV: historical race remains separate; linked checks skipped | Backend: real owner/cross-owner MIME/size/path overwrite/deletion race and private signed-URL expiry |
| SYS025 | Realtime and nearby privacy | PART: bounded-driver discovery hardening exists | Backend/privacy: deployed publication/filter/blocked-user/location-age/role tests; no unrestricted raw coordinates |
| SYS026 | Six-digit member allocation and collisions | PART: canonical member-ID remediation exists; display hash fallback repaired | Backend/mobile: complete migration/collision/capacity/recipient parity tests on actual schema; never fabricate IDs |
| SYS027 | Error/version/container contract validation | PART: strict typed projections and unknown outcomes | API/feature owners: unexpected enum/body/status/version/empty acknowledgement cannot fabricate success |
| SYS028 | Timeouts govern actual underlying work | PART: client deadlines/operation identity; collector total-budget defect | Platform/backend: hung/late/connect/write/read cancellation and one underlying completion owner |
| SYS029 | Idempotency and retry reconciliation | PART: chat/push/privacy/SMS/wallet journals exist | Backend: real duplicate/concurrent/lost-response tests, bounded retries, stable operation IDs and truthful uncertainty |
| SYS030 | Places/geocoding admission and cost limits | FAIL: bootstrap users accepted, isolate-local quota; CR12 | Backend: verified-session/durable rate budget; keep routes/ETA out of scope |
| SYS031 | Notifications use current token/owner | PART: durable outbox and token lifecycle hardening | Mobile/backend: account switch, invalid token, provider errors, expired lease, retry/backoff and delivered/opened receipts |
| SYS032 | AI/admin content generation control | PART: server functions/secrets exist; not exercised with paid providers | Backend/product: authorization, usage budget, prompt/data minimization, output moderation and provider-failure fallback |

## Monetary evidence, optional transport, collector and Face

| ID | Criterion | Result / actual evidence | Closure and responsible owner |
|---|---|---|---|
| SYS033 | External handoff is not payment completion | PART: BioPay typed request/prepare/claimed outcome boundaries | Product/backend: operator cancel/return/missing app/unknown and claimed-vs-confirmed states accepted on devices |
| SYS034 | Booking paid state requires trusted authority | FAIL: direct write denied but permission-helper RPC path remains; CR01 | Backend: actual member cannot invent provider/reference; real authorized receipt/seat transition tested |
| SYS035 | Holds conserve seats under concurrency | PART: hold/expiry SQL hardening and source fixtures | Transport/database: actual simultaneous holds, expiry and confirmation conserve capacity/uniqueness |
| SYS036 | Signed SMS upload is not trusted receipt proof | PART: strict allocation and durable intake source | SMS/backend: independently reconcile merchant/currency/reference/amount/payer; uncertain receipts stay reviewable |
| SYS037 | Collector enrollment and signature lifecycle | PART: policy/lease/storage/native controls implemented | Operations/security: dedicated SIM/device custody, enroll/revoke/replace/key rotation and lost-device drill |
| SYS038 | Collector retention, recovery and queue bounds | PART: durable queue/overflow controls; total request deadline gap | Android/operator: power loss/boot/force stop/OEM throttling/saturation/partial ACK/duplicate/cancel tests |
| SYS039 | Collector permission and distribution separation | PART: separate institutional app with target36/QA variants | Release/security: merged consumer/collector package permission readback and correct private/store distribution approval |
| SYS040 | Face receiving recipient remains eligible | FAIL/PART: recipient Auth moderation not demonstrated; CR11 | Face/backend: banned/deleted/consent withdrawn/method removed/late-vector/account change denied |
| SYS041 | Face model image/calibration/capacity | UV: host/model fixtures do not accept Linux image or real cohort | Face/QA: pinned image/models, consented representative accuracy/margin/cold/warm/burst measurements and accepted residual risk |
| SYS042 | Optional activation is enforced server-side | UV: source defaults/gates are useful but deployed settings unknown | Feature/release owner: prove disabled clients, RPCs and ingress deny activation until G03/G04/G05 acceptance |

## Privacy, trust and legal/store applicability

| ID | Criterion | Result / actual evidence | Closure and responsible owner |
|---|---|---|---|
| SYS043 | Current accurate terms/notices | FAIL: terms describe anonymous optional-phone account; CR13 | Content/privacy: harmonize actual identity, features, sharing, processors and support; deployed review |
| SYS044 | In-app and web deletion request paths | PART: in-app intake implemented; public deletion URL returns200 | Privacy/QA: real account can submit/recover request; disabled/unavailable mode truthful; operator support reachable |
| SYS045 | Erasure fulfillment across processors | UV: workflow intake is not erasure executor; CR10 | Privacy/backend: Auth/SQL/objects/vector/analytics/push and processor deletion with lawful exceptions and receipts |
| SYS046 | Consent and withdrawal are meaningful | PART: optional face enrollment/permission flows source exists | Privacy/UX: understandable scoped consent, denial without coercion, withdrawal excludes lookup and late work |
| SYS047 | Data flow, retention and international locations | UV: no current accepted full flow/processor-location record | Privacy owner: actual Rwanda DPO applicability/registration/transfer/storage contracts, minimization and retention schedule |
| SYS048 | Store privacy labels/declarations match artifacts | UV: notices/source cannot establish submitted console state | Release/privacy: current merged permissions/SDK behavior vs Play Data Safety, Apple privacy manifests/labels and purpose strings |
| SYS049 | Credential and shared-folder containment | UV: previous public-writer removal does not close public-reader/children/provenance | Security/access owner: fresh recursive permissions, need-to-know access and provider revoke/rotation readback |
| SYS050 | Billing and entitlement policy classification | UV: TOKENS/Plus/transport/provider handoff have different possible rules | Product/release: classify enabled physical vs digital benefits and region/store approval; no assumed blanket exemption |

## Mobile and native compatibility

| ID | Criterion | Result / actual evidence | Closure and responsible owner |
|---|---|---|---|
| SYS051 | iOS location strategy compiled and usable | FAIL: missing required permission macro; CR04 | iOS: narrow macro/config correction and signed clean-build/device permission matrix |
| SYS052 | iOS NFC starts only from intended task | FAIL: global poll begins visible reader session; CR05 | Mobile: explicit iOS scanning, one session, cancel/background/timeout, Android passive-intent preservation |
| SYS053 | Native link owner and scene callbacks | FAIL/PART: app_links6.4.1/scene integration and handler conflict | Mobile: supported scene forwarding/owner, valid flags and signed cold/warm invite/payment/NFC one-arrival tests |
| SYS054 | Permission unavailability is truthful | FAIL: missing/unimplemented plugin maps to granted | Mobile: unavailable state and recovery; OS grant/denial remains distinct |
| SYS055 | Location freshness means actual fix age | FAIL: OS last-known cache remembered as now | Location: age/accuracy/clock-skew checks and disclosed stale fallback; live driver fix retains separate behavior |
| SYS056 | Optional startup eventually attaches services | FAIL: late Firebase completion loses handlers/observer; CR06 | Mobile: one eventual handler set and correct crash/push/navigation events after slow/offline initialization |
| SYS057 | Mandatory configuration and sanctioned builds | PART: all four private public values present; current APK/web artifact input identity matches | Release: only sanctioned scripts/defines; never bare build/run; signed artifact/private config remains uncommitted |
| SYS058 | Platform/store release identity | PART: current APK target36/code17 hashed; current iOS archive unverified | Release: Play AAB version/signature/console and signed Xcode/current SDK/TestFlight/physical device evidence |
| SYS059 | Device compatibility and physical hardware | UV: one scoped emulator capture is not launch matrix | Mobile QA: Android/iPhone classes, low-memory/process-death, location/camera/QR/NFC/operator and assistive readers |
| SYS060 | Localization matches advertised support | FAIL/PART: locales declared but many visible/recovery strings English | Product/localization: EN/FR/RW complete tasks/errors/native disclosures/date/plural/number extremes and reviewer acceptance |

## Website, web/PWA and administrative outcomes

| ID | Criterion | Result / actual evidence | Closure and responsible owner |
|---|---|---|---|
| SYS061 | Current local website scope | VL: public-site source verifier passes; HTML/CSS/content read | Web/product: strengthen behavioral/content checks and maintain approved capability truth |
| SYS062 | Live public notices/association docs | PART: sampled website/policy/deletion/assetlinks/AASA HTTP200 | Web/release: correct content, deployed hash/team/signer, installed universal/app links and support outcomes |
| SYS063 | Actual deployed consumer/admin entrypoints | FAIL/UV: canonical probes returned403/503; browser access untested | Hosting/QA: intended host/release/access policy and authenticated task/browser verification |
| SYS064 | Surface-specific security/capability headers | PART: worker policy implemented; sampled marketing lacks CSP/HSTS | Web/security: actual approved shell/header/CSP-origin capability matrix; no wildcard widening merely to load previews |
| SYS065 | Mixed-version assets and update recovery | VL/PART: 69 worker fixtures pass, actual installed/browser update unverified | Web QA: old tab/new deploy/rollback/stale manifest/offline active write and obsolete assets on launch browsers |
| SYS066 | Installed PWA storage/account isolation | UV: fixture/cache source does not establish installed modes | Web QA: storage quota/loss/restricted profiles/logout/same-owner/new-owner/foreground stop and draft recovery |
| SYS067 | Responsive keyboard/zoom/reader outcomes | PART: scoped200% Android capture and widget fixtures | UX/QA: real browser/iOS/Android tasks at declared widths,200%/400% as applicable, keyboard and readers |
| SYS068 | Website SEO and conversion truth | PART: metadata/links implemented, live store/indexability not accepted | Content/web: canonical robots/sitemap/sharing/crawl, real supported store/download path and honest availability |
| SYS069 | Admin query result ordering | FAIL: reports/trips no latest-request guard; CR07 | Admin: newer search/filter/page wins even when older result/error finishes last |
| SYS070 | Admin sort, pagination and totals | FAIL: page-local sorting and lower-bound total labeling; CR08 | Admin/data: stable server query or explicit page-bounded semantics; truthful exact/estimated counts |
| SYS071 | Privilege changes are reviewed and accountable | FAIL: immediate bulk role commit; CR09 | Admin/security: review recipients/effects, cancel, per-row partial/unknown outcomes, freshness and audit trail |
| SYS072 | Moderation/support/health works with real roles | PART: reports/blocks/health admin implementation and tests | Admin/operator QA: actual queue resolve/block escalation, privacy/push age/unknown state, denied/revoked permissions |

## UI, accessibility and testing

| ID | Criterion | Result / actual evidence | Closure and responsible owner |
|---|---|---|---|
| SYS073 | Sole visual authority and own identity | VL/PART: design-authority checker passes; selected originals and specimens inspected | Design: preserve current cohorts/typologies and full colors; no competing spec or source brand identity |
| SYS074 | Fonts, imagery and third-party licensing | PART: Inter packaged, static Aeonik registration corrected; marketing rights unverified | Design/legal: actual supplied weights, loaded fonts/glyphs, production usage entitlement and model/asset licenses |
| SYS075 | Complete R001–R100 and operational criteria | UV: all criteria mapped, zero complete accepted cases | Design/QA: execute applicable task procedures and disposition each comparator/adaptation; resolve denominator |
| SYS076 | WCAG/native reader task acceptance | UV: semantic controls/local fixtures cover a subset only | Accessibility QA: focus/reading/order/labels/errors/reflow/contrast/targets/reader speech on actual supported surfaces |
| SYS077 | Required full Flutter verification | FAIL: current complete run has golden failures; exact final result in summary | App/design QA: inspect each failing comparison vs sole authority; fix or explicitly review baseline, then full passing run |
| SYS078 | Python and backend unit regression | VL:483 Python,116 Deno passed/1 ignored; no failed tests | QA: retain distinctions; ignored provider test is not live acceptance; avoid duplicate-count totals |
| SYS079 | Real SQL/HTTP concurrency vs fixture checks | PART: previous replay/component evidence; new helper path lacks actual-role proof | Backend QA: add material role/race/failure proofs at effective full schema; do not certify via source strings |
| SYS080 | Native/browser integration tests | UV: no root integration_test suite; current full task/device matrix unaccepted | QA: use existing test/evidence conventions, physical/installed task proof; no unnecessary replacement framework |

## Delivery, reliability, operations and business readiness

| ID | Criterion | Result / actual evidence | Closure and responsible owner |
|---|---|---|---|
| SYS081 | Exact dependency/toolchain reproducibility | PART: Flutter pin and lockfiles; Deno v2.x/runner movement | Release: accepted versions/images/models, clean generated outputs, dependency advisories/SBOM/licenses/provenance |
| SYS082 | Hosted required CI actually executes | FAIL: current exact HEAD and recent runs startup_failure | Repository owner: establish cause and successful required matrix at exact candidate; zero jobs cannot pass |
| SYS083 | Repository and deployment separation | FAIL: main unprotected; no environment reviewer rules; admin bypass | Repository/release: enforceable private-repo controls, independent approval/key custody, narrow publisher and audited emergency path |
| SYS084 | Candidate, configuration and approval receipts | PART: Android/PWA manifests and negative validators implemented | Release: verify underlying real evidence, source/artifact/config identities, freshness, reviewer/build actor separation |
| SYS085 | Monitoring, logs and alert ownership | UV: event/outbox/admin-health source exists; face observability disabled | Operations: privacy-safe correlated metrics, real alert exercise and named owner for user-visible failures/backlog ages |
| SYS086 | Capacity, battery, latency and costs | UV: no accepted current launch workload/device/cost measurement | Engineering/operations: native profile/field web/DB/OTP/face budgets, saturation/burst and usage caps; scale after measurements |
| SYS087 | Backup/restore, incident and support readiness | UV: runbooks distributed; no accepted current cross-store restore/incident drill | Operations: actual database+object/vector/config restoration, RPO/RTO, key revocation/replay reconciliation and support escalation |
| SYS088 | Exact-candidate platform/provider/store release decision | UV: no complete independent accepted receipt bundle | Release owner: G01–G10 applicability, signed devices/provider/store, privacy/operations and protected publication authority |

## Research basis and applicability

The main review cites the current official requirements at the claims they support: [OWASP ASVS](https://owasp.org/projects/asvs), [MASVS](https://mas.owasp.org/MASVS/), [WCAG2.2](https://www.w3.org/TR/WCAG22/), [Flutter performance](https://docs.flutter.dev/perf/best-practices), [GitHub deployment controls](https://docs.github.com/en/actions/reference/workflows-and-actions/deployments-and-environments), [Play API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en), [Google deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en), [Apple deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app/), [Rwanda DPO](https://dpo.gov.rw/), [Supabase backup scope](https://supabase.com/docs/guides/platform/backups), and [Web Vitals](https://web.dev/articles/vitals).

Do not infer worldwide legal coverage, guaranteed store eligibility, global accessibility conformance or security certification from this matrix. Applicable launch countries, enabled optional features, platforms, real role/configuration and measured operating objectives determine the acceptance work. Dispatch-grade routing, ride lifecycle and in-app ride settlement remain outside this review's approved implementation recommendations.
