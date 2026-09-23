# Face enrollment, recognition and payment handoff audit

Audit date: 20 September 2026. Repository: Mobio, current working tree on `main`, base `9e21d3dc4939eafe52f23fe4fe5cd43f3620b415`.

**Verdict: NO-GO for releasing the face journey as a complete, secure feature.** The UI, AWS adapter and server-side authorization model exist, but the current Edge/SQL contract is broken. Liveness capture and image binding are incomplete. The face payment path also bypasses configured receiving accounts. No successful authenticated enrollment-to-payment journey was demonstrated in this review.

This is an audit, not a remediation or deployment. Existing annotation edits were preserved. No real face images, authenticated production mutations, provider activations or money transfers were performed. Findings below concern the inspected source unless explicitly identified as a live observation. The deployed database and authenticated Edge versions have not been reconciled with this checkout.

## What the feature currently means

Account registration/sign-in uses **WhatsApp OTP**. Face enrollment attaches a biometric profile to that existing account; it does not create an account, verify a legal identity, or implement face-only login.

The payment scanner is intended to identify the **recipient/payee**, using the rear camera. The payer then reviews receiving details and continues through an external provider. It is not payer biometric authorization, Face ID authentication, or an automatic debit. Android has an explicit dialer handoff; iOS/web/desktop use instructions where native dialing is unsupported. Opening a dialer is not proof of payment.

This interpretation follows the June AWS/USSD scope and the later September payment-discovery expansion, including their restrictions on settlement and recipient assurance.

```mermaid
flowchart LR
    A[WhatsApp OTP account] --> B[Profile: enroll face]
    B --> C[Create provider session]
    C --> D[Three still captures]
    D --> E[Last image sent to AWS]
    E --> F[Store enrolled face]
    F --> G[Payer scans recipient]
    G --> H[Server match proof]
    H --> I[Legacy request using login phone]
    I --> J[Common payment review]
    J --> K[External provider handoff]
```

The diagram represents the intended source sequence, not a passing end-to-end run. The session contract fails before provider work; the capture-to-liveness and face-to-receiving-account boundaries also need repair.

## Current implementation and evidence

| Stage | Implemented in source | Current assessment |
|---|---|---|
| Account registration | WhatsApp OTP and server-side verified-user checks | Face-based account registration is absent; existing-account enrollment is the supported model. OTP delivery was not exercised here. |
| Enrollment entry | Profile entry, Back, front-camera setup and three capture actions | Preview entry/return work. No explicit biometric notice/consent or useful accessible pose guidance. |
| Liveness | Create/Get AWS session API wrappers | No native/web liveness detector or streaming capture integration found. Server enforcement is optional. |
| Enrollment backend | Single-face/quality check, duplicate lookup, indexing, DB record and audit | Substantial implementation, blocked by API/SQL mismatch; liveness proof is not bound to indexed image. |
| Recipient matching | AWS search, server-owned proof, active profile lookup | Contract blocked; no demonstrated real recognition accuracy or anti-spoof behavior. |
| Face-to-payment integration | Match proof creates request; token enters common composer | Uses login phone instead of registered receiving methods; loses face identity context in the legacy/manual bridge. |
| Payment execution | Reviewed provider instruction, Android ACTION_DIAL, outcome evidence separation | External handoff only. Provider settlement and physical-device completion remain unverified. |
| Operations/admin | Enrollment and request views, provider health indicator | Health is configuration-only and cannot support the displayed readiness conclusion. |

Verification performed in this audit:

| Check | Result | What it establishes |
|---|---|---|
| Focused Flutter suites | **80 passed** | Existing face standby/payment surfaces, composer behavior and link contracts. No real camera/AWS/database journey. |
| Existing face Edge tests | **2 passed** | Mocked enrollment and unauthenticated requests blocked before AWS. |
| Additional audit reproductions | **3 defects reproduced** | Missing RPC argument, liveness/image substitution, misleading health policy. These tests assert current defects; their passing result is not acceptance. |
| Dart analysis of BioPay and Profile screen | **No issues found** | Static analysis only. |
| Existing local preview | Enrollment and scan inspected at the 390 × 844 phone frame; accessible tree inspected; scan Back → BioPay and Profile → enrollment → Back observed | Normal-size desktop-browser rendering/navigation. No camera permission or biometric capture. |
| Public provider health GET | HTTP 200; AWS configured; `production_ready: true`; `readiness_basis: configuration_only`; `liveness_required_default: false` | Current public endpoint/configuration indicator only. No AWS/IAM/collection or authenticated operation verified. |
| Preview/source consistency | Previous batch-13 changed-file hashes still match current files | Existing preview retained; no rebuild needed for this audit. |

