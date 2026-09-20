# Mobio full-system QA — current execution status

Updated 19 September 2026. **Incomplete / NO-GO. The native goal currently reports `usageLimited`.** This is a documentation update requested by the user; it does not resume the goal engine, complete QA or approve a release.

The goal already references [the full plan](../fullstack-qa-plan-20260914.md), which now incorporates [all remaining work](remaining-tasks-20260919.md) and a [57-task register](remaining-tasks-20260919.csv). Every original surface and requirement remains in scope.

## Immediate unfinished work

1. Reconcile current source and actual available tools/services. HEAD is `a77efb1e0a78a22c092151a0153468a495adb060` on `codex/recovered-pro-g40-2026-09-10`. Source fingerprint is `6ad4bb0e87fa30224bcb681d86574d42dd3e9bc31f251222e158b466487d30ec` across 1,967 files.
2. Repair the notification compiler error: five named `context:` arguments do not match the positional logging helper signature. The latest retained attempt did not execute either new behavioral suite; six source-contract tests passed.
3. Complete notification failure/retry/read-update/account-switch tests, then subscription/inbox/badge/Admin lifecycle qualification, final analysis/regression and evidence binding.

The last fully validated source fingerprint was `2b6dbce43afd00bee575fa5df163c98f098367ca278be6c4265a7f8c6d8884cb`. Five notification source/test files now differ. A clean Git checkout and a new commit do not constitute QA acceptance.

## Retained verified checkpoint — 15 September

| Layer | Retained result | Limitation |
| --- | --- | --- |
| Flutter / Dart | 648 tests passed; analysis clean | Earlier chat-recovery source, not the unfinished notification patch |
| Chat recovery | Six actual Dart/service cases and five permanent SDK regressions passed | Not full native/web/installed-PWA screen acceptance or general notification replay |
| Backend | 109 Deno tests passed, one ignored; 16 entrypoints checked | Earlier bound inputs; hosted Edge parity remains unverified |
| Database rehearsal | 103 migrations, ten SQL suites and eight rate-limit cases passed | Isolated replay, not deployed migration acceptance |
| Other surfaces | Selected website browser/a11y, routing, Admin widget/controller, collector component and Auth/REST/Storage/Realtime evidence retained | Each report defines its exact bounded scope |

There are 38 registered findings: 35 fixed locally, FQA-004 diagnosed, FQA-023 fixed in source pending OS behavior, and FQA-035 open as a P1 Storage service dependency. Notification work is unfinished and must be recorded after qualified reproduction and retest. Original failure logs remain preserved.

## Remaining system scope

The 57 tasks carry all 35 unverified acceptance groups, all 52 product QA procedures, R001–R100 and all ten MOBILE-DESIGN-100 criteria. The case register remains 654 rows: 612 bounded passes, seven failing Storage race executions and 35 unverified groups. Overlapping cases are not a system completion percentage.

Still required: full consumer and Admin data journeys; designated Storage atomic concurrency repair; remaining Auth/API/BioPay/collector/realtime/jobs/operations checks; configured Android/iOS/browser artifacts and actual installed PWA modes; complete website destinations/source comparison/zoom/reader/performance; visual/accessibility/data extremes/native and API performance; final per-surface report and separate CI/deployment/device/provider/store/independent/owner gates.

Approved build configuration remains a recorded dependency: all four public runtime defines, plus the iOS Firebase app value. The existing request remains pending. Recheck current disk, device and service availability before resource-heavy work. No new configuration, test pass, deployment, external message or approval was created by this update.

## Provenance

The original 14 September plan is archived byte-for-byte at `build/qa/fullstack-qa-20260914/goal-refresh-20260919-original-plan.md`; its hash remains `a76d44557724f4e045aed993afc386c02c744cd6735da3ae7a9998587d971263`. All 34 former registers are archived. Older reports retain their original dates/source bindings and may describe a formerly active goal; the native snapshot above is the current execution status.

See [remaining work](remaining-tasks-20260919.md), [chat recovery](chat-recovery-review.md), [Realtime](realtime-review.md), [Storage](storage-review.md) and [dependencies](dependencies.csv).
