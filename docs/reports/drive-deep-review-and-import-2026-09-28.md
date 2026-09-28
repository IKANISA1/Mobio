# Mobio Drive deep review and local import — 28 September 2026

Source folder: `120JIOTyeNX6nHaHPDqS3UgbaTWyJAE57`

Local branch: `codex/mobio-drive-import-20260928`

Status: **source imported for review; production release remains blocked**.

The Drive root currently advertises `anyone` writer access. Local download hashes and package checks establish the bytes reviewed here; they do not establish who authored or approved an upload. Restricting Drive write access and confirming package authority remains a provenance gate.

## What was compared

I recursively listed the Drive root and every child folder. The point-in-time inventory has **6,176 unique objects: 5,299 files and 877 folders**. Folder listings completed without an error or a page-limit hit. The complete object/path/ID/MIME/size/modified-time inventory is in [drive-inventory-2026-09-28.tsv](drive-inventory-2026-09-28.tsv).

At the start of the import, **4,672 Drive files already had a local path**. [The existing-path comparison](drive-existing-path-size-comparison-2026-09-28.tsv) checks every one: 4,611 sizes matched and 61 differed. All **2,076 Git-tracked counterparts** matched Drive size against the original `HEAD`; the 61 differences were generated or ignored local material such as `.dart_tool`, `.git`, caches, and visual-test failure images. The prior 27 September review had independently downloaded and SHA-256 compared those same 2,076 tracked counterparts and 33 ignored code-like files. That earlier hash finding is historical evidence, not a new hash check of all 4,672 paths today. Size equality alone does not prove byte equality.

**627 Drive paths were absent locally** at the comparison point. [The disposition ledger](drive-only-disposition-2026-09-28.tsv) gives a decision for each path: 621 imported and six excluded. The comparison is by exact relative path; duplicate content under a different Drive path remains a separate path in the ledger.

## What was added and why

The 621 selected Drive files were downloaded and preserved under [docs/drive-imports/2026-09-28/snapshot](../drive-imports/2026-09-28/snapshot). Their total local size is **23,836,776 bytes**, with **443 distinct SHA-256 values**; 178 paths repeat content already represented by another imported path. The [per-file addition ledger](drive-import-added-files-2026-09-28.tsv) lists **every selected file**, Drive ID, original and local path, MIME type, byte count, SHA-256, category, duplicate relationship, versioning status, and the reason for keeping it. The category counts are:

| Category | Files | Reason for local preservation |
| --- | ---: | --- |
| Historical source copies | 419 | Preserve the exact uploaded version for comparison, package provenance, and recovery. |
| Source attachments | 55 | Preserve separately uploaded code/configuration attachments and compare them with integrated source. |
| Reports and runbooks | 36 | Retain scope, prerequisites, execution steps, and stated limits. |
| Reported evidence | 36 | Retain the uploader's test and delivery claims for independent review, without treating them as acceptance. |
| Provenance records | 35 | Preserve package maps, checksum manifests, and upload receipts. |
| ZIP archives | 22 | Preserve the exact packages and verify their contents. |
| Workbooks | 15 | Retain backlog, task status, and review criteria. |
| Native Google Docs | 3 | Exported to `.docx` because Drive native files have no byte-for-byte local representation. |

**595 snapshot files are eligible for Git.** The remaining 26 are historical `.log` files that exist in the local snapshot but are ignored by repository policy for generated test output. Their local paths and hashes remain in the per-file ledger. Importing a historical copy into the snapshot does not make it current application code.

The Drive packages also contained cumulative, applicable changes. I applied the hardening 03 patch and increment 04–09 appliers in order after check-only validation. The active-source ledger, [drive-active-source-2026-09-28.tsv](drive-active-source-2026-09-28.tsv), identifies all **225 active paths** touched by that package lineage: **151 added and 74 updated** against the original checkout, with the package hash, current hash, purpose, and whether local correctness fixes changed the package bytes. **209 still match the latest package exactly; 16 have deliberate local corrections.** These paths cover durable institutional SMS intake, admin and wallet controls, chat delivery, notification outbox, secure session storage, privacy requests, platform bindings, migration preparation, and focused tests. The feature runbooks remain under `docs/production-readiness/`.

Local corrections include Dart compilation fixes, keeping chat data code within the architecture dependency boundary, updating the auth fixture for the new interface, resolving macOS temporary-directory aliases, and updating existing tests for server-owned admin leases, account-bound chat, durable push/wallet/SMS routes, and honest preview identity display. The active files are the integrated result; the snapshot and ZIPs preserve the uploaded originals.

