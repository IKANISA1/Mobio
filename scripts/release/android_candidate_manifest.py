#!/usr/bin/env python3
"""Create an Android candidate record and verify a separate promotion approval.

The candidate is generated only after a signed AAB exists. The approval is a
different, HMAC-authenticated file supplied by the release owner after checking
the exact artifact. This script checks bindings, not the truth of provider or
device observations inside evidence receipts. Those remain human release gates.
"""
from __future__ import annotations

import argparse
import base64
import binascii
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[2]
BUNDLE = Path("supabase/hardening/2026-09-28/manifest.json")
MODEL = Path("services/face-inference/model-manifest.json")
BUILD_INPUTS = Path("build/android-release-build-inputs.json")
PUBLIC_DEFINES = frozenset({"SUPABASE_URL", "SUPABASE_ANON_KEY", "PRIVACY_POLICY_URL", "ACCOUNT_DELETION_URL"})
CHECKS = frozenset({
    "flutter_full", "backend_linked", "db_clean_replay", "db_forward_upgrade",
    "auth_postgrest_matrix", "mobio_feature_gate", "signed_android_device", "store_preflight",
    "privacy_security", "repository_protection", "drive_access",
    "release_operations",
})
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
ANDROID_NAMESPACE = "http://schemas.android.com/apk/res/android"
COMPILED_MANIFEST = "base/manifest/AndroidManifest.xml"
MAX_MANIFEST_BYTES = 2 * 1024 * 1024
# Stable framework attribute IDs, also checked against the Android 36 SDK.
IDENTITY_RESOURCE_IDS = {"versionCode": 0x0101021b, "versionName": 0x0101021c,
                         "versionCodeMajor": 0x01010576}


class ManifestError(ValueError):
    pass


def require(value: bool, message: str) -> None:
    if not value:
        raise ManifestError(message)


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def regular(path: Path) -> Path:
    require(not path.is_symlink(), f"Symlink file not allowed: {path}")
    try:
        resolved = path.resolve(strict=True)
    except OSError as error:
        raise ManifestError(f"Required file missing: {path}") from error
    require(resolved.is_file(), f"Regular file required: {path}")
    return resolved


def parsed_time(value: object, label: str) -> datetime:
    require(isinstance(value, str) and value.endswith("Z"), f"{label} must be UTC Z time")
    try:
        stamp = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ManifestError(f"Invalid {label}") from error
    require(stamp.utcoffset() == timedelta(0), f"{label} must be UTC")
    return stamp


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def utc_text(value: datetime) -> str:
    return value.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def git(root: Path, *arguments: str) -> str:
    result = subprocess.run(["git", "-C", str(root), *arguments], text=True,
                            capture_output=True, timeout=15, check=False)
    require(result.returncode == 0, f"Git readback failed: {' '.join(arguments)}")
    return result.stdout.strip()


def repository_state(root: Path) -> tuple[str, str]:
    require(git(root, "status", "--porcelain", "--untracked-files=normal") == "",
            "Candidate source worktree must be clean")
    commit = git(root, "rev-parse", "HEAD")
    tree = git(root, "rev-parse", "HEAD^{tree}")
    require(bool(HEX40.fullmatch(commit)) and bool(HEX40.fullmatch(tree)),
            "Invalid Git commit/tree identity")
    return commit, tree


def versions(root: Path) -> tuple[str, int, str]:
    pubspec = regular(root / "pubspec.yaml").read_text(encoding="utf-8")
    version = re.findall(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+\+[1-9][0-9]*)\s*$", pubspec, re.M)
    require(len(version) == 1, "Exactly one release version is required in pubspec.yaml")
    app = regular(root / "android/app/build.gradle.kts").read_text(encoding="utf-8")
    package = re.findall(r'^\s*applicationId\s*=\s*"([a-z][a-z0-9_.]+)"\s*$', app, re.M)
    require(len(package) == 1, "Exactly one Android applicationId is required")
    return version[0], int(version[0].split("+")[1]), package[0]


