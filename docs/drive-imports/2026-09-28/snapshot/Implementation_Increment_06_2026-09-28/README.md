# Mobio Increment06 — chat delivery, recovery and history

28 September 2026. **Source candidate, not deployed; new chat SQL and Dart tests are authored but not executed.**

Delivery: https://drive.google.com/drive/folders/1b6P3qCl5mhT_DDkcOIBVDURcN0JfqTYo

This package contains 29 new/modified repository files and a 163-file cumulative overlay preserving Increment05. It advances ten tasks and keeps all 95 original tasks, owner roles, dependencies and acceptance criteria in the workbook/JSON. No production acceptance is claimed.

Start with `IMPLEMENTATION_REPORT.md`, `INTEGRATION_RUNBOOK.md` and `VALIDATION_RESULTS.json`. Inspect `DELTA_MANIFEST.json`, then use `apply_increment06.py` in check-only mode on an isolated complete source checkout. `delta-files/` contains exact changes; `cumulative-overlay/` is not a standalone Flutter repository and must not blindly overwrite a newer checkout. `increment06.patch` is independently checked against the affected reconstructed baseline.

**Cutover:** body10 starts new chat sends OFF, retires the legacy send RPC with 410, and restricts direct client message access. Coordinate the database/client transition and run actual runtime gates before explicit enablement. Earlier admin/wallet cutover conditions remain applicable.

**Verification:** 21 new executable tooling checks, 18 new static assertions and 455 prior regression checks passed. Zero new chat SQL or Dart behavioral tests were executed. PostgreSQL/Docker, Flutter/Dart, Deno, hosted CI, signed-device and real Auth/PostgREST acceptance remain open.

**Access:** the source folder still permits anyone with the link to edit. No permissions or signing credentials were changed. This archive excludes live secrets, private signing stores and Git object databases.
