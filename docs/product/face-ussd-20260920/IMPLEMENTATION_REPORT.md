# Mobio / BioPay: Face-to-USSD
## Updated critical analysis and implementation specification

**Date:** 20 September 2026
**Decision:** Implement a self-service face-to-USSD shortcut; remove AWS Rekognition and all liveness requirements.
**Basis:** The supplied “Face enrollment, recognition and payment handoff audit,” dated 20 September 2026, plus the primary-source documentation recorded in SOURCE_REGISTER.md.
**Evidence boundary:** This is a revised design and implementation specification. It is not a fresh repository audit, an accuracy benchmark, a deployment, or evidence of a completed money transfer. Paths below are locations reported by the audit; Codex must reconcile them with the actual checkout.

## 1. Executive recommendation

Implement the feature as:

**Register a face and receiving MoMo number → scan the recipient → resolve the registered number → automatically open its supported USSD route → continue in MoMo.**

The payer and payee are physically together in the intended use. Face matching saves entering the number and USSD sequence. It is not payer authentication or payment authorization. Recipient confirmation and PIN entry remain in the operator's normal USSD journey.

Use **Cloudflare Containers for face-model inference, a Worker for orchestration, and Vectorize for face-template search**. Keep the existing WhatsApp authentication, authenticated Supabase Edge entry point, and Supabase receiving-method records. The Edge function becomes a thin application-specific facade rather than an AWS integration.

Use **OpenCV YuNet + SFace as the implementation baseline**. Keep the recognition interface replaceable so a commercially licensed InsightFace model can be substituted only when measured results justify it. This recommendation prioritizes implementation simplicity, available model licensing and the requested Cloudflare architecture; it is not a claim that SFace has the highest recognition accuracy. OpenCV documents the paired detector/recognizer and the model-directory licences. [S04–S06]

Do not build a second payment engine, identity-verification service, liveness journey, or mandatory in-app confirmation sequence. The key completion criterion is that a scan launches the correct registered receiving route once, without manual USSD entry.

## 2. Product scope: the implementation contract

### Included

Self-service enrollment under the existing signed-in account; an explicitly selected receiving MoMo method; one useful capture; face lookup; a supported USSD route; automatic Android dialer opening; retry/manual-number fallback; and ordinary update, pause and remove controls.

A payer does not need an enrolled face to scan a recipient. The recipient's receiving number may differ from the WhatsApp/sign-in number. Changing the receiving number must not require re-enrolling the face.

### Excluded

No liveness, blink/head-turn/video challenges, attended enrollment, identity-document onboarding, new wallet-ownership verification workflow, face-only login, biometric payment authorization, physical-presence certification, silent PIN entry, automatic debit, or a new bank/mobile-money API integration.

Do not add a compulsory application payment-review screen between a successful lookup and the dialer. Existing backend destination-resolution and preparation logic can still run without a visible review step. Leave unrelated payment journeys unchanged.

### Amount and operator confirmation

For the initial shortcut, **amount entry stays in USSD**. Do not invent an amount to satisfy an old payment-request schema. Remove the RWF 1,500 default. A later amount-bearing route is a separate configured operator route, not a prerequisite for face lookup.

“Automatic” means the application opens the dialer with the prepared route. With Android ACTION_DIAL, the user may still need to tap Call and choose a SIM. This is platform behavior, not another application approval screen. [S10]

## 3. Revised interpretation of the supplied audit

The audit reported 80 passing focused Flutter checks but no demonstrated authenticated enrollment-to-payment journey. Its reproduction tests deliberately asserted defects; passing those tests is not release acceptance. Its deployed database/functions were not reconciled with the inspected checkout. [A]

