#!/usr/bin/env python3
"""Exercise the shipped Flutter verification entry point with local tool fakes.

The capture comparator exports review images without comparing baselines.
These tests verify that this mode cannot silently turn CI verification green;
they do not execute Flutter, accept images, or change the capture pipeline.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class VerifyFlutterCaptureModeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.trace = self.root / "tool-events.log"
        ci = self.root / "scripts/ci"
        library = self.root / "scripts/lib"
        bin_directory = self.root / "fake-bin"
        for directory in (ci, library, bin_directory):
            directory.mkdir(parents=True)
        self.script = ci / "verify_flutter.sh"
        shutil.copyfile(ROOT / "scripts/ci/verify_flutter.sh", self.script)
        # Keep actual SDK selection, and observe whether the source was reached.
        (library / "flutter.sh").write_text(
            'printf "%s\\n" "sdk-discovery" >> "$MOBIO_VERIFY_FIXTURE_TRACE"\n'
            + (ROOT / "scripts/lib/flutter.sh").read_text()
        )
        self.write_executable(
            ci / "bootstrap_flutter.sh",
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'printf "%s\\n" "bootstrap" >> "$MOBIO_VERIFY_FIXTURE_TRACE"\n',
        )
        self.write_executable(
            bin_directory / "python3",
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'printf "python:%s\\n" "$*" >> "$MOBIO_VERIFY_FIXTURE_TRACE"\n',
        )
        self.flutter = bin_directory / "flutter"
        self.write_executable(
            self.flutter,
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'printf "flutter:%s\\n" "$*" >> "$MOBIO_VERIFY_FIXTURE_TRACE"\n'
            'if [[ "$1" == "test" ]]; then\n'
            '  exit "${MOBIO_VERIFY_FIXTURE_TEST_EXIT:-0}"\n'
            'fi\n'
            'if [[ "$1" == "analyze" ]]; then\n'
            '  exit "${MOBIO_VERIFY_FIXTURE_ANALYZE_EXIT:-0}"\n'
            'fi\n',
        )
        # Avoid ambient capture, credentials and workstation tool configuration.
        self.env = {
            "PATH": str(bin_directory) + os.pathsep + os.defpath,
            "FLUTTER_BIN": str(self.flutter),
            "MOBIO_VERIFY_FIXTURE_TRACE": str(self.trace),
        }
        self.pipeline = [
            "sdk-discovery",
            "bootstrap",
            "python:scripts/ci/check_repository_structure.py",
            "python:scripts/ci/check_design_authority.py",
            "python:-m unittest discover -s scripts/tests -v",
            "flutter:analyze --no-pub",
            "flutter:test --coverage",
        ]

    @staticmethod
    def write_executable(path, source):
        path.write_text(source)
        path.chmod(0o755)

    def run_verification(self):
        result = subprocess.run(
            ["bash", str(self.script)],
            cwd=self.root,
            env=self.env,
            text=True,
            capture_output=True,
            timeout=10,
            check=False,
        )
        events = self.trace.read_text().splitlines() if self.trace.exists() else []
        return result, events

    def assert_capture_rejected(self, capture_value):
        self.env["MOBIO_CAPTURE_DIR"] = capture_value
        result, events = self.run_verification()
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("MOBIO_CAPTURE_DIR", result.stderr)
        self.assertIn("review image export only", result.stderr)
        self.assertIn("Unset MOBIO_CAPTURE_DIR", result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(events, [], "Verification dispatched tools in capture mode")

    def test_unset_capture_runs_ordinary_pipeline(self):
        result, events = self.run_verification()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(events, self.pipeline)

    def test_empty_capture_runs_ordinary_pipeline(self):
        self.env["MOBIO_CAPTURE_DIR"] = ""
        result, events = self.run_verification()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(events, self.pipeline)

    def test_capture_directory_rejected_before_tools(self):
        capture = self.root / "review-images"
        self.assert_capture_rejected(str(capture))
        self.assertFalse(capture.exists())

    def test_whitespace_capture_rejected_before_tools(self):
        self.assert_capture_rejected(" \t ")

    def test_newline_capture_rejected_before_tools(self):
        self.assert_capture_rejected("\n")

    def test_zero_string_capture_rejected_before_tools(self):
        self.assert_capture_rejected("0")

    def test_capture_rejection_precedes_unavailable_sdk(self):
        self.env["FLUTTER_BIN"] = str(self.root / "missing-sdk/flutter")
        self.assert_capture_rejected(str(self.root / "review-images"))

    def test_flutter_test_failure_exit_is_preserved(self):
        self.env["MOBIO_VERIFY_FIXTURE_TEST_EXIT"] = "23"
        result, events = self.run_verification()
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertEqual(events, self.pipeline)

    def test_analysis_failure_stops_before_flutter_tests(self):
        self.env["MOBIO_VERIFY_FIXTURE_ANALYZE_EXIT"] = "19"
        result, events = self.run_verification()
        self.assertEqual(result.returncode, 19, result.stderr)
        self.assertEqual(events, self.pipeline[:-1])


if __name__ == "__main__":
    unittest.main()
