# Design System Package Boundary

The sole design authority is the [external `revolut-design` skill](</Volumes/PRO-G40/Application Data/Codex/Codex-Home/skills/revolut-design/SKILL.md>) and its bundled references, for app, web and admin. This package implements product adapters; it does not define a separate visual reference.

Implementation boundaries:

- Product mappings and comparison evidence: `../../docs/design/README.md`
- Flutter tokens/theme: `lib/src/theme`
- Reusable widgets: `../../lib/shared/widgets`
- Admin primitives: `../../lib/features/admin/presentation/widgets/admin_ui.dart`

Extraction rule: move only stable, app-agnostic widgets here. Feature-specific cards, screens, providers, and backend calls must stay in their feature/app boundary.

Import tokens directly through `package:mobi_design_system/theme/...` or
`package:mobi_design_system/mobi_design_system.dart`. App-level compatibility
exports were removed in the September 2026 consolidation.