| Finding | Updated action |
|---|---|
| FACE-01: incompatible Edge/SQL session contract | Fix. Return the actual validated application session identifier from authentication and pass it to `rpc_reserve_biopay_provider_operation`. Keep session ownership checks. |
| FACE-02: still captures do not implement AWS liveness | Retire the requirement and implementation. Replace three captures with one useful capture. Missing liveness is not a blocker. |
| FACE-03: AWS liveness is not bound to the indexed image | Remove the AWS session/image-assurance path. Do not implement a replacement liveness binder. Use the same received image for ordinary detection and embedding generation. |
| FACE-04: receiving number comes from login details | Fix. Resolve the matched account to its selected active receiving method; never fall back to login phone/WhatsApp. |
| FACE-05: enrollment choice/deletion incomplete | Add short opt-in and working pause/remove/update controls. Remove both authoritative enrollment references and indexed templates through retryable cleanup. |
| FACE-06: unclear task and wrong recovery | Distinguish “Register my face” from “Scan the person you want to pay.” Remove the default amount, similarity percentage and payer-enrollment action after no match. |
| FACE-07: matching behavior unmeasured | Test recognition quality. Handle no face, multiple faces, unknown people and ambiguous results. Do not add liveness acceptance criteria. |
| FACE-08: camera lifecycle and retry gaps | Fix cancellation, lifecycle ownership, temporary files, timeouts and duplicate requests. Delete AWS-specific signing/retry code. |
| FACE-09: configuration is presented as readiness | Report service/model/index/database checks truthfully. Remove the AWS-ready label and configuration-only production readiness. |

**Updated release position:** the inspected implementation still requires functional repair and replacement testing. That conclusion is about broken contracts, incorrect destination construction and absent end-to-end evidence—not the absence of liveness. [A]

## 4. Technology selection

### 4.1 Default: OpenCV YuNet + SFace

Use YuNet to locate a face and landmarks, align the face, and use SFace to calculate the numeric face template. OpenCV supplies `FaceDetectorYN` and `FaceRecognizerSF`; its examples include alignment, feature extraction and cosine comparison. The YuNet directory declares MIT licensing; SFace's directory declares Apache 2.0 licensing. Preserve the notices for the exact artifacts shipped. [S04–S06]

Use a small headless CPU inference service, preferably Python with OpenCV and a minimal HTTP layer. Do not add a second inference runtime unless required by the selected artifacts or measured improvement.

Pin the model files, checksums, OpenCV build, preprocessing and normalization. Do not download whatever is newest during each container start. The current YuNet documentation distinguishes a 2026 dynamic-shape artifact from the older OpenCV 4.x pairing; choose a compatible tested pair instead of mixing runtime/model versions. [S05]

Start with one template per active enrollment and float32 inference. Multi-photo enrollment and quantization are optional optimizations after the baseline works. Derive the embedding dimension from the actual model output; do not hard-code an assumed ArcFace/SFace dimension throughout the application.

### 4.2 Optional upgrade: commercially licensed InsightFace

InsightFace is a credible alternative, but its code licence and pretrained-model permissions differ. The project states that its downloadable training-data-derived models are for non-commercial research and provides recognition-model licensing contacts. Do not ship research-only weights through a permissively licensed wrapper. [S07]

Keep a narrow model interface so changing the detector/recognizer does not change user accounts, receiving methods or Flutter flows. An embedding-model change requires a new model/index version and usually re-enrollment or lawful re-embedding from retained images. Do not compare unrelated models' vectors even if their dimensions match.

### 4.3 What not to use as the recognition authority

ML Kit face detection can help framing but explicitly does not identify individuals. It is optional, not a required new dependency. [S08]

No documented drop-in face-identity model was identified in the Workers AI catalogue reviewed for this report. Use Containers for this specific model rather than an LLM, generic vision model or text embedding model. [S09]

Do not distribute the full enrolled gallery to payer devices or rebuild on-device recognition in the first delivery. Those are different optimization projects.

## 5. Recommended architecture

```text
Flutter enrollment / recipient scanner
                 |
                 v
Existing authenticated Supabase Edge endpoint
  - existing WhatsApp/app-session authority
  - operation reservation and application rate limits
  - enrollment and receiving-method ownership
                 |
                 v
Private Cloudflare Worker
  - service-authenticated requests only
  - request limits and model-contract validation
       |                          |
       v                          v
Cloudflare Container         Cloudflare Vectorize
YuNet + SFace                opaque template IDs
stateless CPU inference      similarity search
       \__________________________/
                 |
          candidate IDs/scores
                 |
                 v
Existing backend / SQL
  - validate current enrollment and receiving method
  - build the supported USSD route
                 |
                 v
Flutter native Android ACTION_DIAL
                 |
                 v
Normal MoMo prompts, recipient confirmation and PIN
```

Cloudflare supports containerized runtimes controlled from Workers, and the documented container types expose CPU, memory and disk resources. Benchmark CPU inference rather than assuming a GPU is present. [S01–S02]

