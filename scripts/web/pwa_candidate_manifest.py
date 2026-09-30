#!/usr/bin/env python3
"""Bind a prepared Pages site to source and a separate release approval.

Receipts describe independent observations; this verifier checks their exact
bindings, completeness and authenticated approval, not their factual truth.
Candidate creation and verification never contact a provider.
"""
from __future__ import annotations

import argparse
import base64
import binascii
from datetime import datetime, timedelta, timezone
import getpass
import hashlib
import hmac
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
ACTOR = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.@-]{2,99}\Z")
CHECKS = frozenset({
    "flutter_full", "backend_linked", "db_clean_replay", "db_forward_upgrade",
    "auth_postgrest_matrix", "mobio_feature_gate", "pwa_bundle", "pwa_browser",
    "privacy_security", "repository_protection", "drive_access", "release_operations",
})
REQUIRED_FILES = frozenset({
    "index.html", "__app_shell", "__admin_shell", "app-manifest.json",
    "admin-manifest.json", "main.dart.js", "flutter_bootstrap.js",
    "flutter_service_worker.js", "_worker.js", "_headers", "_redirects", "release.json",
})
MAX_FILES = 20000
MAX_FILE_BYTES = 256 * 1024 * 1024
MAX_TREE_BYTES = 1024 * 1024 * 1024
MAX_JSON_BYTES = 8 * 1024 * 1024
WRANGLER_VERSION = "4.135.0"


class ManifestError(ValueError):
    pass


def require(value: object, message: str) -> None:
    if not value:
        raise ManifestError(message)


def canonical(value: object) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=False, allow_nan=False).encode("utf-8")


def no_links(path: Path) -> Path:
    absolute = Path(os.path.abspath(path))
    for part in (absolute, *absolute.parents):
        try:
            require(not stat.S_ISLNK(part.lstat().st_mode), "Symlink path not allowed")
        except OSError as error:
            raise ManifestError("Required path missing or unavailable") from error
    return absolute


def read_regular(path: Path, limit: int = MAX_FILE_BYTES) -> bytes:
    path = no_links(path)
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(descriptor, "rb") as source:
            before = os.fstat(source.fileno())
            require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1,
                    "Single-link regular file required")
            require(before.st_size <= limit, "File exceeds size limit")
            data = source.read(limit + 1)
            after = os.fstat(source.fileno())
            current = path.lstat()
        require(len(data) <= limit and len(data) == before.st_size
                and (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns,
                     before.st_ctime_ns) ==
                (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns,
                 after.st_ctime_ns)
                and (current.st_dev, current.st_ino) == (before.st_dev, before.st_ino)
                and not stat.S_ISLNK(current.st_mode), "File changed while reading")
        return data
    except OSError as error:
        raise ManifestError("Required regular file unavailable") from error


def checksum(path: Path, limit: int = MAX_FILE_BYTES) -> str:
    return hashlib.sha256(read_regular(path, limit)).hexdigest()


def unique_pairs(pairs: list[tuple[str, object]]) -> dict:
    result = {}
    for key, value in pairs:
        require(key not in result, "Duplicate JSON key")
        result[key] = value
    return result


def json_file(path: Path) -> dict:
    try:
        value = json.loads(read_regular(path, MAX_JSON_BYTES), object_pairs_hook=unique_pairs,
                           parse_constant=lambda _: (_ for _ in ()).throw(ManifestError("Nonfinite JSON")))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ManifestError("Invalid JSON file") from error
    require(isinstance(value, dict), "JSON object required")
    return value


def tree_state(site: Path) -> dict:
    site = no_links(site)
    require(site.is_dir(), "Prepared site directory required")
    files = []
    total = 0
    directories = 0
    for directory, names, filenames in os.walk(site, followlinks=False):
        directories += 1
        require(directories <= MAX_FILES, "Too many directories")
        for name in sorted(names):
            child = no_links(Path(directory) / name)
            require(child.is_dir(), "Regular directory required")
        for name in sorted(filenames):
            path = Path(directory) / name
            relative = path.relative_to(site).as_posix()
            require("\\" not in relative and all(ord(c) >= 32 for c in relative),
                    "Unsafe site filename")
            data = read_regular(path)
            total += len(data)
            require(total <= MAX_TREE_BYTES and len(files) < MAX_FILES, "Site exceeds size limit")
            files.append({"file": relative, "bytes": len(data),
                          "sha256": hashlib.sha256(data).hexdigest()})
    files.sort(key=lambda row: row["file"])
    require(REQUIRED_FILES <= {row["file"] for row in files}, "Required PWA files missing")
    return {"sha256": hashlib.sha256(canonical(files)).hexdigest(),
            "bytes": total, "files": files}


