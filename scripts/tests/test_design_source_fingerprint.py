import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / "qa/design_source_fingerprint.py"
spec = importlib.util.spec_from_file_location("design_source_fingerprint", MODULE)
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
LAUNCHER = Path(__file__).resolve().parents[1] / "qa/build_design_gallery.py"
launcher_spec = importlib.util.spec_from_file_location("design_gallery_launcher", LAUNCHER)
launcher = importlib.util.module_from_spec(launcher_spec)
launcher_spec.loader.exec_module(launcher)


class DesignSourceFingerprintTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        self.write(".gitignore", ".env*\n**/build/\n**/.dart_tool/\nignored.dart\n")
        self.write("lib/main.dart", "Mobio app")
        self.write("packages/design-system/lib/theme.dart", "Mobio theme")
        self.write("landing/style.css", "Mobio website")
        self.write("apps/momobio_sms_bridge/app/src/main/MainActivity.kt", "Mobio operator")
        subprocess.run(["git", "-C", str(self.root), "add", "."], check=True)

    def write(self, relative, content):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def digest(self):
        return source.fingerprint(self.root)["source_sha256"]

    def test_theme_website_operator_assets_and_build_selection_invalidate_evidence(self):
        for relative in (
            "packages/design-system/lib/theme.dart", "landing/style.css",
            "apps/momobio_sms_bridge/app/src/main/MainActivity.kt",
            "assets/font.ttf", "icon/mobio.png", "web/index.html",
            "android/app/src/main/res/values/styles.xml", "ios/Runner/Info.plist",
            "pubspec.yaml", ".flutter-version", "tool/preview.dart",
        ):
            with self.subTest(relative=relative):
                before = self.digest()
                self.write(relative, "Changed UI source")
                self.assertNotEqual(before, self.digest())

    def test_nonignored_untracked_source_is_bound_but_secrets_and_output_are_excluded(self):
        before = self.digest()
        self.write("lib/new_control.dart", "New UI source")
        self.assertNotEqual(before, self.digest())
        before = self.digest()
        for relative in (
            "lib/ignored.dart", "lib/build/generated.dart", "lib/.dart_tool/generated.dart",
            "lib/.env", "assets/service-account.json", "assets/signing.pem",
            "packages/design-system/README.md", "packages/design-system/test/theme_test.dart",
            "apps/momobio_sms_bridge/app/src/androidTest/Fixture.kt", "build/qa/capture.png",
        ):
            self.write(relative, "Excluded content")
        self.assertEqual(before, self.digest())
        subprocess.run(["git", "-C", str(self.root), "add", "-f", "lib/.env", "lib/build/generated.dart"], check=True)
        self.assertEqual(before, self.digest())

    def test_deletion_and_path_changes_invalidate_evidence(self):
        before = self.digest()
        (self.root / "landing/style.css").rename(self.root / "landing/replacement.css")
        self.assertNotEqual(before, self.digest())
        before = self.digest()
        (self.root / "lib/main.dart").unlink()
        self.assertNotEqual(before, self.digest())

    def test_external_symlink_fails_without_hashing_outside_source(self):
        with tempfile.TemporaryDirectory() as external:
            path = Path(external) / "private.dart"
            path.write_text("External content")
            (self.root / "lib/external.dart").symlink_to(path)
            with self.assertRaisesRegex(ValueError, "leaves project root"):
                self.digest()

    def test_matching_current_reports_pass_and_missing_reports_stay_unverified(self):
        current = self.digest()
        config = {"evidence": "build/qa/design-review"}
        for key in launcher.REPORT_KEYS:
            config[key] = f"{key}.json"
            self.write(f"build/qa/design-review/{key}.json", json.dumps({"source_sha256": current}))
        for relative in launcher.ADMIN_REPORTS.values():
            self.write(f"build/qa/design-review/{relative}", json.dumps({"source_sha256": current}))
        self.assertEqual(launcher.preflight_reports(self.root, config, current), [])
        (self.root / "build/qa/design-review/keyboard_report.json").unlink()
        self.assertEqual(launcher.preflight_reports(self.root, config, current), ["keyboard_report"])

    def test_shared_theme_and_website_edits_reject_stale_report_media(self):
        config = {"evidence": "build/qa/design-review", "matrix_report": "matrix.json"}
        for relative in ("packages/design-system/lib/theme.dart", "landing/style.css"):
            with self.subTest(relative=relative):
                self.write("build/qa/design-review/matrix.json", json.dumps({"source_sha256": self.digest()}))
                self.write(relative, "Changed after screenshot capture")
                with self.assertRaisesRegex(ValueError, "Rerun or recapture"):
                    launcher.preflight_reports(self.root, config, self.digest())

    def test_existing_unbound_report_is_rejected_instead_of_relabelled(self):
        config = {"component_report": "docs/design/component.json"}
        self.write("docs/design/component.json", json.dumps({"captures": []}))
        with self.assertRaisesRegex(ValueError, "missing or stale source_sha256"):
            launcher.preflight_reports(self.root, config, self.digest())

    def test_fixed_admin_capture_report_is_invalidated_by_operator_source_changes(self):
        config = {"evidence": "build/qa/design-review"}
        self.write(
            "build/qa/design-review/exhaustive-admin/admin_browser_qa.json",
            json.dumps({"source_sha256": self.digest(), "results": [{"screenshotPath": "old.png"}]}),
        )
        self.write("apps/momobio_sms_bridge/app/src/main/MainActivity.kt", "Operator changed after capture")
        with self.assertRaisesRegex(ValueError, "admin_browser_report"):
            launcher.preflight_reports(self.root, config, self.digest())


if __name__ == "__main__":
    unittest.main()