# AAB manifests use AAPT2 XmlNode/XmlElement/XmlAttribute, not text XML.
# Field numbers: official AOSP tools/aapt2/Resources.proto (XmlNode and Item).
# https://android.googlesource.com/platform/frameworks/base/+/refs/heads/main/tools/aapt2/Resources.proto
def protobuf_fields(data: bytes) -> list[tuple[int, int, bytes | int]]:
    """Read bounded protobuf wire fields; reject malformed/ambiguous encoding."""
    require(len(data) <= MAX_MANIFEST_BYTES, "Compiled manifest message too large")
    offset = 0

    def varint() -> int:
        nonlocal offset
        value = 0
        for index in range(10):
            require(offset < len(data), "Truncated compiled manifest varint")
            byte = data[offset]
            offset += 1
            require(index < 9 or byte <= 1, "Compiled manifest varint overflow")
            value |= (byte & 127) << (index * 7)
            if byte < 128:
                return value
        raise ManifestError("Compiled manifest varint overflow")

    result = []
    while offset < len(data):
        require(len(result) < 10000, "Too many compiled manifest fields")
        tag = varint()
        number, wire = tag >> 3, tag & 7
        require(0 < number < (1 << 29), "Invalid compiled manifest field number")
        if wire == 0:
            value: bytes | int = varint()
        elif wire in (1, 2, 5):
            length = varint() if wire == 2 else (8 if wire == 1 else 4)
            require(length <= len(data) - offset, "Truncated compiled manifest field")
            value = data[offset:offset + length]
            offset += length
        else:
            raise ManifestError("Unsupported compiled manifest wire type")
        result.append((number, wire, value))
    return result


def protobuf_single(fields: list[tuple[int, int, bytes | int]], number: int,
                    wire: int, *, optional: bool = False) -> bytes | int | None:
    selected = [item for item in fields if item[0] == number]
    require(len(selected) <= 1, "Duplicate compiled manifest scalar field")
    require(bool(selected) or optional, "Required compiled manifest field missing")
    if not selected:
        return None
    require(selected[0][1] == wire, "Wrong compiled manifest field wire type")
    return selected[0][2]


def protobuf_text(fields: list[tuple[int, int, bytes | int]], number: int,
                  *, optional: bool = False) -> str:
    value = protobuf_single(fields, number, 2, optional=optional)
    if value is None:
        return ""
    try:
        return value.decode("utf-8")
    except UnicodeDecodeError as error:
        raise ManifestError("Invalid compiled manifest UTF-8") from error


def compiled_attribute_value(fields: list[tuple[int, int, bytes | int]],
                             *, numeric: bool) -> str | int:
    raw = protobuf_text(fields, 3)
    if numeric:
        require(len(raw) <= 10 and bool(re.fullmatch(r"0|[1-9][0-9]*", raw)),
                "Invalid compiled manifest version code")
        value: str | int = int(raw)
        require(value <= 0x7fffffff, "Compiled manifest version code overflow")
    else:
        value = raw
    item = protobuf_single(fields, 6, 2, optional=True)
    if item is None:
        return value
    item_fields = protobuf_fields(item)
    variants = [field for field in item_fields if 1 <= field[0] <= 7]
    require(len(variants) == 1 and variants[0][1] == 2,
            "Ambiguous compiled manifest attribute item")
    if numeric:
        require(variants[0][0] == 7, "Compiled manifest version code must be a literal integer")
        primitives = [field for field in protobuf_fields(variants[0][2])
                      if 1 <= field[0] <= 14]
        require(len(primitives) == 1 and primitives[0][0] in (6, 7)
                and primitives[0][1] == 0,
                "Compiled manifest version code must be a literal integer")
        compiled: str | int = primitives[0][2]
    else:
        require(variants[0][0] in (2, 3), "Compiled manifest identity must be a literal string")
        compiled = protobuf_text(protobuf_fields(variants[0][2]), 1)
    require(compiled == value, "Raw and compiled manifest identity differ")
    return value


