import importlib.util
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "ci/check_design_authority.py"
spec = importlib.util.spec_from_file_location("design_authority", MODULE)
authority = importlib.util.module_from_spec(spec)
spec.loader.exec_module(authority)


class DesignAuthorityTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for relative in authority.AUTHORITY_DOCUMENTS:
            self.write(relative, "External [revolut-design](</skills/revolut-design/SKILL.md>) is the sole design authority for app, web and admin.\n")
        self.binding = {
            "authority": {
                "skill_id": "revolut-design", "role": "sole_design_authority",
                "entrypoint": {"path": "/unmounted-external/revolut-design/SKILL.md", "sha256": "a" * 64},
                "bundled_references": [],
            },
            "declared_surfaces": ["native_android", "native_ios", "consumer_web", "public_website", "admin_web", "operator_android"],
            "acceptance": {"status": "unverified"},
        }
        self.write("docs/design/authority.json", json.dumps(self.binding))

    def write(self, relative, source):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(source, encoding="utf-8")

    def errors(self, *paths):
        return authority.authority_errors(self.root, list(authority.AUTHORITY_DOCUMENTS) + list(paths))

    def test_removed_spec_cannot_return_in_a_nested_folder(self):
        self.write("docs/archive/design.md", "Local colours and components")
        self.assertTrue(any("must not be restored" in error for error in self.errors("docs/archive/design.md")))

    def test_removed_reference_cannot_remain_a_clickable_instruction(self):
        self.write("docs/development/ui.md", "[design system](../../design.md#colours)\n")
        self.assertTrue(any("active link" in error for error in self.errors("docs/development/ui.md")))

    def test_competing_inspiration_is_rejected_without_banning_framework_apis(self):
        self.write("docs/development/ui.md", "Use Apple-inspired surfaces.\n")
        self.assertTrue(any("competing design" in error for error in self.errors("docs/development/ui.md")))
        self.write("docs/development/ui.md", "Material widgets use Mobio adapters; Apple platform signing and Stripe payment facts retain their technical meaning.\n")
        self.assertEqual(self.errors("docs/development/ui.md"), [])

    def test_donor_interface_cannot_override_the_external_skill(self):
        self.write("docs/product/capture.md", "The MEMORIES capture UI may be used as the interface reference.\n")
        self.assertTrue(any("competing design" in error for error in self.errors("docs/product/capture.md")))
        self.write("docs/product/capture.md", "AWS provider code has MEMORIES provenance. Mobio's approved workflow retains Center, Turn, Hold.\n")
        self.assertEqual(self.errors("docs/product/capture.md"), [])

    def test_gallery_must_delegate_instead_of_republishing_a_palette(self):
        self.write("scripts/qa/build_design_gallery.py", 'generator = entrypoint.parent / "scripts/build_review_gallery.py"\n')
        self.assertEqual(self.errors("scripts/qa/build_design_gallery.py"), [])
        self.write("scripts/qa/build_design_gallery.py", 'generator = "scripts/build_review_gallery.py"\npage = "<style>body{background:#182be2}</style>"\n')
        self.assertTrue(any("must remain in the external skill" in error for error in self.errors("scripts/qa/build_design_gallery.py")))

    def test_historical_hash_records_remain_factual(self):
        self.write("docs/reports/parity.md", "Historical hash for `design.md`: abc123\n")
        self.write("docs/release/evidence/prior.md", "Historical source: Soft Liquid Glass\n")
        self.assertEqual(self.errors("docs/reports/parity.md", "docs/release/evidence/prior.md"), [])

    def test_local_authority_cannot_replace_any_governing_entry_point(self):
        self.write("CRITICAL_RULES.md", "Follow local design.md exactly.\n")
        errors = self.errors()
        self.assertTrue(any("sole design authority" in error for error in errors))
        self.assertTrue(any("used as an instruction" in error for error in errors))

    def test_all_surfaces_are_required(self):
        self.write("docs/design/README.md", "External /skills/revolut-design/SKILL.md is the sole design authority for app and web.\n")
        self.assertTrue(any("cover app, web and admin" in error for error in self.errors()))

    def test_operator_surface_cannot_be_omitted_from_whole_product_scope(self):
        self.binding["declared_surfaces"].remove("operator_android")
        self.write("docs/design/authority.json", json.dumps(self.binding))
        self.assertTrue(any("declared surfaces are incomplete" in error for error in self.errors()))

    def test_separate_mobile_acceptance_rule_is_rejected(self):
        self.binding["acceptance"]["mobile_rule"] = "retired-mobile-rule"
        self.write("docs/design/authority.json", json.dumps(self.binding))
        self.assertTrue(any("separate mobile acceptance rule" in error for error in self.errors()))

    def test_authority_cannot_be_a_copied_local_spec(self):
        self.binding["authority"]["entrypoint"]["path"] = str(self.root / "revolut-design/SKILL.md")
        self.write("docs/design/authority.json", json.dumps(self.binding))
        self.assertTrue(any("must remain external" in error for error in self.errors()))

    def test_accessible_authority_changes_fail_the_binding(self):
        with tempfile.TemporaryDirectory() as external:
            path = Path(external) / "revolut-design/SKILL.md"
            path.parent.mkdir()
            path.write_text("Original authority")
            self.binding["authority"]["entrypoint"] = {
                "path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()
            }
            self.write("docs/design/authority.json", json.dumps(self.binding))
            self.assertEqual(self.errors(), [])
            path.write_text("Changed authority")
            self.assertTrue(any("authority hash changed" in error for error in self.errors()))


if __name__ == "__main__":
    unittest.main()