No current evidence was produced for Android/iOS camera capture, real liveness, two-account database integration, recognition error rates, spoof resistance, native screen readers, provider dialing, or verified payment completion. No overall completion percentage is justified.

## Critical findings

### FACE-01 — P0: Edge/SQL operation contract is incompatible

`supabase/functions/_shared/biopay-authority.ts:11` calls `rpc_reserve_biopay_provider_operation` with only `p_user_id` and `p_action`. The sole current definition, `supabase/migrations/20260906143000_biopay_provider_authority.sql:47`, requires a third argument, `p_auth_session_id`, without a default. It validates that session and stores it in a NOT NULL column. `requireAppUser` returns only the user ID.

Every face action reserves an operation before calling AWS. With these source and schema versions, the RPC cannot resolve the submitted argument set and the Edge handler reports authorization service unavailable. A schema-aware RPC stub reproduced HTTP 503 using the real authority and handler. This was not a live PostgREST test.

**Required fix:** propagate the session identifier from validated authentication, preserve session/user ownership checks, and add an actual PostgREST contract test. Do not remove the session requirement to make the call succeed.

### FACE-02 — P0: Guided still photographs do not implement liveness

`biopay_face_enroll_screen.dart:58–110` creates a liveness session, takes three JPEGs and submits only the last image. The challenge IDs and count are client-reported metadata; the backend does not verify those poses or receive the first two images. No `FaceLivenessDetector`, `StartFaceLivenessSession` or corresponding native/web integration was found in the active app.

`BioPayFaceService.enrollFace` defaults `livenessRequired` to false. The backend requires it only when policy is explicitly true or the client asks for it. Thus fixing FACE-01 alone permits still-image enrollment by default. Turning the policy on alone does not finish the implementation: the app cannot complete the AWS video challenge.

