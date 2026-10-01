"""Offline run indexing preserves review status and rejects incomplete evidence."""
from __future__ import annotations

import csv
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1] / "qa/index_flutter_golden_failures.py"
SPEC = importlib.util.spec_from_file_location("golden_failure_index", SOURCE)
assert SPEC and SPEC.loader
index = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(index)


class GoldenIndexTests(unittest.TestCase):
    def setUp(self):
        scratch = tempfile.TemporaryDirectory()
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name).resolve()
        self.owner = self.root / "test/features/example/visual_test.dart"
        self.owner.parent.mkdir(parents=True)
        self.owner.write_text("// fixture\n")
        self.log = self.root / "run.log"
        self.manifest = self.root / "source.json"
        self.files = []

    def baseline(self, golden="goldens/page_390x844.png"):
        path = self.owner.parent / golden
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"synthetic baseline " + golden.encode())
        self.files.append({"file": path.relative_to(self.root).as_posix(),
                           "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
        return path

    def exception(self, golden="goldens/page_390x844.png", name="page", *, wrapped=False,
                  owner=None, stack_owner=None, interleaved=False):
        owner = owner or self.owner
        stack_owner = stack_owner or owner
        pct = "Pixel test failed,\n 5.50%,\n 30px diff\ndetected." if wrapped else "Pixel test failed, 5.50%, 30px diff detected."
        other = f"00:01 +4 -1: {owner.parent}/unrelated_test.dart: unrelated pass\n" if interleaved else ""
        return ("══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════\n"
                f'Golden "{golden}": {pct}\n'
                f"#1 callback ({stack_owner.as_uri()}:10:7)\n"
                + "═" * 30 + "\n" + other
                + f"00:01 +4 -1: {owner}: {name} [E]\n")

    def record(self, body=None, *, failed=1, terminal=True):
        self.log.write_text((body if body is not None else self.exception())
                            + (f"00:02 +4 -{failed}: Some tests failed.\n" if terminal else ""))
        self.manifest.write_text(json.dumps({"head": "a" * 40, "files": self.files,
                                             "recorded_at_utc": "2026-09-30T19:55:00Z"}))

    def parse(self):
        return index.build_index(self.root, self.log, self.manifest)

    def command(self, tsv, metadata, *, log=None, manifest=None):
        return [sys.executable, str(SOURCE), "--root", str(self.root),
                "--log", str(log or self.log), "--source-manifest", str(manifest or self.manifest),
                "--tsv", str(tsv), "--json", str(metadata)]

    def test_wrapped_diagnostic_with_interleaved_progress(self):
        baseline = self.baseline()
        self.record(self.exception(wrapped=True, interleaved=True))
        result = self.parse()
        self.assertEqual((result["passed"], result["failed"]), (4, 1))
        self.assertEqual(result["recorded_source_head"], "a" * 40)
        self.assertEqual(result["log_sha256"], hashlib.sha256(self.log.read_bytes()).hexdigest())
        self.assertFalse(result["accepted"])
        row = result["failures"][0]
        self.assertEqual(row["baseline_sha256"], hashlib.sha256(baseline.read_bytes()).hexdigest())
        self.assertEqual(row["review_status"], "unclassified_pending_visual_review")
        self.assertEqual(row["image_evidence_status"], "unavailable")

    def test_images_are_present_without_run_provenance(self):
        self.baseline()
        for role in index.IMAGE_ROLES:
            image = self.owner.parent / "failures" / f"page_390x844_{role}.png"
            image.parent.mkdir(exist_ok=True)
            image.write_bytes(b"retained historical image")
        self.record()
        row = self.parse()["failures"][0]
        self.assertEqual(row["image_evidence_status"], "present_unverified_run")
        self.assertTrue(all(v["status"] == "present_unverified_run" for v in row["images"].values()))

    def test_manifest_digest_binds_the_same_snapshot_as_recorded_head(self):
        baseline = self.baseline()
        self.record()
        original = self.manifest.read_bytes()
        actual_digest = index.digest

        def replace_manifest_after_parsing(path):
            if path == baseline:
                self.manifest.write_text(json.dumps({"head": "b" * 40, "files": []}))
            return actual_digest(path)

        with patch.object(index, "digest", side_effect=replace_manifest_after_parsing):
            result = self.parse()
        self.assertEqual(result["recorded_source_head"], "a" * 40)
        self.assertEqual(result["source_manifest_sha256"], hashlib.sha256(original).hexdigest())
        self.assertNotEqual(result["source_manifest_sha256"], hashlib.sha256(self.manifest.read_bytes()).hexdigest())

    def test_light_and_dark_basename_collision_is_ambiguous(self):
        self.baseline()
        self.baseline("goldens/light/page_390x844.png")
        for role in index.IMAGE_ROLES:
            image = self.owner.parent / "failures" / f"page_390x844_{role}.png"
            image.parent.mkdir(exist_ok=True)
            image.write_bytes(b"shared name cannot prove which test")
        self.record(self.exception(name="dark") + self.exception("goldens/light/page_390x844.png", "light"), failed=2)
        rows = self.parse()["failures"]
        self.assertEqual(len(rows), 2)
        self.assertTrue(all(r["image_evidence_status"] == "ambiguous_basename_collision" for r in rows))

    def test_truncated_terminal_is_rejected(self):
        self.baseline()
        self.record(terminal=False)
        with self.assertRaises(ValueError):
            self.parse()

    def test_truncated_exception_block_is_rejected(self):
        self.baseline()
        self.record(self.exception().replace("═" * 30 + "\n", ""))
        with self.assertRaises(ValueError):
            self.parse()

    def test_nonvisual_failed_case_is_rejected(self):
        self.baseline()
        self.record(self.exception() + f"00:01 +4 -2: {self.owner}: functional failure [E]\n", failed=2)
        with self.assertRaises(ValueError):
            self.parse()

    def test_duplicate_baseline_is_rejected(self):
        self.baseline()
        self.record(self.exception(name="first") + self.exception(name="second"), failed=2)
        with self.assertRaises(ValueError):
            self.parse()

    def test_duplicate_failed_case_is_rejected(self):
        self.baseline()
        self.baseline("goldens/other.png")
        self.record(self.exception() + self.exception("goldens/other.png"), failed=2)
        with self.assertRaises(ValueError):
            self.parse()

    def test_count_mismatch_is_rejected(self):
        self.baseline()
        self.record(failed=2)
        with self.assertRaises(ValueError):
            self.parse()

    def test_stack_owner_cannot_be_misattributed_by_progress(self):
        self.baseline()
        second = self.owner.parent / "other_test.dart"
        second.write_text("// other test")
        self.record(self.exception(stack_owner=second))
        with self.assertRaises(ValueError):
            self.parse()

    def test_missing_or_changed_baseline_is_rejected(self):
        baseline = self.baseline()
        self.record()
        baseline.write_bytes(b"changed after source manifest")
        with self.assertRaises(ValueError):
            self.parse()
        baseline.unlink()
        with self.assertRaises(ValueError):
            self.parse()

    def test_path_escape_and_absolute_golden_are_rejected(self):
        self.baseline()
        for golden in ("goldens/../../../../outside.png", "/tmp/baseline.png", "goldens/./page_390x844.png"):
            with self.subTest(golden=golden):
                self.record(self.exception(golden))
                with self.assertRaises(ValueError):
                    self.parse()

    def test_symlink_baseline_is_rejected(self):
        baseline = self.baseline()
        self.record()
        outside = self.root / "outside.png"
        outside.write_bytes(baseline.read_bytes())
        baseline.unlink()
        baseline.symlink_to(outside)
        with self.assertRaises(ValueError):
            self.parse()

    def test_cli_writes_both_outputs_only_after_validation(self):
        self.baseline()
        self.record()
        tsv, metadata = self.root / "index.tsv", self.root / "index.json"
        command = self.command(tsv, metadata)
        positive = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(positive.returncode, 0, positive.stderr)
        self.assertIn("unclassified_pending_visual_review", tsv.read_text())
        with tsv.open() as handle:
            row, = csv.DictReader(handle, delimiter="\t")
        self.assertEqual(row["test_name"], "page")
        self.assertEqual(row["test_file"], self.owner.relative_to(self.root).as_posix())
        self.assertEqual(row["different_pixels"], "30")
        self.assertFalse(json.loads(metadata.read_text())["accepted"])
        saved = (tsv.read_bytes(), metadata.read_bytes())
        self.log.write_text(self.exception())
        negative = subprocess.run(command, capture_output=True, text=True)
        self.assertNotEqual(negative.returncode, 0)
        self.assertEqual(saved, (tsv.read_bytes(), metadata.read_bytes()))

    def test_cli_output_cannot_replace_either_input(self):
        self.baseline()
        self.record()
        for output_name, input_name in (("tsv", "log"), ("tsv", "manifest"),
                                       ("json", "log"), ("json", "manifest")):
            with self.subTest(output=output_name, input=input_name):
                suffix = ".tsv" if output_name == "tsv" else ".json"
                alias = self.root / f"input-{output_name}-{input_name}{suffix}"
                original = self.log if input_name == "log" else self.manifest
                alias.write_bytes(original.read_bytes())
                saved = alias.read_bytes()
                tsv = alias if output_name == "tsv" else self.root / "output.tsv"
                metadata = alias if output_name == "json" else self.root / "output.json"
                result = subprocess.run(self.command(
                    tsv, metadata, log=alias if input_name == "log" else self.log,
                    manifest=alias if input_name == "manifest" else self.manifest),
                    capture_output=True, text=True, timeout=10)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("cannot replace input evidence", result.stderr)
                self.assertEqual(alias.read_bytes(), saved)
                self.assertFalse((self.root / "output.tsv").exists())
                self.assertFalse((self.root / "output.json").exists())

    def test_cli_outputs_cannot_alias_each_other(self):
        self.baseline()
        self.record()
        tsv, metadata = self.root / "output.tsv", self.root / "output.json"
        tsv.write_text("existing index")
        metadata.symlink_to(tsv)
        result = subprocess.run(self.command(tsv, metadata), capture_output=True,
                                text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(tsv.read_text(), "existing index")
        self.assertTrue(metadata.is_symlink())

    def test_cli_stage_failure_does_not_replace_existing_index(self):
        self.baseline()
        self.record()
        tsv = self.root / "output.tsv"
        tsv.write_text("existing index")
        blocker = self.root / "not-a-directory"
        blocker.write_text("existing file")
        result = subprocess.run(self.command(tsv, blocker / "output.json"),
                                capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(tsv.read_text(), "existing index")
        self.assertEqual(blocker.read_text(), "existing file")
        self.assertEqual(list(self.root.glob(".output.tsv.*")), [])


if __name__ == "__main__":
    unittest.main()
