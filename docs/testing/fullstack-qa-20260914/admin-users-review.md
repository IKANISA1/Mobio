# Admin user directory — execution checkpoint

14 September 2026. The review reproduced defects in the actual AdminUsersController with an injected service fixture. Repairs are implemented and current Dart analysis passes. **Final 13 controller and two actual-directory widget tests pass, along with the 643-test root suite.** These results do not establish backend authorization, persisted changes, compiled Admin behavior or acceptance.

## Confirmed failures and repairs

- **FQA-016:** late search/role responses replaced newer results; sorting a later page changed its displayed page to zero; selection admitted IDs outside the displayed page. Query generations now reject stale responses, local sorting preserves the current page and selection is limited to visible records. Changing the query/page clears prior selection. Filter preservation itself passed the original test and is not a confirmed defect.
- **FQA-017:** explicitly passing null to state.copyWith did not clear busy fields, and rapid callbacks submitted another update. A sentinel distinguishes omitted fields from explicit clearing. Mutation guards cover the RPC and subsequent refresh. An added test caught an early indicator reset during refresh in the first repair, which was then corrected.
- **FQA-018:** independent bulk RPC successes were not refreshed when another call failed. The UI reported the captured selection size, including skipped own-account/no-op rows. It now returns acknowledged updated/failed/skipped counts, refreshes after partial outcomes and retains failed selections where still visible. Load/outcome messages use safe copy. These counts describe RPC acknowledgements, not independent database proof.

The existing insurance reward retains its amount and server contract. The shared busy-state correction also guards that action. No reward, role change, message or other real backend mutation was performed.

## Executed and pending checks

| Check | Raw evidence and result |
| --- | --- |
| Original controller fixtures | admin-users-reproduction.log: 1 passed, 8 failed |
| First repair | admin-users-remediation-1.log: 9 passed |
| Expanded boundary fixtures | admin-users-refresh-boundary.log: 12 passed, 1 failed at the refresh interval |
| Final combined Admin suite | admin-users-final-focused.log: ENOSPC compiling the first UI fixture; no tests executed |
| Earlier bounded controller attempt | admin-users-controller-resource.json: not run; 249,446,400 free bytes was below the 256 MiB guard |
| Final controller retry | admin-users-controller-retry.log: 13 passed |
| Final focused Admin/contract batch | admin-contract-focused.log: 45 passed, including both actual-directory widgets |
| Full serial regression | flutter-admin-final.log: 643 passed |
| Current analysis | dart-analyze-admin-final.log: no issues |
| Structure, secret scan, whitespace | structure-admin-final.log, secrets-admin-final.log, diff-admin-final.log: passed |
| Android, iOS and PWA guards | Missing runtime configuration; stopped before compilation |

The 13 controller/state and two actual-directory outcome fixtures passed. The focused Admin/release contract batch passed 45 tests. The full serial Flutter run passed 643, including both proof-harness journeys. An earlier full run passed 642 and failed a source-text check expecting obsolete pagination variable names. That assertion was replaced with actual paging behavior checks. None of these fixtures replaces authenticated Admin/database acceptance.

Original reproduction source/test copies and hashes are preserved under admin-users-before/. Intermediate green/red logs remain explicitly intermediate: their implementation differs from final source. Admin repair checkpoint 1,938-file fingerprint: 7f0f2a3f2d5a0e116029648a0454f40d68b3b6a0ed8e5465f90c51d9f92104a7. Records are in source-manifest-after-admin.json; source-binding-after-admin.json lists five changed files.

## State, RPC and persistence trace

The nine rows in admin-users-state-trace.csv cover load/error, filtering/pagination/sort, selection, single/bulk updates, missing/concurrent targets, the existing reward, permission/revocation and disposal. Resolved source remains 239 Dart files with zero diagnostics, 49 routes, 141 SDK call sites, five Dio requests and 66 overlay sites.

The source RPCs require admin.users.read, admin.users.manage and admin.finance.review respectively. The latest has_platform_permission requires an identified user and either an unexpired explicit matching/platform.admin grant or an active allowlisted Admin profile. Removing an allowlist row does not revoke an independent explicit grant. This is a source trace, not an executed privilege matrix.

Isolated database assertions remain required for denied/revoked callers, effective grants/RLS, audit consistency, missing/deleted targets, concurrency and uncertain transport outcomes. The latest role-update source returns void and has no affected-row or revision assertion; that is queued for isolated validation, not labelled a reproduced database defect. The directory currently sorts its returned page locally; global table ordering, tied timestamps and large-limit behavior remain review items. Client checks do not establish server authority or full W02/W03/W05 acceptance.

## Environment and continuation

One obsolete ignored Flutter test cache produced after this goal began was removed to recover 98,312,736 bytes. Its path, hash and metadata are in obsolete-test-cache-cleanup.json. Source and raw QA evidence were preserved. Storage dropped again during UI compilation and briefly prevented a register-update shell heredoc. Atomic writes protect existing checkpoint files from interrupted writes.

Restore stable capacity before broader testing; the next broader-suite preflight requires at least 1 GiB available after repeated failures around 300–400 MiB. This is an environment prerequisite, not an app-test pass/fail. Approved runtime configuration, an isolated database, devices, installed PWA and independent/owner acceptance remain outstanding.

The review and goal remain active. Release readiness is NO-GO.

Current source and tested-artifact bindings are recorded in source-binding-after-collector.json and source-binding-after-collector-final.json. All executable Dart inputs are unchanged after the passing full suite; only a nonsemantic Kotlin EOF cleanup followed. Storage remains variable, but it no longer prevents the completed Admin and proof-host checks. Backend authority, compiled runtime and owner acceptance remain open.
