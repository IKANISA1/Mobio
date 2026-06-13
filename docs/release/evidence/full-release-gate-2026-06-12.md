# Full Release Gate Evidence

Date: 2026-06-12
Scope: full repository gate, linked Supabase backend verification, and dry-run
go/no-go status.

## Flutter Gate

Command:

```bash
FLUTTER_BIN=/Volumes/PRO-G40/flutter_3_44/bin/flutter ./scripts/ci/verify_flutter.sh
```

Result: passed.

- `flutter pub get`: passed.
- `flutter gen-l10n`: passed.
- `flutter analyze --no-fatal-infos --no-fatal-warnings`: passed with no
  issues.
- `flutter test --coverage`: passed with `213/213` tests.

Notes:

- The first full run exposed stale Admin Revolut golden images and a stale
  release contract test load. The Admin Revolut goldens were refreshed after
  visual inspection, then the full gate was rerun from the start and passed.
- No Android app bundle was rebuilt.

## Linked Backend Gate

Command:

```bash
SUPABASE_PROJECT_REF=paysnhuxngsvzdpwlosv \
REQUIRE_LINKED_SUPABASE=true \
./scripts/ci/verify_backend.sh
```

Result: passed.

- Committed secret-pattern scan: passed.
- Supabase Edge Function Deno checks/tests: passed.
- Remote `public` schema lint on the linked project: passed with no schema
  errors.
- Storage/realtime audit: passed.
- Backend security assertions: passed.

## Aggregate Go/No-Go Dry Run

Command:

```bash
GO_NO_GO_DRY_RUN=true \
RUN_FLUTTER_GATE=false \
RUN_ANDROID_SMOKE=false \
RELEASE_TARGET=android \
SUPABASE_PROJECT_REF=paysnhuxngsvzdpwlosv \
./scripts/release/go_no_go_check.sh
```

Result: expected `NO-GO` in dry-run mode.

Passed inside the dry run:

- Committed secret scan.
- Git secret-history purge proof.
- Linked Supabase backend gates.

Blocked inside the dry run:

- Release config/signing gate: missing `KEYSTORE_BASE64`.
- Play service-account key rotation evidence:
  `PLAY_SERVICE_ACCOUNT_ROTATED=true` is not set.
- Play Console upload validation evidence:
  `PLAY_CONSOLE_UPLOAD_VALIDATED=true` is not set.
- Android release smoke was intentionally skipped because this pass must not
  rebuild release artifacts or the AAB.

## Recovered Resource Dry Run

After local release resources were recovered, the aggregate dry run was repeated
with:

- signing env derived from `android/mobi-upload.jks` and
  `android/key.properties`,
- Play service-account JSON from
  `/Users/jeanbosco/Downloads/easymoai-208b85b24685.json`,
- Play upload evidence from
  `docs/release/evidence/play-console-upload-2026-06-12-v13.md`.

Additional result:

- Release config and signing gates: passed.
- Play Console internal/closed-track upload evidence: passed.
- Owner-approved Play service-account key retention evidence was added after
  Jean Bosco explicitly instructed to keep the keys as they are and not rotate
  or revoke any keys.

Detailed inventory:

`docs/release/evidence/recovered-release-resources-2026-06-12.md`

## Motion Proof Status

Motion proof was attempted separately and remains blocked by device state. See:

`docs/release/evidence/revolut-motion-2026-06-12/README.md`

## Physical Android Release Smoke

Passed using the existing release APK. No app bundle was rebuilt.

Command:

```bash
ANDROID_SERIAL=13111JEC215558 \
ANDROID_SMOKE_EVIDENCE_DIR=docs/release/evidence/android-smoke-2026-06-12 \
./scripts/release/smoke_android_release.sh
```

Result:

- Installed `build/app/outputs/flutter-apk/app-release.apk`.
- Verified APK Signature Scheme v2.
- Launched `rw.mobi.app` on Pixel 4a / Android 13 / API 33.
- Captured a running process id after launch.

Evidence:

`docs/release/evidence/android-smoke-2026-06-12/smoke-20260612T142526Z.log`
