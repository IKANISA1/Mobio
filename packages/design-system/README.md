# Design System Package Boundary

Current source of truth:

- Tokens/spec: `../../design.md`
- Flutter tokens/theme: `lib/src/theme`
- Reusable widgets: `../../lib/shared/widgets`
- Admin-specific audit docs: `../../docs/product/admin_design_system.md`

Extraction rule: move only stable, app-agnostic widgets here. Feature-specific cards, screens, providers, and backend calls must stay in their feature/app boundary.

Import tokens directly through `package:mobi_design_system/theme/...` or
`package:mobi_design_system/mobi_design_system.dart`. App-level compatibility
exports were removed in the September 2026 consolidation.