def compiled_manifest_identity(aab: Path, version: str, code: int, package: str) -> dict:
    try:
        with zipfile.ZipFile(aab) as bundle:
            entries = [entry for entry in bundle.infolist() if entry.filename == COMPILED_MANIFEST]
            require(len(entries) == 1, "Exactly one compiled base Android manifest required")
            require(0 < entries[0].file_size <= MAX_MANIFEST_BYTES,
                    "Compiled Android manifest missing or too large")
            body = bundle.read(entries[0])
    except (OSError, zipfile.BadZipFile, RuntimeError) as error:
        raise ManifestError("Compiled Android manifest is unreadable") from error
    node = protobuf_fields(body)
    require(not any(field[0] == 2 for field in node), "Compiled manifest root must be an element")
    element = protobuf_fields(protobuf_single(node, 1, 2))
    require(protobuf_text(element, 2, optional=True) == ""
            and protobuf_text(element, 3) == "manifest", "Compiled manifest root must be manifest")
    attributes = {}
    for number, wire, data in element:
        if number != 4:
            continue
        require(wire == 2, "Wrong compiled manifest attribute wire type")
        fields = protobuf_fields(data)
        name = (protobuf_text(fields, 1, optional=True), protobuf_text(fields, 2))
        require(name not in attributes, "Duplicate compiled manifest root attribute")
        resource_id = protobuf_single(fields, 5, 0, optional=True)
        if name[0] == ANDROID_NAMESPACE and name[1] in IDENTITY_RESOURCE_IDS:
            require(resource_id == IDENTITY_RESOURCE_IDS[name[1]],
                    "Compiled manifest identity resource ID missing or incorrect")
        elif resource_id in IDENTITY_RESOURCE_IDS.values():
            raise ManifestError("Compiled manifest identity resource ID has wrong name/namespace")
        if name == ("", "package"):
            require(resource_id in (None, 0), "Compiled manifest package resource ID must be absent")
        attributes[name] = fields
    names = (("", "package"), (ANDROID_NAMESPACE, "versionName"),
             (ANDROID_NAMESPACE, "versionCode"))
    require(all(name in attributes for name in names), "Required compiled manifest identity missing")
    actual_package = compiled_attribute_value(attributes[names[0]], numeric=False)
    actual_name = compiled_attribute_value(attributes[names[1]], numeric=False)
    actual_code = compiled_attribute_value(attributes[names[2]], numeric=True)
    major = attributes.get((ANDROID_NAMESPACE, "versionCodeMajor"))
    require(major is None or compiled_attribute_value(major, numeric=True) == 0,
            "Compiled manifest versionCodeMajor must be zero")
    require(actual_package == package and actual_name == version.split("+")[0]
            and actual_code == code, "Compiled AAB version or package differs from source")
    return {"package": actual_package, "version_name": actual_name,
            "version_code": actual_code, "sha256": hashlib.sha256(body).hexdigest()}


def verify_aab_signature(aab: Path) -> None:
    try:
        with zipfile.ZipFile(aab) as bundle:
            names = set(bundle.namelist())
            require("BundleConfig.pb" in names and "base/manifest/AndroidManifest.xml" in names,
                    "Android App Bundle structure missing")
            require(bundle.testzip() is None, "Android App Bundle has corrupt ZIP entries")
    except (OSError, zipfile.BadZipFile) as error:
        raise ManifestError("Android App Bundle is unreadable") from error
    try:
        result = subprocess.run(["jarsigner", "-verify", str(aab)], text=True,
                                capture_output=True, timeout=60, check=False)
    except FileNotFoundError as error:
        raise ManifestError("jarsigner unavailable; signed AAB cannot be checked") from error
    require(result.returncode == 0 and "jar verified." in result.stdout.lower(),
            "Android App Bundle signature did not verify")


def migration_state(root: Path) -> tuple[str, list[dict[str, str]]]:
    bundle = regular(root / BUNDLE)
    specification = json.loads(bundle.read_text(encoding="utf-8"))
    require(specification.get("schema_version") == 1, "Invalid hardening bundle version")
    bodies = specification.get("bodies")
    require(isinstance(bodies, list) and len(bodies) == 12, "Exactly twelve hardening bodies required")
    installed: list[dict[str, str]] = []
    previous = ""
    for entry in bodies:
        name, filename, expected = entry["migration_name"], entry["file"], entry["sha256"]
        require(bool(HEX64.fullmatch(expected)), "Invalid hardening body digest")
        body = regular(root / BUNDLE.parent / filename)
        require(digest(body) == expected, f"Hardening body differs: {filename}")
        matches = list((root / "supabase/migrations").glob(f"*_{name}.sql"))
        require(len(matches) == 1, f"Exactly one migration required for {name}")
        migration = regular(matches[0])
        stamp = migration.name.split("_", 1)[0]
        require(bool(re.fullmatch(r"[0-9]{14}", stamp)) and stamp > previous,
                "Hardening migration order invalid")
        require(digest(migration) == expected, f"Installed source differs: {name}")
        installed.append({"name": name, "version": stamp, "sha256": expected})
        previous = stamp
    return digest(bundle), installed


