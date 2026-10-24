import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

QA = Path(__file__).resolve().parents[1] / "qa"
sys.path.insert(0, str(QA))
try:
    SPEC = importlib.util.spec_from_file_location("mobio_flutter_source_runner", QA / "run_flutter_tests.py")
    runner = importlib.util.module_from_spec(SPEC)
    SPEC.loader.exec_module(runner)
finally:
    sys.path.remove(str(QA))


class FlutterTestSourceBindingTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name).resolve()
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)
        (self.root / "lib").mkdir()
        (self.root / "lib/main.dart").write_text("original UI")
        subprocess.run(["git", "-C", str(self.root), "add", "lib/main.dart"], check=True)
        # This local Python executable is a deterministic child fixture, not a
        # Flutter engine. It observes the wrapper contract and source changes.
        self.child = self.root / "child_fixture.py"
        self.child.write_text(
            f"#!{sys.executable}\n"
            "import json, os, pathlib, stat, sys\n"
            "assert sys.argv[1] == 'test'\n"
            "request = json.loads(sys.argv[2])\n"
            "manifest = pathlib.Path(os.environ['MOBIO_UI_SOURCE_MANIFEST'])\n"
            "observation = {'path': str(manifest), 'file_mode': stat.S_IMODE(manifest.stat().st_mode), "
            "'directory_mode': stat.S_IMODE(manifest.parent.stat().st_mode), "
            "'manifest': json.loads(manifest.read_text()), 'args': sys.argv[1:]}\n"
            "pathlib.Path('observed.json').write_text(json.dumps(observation))\n"
            "change = request.get('change')\n"
            "if change == 'modify': pathlib.Path('lib/main.dart').write_text('changed UI')\n"
            "if change == 'add': pathlib.Path('lib/new.dart').write_text('new UI')\n"
            "if change == 'remove': pathlib.Path('lib/main.dart').unlink()\n"
            "if change == 'ignored':\n"
            " pathlib.Path('.gitignore').write_text('lib/ignored.dart\\n')\n"
            " pathlib.Path('lib/ignored.dart').write_text('ignored UI')\n"
            "sys.exit(request.get('exit', 0))\n"
        )
        self.child.chmod(0o700)
        self.report = self.root / "build/source-result.json"

    def run_child(self, **request):
        # Keep fixture evidence quiet in the ordinary unit-test aggregate.
        with patch("sys.stderr"):
            result = runner.run_tests(self.root, self.child, [json.dumps(request)], self.report)
        return result, json.loads(self.report.read_text())

    def test_private_manifest_is_ordered_current_and_removed_after_success(self):
        code, result = self.run_child()
        self.assertEqual(code, 0)
        self.assertTrue(result["source_unchanged_during_test"])
        self.assertEqual(result["flutter_exit_code"], 0)
        observed = json.loads((self.root / "observed.json").read_text())
        self.assertEqual(observed["file_mode"], 0o600)
        self.assertEqual(observed["directory_mode"], 0o700)
        self.assertFalse(Path(observed["path"]).exists())
        self.assertEqual(observed["manifest"]["files"][0]["path"], "lib/main.dart")
        self.assertEqual(observed["manifest"]["source_sha256"], result["source_before"]["source_sha256"])

    def test_failed_test_preserves_exit_and_still_checks_sources(self):
        code, result = self.run_child(exit=7)
        self.assertEqual(code, 7)
        self.assertEqual(result["flutter_returncode"], 7)
        self.assertTrue(result["source_unchanged_during_test"])

    def test_failed_test_with_modified_source_records_both_failures(self):
        code, result = self.run_child(exit=7, change="modify")
        self.assertEqual(code, 7)
        self.assertFalse(result["source_unchanged_during_test"])
        self.assertEqual(result["source_changes"]["modified"], ["lib/main.dart"])

    def test_passing_test_with_new_nonignored_source_fails_binding(self):
        code, result = self.run_child(change="add")
        self.assertEqual(code, 2)
        self.assertEqual(result["flutter_exit_code"], 0)
        self.assertEqual(result["source_changes"]["added"], ["lib/new.dart"])

    def test_removed_last_source_records_verification_error_after_failed_test(self):
        code, result = self.run_child(exit=9, change="remove")
        self.assertEqual(code, 9)
        self.assertFalse(result["source_unchanged_during_test"])
        self.assertIn("No indexed product UI source", result["source_verification_error"])

    def test_ignored_new_source_keeps_authoritative_selection_unchanged(self):
        code, result = self.run_child(change="ignored")
        self.assertEqual(code, 0)
        self.assertTrue(result["source_unchanged_during_test"])

    def test_unsafe_executable_fails_preflight_without_running_a_child(self):
        with patch("sys.stderr"):
            code = runner.run_tests(self.root, Path("flutter"), [], self.report)
        result = json.loads(self.report.read_text())
        self.assertEqual(code, 2)
        self.assertIsNone(result["flutter_exit_code"])
        self.assertIn("absolute configured Flutter", result["preflight_error"])
        self.assertFalse((self.root / "observed.json").exists())

    def test_manifest_export_preserves_canonical_stdout(self):
        output = self.root / "manifest.json"
        command = [sys.executable, str(QA / "design_source_fingerprint.py"), "--project-root", str(self.root)]
        old = subprocess.run(command, check=True, capture_output=True, text=True)
        exported = subprocess.run([*command, "--manifest-out", str(output)], check=True, capture_output=True, text=True)
        self.assertEqual(json.loads(old.stdout), json.loads(exported.stdout))
        manifest = json.loads(output.read_text())
        self.assertEqual(manifest["project_root"], str(self.root))
        self.assertEqual(len(manifest["files"]), manifest["file_count"])
        self.assertEqual(manifest["source_sha256"], json.loads(old.stdout)["source_sha256"])


if __name__ == "__main__":
    unittest.main()