def git(root: Path, *arguments: str) -> str:
    try:
        result = subprocess.run(["git", "-C", str(root), *arguments], text=True,
                                capture_output=True, timeout=15, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise ManifestError("Git source readback unavailable") from error
    require(result.returncode == 0, "Git source readback failed")
    return result.stdout.strip()


def source_state(root: Path, site: Path) -> dict:
    require(git(root, "status", "--porcelain", "--untracked-files=normal") == "",
            "Candidate source worktree must be clean")
    commit, tree = git(root, "rev-parse", "HEAD"), git(root, "rev-parse", "HEAD^{tree}")
    require(HEX40.fullmatch(commit) and HEX40.fullmatch(tree), "Invalid source identity")
    versions = re.findall(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+\+[1-9][0-9]*)\s*$",
                          read_regular(root / "pubspec.yaml", MAX_JSON_BYTES).decode(), re.M)
    require(len(versions) == 1, "Exactly one source version required")
    artifact = tree_state(site)
    release = json_file(site / "release.json")
    require(set(release) == {"release_id", "commit", "working_tree_dirty", "files",
                             "asset_version", "retained_asset_versions"}, "Invalid release stamp schema")
    require(release["commit"] == commit and release["working_tree_dirty"] is False,
            "Prepared site belongs to another or dirty source")
    require(isinstance(release["release_id"], str) and HEX64.fullmatch(release["release_id"])
            and isinstance(release["asset_version"], str) and HEX64.fullmatch(release["asset_version"]),
            "Invalid release/asset identity")
    retained = release["retained_asset_versions"]
    require(isinstance(retained, list) and len(retained) <= 1
            and all(isinstance(value, str) and HEX64.fullmatch(value) for value in retained),
            "Invalid retained asset cohort")
    expected_files = {row["file"]: row["sha256"] for row in artifact["files"]
                      if row["file"] != "release.json"}
    require(release["files"] == expected_files, "Prepared release inventory differs from actual files")
    worker = read_regular(root / "scripts/web/pages_worker.mjs", MAX_JSON_BYTES).decode()
    require(read_regular(site / "_worker.js", MAX_JSON_BYTES).decode() ==
            worker.replace("__MOBIO_RELEASE_ID__", release["release_id"]),
            "Packaged worker differs from source")
    require(read_regular(site / "flutter_service_worker.js", MAX_JSON_BYTES) ==
            read_regular(root / "scripts/web/admin_service_worker.js", MAX_JSON_BYTES),
            "Packaged service worker differs from source")
    require(site.name == "site", "Prepared combined site directory must be named site")
    # Direct CLI use must meet the existing product-specific bundle checks too.
    verifier = no_links(root / "scripts/web/verify_pwa_bundles.sh")
    checked = subprocess.run(["bash", str(verifier), str(site.parent)], cwd=root,
                             text=True, capture_output=True, timeout=60, check=False)
    require(checked.returncode == 0, "Prepared site failed the PWA bundle contract")
    return {"commit": commit, "tree": tree, "version": versions[0],
            "migration_manifest_sha256": checksum(root / "supabase/hardening/2026-09-28/manifest.json"),
            "model_policy_sha256": checksum(root / "services/face-inference/model-manifest.json"),
            "release_id": release["release_id"], "artifact": artifact}


def destination(account: str, project: str, branch: str, environment: str) -> dict:
    require(re.fullmatch(r"[0-9a-f]{32}", account), "Exact Cloudflare account ID required")
    require(re.fullmatch(r"[a-z0-9][a-z0-9-]{0,57}", project), "Invalid Pages project")
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,79}", branch), "Invalid Pages branch")
    require(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{2,79}", environment)
            and environment != "local-unverified", "Named reviewed environment required")
    return {"account": account, "project": project, "branch": branch, "environment": environment}


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def parsed_time(value: object, label: str) -> datetime:
    require(isinstance(value, str) and value.endswith("Z"), f"{label} must be UTC Z time")
    try:
        stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ManifestError(f"Invalid {label}") from error
    require(stamp.utcoffset() == timedelta(0), f"{label} must be UTC")
    return stamp


