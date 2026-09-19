# Storage and promo generation QA

15 September 2026, Africa/Kigali. **The tested Storage service has an open P1 concurrent-upload integrity defect (FQA-035). Mobio's promo upload accounting defect (FQA-036) is repaired locally. Overall QA remains incomplete and NO-GO.**

## Environment and authority

Tests used the repository's existing four buckets and all 14 Storage policies in the owned isolated database. Auth issued the user sessions; the verified-identity and Admin-allowlist functions remained active. Storage ran with an ephemeral file backend, a five-connection database pool, image transformations disabled and no external network. Queue workers remained disabled. These conditions do not establish S3, CDN, transformation, background cleanup or hosted-service behavior.

The unmodified cached image is Storage **1.68.10**, `public.ecr.aws/supabase/storage-api@sha256:2036b42317d417a6f8a805f168b3fe137a14bd3745028189fa311f7f222f867d`, image ID `471e93a51e8b46ceed1de40ddfb92e1b22980a8c8f3318bdd08a541862074684`. Startup retained the same 62 service schema migrations. The designated deployed Storage version remains unverified. See [service identity](../../../build/qa/fullstack-qa-20260914/storage-qa-service-environment.json).

| Bucket | Current access boundary | Selected result |
| --- | --- | --- |
| avatars | Public reads; verified user writes inside their UUID folder; 5 MiB and image MIME restrictions | Ownership, ordinary writes, signed uploads, exact-size boundary, conflict and deletion checks passed; concurrent create-only overwrite failed |
| tickets | Private reads/writes require verified ownership; 10 MiB and image/PDF restrictions | Ordinary cross-user reads, lists, writes, copies and deletes denied; **concurrent creation can replace another owner's new object** |
| media | Public reads; qualified Admin with `storage.media.manage` writes; 50 MiB | Consumer denial, Admin write, immediate allowlist revocation, restoration and MIME checks passed |
| promo-media | Public reads; service-role writes; 50 MiB | Consumer/Admin denial, service upload and real promo-handler accounting checks passed |

