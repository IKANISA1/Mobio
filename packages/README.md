# Shared packages

Only implemented, buildable packages live here.

| Package | Ownership | Public API |
| --- | --- | --- |
| `design-system` | Flutter theme and design tokens | `package:mobi_design_system/theme/...` |
| `shared-types` | Pure Dart model contracts | `package:mobi_shared_types/models/...` |
| `lucide_icons_compat` | Local icon compatibility fork and licence | `package:lucide_icons/lucide_icons.dart` |

Feature services, state, and screens belong to `lib/features/<owner>/`. Core
platform services belong to `lib/core/`. Import package APIs directly; app-level
model/theme compatibility wrappers have been retired.

Run `scripts/ci/bootstrap_flutter.sh` from the root to prepare shared models and
the application. Add a package only when it has real source, a build definition,
and a clear consumer.