## ZIP and package analysis

All **23 new Drive ZIP paths** were downloaded, including the one excluded from repo import. They represent **10 distinct archive hashes**. Every ZIP passed CRC reading; all **4,825 archive entries** were cataloged with path, sizes, CRC-32, and uncompressed SHA-256. No encrypted entry, path traversal, absolute path, or symlink entry was found. See [archive summary](drive-archive-summary-2026-09-28.tsv) and [entry catalog](drive-archive-entries-2026-09-28.tsv). Seven package checksum manifests were checked against the corresponding extracted files without mismatch. The 184 flattened source attachments for increments 04–09 matched their `INDIVIDUAL_FILE_MAP.json` SHA-256 values.

| Distinct package lineage | Review finding | Integration |
| --- | --- | --- |
| Hardening 01 | Source generator and preparatory controls; package is a candidate, not deployment evidence. | Preserved in snapshot; generator was not blindly executed. |
| Hardening 02–03 | Collector, identity, release, and evidence controls; hardening 03 is cumulative. | Applied hardening 03 once. |
| Increment 04 | Durable SMS intake and receipt handling for the existing institutional collector. | Applied source and tests; no live SMS/provider acceptance inferred. |
| Increment 05 | Admin, account, wallet, startup, and reconciliation controls. | Applied source and tests; financial/database activation remains gated. |
| Increment 06 | Chat delivery journal, pagination, retry, and read state. | Applied source and tests; corrected architecture placement. |
| Increment 07 | Notification outbox and delivery operations. | Applied source and tests; provider behavior needs live validation. |
| Increment 08 | Secure native session and account-bound UI handling. | Applied source and tests; native acceptance remains open. |
| Increment 09 | Privacy request workflow, evidence, and operational status. | Applied source and tests; database and operator acceptance remain open. |

These increments harden already documented expansions. They do not authorize route computation, dispatch-grade routing, fare settlement, or payment execution. `maps-gateway` still rejects `compute_route` with HTTP 410. Package reports and upload receipts are retained as claims and provenance; they are not proof of migration, deployment, store release, or production acceptance.

## Six paths excluded from import

Two Drive paths are `.git/refs/codex/turn-diffs` checkpoints. Three `All_Conversation_Files_2026-09-28` binary attachments are a Git config export, object pack, and index. The sixth is the consolidated `Mobio_All_Conversation_Files_2026-09-28.zip`, which contains Git object material. Its ZIP entries were still inventoried and checked. These six are repository internals with potential historical secrets, not application source; their exact paths and reasons are in the disposition ledger. No `.env`, service-role credential, signing key, keystore, or copied CI secret was imported as active source.

## Verification and remaining limits

| Check | Result |
| --- | --- |
| Flutter clean-checkout bootstrap | Passed using local Flutter 3.44.4 / Dart 3.12.2; repository pin is Flutter 3.44.3. |
| Dart analysis | Passed with no errors or warnings; 92 informational style hints. Archival Dart copies are excluded from active analysis. |
| Repository structure and secret scan | Passed. |
| Python test suite | 370 tests passed. |
| Privacy checks | Passed: 70 Node tests and 61 Python tests. |
| Edge hardening, handler, and intake checks | 66 and 138 tests passed in the available lanes. |
| Focused Flutter increment 05–09 tests | 136 passed. |
| Full Flutter test suite | Final rerun: **964 visible tests passed, 157 failed**. Every remaining failure is in `test/features/preview/revolut_reference_golden_test.dart`; no other test failed. The 22 nonvisual failures from the initial run were corrected and the suite was rerun. No golden baseline was rewritten or accepted. |
| Aggregate hardening script | Could not complete because `kotlinc` is unavailable. The available lanes were run separately. Docker daemon, `psql`, and Supabase CLI were unavailable for live SQL/native acceptance. |
| Android appbundle release script | Invoked through `scripts/release/build_android_release.sh appbundle`; it stopped before compilation because the local `.env` and four required public build defines are absent. No dummy URL or key was supplied. |

No migration was applied, no external service was deployed, and no store artifact was produced. The repo contains an imported, reviewable source candidate with explicit provenance and remaining QA gates. The original 27 September reports were pre-existing untracked files and are not counted among this import's 621 additions.
