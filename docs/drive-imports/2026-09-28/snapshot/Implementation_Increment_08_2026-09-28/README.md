# Mobio Increment08

Secure native session storage and guarded passenger/admin login/logout integration.

31 changed/new repository files; 207-file cumulative overlay. Source candidate only, not a full checkout or deployed release.

Start with `IMPLEMENTATION_REPORT.md`, then `INTEGRATION_RUNBOOK.md`. Review `SOURCES.json`, `DELTA_MANIFEST.json`, the original acceptance criteria and actual lane boundaries in `VALIDATION_RESULTS.json`.

- `delta-files/`: the new increment only, at repository-relative paths.
- `cumulative-overlay/`: earlier source increments plus this increment; not a standalone app.
- `increment08.patch` and `apply_increment08.py`: two reviewed integration paths. The applier checks by default.
- `TASK_STATUS_ALL95.json`, `ALL95_TASKS.csv`, workbook: all original tasks preserved; 10 advanced, 39 prior source/acceptance open, 46 not advanced.
- `evidence/`: real check logs and unavailable/runtime boundaries. JVM cryptography is not native Keystore/Keychain acceptance.

671 passing local checks = 70 new (52 executable; 18 static) + 601 prior rerun. No new Flutter/Dart/native secure-storage behavior has been executed. Forced re-login for legacy credentials and memory-only web sessions require rollout approval and actual device/browser acceptance. No dependency upgrade or new SQL; previous cutover requirements remain.

Drive delivery: https://drive.google.com/drive/folders/16uKtJ0pDmn_uVnlo7Tpt-ittYxnwhvrC
