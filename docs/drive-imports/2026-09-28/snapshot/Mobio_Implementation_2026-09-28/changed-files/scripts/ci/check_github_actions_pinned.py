#!/usr/bin/env python3
"""Validate actual YAML uses values; do not confuse run-block text with actions."""
from __future__ import annotations
import argparse
from pathlib import Path
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("UNAVAILABLE: install scripts/ci/requirements.txt before checking action pins")

class UniqueKeyLoader(yaml.SafeLoader):
    def construct_mapping(self, node, deep=False):
        self.flatten_mapping(node)
        keys = set()
        for key_node, _ in node.value:
            key = self.construct_object(key_node, deep=deep)
            try:
                if key in keys:
                    raise ValueError(f"Duplicate YAML key: {key!r}")
                keys.add(key)
            except TypeError as exc:
                raise ValueError("YAML mapping keys must be scalar") from exc
        return super().construct_mapping(node, deep=deep)

REMOTE = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:/[A-Za-z0-9_.-]+)*@[0-9a-fA-F]{40}\Z")
DOCKER = re.compile(r"docker://[A-Za-z0-9._:/-]+@sha256:[0-9a-f]{64}\Z")
WORKFLOW = re.compile(r"\./\.github/workflows/[A-Za-z0-9_-][A-Za-z0-9_.-]*\.ya?ml\Z")

def check_reference(root: Path, value: object, job_call: bool = False) -> str | None:
    if not isinstance(value, str) or not value or value.strip() != value:
        return "uses must be one literal nonempty string"
    if "${{" in value:
        return "dynamic uses references are not accepted"
    if job_call and value.startswith("$/"):
        value = "./" + value[2:]
    if value.startswith("./"):
        if job_call and not WORKFLOW.fullmatch(value):
            return "local reusable workflows must be directly inside .github/workflows"
        parts = value[2:].split("/")
        if any(part in ("", ".", "..") for part in parts) or "@" in value or "\\" in value:
            return "invalid local action/workflow path"
        current = root
        for part in parts:
            current = current / part
            if current.is_symlink():
                return "symlinked local references are not accepted"
        if not current.exists():
            return "local reference does not exist"
        if job_call:
            return None if current.is_file() else "local workflow must be a regular file"
        if not current.is_dir():
            return "local action must be a directory with action.yml or action.yaml"
        if not any((current / name).is_file() and not (current / name).is_symlink()
                   for name in ("action.yml", "action.yaml")):
            return "local action metadata is missing or symlinked"
        return None
    if not job_call and DOCKER.fullmatch(value):
        return None
    if not REMOTE.fullmatch(value):
        return "remote uses must be pinned to a full 40-hex commit SHA (Docker: sha256 digest)"
    if any(part in (".", "..") for part in value.split("@", 1)[0].split("/")):
        return "invalid remote action path"
    if job_call and not re.fullmatch(
        r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/\.github/workflows/[A-Za-z0-9_.-]+\.ya?ml@[0-9a-fA-F]{40}", value
    ):
        return "remote reusable workflow must name .github/workflows/<file> at a full SHA"
    return None

def validate(root: Path) -> list[str]:
    folder = root / ".github/workflows"
    if (root / ".github").is_symlink() or folder.is_symlink() or not folder.is_dir():
        return ["workflow directory is missing or symlinked"]
    files = sorted([*folder.glob("*.yml"), *folder.glob("*.yaml")])
    if not files:
        return ["no workflow files found"]
    errors: list[str] = []
    for path in files:
        label = path.relative_to(root).as_posix()
        try:
            if path.is_symlink() or path.stat().st_size > 1_000_000:
                raise ValueError("workflow is symlinked or exceeds the review size limit")
            data = yaml.load(path.read_text(encoding="utf-8"), Loader=UniqueKeyLoader)
            if not isinstance(data, dict) or not isinstance(data.get("jobs"), dict) or not data["jobs"]:
                raise ValueError("workflow must contain a nonempty jobs mapping")
            for job_id, job in data["jobs"].items():
                if not isinstance(job, dict):
                    raise ValueError(f"job {job_id} must be a mapping")
                if "uses" in job:
                    error = check_reference(root, job["uses"], job_call=True)
                    if error:
                        errors.append(f"{label}: job {job_id}: {error}")
                steps = job.get("steps", [])
                if not isinstance(steps, list):
                    raise ValueError(f"job {job_id}: steps must be a list")
                for i, step in enumerate(steps, 1):
                    if not isinstance(step, dict):
                        raise ValueError(f"job {job_id}: step {i} must be a mapping")
                    if "uses" in step:
                        error = check_reference(root, step["uses"])
                        if error:
                            errors.append(f"{label}: job {job_id}: step {i}: {error}")
        except (OSError, UnicodeError, ValueError, yaml.YAMLError) as exc:
            errors.append(f"{label}: {exc}")
    return errors

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    errors = validate(args.root.resolve())
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print("NO-GO: GitHub Actions pin validation failed", file=sys.stderr)
        return 1
    print("github-actions pin check passed")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