def create(root: Path, site: Path, output: Path, target: dict) -> None:
    actor = os.environ.get("GITHUB_ACTOR") or getpass.getuser()
    require(ACTOR.fullmatch(actor), "Named build actor required")
    record = {"schema_version": 1, "kind": "pwa_candidate",
              "created_at": utc_now().replace(microsecond=0).isoformat().replace("+00:00", "Z"),
              "build_actor": actor, "build_run_id": os.environ.get("GITHUB_RUN_ID", "local"),
              "destination": target, "source": source_state(root, site)}
    require(not output.exists() and not output.is_symlink(), "New candidate output required")
    output.parent.mkdir(parents=True, exist_ok=True)
    no_links(output.parent)
    with output.open("x", encoding="utf-8") as stream:
        stream.write(json.dumps(record, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": "CANDIDATE_RECORDED", "candidate_sha256": checksum(output),
                      "artifact_sha256": record["source"]["artifact"]["sha256"]}))


def approval_key() -> bytes:
    try:
        key = base64.b64decode(os.environ.get("MOBIO_PWA_RELEASE_APPROVAL_HMAC_KEY_B64", ""), validate=True)
    except (ValueError, binascii.Error) as error:
        raise ManifestError("PWA approval key unavailable") from error
    require(len(key) >= 32, "PWA approval key unavailable")
    return key


def verify(root: Path, site: Path, candidate_path: Path, approval_path: Path, target: dict) -> dict:
    require(not candidate_path.name.endswith(".example.json")
            and not approval_path.name.endswith(".example.json"), "Example release evidence is not eligible")
    candidate = json_file(candidate_path)
    require(set(candidate) == {"schema_version", "kind", "created_at", "build_actor", "build_run_id",
                              "destination", "source"} and type(candidate["schema_version"]) is int
            and candidate["schema_version"] == 1 and candidate["kind"] == "pwa_candidate",
            "Invalid candidate schema")
    require(isinstance(candidate["build_actor"], str) and ACTOR.fullmatch(candidate["build_actor"])
            and isinstance(candidate["build_run_id"], str) and candidate["build_run_id"],
            "Invalid build identity")
    now = utc_now()
    created = parsed_time(candidate["created_at"], "candidate time")
    require(now - timedelta(days=14) <= created <= now + timedelta(minutes=5), "Candidate is stale or future-dated")
    require(candidate["destination"] == target, "Candidate destination differs from requested destination")
    expected = source_state(root, site)
    require(candidate["source"] == expected, "Candidate differs from current source or artifact")
    candidate_sha = checksum(candidate_path, MAX_JSON_BYTES)
    approval = json_file(approval_path)
    require(set(approval) == {"schema_version", "candidate_sha256", "reviewer", "approved_at", "destination",
                             "checks", "signature_hmac_sha256"} and type(approval["schema_version"]) is int
            and approval["schema_version"] == 1, "Invalid approval schema")
    require(approval["candidate_sha256"] == candidate_sha, "Approval belongs to another candidate")
    require(approval["destination"] == target, "Approval destination differs from requested destination")
    reviewer = approval["reviewer"]
    require(isinstance(reviewer, str) and ACTOR.fullmatch(reviewer)
            and reviewer.casefold() != candidate["build_actor"].casefold(), "Independent named reviewer required")
    approved = parsed_time(approval["approved_at"], "approval time")
    require(created <= approved <= now + timedelta(minutes=5) and approved >= now - timedelta(days=7),
            "Approval is stale or predates candidate")
    signature = approval["signature_hmac_sha256"]
    require(isinstance(signature, str) and HEX64.fullmatch(signature), "Invalid approval signature")
    payload = {key: value for key, value in approval.items() if key != "signature_hmac_sha256"}
    require(hmac.compare_digest(signature, hmac.new(approval_key(), canonical(payload), hashlib.sha256).hexdigest()),
            "Approval signature mismatch")
    checks = approval["checks"]
    require(isinstance(checks, list) and len(checks) == len(CHECKS), "Required check receipts missing")
    found = set()
    for row in checks:
        require(isinstance(row, dict) and set(row) == {"id", "file", "sha256"}, "Invalid check pointer")
        check_id = row["id"]
        require(isinstance(check_id, str) and check_id in CHECKS and check_id not in found,
                "Unknown or duplicate required check")
        found.add(check_id)
        name = row["file"]
        require(isinstance(name, str) and "\\" not in name and all(ord(c) >= 32 for c in name),
                "Unsafe evidence path")
        relative = PurePosixPath(name)
        require(not relative.is_absolute() and relative.parts and ".." not in relative.parts
                and relative.as_posix() == name and not name.endswith(".example.json"), "Unsafe evidence path")
        evidence = no_links(approval_path.parent / name)
        require(evidence.is_relative_to(no_links(approval_path.parent)), "Evidence escapes approval bundle")
        require(isinstance(row["sha256"], str) and HEX64.fullmatch(row["sha256"])
                and checksum(evidence, MAX_JSON_BYTES) == row["sha256"], "Evidence hash mismatch")
        receipt = json_file(evidence)
        require(set(receipt) == {"schema_version", "check_id", "status", "commit", "artifact_sha256",
                                "candidate_sha256", "destination", "completed_at", "evidence_ref"}
                and type(receipt["schema_version"]) is int and receipt["schema_version"] == 1
                and receipt["check_id"] == check_id and receipt["status"] == "passed"
                and receipt["commit"] == expected["commit"]
                and receipt["artifact_sha256"] == expected["artifact"]["sha256"]
                and receipt["candidate_sha256"] == candidate_sha and receipt["destination"] == target,
                f"Check is not a passed receipt for this artifact: {check_id}")
        ref = receipt["evidence_ref"]
        require(isinstance(ref, str) and urlsplit(ref).scheme == "https" and urlsplit(ref).hostname
                and not urlsplit(ref).username and not urlsplit(ref).password, "HTTPS observation reference required")
        completed = parsed_time(receipt["completed_at"], "check completion")
        require(created <= completed <= approved, "Check time outside candidate review")
    require(found == CHECKS, "Required check set incomplete")
    return {"status": "BOUND_APPROVAL_VERIFIED", "commit": expected["commit"],
            "artifact_sha256": expected["artifact"]["sha256"], "destination": target,
            "reviewer": reviewer, "checks": len(found)}