Keeping the existing public Edge entry point avoids migrating custom WhatsApp/session semantics into another authentication implementation. It does add an Edge-to-Cloudflare network hop; measure it. Do not introduce an additional public Worker proxy in front of Edge as well. Cloudflare still runs the replacement recognition and vector-search workload.

The Worker does not need payment-database service-role credentials. It returns opaque template identifiers and similarity information only to the authenticated backend. The backend resolves those identifiers to current application records.

Use one server-to-server authentication mechanism, such as a scoped secret held in the two server environments. Never embed it, a Cloudflare account token, or a Supabase service-role key in Flutter. Do not trust `user_id`, a raw embedding or an authoritative match supplied by the mobile client.

### Cloudflare scope

Workers, Containers and Vectorize are the core services. Use the Container-associated Durable Object for its documented lifecycle/routing, not to create a second user or payment database. [S01]

R2 is optional for private, checksum-pinned model artifacts. Baking the small selected model bundle into the container is simpler initially. Do not create a raw-selfie bucket merely to use more Cloudflare products.

Do not add D1 migration, Kubernetes, a custom vector-search cluster, an AI agent framework or a new workflow engine to this task. Reuse an existing durable cleanup job mechanism. If none exists, add one small retry table and scheduled processor, not several competing queue systems.

## 6. Enrollment and receiving-number behavior

### User journey

Open Profile → Register my face → choose/enter receiving MoMo number → read a short purpose notice and opt in → capture once → save.

Suggested purpose text: “Let people find your receiving MoMo number by scanning your face. You can remove this at any time.” The actual consent choice, notice version and timestamp must be recorded; a database timestamp by itself is not a user decision.

Default to the front camera. Show a simple framing outline and one instruction. Do not require smiles, eye movements, head turns or video. A camera-switch control may remain available for usability.

### Backend behavior

Validate the signed-in account and its actual session; validate that the chosen method belongs to that account and is active for receiving. Do not add a provider-confirmed-wallet requirement to this feature.

Reserve an enrollment revision and vector identifier before an external index write. Decode the received image, reject unusable/multiple-face captures, align it, create the template, and write the versioned vector to Vectorize. Persist authoritative lifecycle status in SQL.

Keep one selected receiving method for this face shortcut. A user with several existing receiving methods chooses the default during setup or in Profile; do not ask the payer to select among the recipient's accounts on every scan.

Allow receiving-number changes without recapturing the face. For a replacement face, keep the previous valid enrollment until the replacement is searchable and the authority pointer is switched successfully. Then delete the old vector by its explicit ID.

Retain existing basic duplicate constraints where compatible, but do not silently attach or overwrite another account on a similarity result. An unresolved conflict should return an ordinary retry/alternative-method response, not a new attended-enrollment or investigation process.

### Minimum logical data

Reuse existing tables rather than inventing a parallel user/payment model. The authoritative enrollment needs an owner, active/pending/paused/deleted state, enrollment revision, vector ID, model/preprocessing version, consent record and selected receiving-method reference. Existing receiving-method records retain provider, transfer type, canonical receiving number, active status and method version.

No receiving phone number is needed in Vectorize metadata. No raw image, MoMo PIN or alleged bank-verified identity should be added to the face record.

## 7. Lookup and automatic handoff

### User journey

Open Scan to pay → point the rear camera at the recipient → take one scan → open the dialer automatically when a usable match is resolved.

Show a transient status such as “Opening MoMo…”; do not wait for an application confirmation button. No match offers “Try again” and the existing manual-number/QR alternative. Do not send the payer into enrolling their own face.

Only one recognition request should be in flight for a scan. Do not upload every preview frame. Automatic best-frame capture is optional; one capture button is an acceptable baseline.

### Matching policy

Use a versioned cosine index compatible with the active embedding contract. Verify dimensionality, finite values and normalization. Test score direction with known vectors; do not assume all distance APIs have identical semantics.

Retrieve several candidates, for example five, rather than blindly accepting the first returned item. Apply a calibrated threshold and a separation rule for the next plausible distinct recipient. Group duplicate templates of the same recipient when relevant. Return a no-match/ambiguous response when the result is insufficient.

Do not promote a lower, unrelated candidate simply because the best candidate's enrollment is inactive or invalid. Do not display a gallery of candidate users or a misleading identity-confidence percentage.

The audit's 0.99 threshold is not portable. OpenCV's own example thresholds vary by benchmark; a two-image demonstration threshold is not automatically a one-to-many identification threshold. Record the actual threshold/policy and its test evidence. [A; S06]

