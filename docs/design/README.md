# Mobio design authority and product evidence

The [external `revolut-design` skill](</Volumes/PRO-G40/Application Data/Codex/Codex-Home/skills/revolut-design/SKILL.md>)
and its bundled references are the **sole design authority** for the whole Mobio
app, web experience, public website and admin workspace. The selected visual
typologies and full applicable colour system govern all routes, components and
states. Preserve Mobio's own name, logo, icon, features, navigation, workflows,
content, permissions and server contracts.

This directory records product mappings and evidence. It does not define a
second visual system. Read the external skill's `brand-adaptation.md`, applicable
native or web/Business reference, and state/component references before changes.
Choose and record the applicable dated source cohort; do not mix different
cohorts silently. Every applicable route/state requires a direct comparator,
component/pattern comparator or explicit adaptation. Unknown source treatments
and inaccessible originals remain unverified.

## Implementation owners

- Shared Flutter semantic adapters: `packages/design-system/lib/src/theme/`.
- Shared app controls: `lib/shared/widgets/`; shell: `lib/app/shell.dart`.
- Feature screens: `lib/features/*/presentation/`.
- Admin primitives: `lib/features/admin/presentation/widgets/admin_ui.dart`.
- Public website and policy pages: `landing/`; browser boot surface: `web/`.

## Existing product comparison evidence

- [Authority binding](authority.json): SHA-256 bindings for the external skill
  and governing identity/mobile acceptance references; current visual acceptance
  for every declared surface remains unverified.
- [Whole-product reimplementation](reimplementation-20260905.md): dated native,
  public website and Business-to-admin mappings and implementation checks.
- [Colour and authentication follow-up](colour-and-auth-followup-20260905.md):
  dated colour families, source boundaries, own-identity migration and states.
- [Reference-source hashes](reference-sources-20260905.json),
  [route inventory](routes-20260905.json),
  [colour-role inventory](colour-role-inventory-20260905.json), and
  [runtime assets](runtime-assets-20260905.json): historical product evidence,
  with their own scope/date limits.
- [Full-system QA plan](../testing/fullstack-qa-plan-20260914.md) and
  [design-rule crosswalk](../testing/fullstack-qa-20260914/design-rule-crosswalk.csv):
  product acceptance adapters and remaining evidence requirements.

These records do not assert current completeness, exact native tokens or release
acceptance. Mobile acceptance follows the external skill's `MOBILE-DESIGN-100`;
web, public website and admin require their own complete declared route/state
comparisons and workflow checks. Build/test success, a gallery or a target-only
golden does not establish 100% fidelity. Independent visual review and owner
acceptance remain separate evidence.

## Authority hygiene

Local design specifications and the obsolete logo-derived palette proposal were
removed on 30 September 2026. Do not restore them or introduce other design
inspiration. Historical source manifests retain filenames and hashes as factual
records; they do not supply instructions or active design references. Run:

```sh
python3 scripts/ci/check_design_authority.py
```

The checker enforces the authority boundary and removed-reference hygiene. It
does not certify rendered visual fidelity.
