# Mobio

Rwanda-first mobility discovery, scheduled trip posts, profiles, and communication,
with separately documented public-transport and BioPay USSD features.

The entire source repository lives directly in `/Volumes/PRO-G40/mobio`, with
`.git` at this root and no nested application checkout.

```sh
git -C /Volumes/PRO-G40/mobio status
```

## Start here

- [Architecture and ownership](docs/architecture/README.md)
- [Product scope](docs/product/scope.md) and its dated expansion documents
- [Critical rules](CRITICAL_RULES.md) and [design authority and evidence](docs/design/README.md)
- [Development workflow](docs/development/flutter_dart_2026_workflow.md)
- [Release procedures](docs/release/google-play-submission.md)

## Setup and verification

Use Flutter **3.44.3 / Dart 3.12.2**, pinned in `.flutter-version`. Scripts honor
`FLUTTER_BIN`; on this workstation they prefer
`/Volumes/PRO-G40/Development/Flutter/flutter_3_44_codex/bin/flutter`.

```sh
./scripts/ci/bootstrap_flutter.sh
./scripts/ci/verify_flutter.sh
# Flutter and backend verification, using local tools:
./scripts/ci/verify_local.sh
# Also build Android AAB/APK, unsigned iOS, and the website/admin package:
./scripts/ci/verify_local.sh --builds
```

Bootstrap resolves dependencies, generates shared model parts in their owning
package, and generates localizations. Verification checks architecture, build
helpers, static analysis, and Flutter tests. Reviewed golden baselines remain in
`test/features/preview/goldens/`; generated differences in `failures/` are ignored.
Update baselines only after reviewing an intentional visual change.

The local verification command requires Deno 2.x on `PATH`. The `--builds`
option also requires macOS/Xcode, CocoaPods, Android signing files, and the public
values in `.env`. It runs backend type checks and unit tests without linked
Supabase credentials. It does not deploy or upload artifacts. This is the
selected workflow while keeping the existing GitHub Free account; paid Actions
and billing changes are not required for these local commands.

## Repository layout

```text
lib/
  main.dart                  Entry point
  app/                       Bootstrap, root widget, shell, router, app state
  core/                      Auth, backend, config, Firebase, location, utilities
  features/<feature>/
    application/             Riverpod composition, state, and orchestration
    data/                    Services and platform adapters
    domain/                  Feature models and pure business helpers
    presentation/            Screens and feature widgets
  shared/                    App-specific shared widgets, models, and data
  l10n/                      Translations and generated localization bindings
packages/
  design-system/             Reusable Flutter theme tokens
  shared-types/              Pure Dart contracts
  lucide_icons_compat/       Maintained compatibility fork and licence
apps/momobio_sms_bridge/     Separate Android operator utility
landing/                    Public website and policy pages
supabase/                   Canonical migrations, functions, seeds, backend tests
scripts/                    Bootstrap, QA, release, and deployment commands
docs/                       Product, architecture, operations, release evidence
test/                       Unit, widget, visual, and release-contract tests
tool/                       Local visual preview harnesses
android/ ios/ web/          Flutter platform hosts
```

Mobile and web/admin share the root Flutter application. `apps/` contains actual
separate applications, without placeholder shells. Supabase remains the system
of record and authorization authority. Firebase provides auxiliary infrastructure
such as push, crash reporting, analytics, and remote configuration.

## Runtime configuration and builds

Provide these **public client values** through the local ignored `.env` or the
process environment: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `PRIVACY_POLICY_URL`, and
`ACCOUNT_DELETION_URL`.

The shared build helper reads literal values and forwards only those four keys
for Android/web. iOS additionally requires `FIREBASE_IOS_APP_ID` and accepts the
public `FIREBASE_IOS_API_KEY` and `FIREBASE_IOS_BUNDLE_ID` overrides.
Service-role credentials, signing material, and provider secrets never belong in
Flutter defines. Android builds require the existing local signing configuration.

```sh
./scripts/release/build_android_release.sh appbundle
./scripts/release/build_android_release.sh apk
./scripts/ci/verify_ios_release.sh
./scripts/web/prepare_pwa_bundles.sh
```

These commands create local artifacts. Deployment and store submission use the
separate procedures in `docs/release/` and `scripts/release/`.

The iOS command reads `.env` directly, validates the iOS registration, and uses a
temporary native-architecture CocoaPods shim on Apple Silicon where supported.
It does not require manually exporting values or changing system Ruby gems.

## Maintainer rules

- Put feature code beside its owner; import only the providers a consumer uses.
- Import shared contracts and theme tokens directly through their package APIs.
- Keep core independent of features; keep domain code independent of UI and data.
- Preserve applied migration history under `supabase/migrations/`.
- Preserve app IDs, OTP authorization, numeric member IDs, route guards, external
  USSD semantics, and the disabled route-computation boundary during refactors.
- Save generated runs under ignored `build/`. Curated historical evidence belongs
  in `docs/release/evidence/`.

The September 2026 consolidation is recorded in
[the refactor log](docs/architecture/structure_refactor_changelog.md). Earlier
plans and the previous README are preserved in [architecture history](docs/architecture/history/).