def promote(root: Path, site: Path, candidate: Path, approval: Path, target: dict) -> None:
    result = verify(root, site, candidate, approval, target)
    require(os.environ.get("CLOUDFLARE_API_TOKEN"), "Cloudflare deployment credential unavailable")
    environment = {key: value for key, value in os.environ.items()
                   if key != "MOBIO_PWA_RELEASE_APPROVAL_HMAC_KEY_B64"}
    environment["CLOUDFLARE_ACCOUNT_ID"] = target["account"]
    version = subprocess.run(["npx", "--no-install", "wrangler", "--version"], text=True,
                             capture_output=True, env=environment, timeout=30, check=False)
    require(version.returncode == 0 and version.stdout.strip() == WRANGLER_VERSION,
            "Reviewed local Wrangler version unavailable")
    with tempfile.TemporaryDirectory(prefix="mobio-approved-pwa-") as temporary:
        staged = Path(temporary).resolve() / "site"
        shutil.copytree(site, staged, symlinks=True)
        require(tree_state(staged)["sha256"] == result["artifact_sha256"],
                "Prepared site changed before staging")
        for directory, names, files in os.walk(staged):
            for name in files:
                (Path(directory) / name).chmod(0o400)
            Path(directory).chmod(0o500)
        try:
            published = subprocess.run(["npx", "--no-install", "wrangler", "pages", "deploy", str(staged),
                                        "--project-name=" + target["project"], "--branch=" + target["branch"]],
                                       env=environment, timeout=300, check=False)
            require(published.returncode == 0, "Pages deployment failed")
            print(json.dumps({**result, "status": "APPROVED_SITE_DEPLOYED"}))
        finally:
            for directory, names, files in os.walk(staged):
                Path(directory).chmod(0o700)
                for name in files:
                    (Path(directory) / name).chmod(0o600)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--root", type=Path, default=ROOT)
    subcommands = parser.add_subparsers(dest="command", required=True)
    for command in ("create", "verify", "promote"):
        action = subcommands.add_parser(command, allow_abbrev=False)
        action.add_argument("--site", type=Path, required=True)
        for field in ("account", "project", "branch", "environment"):
            action.add_argument("--" + field, required=True)
        if command == "create":
            action.add_argument("--out", type=Path, required=True)
        else:
            action.add_argument("--candidate", type=Path, required=True)
            action.add_argument("--approval", type=Path, required=True)
    args = parser.parse_args()
    try:
        target = destination(args.account, args.project, args.branch, args.environment)
        root, site = no_links(args.root), no_links(args.site)
        if args.command == "create":
            create(root, site, args.out, target)
        elif args.command == "verify":
            print(json.dumps(verify(root, site, args.candidate, args.approval, target)))
        else:
            promote(root, site, args.candidate, args.approval, target)
    except (ManifestError, OSError, UnicodeDecodeError, subprocess.TimeoutExpired, shutil.Error) as error:
        print("NO-GO: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
