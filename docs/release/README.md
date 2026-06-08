# Release

Release source of truth currently lives in:

- `../../.github/workflows/release.yml`
- `../../scripts/release`
- `../../scripts/ci/verify_release_config.sh`
- `../../scripts/release/go_no_go_check.sh`
- `evidence/`
- Root `README.md` release sections.

Every release must run Flutter verification, backend verification, migration/lint checks, signing validation, and artifact generation before deployment.