def model_policy_state(root: Path) -> str:
    path = regular(root / MODEL)
    policy = json_file(path)
    require(set(policy) == {"version", "opencv", "source_commit", "dimensions",
                            "metric", "preprocessing", "models"},
            "Invalid Face model policy schema")
    require(isinstance(policy["version"], str) and len(policy["version"]) >= 8
            and isinstance(policy["opencv"], str)
            and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", policy["opencv"])
            and isinstance(policy["source_commit"], str)
            and HEX40.fullmatch(policy["source_commit"])
            and policy["dimensions"] == 128 and policy["metric"] == "cosine"
            and isinstance(policy["preprocessing"], str)
            and len(policy["preprocessing"].strip()) >= 20,
            "Invalid Face model policy fields")
    models = policy["models"]
    require(isinstance(models, list) and len(models) == 2,
            "Face model policy requires detector and recognizer")
    found: set[str] = set()
    for model in models:
        require(isinstance(model, dict)
                and set(model) == {"role", "file", "sha256", "license", "url"},
                "Invalid Face model entry")
        role = model["role"]
        require(isinstance(role, str) and role in {"detector", "recognizer"}
                and role not in found,
                "Duplicate or unknown Face model role")
        found.add(role)
        filename = model["file"]
        require(isinstance(filename, str) and re.fullmatch(r"[A-Za-z0-9_.-]+\.onnx", filename)
                and isinstance(model["sha256"], str) and HEX64.fullmatch(model["sha256"])
                and isinstance(model["license"], str) and bool(model["license"].strip())
                and isinstance(model["url"], str)
                and model["url"].startswith("https://")
                and policy["source_commit"] in model["url"],
                "Invalid Face model source or digest")
    require(found == {"detector", "recognizer"}, "Face model roles incomplete")
    return digest(path)


def build_input_state(root: Path, aab: Path, version: str, code: int, package: str) -> dict:
    path = regular(root / BUILD_INPUTS)
    record = json_file(path)
    require(set(record) == {"schema_version", "environment", "source_version", "build_name",
                            "build_number", "package", "target_platforms", "release_shrink",
                            "public_define_sha256", "aab_sha256"}
            and record["schema_version"] == 1, "Invalid Android build-input schema")
    environment = record["environment"]
    require(isinstance(environment, str)
            and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{2,79}", environment)
            and environment != "local-unverified", "Named reviewed build environment required")
    require(record["source_version"] == version
            and record["build_name"] == version.split("+")[0]
            and record["build_number"] == str(code)
            and record["package"] == package,
            "Build version or package differs from source")
    require(isinstance(record["target_platforms"], str)
            and isinstance(record["release_shrink"], str), "Invalid Android build options")
    hashes = record["public_define_sha256"]
    require(isinstance(hashes, dict) and set(hashes) == PUBLIC_DEFINES
            and all(isinstance(value, str) and HEX64.fullmatch(value) for value in hashes.values()),
            "Public runtime define digests missing")
    require(record["aab_sha256"] == digest(aab), "Build-input record refers to another AAB")
    return {"environment": environment, "record_sha256": digest(path),
            "public_define_sha256": hashes, "target_platforms": record["target_platforms"],
            "release_shrink": record["release_shrink"]}


def source_state(root: Path, aab: Path) -> dict:
    commit, tree = repository_state(root)
    version, version_code, package = versions(root)
    migration_sha, migrations = migration_state(root)
    build_inputs = build_input_state(root, aab, version, version_code, package)
    compiled_manifest = compiled_manifest_identity(aab, version, version_code, package)
    return {
        "commit": commit, "tree": tree, "version": version,
        "version_code": version_code, "package": package,
        "flutter_version": regular(root / ".flutter-version").read_text(encoding="utf-8").strip(),
        "migration_bundle_sha256": migration_sha, "migrations": migrations,
        "model_manifest_sha256": model_policy_state(root),
        "build_inputs": build_inputs,
        "aab": {"name": aab.name, "sha256": digest(aab), "size_bytes": aab.stat().st_size,
                "compiled_manifest": compiled_manifest},
        "optional_features": {"paid_transport": False, "institutional_sms": False, "face_ussd": False},
    }