### Current receiving details

Resolve the matched active enrollment to the selected current receiving method through the existing backend. Never use `coalesce(profile.phone, profile.whatsapp)` as a payment destination. Never convert a known face result into an anonymous legacy/manual request that loses its receiving-method reference.

Reuse the common payment system's method/route-resolution functions, but do not force this shortcut through its amount-and-review widget. A dedicated typed shortcut result is preferable to a fabricated monetary payment request.

Where the existing session-bound proof and preparation mechanism can be reused, compose those operations behind the endpoint without adding user steps. Keep route construction and current-method validation together. The final returned instruction should identify the method revision used.

### At-most-once automatic launch

Each scan has a request identifier. Ignore responses belonging to an older scan, a dismissed screen, a signed-out account or a backgrounded application. Set the local launch guard before awaiting native handoff. Stop capture/streaming before opening the dialer.

A late network response or a resume event must not open the dialer again. A deliberate “Open MoMo again” control can exist after return, with fresh destination preparation where needed. Network retries may repeat safe backend work; they must not repeat the external launch automatically.

## 8. Service contracts and implementation boundaries

The following names are proposed contracts, not claims about APIs already present. Adapt them to the repository's conventions.

### Application API operations

| Logical action | Input | Output |
|---|---|---|
| Enroll/replace | Image, chosen receiving-method ID, explicit consent version, idempotency key | Enrollment ID, revision, pending/active state |
| Enrollment status | Owned enrollment/operation ID | Processing, active, failed, paused or removed |
| Resolve shortcut | Scan image and idempotency key | `dial_ready`, `no_match`, `ambiguous`, `retry_capture`, `recipient_unavailable` or a structured service error |
| Change receiving method | Owned method ID | Updated selected method; existing face retained |
| Pause/remove | Owned enrollment ID | Immediate discovery-disabled state and cleanup status |

The endpoint derives the owner/session itself. No mandatory amount field belongs in the initial resolve request.

A useful successful logical response is:

```ts
type PreparedFaceUssdShortcut = {
  status: 'dial_ready';
  request_id: string;
  payee_id: string;
  display_name: string | null;
  receiving_method_id: string;
  receiving_method_version: number;
  provider: string;
  route_id: string;
  route_version: number;
  ussd_code: string;
  expires_at: string;
};
```

Identifiers, version representations and nullable fields must follow actual repository types. This response is not a receipt, an amount-bearing transfer instruction or a claim of settlement. Use short expiry behavior from existing operation policy rather than inventing a new proof system.

### Private Worker operations

A compact interface can expose enroll/index, query, delete and status operations. Enrollment receives a backend-assigned vector ID and image; query receives an image and returns opaque candidate IDs/scores; delete accepts explicit vector IDs. Neither Flutter nor the public internet should be able to call them without server authentication.

The container only decodes, detects, aligns and embeds. It does not resolve MoMo numbers, authenticate users or maintain an authoritative SQLite gallery. Validate malformed image bodies and decoded pixel size; disable arbitrary image-URL fetching.

For a retry with the same idempotency key, return the stored completed result while still valid rather than repeating an enrollment mutation or consuming a new proof. If preparation must be refreshed, revalidate current receiving details. A cached backend result does not authorize a second automatic native launch.

Use typed error reasons such as `NO_FACE`, `MULTIPLE_FACES`, `POOR_CAPTURE`, `NO_MATCH`, `AMBIGUOUS_MATCH`, `RECIPIENT_UNAVAILABLE`, `SERVICE_BUSY`, `TIMEOUT` and `AUTH_EXPIRED`. Map them to short localized application messages. Do not leak raw model responses or credentials.

## 9. Cloudflare lifecycle and index consistency

Container disk is ephemeral; cold starts include application/model startup. A container is not guaranteed to run indefinitely. Therefore keep enrollment authority and vectors outside the inference container. [S03]

Start with a small fixed pool and a hard instance cap. A reasonable staging benchmark is one `standard-2` CPU instance, then compare smaller configurations and select the least expensive one meeting the measured latency target. Do not create a fresh container identity for each payer. The published instance table and pricing distinguish provisioned memory/disk from active CPU. [S02; S15]

Load model artifacts once per process. Limit concurrent inference according to measured CPU/memory behavior and the thread-safety of the selected model wrapper. Serialize access or give each bounded worker its own model instance; do not share mutable detector state across concurrent requests without protection.

