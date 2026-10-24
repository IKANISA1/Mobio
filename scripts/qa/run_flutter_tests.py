#!/usr/bin/env python3
"""Run configured Flutter tests with canonical UI-source binding outside the engine."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid

from design_source_fingerprint import ROOT, source_manifest


def test_completion(report_path: Path) -> dict:
    """Require the JSON reporter's complete, successful terminal state."""
    errors = []
    started = set()
    completed = set()
    event_count = error_count = failed_count = start_count = suite_count = done_count = 0
    done_success = None
    known_events = {"start", "allSuites", "suite", "debug", "group", "testStart", "testDone", "print", "error", "done"}
    try:
        with report_path.open(encoding="utf-8") as report:
            for line_number, line in enumerate(report, 1):
                if not line.strip():
                    continue
                try:
                    event = json.loads(line)
                except ValueError:
                    errors.append(f"Malformed JSON at line {line_number}")
                    continue
                event_count += 1
                if not isinstance(event, dict) or not isinstance(event.get("type"), str) or event["type"] not in known_events:
                    errors.append(f"Invalid reporter event at line {line_number}")
                    continue
                kind = event["type"]
                if done_count:
                    errors.append(f"Event after terminal done at line {line_number}")
                if type(event.get("time")) is not int or event["time"] < 0:
                    errors.append(f"Invalid event time at line {line_number}")
                if event_count == 1 and kind != "start":
                    errors.append("The first reporter event is not start")
                if kind == "start":
                    start_count += 1
                elif kind == "allSuites":
                    suite_count += 1
                    if type(event.get("count")) is not int or event["count"] < 0:
                        errors.append(f"Invalid suite count at line {line_number}")
                elif kind == "testStart":
                    test = event.get("test")
                    test_id = test.get("id") if isinstance(test, dict) else None
                    if type(test_id) is not int or test_id < 0 or test_id in started:
                        errors.append(f"Invalid or duplicate testStart at line {line_number}")
                    else:
                        started.add(test_id)
                elif kind == "testDone":
                    test_id = event.get("testID")
                    if type(test_id) is not int or test_id not in started or test_id in completed:
                        errors.append(f"Unmatched or duplicate testDone at line {line_number}")
                    else:
                        completed.add(test_id)
                    if event.get("result") not in ("success", "failure", "error"):
                        errors.append(f"Invalid test result at line {line_number}")
                    elif event["result"] != "success":
                        failed_count += 1
                    if type(event.get("hidden")) is not bool or type(event.get("skipped")) is not bool:
                        errors.append(f"Invalid test completion flags at line {line_number}")
                elif kind == "error":
                    # Errors may arrive after a successful testDone event.
                    error_count += 1
                elif kind == "done":
                    done_count += 1
                    done_success = event.get("success")
                    if "success" not in event or (done_success is not None and type(done_success) is not bool):
                        errors.append(f"Invalid terminal success at line {line_number}")
    except (OSError, UnicodeError) as error:
        errors.append(f"Cannot read Flutter JSON reporter: {error}")
    if start_count != 1:
        errors.append("Expected exactly one start event")
    if suite_count != 1:
        errors.append("Expected exactly one allSuites event")
    if done_count != 1:
        errors.append("Expected exactly one terminal done event")
    if not started:
        errors.append("No testStart events were recorded")
    unfinished = sorted(started - completed)
    if unfinished:
        errors.append("Some started tests did not complete")
    complete = not errors and done_success is not None
    return {
        "stream_valid": not errors,
        "complete": complete,
        "successful": complete and done_success is True and error_count == 0 and failed_count == 0,
        "done_success": done_success,
        "event_count": event_count,
        "started_test_count": len(started),
        "completed_test_count": len(completed),
        "error_event_count": error_count,
        "failed_test_count": failed_count,
        "unfinished_test_ids": unfinished,
        "validation_errors": errors,
    }


def preserve_test_report(report_path: Path, result_path: Path) -> dict:
    """Retain raw reporter bytes without overwriting evidence from another run."""
    result_path.parent.mkdir(parents=True, exist_ok=True)
    destination = result_path.with_name(f"{result_path.stem}.flutter-events-{uuid.uuid4().hex}.jsonl")
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    checksum = hashlib.sha256()
    size = 0
    with os.fdopen(descriptor, "wb") as output, report_path.open("rb") as report:
        while block := report.read(1024 * 1024):
            output.write(block)
            checksum.update(block)
            size += len(block)
    return {"path": str(destination), "sha256": checksum.hexdigest(), "bytes": size}


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
        "flutter_interrupted": False,
        "test_run_complete": False,
        "test_run_successful": False,
    }
    exit_code = 2
    try:
        if not flutter_bin.is_absolute() or not flutter_bin.is_file() or not os.access(flutter_bin, os.X_OK):
            raise ValueError("Set FLUTTER_BIN or --flutter-bin to the absolute configured Flutter executable.")
        if any(value == "--file-reporter" or value.startswith("--file-reporter=") for value in test_args):
            raise ValueError("The wrapper manages --file-reporter; use --reporter for console output.")
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
            test_report_path = Path(private_directory) / "flutter-events.jsonl"
            descriptor = os.open(test_report_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            os.close(descriptor)
            environment = {**os.environ, "MOBIO_UI_SOURCE_MANIFEST": str(manifest_path)}
            try:
                child = subprocess.run(
                    [str(flutter_bin), "test", f"--file-reporter=json:{test_report_path}", *test_args],
                    cwd=root, env=environment, check=False,
                )
                child_code = child.returncode
            except KeyboardInterrupt:
                result["flutter_interrupted"] = True
                child_code = 130
            except OSError as error:
                result["flutter_error"] = str(error)
                child_code = 127
            result["flutter_returncode"] = child_code
            child_exit = child_code if child_code >= 0 else 128 - child_code
            result["flutter_exit_code"] = child_exit
            try:
                result["test_report"] = preserve_test_report(test_report_path, result_path)
                completion_path = Path(result["test_report"]["path"])
            except OSError as error:
                result["test_report_error"] = str(error)
                completion_path = test_report_path
            # Validate the retained snapshot, so its digest identifies exactly
            # the stream used for the completion decision.
            completion = test_completion(completion_path)
            result["test_completion"] = completion
            result["test_run_complete"] = completion["complete"]
            result["test_run_successful"] = (
                completion["successful"] and not result["flutter_interrupted"] and "test_report" in result
            )
            try:
                after = source_manifest(root)
                result["source_after"] = {key: value for key, value in after.items() if key != "files"}
                result["source_changes"] = changed_sources(before, after)
                unchanged = before["files"] == after["files"]
                result["source_unchanged_during_test"] = unchanged
            except (OSError, ValueError, subprocess.SubprocessError) as error:
                unchanged = False
                result["source_verification_error"] = str(error)
            # Child exit zero alone does not prove completion: interruption or
            # engine errors can leave a truncated stream while Flutter exits 0.
            # Preserve an actual nonzero child exit ahead of evidence failures.
            passed = unchanged and result["test_run_successful"]
            exit_code = child_exit if child_exit != 0 else (0 if passed else 2)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        result["preflight_error"] = str(error)
    result["wrapper_exit_code"] = exit_code
    try:
        result_path.parent.mkdir(parents=True, exist_ok=True)
        result_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    except OSError as error:
        result["result_recording_error"] = str(error)
        print(f"Cannot record UI source verification: {error}", file=sys.stderr)
        if exit_code == 0:
            exit_code = 2
        result["wrapper_exit_code"] = exit_code
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
