# Implement Mobio/BioPay face-to-USSD

Read IMPLEMENTATION_REPORT.md and the supplied original audit before changing code. The updated report supersedes the audit's AWS-retention and liveness-completion recommendations. Implement the feature; do not stop at another analysis or plan.

## Product contract

The recipient self-enrolls one face under their existing account and selects their receiving MoMo method. The payer and recipient are physically together. A signed-in payer scans the recipient; the application automatically opens the corresponding supported USSD route in the Android dialer. Recipient confirmation, amount entry and PIN remain in MoMo.

The payer does not need a face enrollment. The receiving number may differ from the WhatsApp/sign-in number. Changing the receiving number must not require recapturing the face.

Do not implement liveness, video/head-turn/blink challenges, attended enrollment, identity-document onboarding, another wallet-verification journey, face-only login, biometric payment authorization, physical-presence certification, mandatory app payment review, automatic debiting, PIN handling or a new MoMo API integration. Do not claim payment success from a match or dialer opening.

## Architecture

Preserve WhatsApp authentication and the existing validated application-session authority. Keep the existing Supabase Edge endpoint as a thin authenticated facade and Supabase as authority for enrollment lifecycle and receiving methods. Replace the AWS adapter with a private Cloudflare Worker, stateless Cloudflare Container running pinned OpenCV YuNet + SFace, and a versioned cosine Vectorize index.

The Worker handles inference/search and returns opaque template candidates to the authenticated backend. It must not decide a receiving number from image content or client claims. No public unauthenticated match endpoint, client-side service secrets, authoritative container SQLite database or second payment database.

Use a narrow inference/model interface. Do not adopt InsightFace research-only pretrained weights for commercial deployment. A separately licensed model is an optional subsequent upgrade, not a prerequisite. Pin and document exact model/runtime versions, checksums, output dimension, preprocessing, normalization and licences. Verify compatibility instead of automatically downloading the newest artifacts.

## Start from the actual checkout

Preserve unrelated user edits. Reconcile the audit locations with current source:

- `supabase/functions/_shared/biopay-authority.ts`
- `supabase/functions/biopay-face-provider/index.ts`
- `supabase/migrations/20260906143000_biopay_provider_authority.sql`
- `supabase/migrations/20260908090000_biopay_payment_discovery.sql`
- `lib/features/biopay/`
- `lib/features/profile/presentation/profile_screen.dart`

Find actual face-screen, service, model, receiving-method, admin-status and native handoff files instead of assuming new paths already exist.

## Required changes

1. Fix FACE-01. Authentication must expose the actual validated session identifier. Pass `p_auth_session_id` to `rpc_reserve_biopay_provider_operation`; preserve session/user ownership and existing limits. Add a real local Postgres/PostgREST contract test. Never invent a random session ID or remove the SQL requirement.

2. Fix FACE-04. Resolve the selected active receiving method for the matched account. Never use `profile.phone`/`profile.whatsapp` as a fallback. Preserve method identity/version and reuse common route construction without sending face lookup through the anonymous legacy/manual bridge.

3. Replace enrollment with self-service receiving-method selection, short explicit opt-in and one good camera capture. Keep update, pause and remove. No liveness calls or challenge fields in the new active contract. Do not require an additional receiving-account verification mechanism.

4. Implement the model service and private Worker. Decode a bounded image, enforce one usable face, align, embed, validate model output and search the correct model-specific index. Use one request per scan rather than uploading every frame. Return structured capture, no-match, ambiguity and service errors. Do not carry over the 0.99 threshold or display a similarity percentage as identity certainty. Update AWS-specific provider enums/checks, DTOs and SQL score requirements as well as the Edge policy; remove active liveness-assurance assertions rather than claiming them for a still capture.

5. Add a typed scan-to-USSD shortcut result. Reuse existing backend proof/preparation functions where useful, composed without a new visible review. Resolve current method status immediately before route generation. Do not create dummy monetary requests; amount entry is in USSD for the initial route.

6. Keep route configuration provider-specific. The user's example is `*182*1*1*0788767816#`; treat it as the requested example and confirm device/operator behavior separately. Normalize supported number representations and generate only configured routes. Do not invent merchant codes, alternate operators or amount positions.

7. Automatically invoke the existing Android ACTION_DIAL bridge once a valid current scan returns. Preserve trailing `#`, encode exactly once and handle native launch failure. Stop camera activity before handoff. Ignore stale/backgrounded/cancelled responses and guard before awaiting launch. Do not auto-relaunch on rebuild, resume or network retry. Do not add ACTION_CALL, accessibility automation or PIN processing.

8. On no match, offer retry/manual-number/QR. Never offer to enroll the signed-in payer as the recipient. Remove the RWF 1,500 default. Preserve the existing theme and localization architecture; add short translated task/status/error strings. iOS/web/desktop use honest capability-based alternatives, not claimed Android-equivalent USSD automation.

9. Handle Vectorize's asynchronous mutations. Reserve a revision/vector ID before external writes; activate only after searchable. Pause/remove excludes immediately in SQL. Persist minimal retryable cleanup records for failed/replaced/orphaned vectors. Delete explicit old IDs, never a newer replacement. Reuse existing jobs rather than adding an unnecessary workflow platform.

10. Fix camera initialization cancellation, lifecycle, temporary capture files, request deadlines and errors. Do not store raw images by default or log faces, embeddings, PINs or complete receiving numbers. Keep server secrets in server environments. Document actual processing/storage locations for owner review without adding user-facing verification steps.

11. Remove active face-related Rekognition adapters, AWS signer, SDK dependencies where unshared, liveness flags, secrets, health labels, deployment configuration and runtime fallbacks. Use forward migrations; preserve historical migrations and unrelated features. Existing AWS enrollment IDs are not new-model vectors. Prepare re-enrollment and a scoped, explicitly authorized operator cleanup runbook. Do not delete production resources merely because this task requests code implementation. No AWS fallback on failure.

12. Add honest readiness: configured, model reachable/loaded, compatible index, database contract and last real acceptance evidence. Do not equate configuration or mocked tests with production readiness.

## Verification

Implement every acceptance case in IMPLEMENTATION_REPORT.md using maintained tests/checklists. At minimum prove login number A resolves to selected receiving number B; payer face enrollment is unnecessary; receiving-method edits work without recapture; paused/deleted or unconfigured recipients cannot dial; no liveness dependency; no fake amount; no extra application review; one dialer launch per scan; final `#` survives; database contract is real; old cleanup cannot delete replacement templates; AWS secrets are not needed; and existing manual/QR/authentication flows still work.

Use genuine model execution for the container smoke test and consented separate enrollment/scan images for recognition evaluation. Mocked or generated fixtures can test plumbing but must not be presented as measured real-user accuracy. Do not harvest people's faces from the web. Test physical Android/SIM behavior when an authorized device is available. No real-money transfer is necessary.

If credentials, deployment access, a licensed model choice, consented evaluation images or physical devices are unavailable, complete all unblocked code/tests and document the exact remaining check. Do not fabricate results, claim deployment, or replace requested implementation with a broad clarification question.

## Deliverables

Provide the code, forward migrations, Cloudflare/container configuration, locked model/licence manifest or reproducible checksum-verified artifact fetch, local test commands, automated regression tests, device acceptance checklist, decommission/re-enrollment runbook and an evidence report listing changed files, commands run, outcomes and checks not run.

Success means: **scan the recipient → correct receiving USSD route opens once → normal MoMo flow; no AWS, no liveness, no extra payment-review screen.**