Expose private readiness only after the model checksum, output shape and a controlled inference check pass. Distinguish configuration present, inference reachable, compatible index available and database contract passing. Do not call environment-variable presence “production ready.”

Vectorize mutations are asynchronous. New or deleted vectors may take several seconds to appear or disappear from search. [S12]

Accordingly:

- Mark a new enrollment processing until the new vector is demonstrably searchable. An accepted mutation alone is not full activation.
- Exclude paused/removed enrollments immediately in SQL, even while a stale vector is still searchable.
- Use unique versioned vector IDs and explicit deletion IDs. Old retry jobs must never remove a newer replacement.
- Persist pending-write/cleanup intent before the external mutation so a timeout or later SQL failure leaves a recoverable identifier.
- Make cleanup idempotent and retryable. Reconcile stuck pending operations and orphaned/stale vector IDs. Do not log images in cleanup jobs.

These are background implementation details; the payer does not see an approval queue.

## 10. USSD routing and platform behavior

### Structured route generation

Use the existing operator route registry. Store the receiving number and route selection, then generate the full USSD string. Accepting a pasted supported route during setup is optional; parse it into structured receiving details rather than granting arbitrary text execution.

The user's supplied example is:

```text
*182*1*1*0788767816#
```

Treat this as the requested template/example, not as an independently certified current MTN contract. Keep it configurable and confirm its actual prompts on a supported MTN Rwanda SIM. No live transfer is needed to prove the pre-PIN handoff. Other operators, merchant codes and amount-bearing sequences need their own configured/tested templates.

Keep canonical number normalization separate from route formatting. A domestic route may require the local `0...` representation even when the database stores `+250...`. Add tests for accepted input representations and reject unsupported routes.

### Android

Reuse the native ACTION_DIAL implementation. Android documents that this opens the dialer, whereas ACTION_CALL directly initiates a call and requires the call permission. Do not introduce ACTION_CALL, accessibility-driven automation or PIN handling for this task. [S10]

Build the `tel` URI safely, for example with the native `Uri.fromParts("tel", rawUssd, null)` pattern supported by Android's URI guidance. Ensure the trailing `#` reaches the dialer and is not treated as a URL fragment. Encode at one boundary only; test against double encoding. [S10]

Handle missing handlers and activity-launch failure. Respect dual-SIM system selection. Record only a handoff event once a launch request succeeds. Do not automatically mark a payment completed when the user returns.

### iOS, web and desktop

Apple's archived phone-link documentation states that star/hash telephone URLs are not dialed. Do not promise Android-equivalent automatic USSD on iOS from a Flutter plugin alone. Provide the existing manual instructions/copy-number flow. [S11]

Web and desktop should retain honest capability-based alternatives rather than reporting a successful native handoff. Keep any browser-required user gesture distinct from the Android implementation. Test supported platforms independently.

The selected server-side face matcher needs internet connectivity. If unavailable, show the existing manual/QR route; do not describe face lookup as offline simply because the later interaction uses USSD.

## 11. Camera, user data and operational limits

Use the existing Flutter camera integration and design system. The Flutter camera package makes application code responsible for lifecycle management. Handle initialization that finishes after cancellation, pause/resume, permission denial and disposal. [S13]

Configure still capture without audio. Delete temporary capture files after reading/upload where the platform provides an owned file, release byte references in finally paths, and do not claim cryptographic memory erasure. Handle failure and cancellation as well as success. Treat mirrored front-camera preview separately from the actual pixel orientation sent for recognition.

Initial engineering defaults, to be tuned rather than represented as vendor limits: resize the longest image side to about 1024 pixels, target a few hundred kilobytes per JPEG, cap uploads around 1.5 MB, and separately cap decoded pixel count. Preserve enough face detail for the chosen detector/recognizer. Reject oversized/malformed requests before unnecessary inference.

Use finite deadlines and structured retries. Illustrative budgets are a 15-second client deadline with shorter internal deadlines, not an endlessly spinning capture screen. One retry of a safe operation can reuse its idempotency key. Do not retry a completed dialer launch.

Do not routinely store raw captures or log faces, embeddings, complete receiving numbers or PINs. Keep a short optional-enrollment notice and working deletion. Record only necessary operational identifiers, outcome codes, versions and timings.

