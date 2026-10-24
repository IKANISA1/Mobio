#!/usr/bin/env python3
"""Run configured Flutter tests with canonical UI-source binding outside the engine."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid

from design_source_fingerprint import ROOT, source_manifest


def changed_sources(before: dict, after: dict) -> dict[str, list[str]]:
    old = {record["path"]: record["sha256"] for record in before["files"]}
    new = {record["path"]: record["sha256"] for record in after["files"]}
    return {
        "added": sorted(new.keys() - old.keys()),
        "removed": sorted(old.keys() - new.keys()),
        "modified": sorted(path for path in old.keys() & new.keys() if old[path] != new[path]),
    }


def run_tests(root: Path, flutter_bin: Path, test_args: list[str], result_path: Path) -> int:
    root = root.resolve()
    result = {
        "schema_version": 1,
        "product": "Mobio",
        "acceptance_effect": "none",
        "source_unchanged_during_test": False,
        "flutter_returncode": None,
        "flutter_exit_code": None,
    }
    exit_code = 2
    try:
        if not flutter_bin.is_absolute() or not flutter_bin.is_file() or not os.access(flutter_bin, os.X_OK):
            raise ValueError("Set FLUTTER_BIN or --flutter-bin to the absolute configured Flutter executable.")
        before = source_manifest(root)
        result["source_before"] = {key: value for key, value in before.items() if key != "files"}
        # The manifest is readable only to this user and removed after the child
        # ends. Capture tests never need to spawn Python or Git inside the engine.
        with tempfile.TemporaryDirectory(prefix="mobio-ui-source-") as private_directory:
            manifest_path = Path(private_directory) / "manifest.json"
            descriptor = os.open(manifest_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(descriptor, "w", encoding="utf-8") as manifest_file:
                json.dump(before, manifest_file, sort_keys=True)
                manifest_file.write("\n")
            environment = {**os.environ, "MOBIO_UI_SOURCE_MANIFEST": str(manifest_path)}
            try:
                child = subprocess.run([str(flutter_bin), "test", *test_args], cwd=root, env=environment, check=False)
                child_code = child.returncode
            except KeyboardInterrupt:
                child_code = 130
            except OSError as error:
                result["flutter_error"] = str(error)
                child_code = 127
            result["flutter_returncode"] = child_code
            child_exit = child_code if child_code >= 0 else 128 - child_code
            result["flutter_exit_code"] = child_exit
            try:
                after = source_manifest(root)
                result["source_after"] = {key: value for key, value in after.items() if key != "files"}
                result["source_changes"] = changed_sources(before, after)
                unchanged = before["files"] == after["files"]
                result["source_unchanged_during_test"] = unchanged
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                unchanged = False
                result["source_verification_error"] = str(error)
            # A failed test retains its actual exit. A passing test with changed
            # sources fails separately, and the report always records both facts.
            exit_code = child_exit if child_exit != 0 else (0 if unchanged else 2)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        result["preflight_error"] = str(error)
    result["wrapper_exit_code"] = exit_code
    try:
        result_path.parent.mkdir(parents=True, exist_ok=True)
        result_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    except OSError as error:
        print(f"Cannot record UI source verification: {error}", file=sys.stderr)
        if exit_code == 0:
            exit_code = 2
    print(f"UI source verification report: {result_path}", file=sys.stderr)
    print(json.dumps(result, sort_keys=True), file=sys.stderr)
    return exit_code


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=ROOT)
    parser.add_argument("--flutter-bin", type=Path, default=os.environ.get("FLUTTER_BIN"))
    parser.add_argument("--source-result", type=Path, help="Write combined child-exit and source-stability evidence here.")
    parser.add_argument("test_args", nargs=argparse.REMAINDER, help="Flutter test arguments following --.")
    args = parser.parse_args()
    if args.flutter_bin is None:
        parser.error("Set FLUTTER_BIN or pass --flutter-bin with the absolute configured Flutter executable.")
    root = args.project_root.resolve()
    result_path = args.source_result or root / "build/qa/flutter-test-source" / f"{uuid.uuid4().hex}.json"
    if not result_path.is_absolute():
        result_path = root / result_path
    test_args = args.test_args[1:] if args.test_args[:1] == ["--"] else args.test_args
    return run_tests(root, args.flutter_bin, test_args, result_path)


if __name__ == "__main__":
    raise SystemExit(main())
