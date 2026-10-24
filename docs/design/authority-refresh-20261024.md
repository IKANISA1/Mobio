# Design authority binding refresh — 24 October 2026

The Mobio authority check failed because the current maintained `SKILL.md` and `100-design-checks.md` no longer matched their recorded hashes. The five external authority files below were reread before refreshing the two changed bindings in [authority.json](authority.json). The other three hashes already matched and remain unchanged.

The selected provider remains `revolut-design@jean-bosco-skills`. Installed skill discovery was unavailable in this session, so review used the repository-authorized maintained-source fallback at `/Volumes/PRO-G40/Projects/ChatGPT/Revolut/skill/revolut-design/SKILL.md` and its bundled references. The instruction-library index and the Mobio source-role record were consulted as provenance; they do not independently grant authority.

The current entrypoint preserves each target product's identity, capabilities and workflow outcomes and carries the owner's clean/minimal, readable-responsive, admin/portal icon and PWA directions. The current R001–R100 reference keeps its stable IDs and requires evidence for applicable visual, interaction, accessibility and PWA claims. These are reviewed current-source findings; this refresh does not assert an exact textual comparison with unavailable historical source bytes.

| External file | Previously recorded SHA-256 | Reviewed SHA-256 |
|---|---|---|
| `SKILL.md` | `e593550503309fe1ea94642e8cdc1065d112573b572c11cdbabdd8811f4dc346` | `e57cec94ab98fe431c21afb6caf071eafcf1dcbea9f0b2a4362ab428c9b86119` |
| `references/brand-adaptation.md` | `135a13f0672dc0384668b92c5ac88e77b9219c5760f10cdcaff8ec456501f9fd` | `135a13f0672dc0384668b92c5ac88e77b9219c5760f10cdcaff8ec456501f9fd` |
| `references/100-design-checks.md` | `483285a5290bb63a51366b9e1aae75226b395fdf4d7a1853ef228b67668407c9` | `31ac2a0c101885ad985670b89dc2f51427770ec19b97a13aec02bebd495701b1` |
| `references/quality-standard.md` | `ced82304fee23070e875a45a85e4215629305bb9840636cdd1b6f93a58c31d0a` | `ced82304fee23070e875a45a85e4215629305bb9840636cdd1b6f93a58c31d0a` |
| `references/operational-checklist.md` | `d2fc52670574e669b88a8ccd8daa8b531b14fca0220d2217ab5a5d2ba82fa536` | `d2fc52670574e669b88a8ccd8daa8b531b14fca0220d2217ab5a5d2ba82fa536` |

The original `recorded_on` date, earlier binding history, provider, product identity and declared surfaces remain unchanged. Every visual-acceptance field remains **unverified**. This binding refresh changed no UI, route, token, asset, screenshot, baseline, historical capture or external skill file. The dated history entry retains the prior entrypoint and changed-reference hashes.

Verification: `python3 scripts/ci/check_design_authority.py` and `python3 -m unittest scripts.tests.test_design_authority`. These checks establish binding integrity and authority hygiene only; they do not establish visual fidelity, deployment, device behavior or owner acceptance.