Before production, the owner must confirm the actual processing/storage locations and applicable existing Rwanda data-handling arrangements. Rwanda's Data Protection Office provides overseas transfer/storage authorization procedures; using Cloudflare does not itself settle that deployment question. This is an owner/deployment matter, not a new payment-screen or attended-enrollment requirement. [S17]

## 12. AWS removal and migration

Remove AWS from the active face-feature path completely: Rekognition calls, liveness session creation/results, liveness policy switches, custom signer, face-specific AWS packages, environment variables, IAM dependency, readiness UI, runtime fallbacks and deployment instructions.

Do not delete AWS resources or shared dependencies belonging to unrelated application features. Do not edit already-applied historical migrations or falsify historical provider records. Add forward migrations and mark old enrollments as requiring re-enrollment.

Rekognition's documented ListFaces response returns identifiers and metadata, not a reusable embedding array for this replacement. Plan on re-enrollment unless lawfully retained source images already exist and may appropriately be reprocessed. Never fabricate compatibility between an AWS face ID and a new model's template. [S14]

For the normal no-raw-image case, show: “Update your face setup to continue using Scan to pay.” Keep ordinary number/QR payments available during migration.

Create an operator-run, scoped cleanup script/runbook. Inventory relevant collection IDs; verify the target scope; delete only approved face resources; verify completion; then revoke face-specific credentials. AWS documents that deleting a collection removes its associated face metadata. Do not revoke credentials before the cleanup that needs them. Destructive production cleanup requires the normal explicit authorization. [S18]

The application can be implemented and tested without executing that production cleanup. Report code removal, deployed configuration changes and verified remote deletion as separate facts.

Rollback means disabling face lookup while keeping manual/QR payment. There must be no silent AWS fallback.

## 13. Acceptance tests

These tests are proposed release criteria, not claims of tests already run.

| Area | Required evidence |
|---|---|
| Session contract | A real local Postgres/PostgREST test passes the validated session to the RPC; expired/mismatched sessions are rejected. |
| Correct receiving number | An account signing in with number A and selecting receiving number B returns only B in the dialer route. |
| Payer enrollment independence | A signed-in payer without a face enrollment can scan and pay an enrolled recipient. |
| Default receiving method | A recipient with several methods resolves to the explicitly selected one, not the first row or login number. |
| Receiving-number edit | A subsequent scan resolves the updated number without a face recapture. |
| No configured destination | No fallback to login phone; no dialer launch. |
| No liveness | Enrollment succeeds using the single-capture route; active code makes no liveness calls or requests challenge evidence. |
| Model execution | Real detector/recognizer inference is tested in the container; a mocked embedding alone does not establish functioning recognition. |
| Recognition behavior | Consented intended users, separate enrollment/scan captures, unknown people, lighting and device variation; report wrong candidates, no-matches and retries. |
| Ambiguous/multiple faces | No automatic destination guessing; retry/manual alternative works. |
| Search activation | Pending insertion is not shown as active before it is searchable. |
| Pause/remove | Immediately excluded by authority even while a stale index entry remains. |
| Replacement/cleanup | New template becomes active without stale jobs deleting it; failed/index-orphan operations reconcile. |
| Amount independence | No RWF 1,500 default or dummy payment amount; amount is entered in USSD. |
| No extra review | Android successful scan path reaches native handoff without a compulsory application payment-review screen. |
| URI correctness | The exact supported route, including final `#`, is present in the native dialer; no double encoding. |
| Launch deduplication | Rebuild, retry, resume, duplicate response and late response do not cause repeated or background dialer opening. |
| Cancellation/lifecycle | Leaving during camera initialization/upload, pause/resume and denied permission do not crash or leak owned camera/file resources. |
| Operator/device acceptance | Physical supported Android devices and SIMs reach the expected MoMo prompt; cancellation and dual SIM behavior documented. |
| Unsupported platforms | iOS/web/desktop show the intended alternative, not false dialer/payment success. |
| Payment status | Matching and handoff never create a paid/settled status without the application's existing independent confirmation source. |
| AWS independence | App/server build and tests work without face-related AWS secrets; no active Rekognition calls or AWS fallback. |
| Existing flows | WhatsApp auth, QR/manual routes and unrelated payment composer behavior remain intact. |

Use a small consented representative device/user cohort to select a model policy, then record its limits and expand evaluation with scale. Report counts, denominators, gallery size, conditions and latency; do not call a small pilot proof of universal accuracy or invent percentage results.

