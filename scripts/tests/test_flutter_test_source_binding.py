import importlib.util
import hashlib
import io
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
            "reporters = [arg for arg in sys.argv[2:] if arg.startswith('--file-reporter=')]\n"
            "assert len(reporters) == 1 and reporters[0].startswith('--file-reporter=json:')\n"
            "report = pathlib.Path(reporters[0].split('json:', 1)[1])\n"
            "request = json.loads([arg for arg in sys.argv[2:] if arg not in reporters][0])\n"
            "manifest = pathlib.Path(os.environ['MOBIO_UI_SOURCE_MANIFEST'])\n"
            "observation = {'path': str(manifest), 'file_mode': stat.S_IMODE(manifest.stat().st_mode), "
            "'directory_mode': stat.S_IMODE(manifest.parent.stat().st_mode), "
            "'report_path': str(report), 'report_mode': stat.S_IMODE(report.stat().st_mode), "
            "'manifest': json.loads(manifest.read_text()), 'args': sys.argv[1:]}\n"
            "pathlib.Path('observed.json').write_text(json.dumps(observation))\n"
            "change = request.get('change')\n"
            "if change == 'modify': pathlib.Path('lib/main.dart').write_text('changed UI')\n"
            "if change == 'add': pathlib.Path('lib/new.dart').write_text('new UI')\n"
            "if change == 'remove': pathlib.Path('lib/main.dart').unlink()\n"
            "if change == 'ignored':\n"
            " pathlib.Path('.gitignore').write_text('lib/ignored.dart\\n')\n"
            " pathlib.Path('lib/ignored.dart').write_text('ignored UI')\n"
            "events = request.get('events', [\n"
            " {'type': 'start', 'time': 0, 'protocolVersion': '0.1.1', 'runnerVersion': 'fixture', 'pid': 1},\n"
            " {'type': 'allSuites', 'time': 1, 'count': 1},\n"
            " {'type': 'testStart', 'time': 2, 'test': {'id': 1}},\n"
            " {'type': 'testDone', 'time': 3, 'testID': 1, 'result': 'success', 'hidden': False, 'skipped': False},\n"
            " {'type': 'done', 'time': 4, 'success': True},\n"
            "])\n"
            "if request.get('missing_report'): report.unlink()\n"
            "elif 'raw_report' in request: report.write_bytes(bytes.fromhex(request['raw_report']))\n"
            "else: report.write_text(''.join(json.dumps(event) + '\\n' for event in events))\n"
            "if request.get('signal'): os.kill(os.getpid(), request['signal'])\n"
            "sys.exit(request.get('exit', 0))\n"
        )
        self.child.chmod(0o700)
        self.report = self.root / "build/source-result.json"

    def run_child(self, console_args=(), **request):
        # Keep fixture evidence quiet in the ordinary unit-test aggregate.
        with patch("sys.stderr"):
            result = runner.run_tests(self.root, self.child, [json.dumps(request), *console_args], self.report)
        return result, json.loads(self.report.read_text())

    @staticmethod
    def complete_events():
        return [
            {"type": "start", "time": 0},
            {"type": "allSuites", "time": 1, "count": 1},
            {"type": "testStart", "time": 2, "test": {"id": 1}},
            {"type": "testDone", "time": 3, "testID": 1, "result": "success", "hidden": False, "skipped": False},
            {"type": "done", "time": 4, "success": True},
        ]

    def test_private_manifest_is_ordered_current_and_removed_after_success(self):
        code, result = self.run_child()
        self.assertEqual(code, 0)
        self.assertTrue(result["source_unchanged_during_test"])
        self.assertEqual(result["flutter_exit_code"], 0)
        self.assertTrue(result["test_run_complete"])
        self.assertTrue(result["test_run_successful"])
        observed = json.loads((self.root / "observed.json").read_text())
        self.assertEqual(observed["file_mode"], 0o600)
        self.assertEqual(observed["directory_mode"], 0o700)
        self.assertEqual(observed["report_mode"], 0o600)
        self.assertFalse(Path(observed["path"]).exists())
        self.assertFalse(Path(observed["report_path"]).exists())
        raw_report = Path(result["test_report"]["path"])
        self.assertEqual(raw_report.stat().st_mode & 0o777, 0o600)
        self.assertEqual(hashlib.sha256(raw_report.read_bytes()).hexdigest(), result["test_report"]["sha256"])
        self.assertEqual(raw_report.stat().st_size, result["test_report"]["bytes"])
        self.assertEqual(observed["manifest"]["files"][0]["path"], "lib/main.dart")
        self.assertEqual(observed["manifest"]["source_sha256"], result["source_before"]["source_sha256"])

    def test_console_reporter_is_preserved_alongside_private_json_reporter(self):
        code, _ = self.run_child(console_args=("--reporter", "expanded"))
        self.assertEqual(code, 0)
        observed = json.loads((self.root / "observed.json").read_text())
        self.assertEqual(observed["args"][-2:], ["--reporter", "expanded"])

    def test_exit_zero_without_done_is_not_a_completed_test_run(self):
        code, result = self.run_child(events=self.complete_events()[:-1])
        self.assertEqual(code, 2)
        self.assertEqual(result["flutter_exit_code"], 0)
        self.assertTrue(result["source_unchanged_during_test"])
        self.assertFalse(result["test_run_complete"])
        self.assertTrue(Path(result["test_report"]["path"]).is_file())

    def test_false_or_interrupted_terminal_state_cannot_pass_with_exit_zero(self):
        for success in (False, None):
            with self.subTest(success=success):
                events = self.complete_events()
                events[-1]["success"] = success
                code, result = self.run_child(events=events)
                self.assertEqual(code, 2)
                self.assertFalse(result["test_run_successful"])
                self.assertEqual(result["test_completion"]["done_success"], success)

    def test_errors_and_failed_results_override_an_incorrect_success_done(self):
        for failed_result in ("failure", "error"):
            with self.subTest(result=failed_result):
                events = self.complete_events()
                events[3]["result"] = failed_result
                events.insert(3, {"type": "error", "time": 3, "testID": 1, "error": "fixture failure"})
                code, result = self.run_child(events=events)
                self.assertEqual(code, 2)
                self.assertEqual(result["flutter_exit_code"], 0)
                self.assertEqual(result["test_completion"]["error_event_count"], 1)
                self.assertEqual(result["test_completion"]["failed_test_count"], 1)

    def test_late_error_after_successful_test_done_is_still_a_failure(self):
        events = self.complete_events()
        events.insert(-1, {"type": "error", "time": 3, "testID": 1, "error": "late fixture failure"})
        code, result = self.run_child(events=events)
        self.assertEqual(code, 2)
        self.assertEqual(result["test_completion"]["failed_test_count"], 0)
        self.assertEqual(result["test_completion"]["error_event_count"], 1)

    def test_success_done_with_unfinished_test_fails_closed(self):
        events = self.complete_events()
        events.insert(-1, {"type": "testStart", "time": 3, "test": {"id": 2}})
        code, result = self.run_child(events=events)
        self.assertEqual(code, 2)
        self.assertEqual(result["test_completion"]["unfinished_test_ids"], [2])

    def test_missing_empty_or_malformed_json_report_cannot_pass(self):
        for request in (
            {"missing_report": True},
            {"events": []},
            {"raw_report": b'{"type":'.hex()},
            {"raw_report": b'\xff'.hex()},
            {"events": [{"type": []}]},
        ):
            with self.subTest(request=request):
                code, result = self.run_child(**request)
                self.assertEqual(code, 2)
                self.assertEqual(result["flutter_exit_code"], 0)
                self.assertFalse(result["test_completion"]["stream_valid"])

    def test_duplicate_or_nonterminal_done_is_rejected(self):
        for extra in ({"type": "done", "time": 5, "success": True}, {"type": "print", "time": 5}):
            with self.subTest(extra=extra):
                code, result = self.run_child(events=[*self.complete_events(), extra])
                self.assertEqual(code, 2)
                self.assertFalse(result["test_completion"]["stream_valid"])

    def test_nonzero_child_exit_is_preserved_for_incomplete_report(self):
        code, result = self.run_child(exit=7, events=self.complete_events()[:-1])
        self.assertEqual(code, 7)
        self.assertEqual(result["flutter_returncode"], 7)
        self.assertFalse(result["test_run_complete"])

    def test_child_signal_is_preserved_even_with_a_successful_report(self):
        code, result = self.run_child(signal=15)
        self.assertEqual(code, 143)
        self.assertEqual(result["flutter_returncode"], -15)
        self.assertEqual(result["flutter_exit_code"], 143)

    def test_wrapper_interrupt_cannot_pass(self):
        actual_run = subprocess.run

        def interrupt_child(command, *args, **kwargs):
            if command[0] == str(self.child):
                raise KeyboardInterrupt
            return actual_run(command, *args, **kwargs)

        with patch.object(runner.subprocess, "run", side_effect=interrupt_child), patch("sys.stderr"):
            code = runner.run_tests(self.root, self.child, [], self.report)
        result = json.loads(self.report.read_text())
        self.assertEqual(code, 130)
        self.assertTrue(result["flutter_interrupted"])
        self.assertFalse(result["test_run_successful"])

    def test_caller_cannot_replace_the_private_completion_reporter(self):
        for arguments in (["--file-reporter", "json:other.json"], ["--file-reporter=json:other.json"]):
            with self.subTest(arguments=arguments), patch("sys.stderr"):
                code = runner.run_tests(self.root, self.child, arguments, self.report)
                result = json.loads(self.report.read_text())
                self.assertEqual(code, 2)
                self.assertIn("wrapper manages --file-reporter", result["preflight_error"])
                self.assertFalse((self.root / "observed.json").exists())

    def test_report_preservation_failure_cannot_be_reported_as_success(self):
        with patch.object(runner, "preserve_test_report", side_effect=OSError("fixture disk full")):
            code, result = self.run_child()
        self.assertEqual(code, 2)
        self.assertEqual(result["flutter_exit_code"], 0)
        self.assertTrue(result["test_run_complete"])
        self.assertFalse(result["test_run_successful"])
        self.assertIn("fixture disk full", result["test_report_error"])

    def test_final_result_write_failure_reports_the_actual_wrapper_exit(self):
        actual_write = Path.write_text

        def fail_result_write(path, *args, **kwargs):
            if path == self.report:
                raise OSError("fixture final result disk full")
            return actual_write(path, *args, **kwargs)

        for child_exit, expected_exit in ((0, 2), (7, 7)):
            with self.subTest(child_exit=child_exit), patch.object(Path, "write_text", new=fail_result_write), patch("sys.stderr", new_callable=io.StringIO) as output:
                code = runner.run_tests(self.root, self.child, [json.dumps({"exit": child_exit})], self.report)
            result = json.loads(output.getvalue().splitlines()[-1])
            self.assertEqual(code, expected_exit)
            self.assertEqual(result["wrapper_exit_code"], code)
            self.assertEqual(result["flutter_exit_code"], child_exit)
            self.assertIn("fixture final result disk full", result["result_recording_error"])
            self.assertTrue(Path(result["test_report"]["path"]).is_file())
            self.assertFalse(self.report.exists())

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