The runtime populated both `owner` and `owner_id`. Existing ownership policies did not fail because of an empty owner column. Supabase documents `owner_id` as the preferred field, so future service-version qualification must still check that compatibility. [Ownership documentation](https://supabase.com/docs/guides/storage/security/ownership)

## FQA-035: concurrent private ownership replacement

Two independently authenticated verified users submitted different 1 MiB synthetic PNG payloads to the same absent `tickets` object key. Both received HTTP 200. The final row belonged to one user, whose bytes replaced the other user's successfully uploaded object. The losing user then received a denied private read. This occurred twice with explicit `x-upsert:false` and twice with `x-upsert:true`. Two same-user avatar create-only races also incorrectly reported two successes. Same-user upsert races correctly allowed replacement.

This establishes concurrent replacement and loss of access to a successful upload. It does **not** establish that either user read the other user's private payload, that already-existing private objects are ordinarily writable by another user, or that a production incident occurred. Sequential cross-user private writes were denied. No active Flutter Storage upload caller was found in `lib/` or `packages/`; the verified-user Storage API itself remains exposed by the schema. The active Edge Storage caller is `generate-promo-content`.

The inspected service source explains the result. `canUpload` tests an insert/upsert under the caller's authorization and rolls that transaction back. After bytes are uploaded, `completeUpload` creates a service-role database context, takes the object lock and unconditionally upserts. It neither rejects a newly appeared row for a create-only request nor rechecks replacement authorization under the original caller. The upsert updates both owner fields. See the [runtime source binding](../../../build/qa/fullstack-qa-20260914/storage-runtime-source-binding.json), `storage-runtime-uploader.js` lines 49–71 and 156–185, and `storage-runtime-pg.js` lines 182–195 and 694 onward.

Supabase's documented create-only contract requires a single winning upload when clients use the same path concurrently. [Standard upload concurrency](https://supabase.com/docs/guides/storage/uploads/standard-uploads#concurrency)

Evidence and repeatable runners:

- [Four explicit create-only races](../../../build/qa/fullstack-qa-20260914/storage-qa-create-races.json), produced by `probe_storage_create_races.py`.
- [Four explicit upsert races](../../../build/qa/fullstack-qa-20260914/storage-qa-upsert-races.json), produced by `probe_storage_upsert_races.py`.
- [Original Storage checks](../../../build/qa/fullstack-qa-20260914/storage-qa-http-regression.json), including the initial same-user race.

**Status: open service dependency.** Closure requires the designated service version and a service-level repair that enforces conflict and replacement authorization atomically at final persistence, followed by these same real-service tests. The repository does not contain the Storage server implementation. No image patch or speculative Storage SQL trigger was shipped as a product fix. The service fix must also be qualified against other supported upload modes before broader acceptance. No external issue, support message or deployment was submitted.

## Access, signed capabilities and harness qualification

The original 53-check run recorded 48 passes and five mismatches. Four mismatches came from the harness's error expectations: this runtime returns `InvalidRequest` for missing authorization, `NoSuchBucket` with a 404 body status on a private public URL, `KeyAlreadyExists` for an existing object, and `EntityTooLarge` with a 413 body status for the size limit. Those errors use an HTTP 400 compatibility envelope. Their protected-state assertions held.

Fresh requests with the correct error contract passed all four retests. The original result is preserved. The fifth mismatch was the genuine concurrent create defect. See [harness qualification](../../../build/qa/fullstack-qa-20260914/storage-promo-harness-qualification.json) and [Supabase error documentation](https://supabase.com/docs/guides/storage/debugging/error-codes).

The [14 follow-up checks](../../../build/qa/fullstack-qa-20260914/storage-qa-followup-regression.json) all passed. Besides the four retests, they cover private owner replacement/move, continued cross-user denial, signed-upload minting authority, path binding, exact persisted bytes/owner, sequential create-only replay denial, explicit signed upsert and MIME restrictions.

Other successful checks cover public exact bytes, private listing, ETag/304, range/206, HEAD, copy/move/delete authority, short signed-link expiry, anonymous/unverified/invalid/expired credentials, real logout and immediate Admin-allowlist revocation. A previously issued signed download remains a bearer capability until expiry or object deletion; logout blocks new authenticated requests and new links. That capability behavior is recorded separately from live-session authority. Signed URLs and credential values remain private and are excluded from evidence.

## FQA-036: promo accounting repair

The generator awaited Supabase upload calls but ignored their returned `error` values. Failed uploads therefore increased `generatedCount` and emitted success logs. A run producing no assets still returned `success:true`. Audit inserts also ignored returned SDK errors. Supabase's SDK examples explicitly check the error result. [Upload result handling](https://supabase.com/docs/guides/storage/uploads/standard-uploads#uploading)

Both upload branches now throw returned SDK errors into the existing failure counter; audit failures are logged. A zero-output run returns HTTP 502 with `success:false` and its counts. Runs with successful assets retain HTTP 200 and explicit failure totals. The exported handler remains the production entrypoint, served through guarded `Deno.serve` startup. Existing disabled video generation is unchanged and continues to contribute four reported failures per run.

The [initial behavioral reproduction](../../../build/qa/fullstack-qa-20260914/promo-generation-red.log) failed four of eight tests after only making the existing handler importable. The original implementation is preserved in `promo-generation-before-repair.ts`. After repair, all eight tests pass: authorization/method gates, complete and partial upload failures, successful images, provider failure and audit diagnostics.

The [actual Storage/PostgREST regression](../../../build/qa/fullstack-qa-20260914/promo-storage-handler-regression.json) passed three scenarios. Unauthorized requests made no calls. A permitted run persisted 13 exact synthetic images and matching audit counts. A temporary one-byte bucket limit then caused 13 real Storage denials: the handler returned zero generated assets, 17 failures and HTTP 502 while all prior bytes stayed intact. The original limit was restored. Only media generation responses were mocked; no paid Google request occurred. Hosted Edge runtime/provider acceptance remains unverified.

## Validation and retained state

The complete frozen Deno tree passed **109 tests**, with **one existing ignored test**; all 16 Edge entrypoints type checked. Pinned Flutter 3.44.3 passed **643 tests**, and Dart 3.12.2 analysis, structure, secret and whitespace checks passed. The Android release script stopped before compilation for the same four missing public build values. [Validation commands and hashes](../../../build/qa/fullstack-qa-20260914/storage-promo-validation-runs.json)

Only the promo handler and its new test file changed in this batch. Source now contains **1,962 files**, fingerprint `4793f13aa2c1cafc4098fae9ecaf8b5d738135d23e8f12f3006ef6a47a5fc718`. The prior 102 migration inputs and nine SQL suites are unchanged, so their earlier local replay evidence remains applicable to those inputs. Storage cases before the promo edit retain their earlier source binding; later follow-ups use the current binding.

Cleanup deleted 30 remaining synthetic objects through Storage APIs, three added Auth accounts through Auth APIs, one owned OTP row and four synthetic promo audit rows. The four bucket settings and all 14 policies match their pre-test state. Eleven earlier fixture accounts/sessions/profiles remain; objects, OTPs, notifications, HTTP queue entries, FCM tokens and Admin audit rows are zero. Cron execution remains off. The temporary Storage test gateway was stopped; the isolated Storage service remains available for subsequent work. [Cleanup readback](../../../build/qa/fullstack-qa-20260914/storage-qa-retained-environment.json)

The register now has **579 rows: 537 bounded passes, seven failing race executions and 35 unverified groups**. Several rows are repetitions or overlapping checks; these figures are not a whole-system quality percentage. The 36 findings include the open Storage service defect and the locally repaired promo defect. Realtime/jobs, remaining actor/argument paths, configured apps/Admin/PWA/native journeys, design and device/provider/independent acceptance remain outstanding.