**Required fix:** integrate the supported liveness capture component and enforce the chosen enrollment policy on the server. Treat the existing three-pose display as UI, not anti-spoof evidence. AWS documents the required detector-based capture flow. [AWS Face Liveness](https://docs.aws.amazon.com/rekognition/latest/dg/face-liveness.html)

### FACE-03 — P0: A live session can authorize a different submitted image

`biopay-face-provider/index.ts:171–244` reads only AWS liveness status/confidence, discards its reference image, and then detects/searches/indexes the caller's independent `image_b64`.

The isolated reproduction supplied successful liveness for synthetic reference A and a different caller image B. The handler indexed B and recorded `provider_liveness_verified`. AWS responses and images were mocked; no real biometric processing occurred.

**Required fix:** obtain the reference image from the same server-validated liveness session and use that image for identity enrollment, failing closed when unavailable. If an additional enrollment image is needed, bind it through an explicit comparison and validated policy. AWS returns a reference image specifically usable for comparison/search. [GetFaceLivenessSessionResults](https://docs.aws.amazon.com/rekognition/latest/APIReference/API_GetFaceLivenessSessionResults.html)

### FACE-04 — P0: Face payment derives the receiving endpoint from the login phone

`20260906143000_biopay_provider_authority.sql:204–210` constructs the payment request using `coalesce(profile.phone, profile.whatsapp)` and the default MTN provider. It does not resolve the recipient's configured `biopay_payment_methods`, receiving role, provider, MoMo number or merchant code.

The common composer then parses the face token as a legacy request. `20260908090000_biopay_payment_discovery.sql:206–237` extracts the old USSD receiver and converts it into a manual destination labelled “Entered receiving details,” without preserving the matched payee's account/method identity. Conservative manual assurance is appropriate for arbitrary legacy input, but it does not complete a verified face-to-recipient integration.

If someone signs in with phone A and receives money through account B, this path proposes A. A real misdirected payment was not attempted. The bug is visible in the authoritative destination construction.

**Required fix:** resolve the matched account to an explicitly authorized, active receiving method, preserving payee identity and method/version through review and prepare. Revalidate sharing/revocation and changed details. Do not infer a payment account from the sign-in number.

### FACE-05 — P1: Consent, withdrawal and provider deletion are incomplete

The enrollment page goes directly to Start Enrollment. It contains no explicit purpose/retention disclosure, consent decision or consent version. SQL sets `consent_granted_at = now()` during enrollment/upsert (`...provider_authority.sql:125–132`), which records a timestamp without recording the user's informed choice.

There is no active AWS `DeleteFaces` path in the inspected client/Edge implementation. The Profile account-deletion link and old biometric database functions do not establish AWS vector erasure. Re-enrollment replaces the stored provider ID without an observed cleanup operation for the old vector; an AWS indexing success followed by a database failure can also leave an orphan.

**Required fix:** implement optional informed enrollment, versioned consent, visible pause/remove/re-enroll controls, immediate matching exclusion on withdrawal, and retryable audited provider deletion. Delete old/orphaned vectors without deleting a still-authoritative replacement. The service provides a specific deletion API. [AWS DeleteFaces](https://docs.aws.amazon.com/rekognition/latest/APIReference/API_DeleteFaces.html)

### FACE-06 — P1: UI guidance and recovery do not explain the actual task

The enrollment preview shows an oval, Start Enrollment and three icons. The source defines Center/Turn/Hold guidance but does not render its explanatory title/body. The browser accessibility tree exposes Back, the heading and Start Enrollment; the pose/progress icons have no meaningful labels.

The scan screen defaults to **RWF 1,500**, shows no explanation of whose face to scan, and uses a rear camera while a permission error says “your face.” After no match, “Enroll BioPay face” opens enrollment for the currently signed-in payer, even though the scanned person should be the recipient. This invites account/face confusion. A match percentage is displayed without explaining that it is a similarity score rather than a guarantee of identity.

Both screens contain hard-coded English guidance/errors. Provider rejection reasons become generic failure messages. Permanent permission denial has no targeted Settings recovery. Native VoiceOver/TalkBack and larger text have not been accepted for these capture states.

**Required fix:** explain “Set up your face to be found as a recipient” versus “Scan the person you want to pay”; show one actionable instruction and accessible progress at a time; require an intentional amount; distinguish permission, quality, expiry, duplicate and network failures; preserve task context when returning to another existing payment method. Keep the interface sparse, but retain information needed to perform the task. Enrollment of another person must happen under that person's account.

### FACE-07 — P1: Matching policy has no demonstrated operating accuracy

Enrollment checks for exactly one detected face. The match path calls `SearchFacesByImage` directly, takes the first match and records it. There is no explicit multiple-face rejection in the scan path, ambiguity margin between plausible matches, or liveness proof for the scanned subject. A photo should therefore not be described as proof that a recipient is physically present. AWS searches the largest detected face for this API. [AWS face-search behavior](https://docs.aws.amazon.com/rekognition/latest/dg/search-face-with-image-procedure.html)

The default similarity threshold is 99, SQL requires at least 0.99, and default liveness threshold is 0.95. These values do not demonstrate 99% identity accuracy or a suitable false-match rate. No representative evaluation across lighting, camera quality, pose, age changes and relevant users was produced.

**Required fix:** validate single-subject and ambiguity behavior; measure false matches, false rejections, retry/abandonment and spoof cases using consented test participants. Keep face discovery separate from payer authorization. Decide whether lookup needs recipient-presence proof based on its actual risk, and keep an accessible non-face route. AWS recommends application-specific thresholds and alternatives for users who cannot complete a challenge. [AWS liveness recommendations](https://docs.aws.amazon.com/rekognition/latest/dg/recommendations-liveness.html)

### FACE-08 — P1: Camera/data lifecycle and provider recovery need hardening

Both screens initialize a local controller and assign it only after an awaited initialization. A timeout or leaving during that await has no corresponding local-controller cleanup. There is no camera lifecycle observer for pause/resume. Captured `XFile` data is read without explicit capture-file deletion; enrollment keeps all three byte arrays until restart/failure or eventual widget reclamation. Actual file retention depends on platform behavior and was not measured.

The backend marks `raw_asset_deleted_at = now()` and returns `raw_selfie_disposition` text without a cleanup acknowledgment that covers device captures/provider retention. This is an evidence gap, not proof that raw images are persisted in the database.

The custom AWS signer has no `AWS_SESSION_TOKEN` support, explicit fetch deadline or controlled retry handling. Client provider calls likewise lack a feature-specific deadline. Session consumption precedes provider work, so a transient failure can require a new enrollment attempt. Amount validation occurs after the paid match lookup.

**Required fix:** lifecycle-safe camera ownership, explicit temporary-data cleanup, truthful retention audit fields, structured retryable errors, bounded requests, scoped temporary credentials where appropriate, and idempotent recovery. Validate amount/camera availability before unnecessary provider work.

### FACE-09 — P1: Readiness indicators overstate what has been verified

`/health` reports `production_ready` from environment-variable presence. It does not call AWS or validate the RPC contract. It also hard-codes `liveness_required_default: false`, even when the enforcement environment flag is true; the third audit reproduction confirms this mismatch.

`BioPayFaceProviderStatus` ignores `readiness_basis`. `BioPayAdminService.getSystemStatus` maps `production_ready` into “AWS ready: Ready.” The public endpoint observed in this audit returned the same configuration-only readiness shape. The existing live-readiness script also treats this response as stronger provider proof than it supplies.

**Required fix:** report configured, reachable, authorization/collection verified, liveness policy, contract version and last controlled end-to-end verification separately. Only an appropriately authorized, auditable functional check can establish provider readiness.

## Controls worth retaining

Server-side authenticated-user resolution excludes anonymous sessions and requires verified WhatsApp sign-in. Provider-operation tables and service-role functions restrict client assertions. The source contains durable per-user rate limits, expiring operation records, session-bound single-use match proofs, active/verified profile checks and duplicate-identity constraints. Fix FACE-01 without weakening these controls.

The shared payment composer revalidates methods/routes at review/prepare. Native Android uses ACTION_DIAL and leaves the provider's final authorization to the user. Payment evidence distinguishes handoff, user reports and trusted confirmation. These boundaries are appropriate; the face input needs to join them correctly.

## Most efficient tooling for this implementation

The recommendation below is based on integration effort and the existing AWS-approved architecture. It is **not a measured vendor latency or accuracy ranking**. A provider replacement would not fix account binding, consent or receiving-account bugs.

| Need | Recommended tool | Rationale and limits |
|---|---|---|
| Real liveness capture | Official Amplify Face Liveness components for Android and Swift; supported web component if web enrollment ships | Completes the missing capture stage. AWS documents native components and custom credential providers; using their authorization mechanism need not migrate Mobio's users. [Android](https://ui.docs.amplify.aws/android/connected-components/liveness), [Swift](https://ui.docs.amplify.aws/swift/connected-components/liveness) |
| Flutter integration | Small typed Pigeon/platform-channel bridge to a native liveness screen | Keep current Flutter navigation/design, return only session/outcome data, and avoid a custom Dart implementation of the video protocol. Browser integration needs its own JS/component path. [Flutter platform channels](https://docs.flutter.dev/platform-integration/platform-channels) |
| Backend AWS requests | Official AWS SDK for JavaScript v3 with bounded deadlines/retries and suitable credentials | Reduce custom signing/temporary-credential maintenance. Validate package/runtime compatibility and cold-start cost in the actual Supabase Edge runtime before adopting it. Do not automatically retry indexing or other mutations without an idempotency/cleanup design. [Credential providers](https://docs.aws.amazon.com/sdk-for-javascript/v3/developer-guide/migrate-credential-providers.html), [retry behavior](https://docs.aws.amazon.com/sdkref/latest/guide/feature-retry-behavior.html) |
| Identity search | Retain Rekognition collections initially; evaluate user vectors only after the critical fixes | Associating verified images with one user can improve recognition across appearance variations, but adds retention/migration work and requires measured benefit. Do not store three redundant images just because the current UI captures three. [Managing face/user collections](https://docs.aws.amazon.com/rekognition/latest/dg/managing-face-collections.html) |
| Proof and operations | Existing Deno tests + actual local Postgres/PostgREST contracts + Flutter integration tests on devices; privacy-safe correlated metrics | The current mock-only boundary missed FACE-01. Add server/device integration coverage before buying a larger test platform. Track latency, rejection reasons, failure/retry rates and orphan cleanup without logging raw faces, credentials or complete account identifiers. |

AWS lists a limited set of liveness regions. Measure from the actual Rwanda network/device mix and choose a supported region consistent with the required data handling; do not assume every Rekognition region supports liveness. Review the AWS AI-service opt-out configuration as part of biometric data handling. [AWS Face Liveness FAQ](https://docs.aws.amazon.com/rekognition/latest/dg/face-liveness-faq.html)

Indicative provider cost, not a quote: the AWS pricing page's US East example charges **$0.015 per liveness check** in its first 500,000-check tier. Its image API examples charge **$0.001 per call** in the first million tier, counted per API group, and **$0.00001 per stored face/user vector-month**. At those assumptions, 10,000 enrollments with one liveness check and three image calls each plus 50,000 one-call lookups are approximately **$230**, plus storage and other infrastructure. Retries, extra quality checks, multi-image enrollment, region/tier changes and per-lookup liveness increase that figure. No actual cost or latency benchmark was run. [AWS pricing](https://aws.amazon.com/rekognition/pricing/)

For efficiency, remove the two unused capture steps when the approved replacement flow is ready; use the verified liveness reference; perform local input checks early; avoid unnecessary raw-image copies; and benchmark p50/p95 capture, upload, AWS and database time separately. Retain meaningful quality/security checks even when they add an API call. Existing WhatsApp OTP should remain the account authentication authority. The retired ML Kit/TFLite path is not an approved replacement identity authority.

## Recommended completion order and acceptance

1. **Repair the contracts and destination model.** Bind operations to validated auth sessions; map face identity to explicitly shared receiving methods. Prove with real local database/API tests using different login and receiving numbers, two accounts, revoked sessions and changed destination versions.
2. **Complete enrollment as a single verified flow.** Consent → native liveness capture → server result/reference binding → quality/duplicate check → authoritative enrollment. Prove spoof rejection, wrong-image rejection, expiry, cancellation, replay and concurrent enrollment without orphaned vectors.
3. **Finish the user experience and lifecycle.** Clear recipient/payer language, intentional amount, accessible instructions/status announcements, localization, denial/retry/alternative route, background/resume and cleanup. Show success only after authoritative persistence; refresh Profile state on return.
4. **Complete withdrawal and operations.** Pause/revoke/delete provider data, clean replacement/orphan vectors, retain appropriate audit evidence, and replace misleading readiness badges. Reconcile current deployed migrations/Edge versions before any rollout.
5. **Run controlled device/provider acceptance.** Real Android and iOS, front/rear camera variants, low light/network, permission denial, interruption, TalkBack/VoiceOver, text enlargement, keyboard and alternate payment methods. Measure recognition performance with consented participants. Test the payment review with distinct configured accounts; any live transfer requires separate authorization.
6. **Apply release gates separately.** Local tests, database rehearsal, deployed contract, AWS capability, device behavior, recognition evaluation, accessibility, provider handoff and owner acceptance each need evidence. A provider-confirmed payment requires trusted provider evidence; an opened dialer or a successful face match cannot supply it.

The current face experience fails task usability/accessibility and resilience requirements in the Revolut-design review. Visual standby rendering alone cannot satisfy MOBILE-DESIGN-100 or full-system acceptance. The broader QA goal remains separate and unfinished.

## Evidence and reproduction

Artifacts are in `build/qa/face-feature-audit-20260920/`:

- `source-receipt.json`: source/build hashes, base commit and preview consistency.
- `flutter-focused.log`: 80 focused Flutter checks.
- `deno-existing.log`: two existing Edge checks.
- `audit_reproduction_test.ts` and `deno-reproductions.log`: three isolated defect reproductions.
- `dart-analysis.log`: focused static analysis.
- `public-health.json`: sanitized public health observation, 2026-09-20 15:10 UTC.
- `enrollment-standby.png`, `scan-standby.png` and their accessibility text files: existing synthetic preview evidence, no biometric capture.

Commands used:

```sh
/Users/jeanbosco/Developer/flutter_3_44_codex/bin/dart analyze \
  lib/features/biopay lib/features/profile/presentation/profile_screen.dart

/Users/jeanbosco/Developer/flutter_3_44_codex/bin/flutter test \
  test/features/biopay/biopay_payment_surfaces_test.dart \
  test/features/biopay/payment_discovery_test.dart \
  test/features/biopay/payment_discovery_widgets_test.dart \
  test/release/biopay_payment_link_contract_test.dart --reporter expanded

/Users/jeanbosco/.local/bin/deno test --allow-env --allow-net \
  supabase/functions/biopay-face-provider/index_test.ts

/Users/jeanbosco/.local/bin/deno test --allow-env --allow-net --allow-read \
  build/qa/face-feature-audit-20260920/audit_reproduction_test.ts
```

The last command intentionally reproduces current defects. Once fixed, replace these defect assertions with proper regression acceptance tests in the maintained suites.