def create(root: Path, aab: Path, output: Path) -> None:
    aab = regular(aab)
    require(aab.suffix == ".aab" and aab.stat().st_size > 0, "Nonempty AAB required")
    verify_aab_signature(aab)
    actor = os.environ.get("MOBIO_BUILD_ACTOR") or os.environ.get("GITHUB_ACTOR")
    run_id = os.environ.get("MOBIO_BUILD_RUN_ID") or os.environ.get("GITHUB_RUN_ID")
    require(bool(actor and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{1,79}", actor)),
            "Named build actor required")
    require(bool(run_id and re.fullmatch(r"[1-9][0-9]{0,19}", run_id)),
            "Actual build run id required")
    data = {
        "schema_version": 1, "kind": "android_candidate", "created_at": utc_text(utc_now()),
        "build_actor": actor, "build_run_id": run_id, "source": source_state(root, aab),
    }
    require(output.absolute() != aab and not output.exists(), "New manifest output path required")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": "CANDIDATE_ONLY", "manifest": str(output),
                      "artifact_sha256": data["source"]["aab"]["sha256"]}))


def json_file(path: Path) -> dict:
    value = json.loads(regular(path).read_text(encoding="utf-8"))
    require(isinstance(value, dict), "JSON object required")
    return value


def record_build_inputs(root: Path, defines_file: Path, aab: Path, output: Path) -> None:
    aab = regular(aab)
    require(aab.suffix == ".aab" and aab.stat().st_size > 0, "Nonempty AAB required")
    defines = json_file(defines_file)
    require(set(defines) == PUBLIC_DEFINES
            and all(isinstance(value, str) and value for value in defines.values()),
            "Android build inputs lack a required public Dart define")
    version, code, package = versions(root)
    compiled_manifest_identity(aab, version, code, package)
    environment = os.environ.get("MOBIO_BUILD_ENVIRONMENT", "local-unverified")
    require(bool(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{2,79}", environment)),
            "Invalid named Android build environment")
    record = {
        "schema_version": 1, "environment": environment,
        "source_version": version,
        "build_name": os.environ.get("ANDROID_BUILD_NAME") or version.split("+")[0],
        "build_number": os.environ.get("ANDROID_BUILD_NUMBER") or str(code),
        "package": package,
        "target_platforms": os.environ.get("ANDROID_TARGET_PLATFORMS", ""),
        "release_shrink": os.environ.get("ANDROID_RELEASE_SHRINK", ""),
        "public_define_sha256": {key: hashlib.sha256(defines[key].encode("utf-8")).hexdigest()
                                 for key in sorted(PUBLIC_DEFINES)},
        "aab_sha256": digest(aab),
    }
    require(not output.exists(), "New build-input output path required")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({"status": "BUILD_INPUTS_RECORDED", "record": str(output)}))


def approval_key() -> bytes:
    encoded = os.environ.get("MOBIO_RELEASE_APPROVAL_HMAC_KEY_B64", "")
    try:
        key = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error) as error:
        raise ManifestError("Release approval key unavailable") from error
    require(len(key) >= 32, "Release approval key unavailable")
    return key


def canonical(value: dict) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")