Suggested performance targets, not measured claims: warm scan-to-dialer p50 at or below 2 seconds and p95 at or below 4 seconds on defined representative network/device conditions. Measure cold starts separately. Track capture, upload, inference, index search, SQL resolution and native launch timings to identify the actual bottleneck.

## 14. Cost and scaling recommendation

Avoid a fixed cost promise before profiling the workload. Cloudflare currently lists Containers on the $5/month Workers Paid plan, with additional provisioned-memory/disk, active-CPU, Worker/Durable Object and other applicable usage charges. Vectorize bills queried and stored dimensions with included allowances. The model dimension, instance uptime and traffic determine the result. [S15–S16]

For early usage, benchmark the cost of a warm small instance against sleep/cold-start behavior. Load models once, resize images sensibly, issue one search per scan and cap instance count. Do not provision a large memory/GPU-style configuration merely because a vendor's unrelated benchmark used one.

Record CPU time, provisioned uptime, model memory and monthly scan/enrollment volume. Optimize that measured cost rather than treating vector-search pricing as the whole service bill.

## 15. Implementation sequence for Codex

### Stage 1: reconcile and repair

Inspect the real repository, branch and local modifications. Preserve unrelated work. Start with the audit-reported paths:

```text
supabase/functions/_shared/biopay-authority.ts
supabase/functions/biopay-face-provider/index.ts
supabase/migrations/20260906143000_biopay_provider_authority.sql
supabase/migrations/20260908090000_biopay_payment_discovery.sql
lib/features/biopay/
lib/features/profile/presentation/profile_screen.dart
```

Locate `requireAppUser`, `rpc_reserve_biopay_provider_operation`, receiving-method resolvers, face screens, native dialer bridge and actual authentication-session storage. Fix the session argument and login-versus-receiving-number bug with forward migrations and regression tests. Update AWS-specific provider enums/checks, DTO assertions and hard-coded SQL similarity requirements to the new versioned model contract; changing the Edge threshold alone must not leave SQL rejecting valid new-model results. Remove active `provider_liveness_verified` assertions rather than populating them for a still capture. Preserve verified WhatsApp/session checks. Do not hard-code the local paths to the author's Flutter binary from the audit.

### Stage 2: build the Cloudflare adapter

Add the private Worker, stateless container, pinned model manifest/checksums/licences, index configuration, model contract and tests. Keep user/session and receiving-method authority in the existing backend. Use repository-consistent directory names; proposed boundaries are `services/face-inference/` and `cloudflare/face-service/`, not mandatory pre-existing paths.

Provide reproducible local development, staging configuration and secret names without committed secret values. Do not pretend to have deployed resources when credentials are absent.

### Stage 3: finish the shortcut

Replace three-step liveness enrollment with one capture. Add explicit receiving-method selection, opt-in and update/remove. Implement typed scan-to-shortcut resolution and an immediate, guarded Android handoff. Leave amount entry to USSD. Reuse existing visual components and localization; do not restyle the application or introduce unrelated product features.

### Stage 4: reconcile lifecycle and removal

Implement index activation, replacement and removal cleanup; camera cancellation/permissions; timeouts; structured errors; and truthful health. Remove the active AWS face implementation and prepare separately authorized remote cleanup/re-enrollment instructions.

### Stage 5: demonstrate and report

Run maintained Flutter/Deno/Worker/container tests plus actual database-contract tests. Replace audit tests that expected defects with proper regression acceptance tests. Run physical-device/operator checks where an authorized device/environment is available. No real-money transfer is required for shortcut completion.

Deliver implementation code, forward migrations, locked model artifacts or checksum-verified download instructions, Cloudflare configuration, model/licence record, automated tests, device checklist, AWS decommission runbook and a factual evidence report. Categorize each result as implemented, locally tested, deployed/observed, or not run with its concrete reason. Do not claim production readiness from mocked tests.

## 16. Final acceptance statement

**A recipient registers one face and a chosen receiving method. A signed-in payer scans that recipient, and the app opens the correctly prepared USSD route once, without entering the number or passing through another mandatory application review. MoMo handles the remaining prompts and authorization. AWS Rekognition and liveness are not part of the active feature.**

This specification supersedes the supplied audit's recommendations to complete AWS liveness and retain Rekognition. It does not discard the audit's evidenced contract, receiving-number, lifecycle or testing defects.
