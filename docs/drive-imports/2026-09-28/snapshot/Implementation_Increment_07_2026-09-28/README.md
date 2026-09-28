# Mobio Increment07

**Source implementation and local verification, not a deployed production release.**

32 changed repository files; 188-file cumulative overlay; durable notification outbox, bounded worker, session-bound Flutter delivery and administrative health. All 95 backlog tasks retain their original acceptance criteria.

Start with `IMPLEMENTATION_REPORT.md`, `INTEGRATION_RUNBOOK.md` and `VALIDATION_RESULTS.json`.

- `delta-files/`: new/modified source only, relative to the stated Increment06 baseline and exact original prerequisites.
- `cumulative-overlay/`: all prior delivered source plus this increment; not a standalone application.
- `DELTA_MANIFEST.json`, `increment07.patch`, `apply_increment07.py`: checked integration paths. Checksums detect drift, not authenticity.
- `Mobio_Backlog_Increment07_2026-09-28.xlsx`: six-sheet status, original criteria, verification, workstreams and sources.
- `TASK_STATUS_ALL95.json`, `ALL95_TASKS.csv`, `WORKSTREAMS.json`: machine-readable task tracking.
- `evidence/`: final test logs, original intermediate failures where retained, package checks and workbook verification.
- `SOURCES.json`: exact source/access/technical reference boundaries.

On an isolated complete review checkout with reconciled earlier work:

```sh
python3 apply_increment07.py --bundle /path/to/Mobio_Increment07_2026-09-28 --repo /path/to/mobio-review
# After inspecting the check-only plan and patch:
python3 apply_increment07.py --bundle /path/to/Mobio_Increment07_2026-09-28 --repo /path/to/mobio-review --apply
```

These commands change reviewed local source only. They do not deploy functions, apply database migrations, send notifications, change Drive access or rotate credentials. Database/client/function cutover is mandatory: dispatch defaults off; direct legacy registration is restricted and the old dispatcher returns 410. Read the runbook before applying body11 or enabling any scheduler.

601 local checks passed (107 new and 494 prior), including actual new TS/HTTP/crypto with explicit external fixtures. SQL/Dart/Deno, live Google/device and production acceptance remain unexecuted. No exactly-once external delivery guarantee is made.