def verify(root: Path, aab: Path, candidate_path: Path, approval_path: Path,
           track: str, release_status: str, package: str) -> None:
    aab = regular(aab)
    verify_aab_signature(aab)
    candidate_path, approval_path = regular(candidate_path), regular(approval_path)
    candidate = json_file(candidate_path)
    require(set(candidate) == {"schema_version", "kind", "created_at", "build_actor", "build_run_id", "source"}
            and candidate["schema_version"] == 1 and candidate["kind"] == "android_candidate",
            "Invalid candidate schema")
    created = parsed_time(candidate["created_at"], "candidate time")
    now = utc_now()
    require(now - timedelta(days=14) <= created <= now + timedelta(minutes=5), "Candidate is stale or future-dated")
    expected = source_state(root, aab)
    require(candidate["source"] == expected, "Candidate differs from current commit, manifest, version or AAB")
    require(expected["package"] == package, "Requested Play package differs from Android applicationId")
    candidate_sha = digest(candidate_path)
    approval = json_file(approval_path)
    require(set(approval) == {"schema_version", "candidate_sha256", "reviewer", "approved_at",
                              "track", "release_status", "checks", "signature_hmac_sha256"}
            and approval["schema_version"] == 1, "Invalid approval schema")
    require(approval["candidate_sha256"] == candidate_sha, "Approval refers to another candidate")
    require(approval["track"] == track and approval["release_status"] == release_status,
            "Approval does not match requested Play track/status")
    reviewer = approval["reviewer"]
    require(isinstance(reviewer, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.@-]{2,99}", reviewer)
            and isinstance(candidate["build_actor"], str)
            and reviewer.casefold() != candidate["build_actor"].casefold(),
            "Distinct named release reviewer required")
    approved = parsed_time(approval["approved_at"], "approval time")
    require(created <= approved <= now + timedelta(minutes=5)
            and approved >= now - timedelta(days=7), "Approval is stale or predates candidate")
    signature = approval["signature_hmac_sha256"]
    require(isinstance(signature, str) and bool(HEX64.fullmatch(signature)), "Invalid approval signature")
    payload = {key: value for key, value in approval.items() if key != "signature_hmac_sha256"}
    expected_signature = hmac.new(approval_key(), canonical(payload), hashlib.sha256).hexdigest()
    require(hmac.compare_digest(signature, expected_signature), "Release approval signature mismatch")
    checks = approval["checks"]
    require(isinstance(checks, list) and len(checks) == len(CHECKS), "Required check receipts missing")
    found: set[str] = set()
    for row in checks:
        require(isinstance(row, dict) and set(row) == {"id", "file", "sha256"}, "Invalid check pointer")
        check_id = row["id"]
        require(isinstance(check_id, str) and check_id in CHECKS and check_id not in found,
                "Unknown or duplicate required check")
        found.add(check_id)
        relative = Path(row["file"])
        require(not relative.is_absolute() and relative.parts and ".." not in relative.parts
                and all(part not in ("", ".") for part in relative.parts)
                and not relative.name.endswith(".example.json"), "Unsafe check evidence path")
        evidence = approval_path.parent / relative
        require(regular(evidence).is_relative_to(approval_path.parent),
                "Check evidence must stay inside approval bundle")
        receipt = json_file(evidence)
        require(isinstance(row["sha256"], str) and digest(evidence) == row["sha256"],
                f"Evidence hash mismatch: {check_id}")
        require(set(receipt) == {"schema_version", "check_id", "status", "commit",
                                 "artifact_sha256", "candidate_sha256", "completed_at", "evidence_ref"}
                and receipt["schema_version"] == 1 and receipt["check_id"] == check_id
                and receipt["status"] == "passed"
                and receipt["commit"] == expected["commit"]
                and receipt["artifact_sha256"] == expected["aab"]["sha256"]
                and receipt["candidate_sha256"] == candidate_sha
                and isinstance(receipt["evidence_ref"], str)
                and receipt["evidence_ref"].startswith("https://"),
                f"Check is not a passed receipt for this artifact: {check_id}")
        completed = parsed_time(receipt["completed_at"], f"{check_id} completion")
        require(created <= completed <= approved, f"Check time outside candidate review: {check_id}")
    require(found == CHECKS, "Required check set incomplete")
    print(json.dumps({"status": "BOUND_APPROVAL_VERIFIED", "commit": expected["commit"],
                      "artifact_sha256": expected["aab"]["sha256"], "track": track,
                      "reviewer": reviewer, "checks": len(found)}))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    sub = parser.add_subparsers(dest="action", required=True)
    produce = sub.add_parser("create")
    produce.add_argument("--aab", type=Path, required=True)
    produce.add_argument("--out", type=Path, required=True)
    record = sub.add_parser("record-build-inputs")
    record.add_argument("--defines-file", type=Path, required=True)
    record.add_argument("--aab", type=Path, required=True)
    record.add_argument("--out", type=Path, required=True)
    validate = sub.add_parser("verify")
    validate.add_argument("--aab", type=Path, required=True)
    validate.add_argument("--candidate", type=Path, required=True)
    validate.add_argument("--approval", type=Path, required=True)
    validate.add_argument("--track", choices=("internal", "alpha", "beta", "production"), required=True)
    validate.add_argument("--release-status", choices=("draft", "completed", "inProgress", "halted"), required=True)
    validate.add_argument("--package", required=True)
    args = parser.parse_args()
    try:
        root = args.root.resolve(strict=True)
        if args.action == "create":
            create(root, args.aab, args.out)
        elif args.action == "record-build-inputs":
            record_build_inputs(root, args.defines_file, args.aab, args.out)
        else:
            verify(root, args.aab, args.candidate, args.approval, args.track, args.release_status, args.package)
        return 0
    except (ManifestError, KeyError, TypeError, json.JSONDecodeError, OSError,
            subprocess.TimeoutExpired) as error:
        print(f"NO-GO: Android candidate manifest: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
