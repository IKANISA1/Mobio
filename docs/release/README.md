# Release

Release source of truth currently lives in:

- `../../.github/workflows/release.yml`
- `../../scripts/release`
- `../../scripts/ci/verify_release_config.sh`
- `../../scripts/release/go_no_go_check.sh`
- `evidence/`
- Root `README.md` release sections.

Every release must run Flutter verification, backend verification, migration/lint checks, signing validation, and artifact generation before deployment.

## Native smoke checks

The Android release smoke command requires an authorized physical device by
default:

```sh
ANDROID_SERIAL=<physical-device-serial> ./scripts/release/smoke_android_release.sh
```

For local emulator QA, explicitly opt in:

```sh
ANDROID_SERIAL=<emulator-serial> ANDROID_SMOKE_ALLOW_EMULATOR=true \
  ./scripts/release/smoke_android_release.sh
```

The evidence records `device_type` and `physical_device_evidence`. The production
go/no-go command always disables the emulator opt-in, even if the calling shell
enables it. Neither command substitutes for authenticated workflow/device UAT.
The smoke command resolves Mobio's launcher activity and starts it directly.

Current local build evidence is in
[`local-verification-20260905.md`](../development/local-verification-20260905.md).
The subsequent [native QA report](../development/native-qa-20260906.md) records
the country-picker fix, current tests, native checks, and artifact updates.
The May `go-no-go.md` report is historical; apply the dated product approvals
listed in `AGENTS.md` when interpreting its older scope statements.
