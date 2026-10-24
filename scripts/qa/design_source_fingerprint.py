#!/usr/bin/env python3
"""Bind current Mobio UI sources for the external review gallery."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIRECTORIES = (
    "lib/",
    "packages/",
    "assets/",
    "icon/",
    "landing/",
    "web/",
    "android/app/src/",
    "ios/Runner/",
    "apps/momobio_sms_bridge/app/src/",
    "tool/",
)
CONFIG_FILES = frozenset({
    "pubspec.yaml", "pubspec.lock", ".flutter-version",
    "android/app/build.gradle.kts", "android/app/proguard-rules.pro",
    "android/build.gradle.kts", "android/settings.gradle.kts",
    "ios/Runner.xcodeproj/project.pbxproj",
    "apps/momobio_sms_bridge/app/build.gradle.kts",
    "apps/momobio_sms_bridge/build.gradle.kts",
    "apps/momobio_sms_bridge/settings.gradle.kts",
})
EXCLUDED_PARTS = frozenset({
    ".git", ".dart_tool", ".gradle", ".cache", ".symlinks", ".venv",
    "build", "Pods", "node_modules", "__pycache__", "test", "androidTest",
    "testFixtures",
})
SECRET_SUFFIXES = frozenset({".jks", ".keystore", ".key", ".pem", ".p12", ".p8"})
SECRET_NAMES = frozenset({
    "key.properties", "google-services.json", "googleservice-info.plist",
    "credentials.json", "secrets.json",
})


def source_path(relative: str) -> bool:
    path = PurePosixPath(relative)
    name = path.name.lower()
    if not (relative in CONFIG_FILES or relative.startswith(SOURCE_DIRECTORIES)):
        return False
    if any(part in EXCLUDED_PARTS for part in path.parts):
        return False
    if name.startswith(".env") or name in SECRET_NAMES or path.suffix.lower() in SECRET_SUFFIXES:
        return False
    if "service-account" in name or "service_account" in name:
        return False
    if "generatedpluginregistrant" in name:
        return False
    return path.suffix.lower() not in {".md", ".log", ".pyc"}


def source_records(root: Path) -> list[dict[str, str]]:
    """Read the canonical Git-indexed UI set without including private material."""
    root = root.resolve()
    result = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        check=True, capture_output=True,
    )
    paths = sorted({
        value.decode("utf-8") for value in result.stdout.split(b"\0")
        if value and source_path(value.decode("utf-8"))
    })
    records = []
    for relative in paths:
        path = root / relative
        if not path.is_file():
            continue
        if not path.resolve().is_relative_to(root):
            raise ValueError(f"UI source leaves project root: {relative}")
        records.append({"path": relative, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
    if not records:
        raise ValueError("No indexed product UI source is available")
    return records


def fingerprint(root: Path, *, records: list[dict[str, str]] | None = None) -> dict:
    records = source_records(root) if records is None else records
    digest = hashlib.sha256(
        "".join(f"{record['path']}\0{record['sha256']}\n" for record in records).encode("utf-8")
    ).hexdigest()
    return {
        "schema_version": 1,
        "product": "Mobio",
        "source_sha256": digest,
        "file_count": len(records),
        "scope": list(SOURCE_DIRECTORIES),
        "selection": "tracked and nonignored untracked UI sources; known secrets, documentation, tests and generated build output excluded",
        "acceptance_effect": "none",
    }


def source_manifest(root: Path) -> dict:
    """Export ordered file hashes for synchronous, child-process-free captures."""
    root = root.resolve()
    records = source_records(root)
    return {
        **fingerprint(root, records=records),
        "project_root": str(root),
        "config_files": sorted(CONFIG_FILES),
        "files": records,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=ROOT)
    parser.add_argument("--manifest-out", type=Path, help="Also write the canonical ordered file/hash manifest.")
    args = parser.parse_args()
    if args.manifest_out:
        manifest = source_manifest(args.project_root)
        with args.manifest_out.open("w", encoding="utf-8") as output:
            json.dump(manifest, output, sort_keys=True)
            output.write("\n")
        summary = {key: value for key, value in manifest.items() if key not in {"project_root", "config_files", "files"}}
    else:
        summary = fingerprint(args.project_root)
    print(json.dumps(summary, sort_keys=True))


if __name__ == "__main__":
    main()
