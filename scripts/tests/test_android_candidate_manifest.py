"""Artifact-bound promotion fixtures; no provider, device or signing keys."""
from __future__ import annotations

import base64
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

SOURCE = Path(__file__).resolve().parents[1] / "release/android_candidate_manifest.py"
SPEC = importlib.util.spec_from_file_location("android_candidate_manifest", SOURCE)
assert SPEC and SPEC.loader
manifest = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(manifest)
REAL_VERIFY_AAB_SIGNATURE = manifest.verify_aab_signature


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def stamp(value: datetime) -> str:
    return value.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def wire_integer(number: int, value: int) -> bytes:
    def varint(value: int) -> bytes:
        result = bytearray()
        while value >= 128:
            result.append((value & 127) | 128)
            value >>= 7
        result.append(value)
        return bytes(result)
    return varint(number << 3) + varint(value)


def wire_bytes(number: int, value: bytes) -> bytes:
    prefix = wire_integer(number, len(value))
    return bytes([prefix[0] | 2]) + prefix[1:] + value


def attribute(name: str, value: str, *, namespace: str = "",
              compiled: bytes | None = None, resource_id: int | None = None) -> bytes:
    body = wire_bytes(2, name.encode()) + wire_bytes(3, value.encode())
    if namespace:
        body += wire_bytes(1, namespace.encode())
    if namespace == manifest.ANDROID_NAMESPACE and name in manifest.IDENTITY_RESOURCE_IDS:
        body += wire_integer(5, resource_id if resource_id is not None
                            else manifest.IDENTITY_RESOURCE_IDS[name])
    if compiled is not None:
        body += wire_bytes(6, compiled)
    return wire_bytes(4, body)


def compiled_fixture(*, package: str = "rw.mobi.app", name: str = "1.0.0",
                     code: str = "17", omit: str = "", extra: bytes = b"",
                     code_item: bytes | None = None) -> bytes:
    element = wire_bytes(3, b"manifest")
    for key, value, namespace, compiled in (
        ("package", package, "", None),
        ("versionName", name, manifest.ANDROID_NAMESPACE, None),
        ("versionCode", code, manifest.ANDROID_NAMESPACE, code_item),
    ):
        if key != omit:
            element += attribute(key, value, namespace=namespace, compiled=compiled)
    return wire_bytes(1, element + extra)


def write_aab(path: Path, body: bytes) -> None:
    with zipfile.ZipFile(path, "w") as bundle:
        bundle.writestr("BundleConfig.pb", b"synthetic")
        bundle.writestr(manifest.COMPILED_MANIFEST, body)


# Real AAPT2 36.0.0 --proto-format output for a minimal synthetic manifest:
# package rw.mobi.app, versionName 1.0.0, versionCode 17. No credentials/signing.
AAPT2_MANIFEST = base64.b64decode(
    "CoQECjkKB2FuZHJvaWQSKmh0dHA6Ly9zY2hlbWFzLmFuZHJvaWQuY29tL2Fway9yZXMvYW5kcm9pZBoCCAEaCG1hbmlmZXN0IhYSB3BhY2thZ2UaC3J3Lm1vYmkuYXBwIkwKKmh0dHA6Ly9zY2hlbWFzLmFuZHJvaWQuY29tL2Fway9yZXMvYW5kcm9pZBILdmVyc2lvbkNvZGUaAjE3IgIIASibhIQIMgQ6AjARIkUKKmh0dHA6Ly9zY2hlbWFzLmFuZHJvaWQuY29tL2Fway9yZXMvYW5kcm9pZBILdmVyc2lvbk5hbWUaBTEuMC4wKJyEhAgiUgoqaHR0cDovL3NjaGVtYXMuYW5kcm9pZC5jb20vYXBrL3Jlcy9hbmRyb2lkEhFjb21waWxlU2RrVmVyc2lvbhoCMzYiAggBKPKKhAgyBDoCMCQiKBIYcGxhdGZvcm1CdWlsZFZlcnNpb25Db2RlGgIzNiICCAEyBDoCMCQiUAoqaHR0cDovL3NjaGVtYXMuYW5kcm9pZC5jb20vYXBrL3Jlcy9hbmRyb2lkEhljb21waWxlU2RrVmVyc2lvbkNvZGVuYW1lGgIxNijzioQIIigSGHBsYXRmb3JtQnVpbGRWZXJzaW9uTmFtZRoCMTYiAggBMgQ6AjAQKhYKDRoLYXBwbGljYXRpb24aBQgBEJABGgIIAQ=="
)


class CompiledManifestTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.aab = Path(temp.name) / "fixture.aab"

    def inspect(self, body: bytes) -> dict:
        write_aab(self.aab, body)
        return manifest.compiled_manifest_identity(self.aab, "1.0.0+17", 17, "rw.mobi.app")

    def test_real_aapt2_compiled_manifest_identity(self):
        result = self.inspect(AAPT2_MANIFEST)
        self.assertEqual(result, {"package": "rw.mobi.app", "version_name": "1.0.0",
                                 "version_code": 17,
                                 "sha256": hashlib.sha256(AAPT2_MANIFEST).hexdigest()})

    def test_literal_compiled_string_and_integer_agree(self):
        integer = wire_bytes(7, wire_integer(6, 17))
        name = attribute("versionName", "1.0.0", namespace=manifest.ANDROID_NAMESPACE,
                         compiled=wire_bytes(2, wire_bytes(1, b"1.0.0")))
        result = self.inspect(compiled_fixture(omit="versionName", extra=name, code_item=integer))
        self.assertEqual(result["version_code"], 17)

    def test_zero_major_version_is_accepted(self):
        self.inspect(compiled_fixture(extra=attribute("versionCodeMajor", "0",
                                                     namespace=manifest.ANDROID_NAMESPACE)))

    def test_missing_and_wrong_actual_identity_rejected(self):
        fixtures = {
            "missing package": compiled_fixture(omit="package"),
            "missing name": compiled_fixture(omit="versionName"),
            "missing code": compiled_fixture(omit="versionCode"),
            "wrong package": compiled_fixture(package="rw.wrong.app"),
            "wrong name": compiled_fixture(name="9.9.9"),
            "wrong code": compiled_fixture(code="99"),
            "nonzero major": compiled_fixture(extra=attribute("versionCodeMajor", "1",
                                                             namespace=manifest.ANDROID_NAMESPACE)),
            "string resource": compiled_fixture(name="@string/version"),
            "negative code": compiled_fixture(code="-17"),
            "overflow code": compiled_fixture(code="2147483648"),
            "ambiguous decimal": compiled_fixture(code="017"),
        }
        for label, body in fixtures.items():
            with self.subTest(label=label), self.assertRaises(manifest.ManifestError):
                self.inspect(body)

    def test_malformed_and_ambiguous_protobuf_rejected(self):
        fixtures = {
            "text XML": b"<manifest package='rw.mobi.app'/>",
            "truncated length": b"\x0a\xff\xff",
            "truncated nested field": wire_bytes(1, b"\x1a\x7fshort"),
            "invalid field zero": b"\x00\x00",
            "invalid wire": b"\x0b\x00",
            "overflow varint": b"\x08" + b"\xff" * 10,
            "wrong root": wire_bytes(1, wire_bytes(3, b"application")),
            "text and element": compiled_fixture() + wire_bytes(2, b"text"),
            "duplicate root": compiled_fixture() * 2,
            "duplicate attribute": compiled_fixture(extra=attribute("package", "rw.mobi.app")),
            "duplicate value": wire_bytes(1, wire_bytes(3, b"manifest") + wire_bytes(4,
                wire_bytes(2, b"package") + wire_bytes(3, b"rw.mobi.app") + wire_bytes(3, b"rw.mobi.app"))),
            "wrong attribute wire": wire_bytes(1, wire_bytes(3, b"manifest") + wire_integer(4, 1)),
            "invalid UTF-8": wire_bytes(1, wire_bytes(3, b"\xff")),
            "raw compiled disagree": compiled_fixture(code_item=wire_bytes(7, wire_integer(6, 99))),
            "resource code": compiled_fixture(code_item=wire_bytes(1, wire_integer(2, 17))),
            "ambiguous primitive": compiled_fixture(code_item=wire_bytes(7,
                wire_integer(6, 17) + wire_integer(7, 17))),
            "wrong identity resource ID": compiled_fixture(omit="versionCode", extra=attribute(
                "versionCode", "17", namespace=manifest.ANDROID_NAMESPACE, resource_id=0x0101021c)),
            "identity resource ID missing": compiled_fixture(omit="versionCode", extra=wire_bytes(4,
                wire_bytes(1, manifest.ANDROID_NAMESPACE.encode()) + wire_bytes(2, b"versionCode")
                + wire_bytes(3, b"17"))),
        }
        for label, body in fixtures.items():
            with self.subTest(label=label), self.assertRaises(manifest.ManifestError):
                self.inspect(body)

    def test_missing_duplicate_and_oversized_zip_manifest_rejected(self):
        with zipfile.ZipFile(self.aab, "w") as bundle:
            bundle.writestr("BundleConfig.pb", b"synthetic")
        with self.assertRaisesRegex(manifest.ManifestError, "Exactly one"):
            manifest.compiled_manifest_identity(self.aab, "1.0.0+17", 17, "rw.mobi.app")
        with zipfile.ZipFile(self.aab, "w") as bundle:
            bundle.writestr(manifest.COMPILED_MANIFEST, compiled_fixture())
            with self.assertWarns(UserWarning):
                bundle.writestr(manifest.COMPILED_MANIFEST, compiled_fixture())
        with self.assertRaisesRegex(manifest.ManifestError, "Exactly one"):
            manifest.compiled_manifest_identity(self.aab, "1.0.0+17", 17, "rw.mobi.app")
        with self.assertRaisesRegex(manifest.ManifestError, "too large"):
            self.inspect(b"\0" * (manifest.MAX_MANIFEST_BYTES + 1))


class CandidateManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.base = Path(temp.name)
        self.root = self.base / "repo"
        self.root.mkdir()
        def put(relative: str, text: str) -> Path:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text)
            return target
        put(".gitignore", "build/\n")
        put("pubspec.yaml", "name: mobi_app\nversion: 1.0.0+17\n")
        put("android/app/build.gradle.kts", 'applicationId = "rw.mobi.app"\n')
        put(".flutter-version", "3.44.3\n")
        model_commit = "a" * 40
        write_json(self.root / manifest.MODEL, {
            "version": "synthetic-face-v1", "opencv": "4.11.0",
            "source_commit": model_commit, "dimensions": 128,
            "metric": "cosine", "preprocessing": "Synthetic normalized image fixture",
            "models": [
                {"role": role, "file": f"{role}.onnx", "sha256": "a" * 64,
                 "license": "MIT", "url": f"https://example.invalid/{model_commit}/{role}.onnx"}
                for role in ("detector", "recognizer")
            ],
        })
        bodies = []
        for index in range(12):
            name = f"mobio_hardening_fixture_{index:02}"
            filename = f"{index + 1:02}_fixture_{index:02}.sql"
            sql = f"-- synthetic migration {index}\n"
            put(f"supabase/hardening/2026-09-28/{filename}", sql)
            put(f"supabase/migrations/{20260929000000 + index}_{name}.sql", sql)
            bodies.append({"file": filename, "migration_name": name,
                           "sha256": hashlib.sha256(sql.encode()).hexdigest()})
        write_json(self.root / manifest.BUNDLE, {"schema_version": 1, "bodies": bodies})
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("add", ".")
        self.git("commit", "-qm", "Fixture source")
        self.aab = self.root / "build/app-release.aab"
        self.aab.parent.mkdir(parents=True)
        write_aab(self.aab, AAPT2_MANIFEST)
        self.defines_file = self.root / "build/private-defines.json"
        write_json(self.defines_file, {key: key for key in manifest.PUBLIC_DEFINES})
        self.build_inputs = self.root / manifest.BUILD_INPUTS
        with patch.dict(os.environ, {"MOBIO_BUILD_ENVIRONMENT": "Mobio-qa"}):
            manifest.record_build_inputs(self.root, self.defines_file, self.aab, self.build_inputs)
        signature_patch = patch.object(manifest, "verify_aab_signature", lambda _: None)
        signature_patch.start()
        self.addCleanup(signature_patch.stop)
        self.candidate = self.root / "build/release-candidate.json"
        self.key = os.urandom(32)
        self.approval = self.base / "approval/approval.json"
        self.approval.parent.mkdir()
        self.env = {"MOBIO_BUILD_ACTOR": "build-bot", "MOBIO_BUILD_RUN_ID": "12345",
                    "MOBIO_RELEASE_APPROVAL_HMAC_KEY_B64": base64.b64encode(self.key).decode()}
        with patch.dict(os.environ, self.env):
            manifest.create(self.root, self.aab, self.candidate)
        self.candidate_data = json.loads(self.candidate.read_text())
        self.candidate_sha = manifest.digest(self.candidate)
        self.artifact_sha = manifest.digest(self.aab)
        self.create_approval()

    def git(self, *args: str) -> None:
        subprocess.run(["git", "-C", str(self.root), *args], check=True,
                       text=True, capture_output=True)

    def create_approval(self, overrides: dict | None = None) -> None:
        now = datetime.now(timezone.utc)
        rows = []
        for check_id in sorted(manifest.CHECKS):
            receipt = {"schema_version": 1, "check_id": check_id, "status": "passed",
                       "commit": self.candidate_data["source"]["commit"],
                       "artifact_sha256": self.artifact_sha,
                       "candidate_sha256": self.candidate_sha,
                       "completed_at": stamp(now),
                       "evidence_ref": f"https://example.invalid/qa/{check_id}"}
            path = self.approval.parent / f"{check_id}.json"
            write_json(path, receipt)
            rows.append({"id": check_id, "file": path.name, "sha256": manifest.digest(path)})
        value = {"schema_version": 1, "candidate_sha256": self.candidate_sha,
                 "reviewer": "release-reviewer", "approved_at": stamp(now + timedelta(seconds=1)),
                 "track": "internal", "release_status": "draft", "checks": rows}
        if overrides:
            value.update(overrides)
        value["signature_hmac_sha256"] = hmac.new(self.key, manifest.canonical(value), hashlib.sha256).hexdigest()
        write_json(self.approval, value)

    def verify(self) -> None:
        with patch.dict(os.environ, self.env):
            manifest.verify(self.root, self.aab, self.candidate, self.approval, "internal", "draft", "rw.mobi.app")

    def test_matching_artifact_source_receipts_and_approval(self):
        self.verify()
        self.assertEqual(self.candidate_data["source"]["aab"]["compiled_manifest"]["version_code"], 17)

    def test_case_variant_of_builder_cannot_approve_the_candidate(self):
        self.create_approval({"reviewer": self.candidate_data["build_actor"].upper()})
        with self.assertRaisesRegex(manifest.ManifestError, "Distinct named release reviewer"):
            self.verify()

    def rebind_wrong_manifest(self) -> None:
        write_aab(self.aab, compiled_fixture(code="99"))
        inputs = json.loads(self.build_inputs.read_text())
        inputs["aab_sha256"] = manifest.digest(self.aab)
        write_json(self.build_inputs, inputs)

    def test_record_rejects_actual_version_mismatch_without_writing_record(self):
        write_aab(self.aab, compiled_fixture(code="99"))
        output = self.root / "build/rejected-inputs.json"
        with self.assertRaisesRegex(manifest.ManifestError, "Compiled AAB version"):
            manifest.record_build_inputs(self.root, self.defines_file, self.aab, output)
        self.assertFalse(output.exists())

    def test_create_rejects_wrong_actual_version_despite_rebound_inputs(self):
        self.rebind_wrong_manifest()
        output = self.root / "build/rejected-candidate.json"
        with patch.dict(os.environ, self.env), self.assertRaisesRegex(
                manifest.ManifestError, "Compiled AAB version"):
            manifest.create(self.root, self.aab, output)
        self.assertFalse(output.exists())

    def test_verify_rejects_wrong_actual_version_despite_rebound_approval(self):
        self.rebind_wrong_manifest()
        self.artifact_sha = manifest.digest(self.aab)
        self.candidate_data["source"]["aab"]["sha256"] = self.artifact_sha
        self.candidate_data["source"]["aab"]["size_bytes"] = self.aab.stat().st_size
        self.candidate_data["source"]["aab"]["compiled_manifest"]["version_code"] = 99
        self.candidate_data["source"]["build_inputs"]["record_sha256"] = manifest.digest(self.build_inputs)
        write_json(self.candidate, self.candidate_data)
        self.candidate_sha = manifest.digest(self.candidate)
        self.create_approval()
        with self.assertRaisesRegex(manifest.ManifestError, "Compiled AAB version"):
            self.verify()

    def test_build_input_record_contains_hashes_without_values(self):
        record = json.loads(self.build_inputs.read_text())
        self.assertEqual(record["environment"], "Mobio-qa")
        self.assertEqual(record["build_number"], "17")
        self.assertEqual(record["public_define_sha256"]["SUPABASE_URL"],
                         hashlib.sha256(b"SUPABASE_URL").hexdigest())
        self.assertNotIn('"SUPABASE_URL": "SUPABASE_URL"', self.build_inputs.read_text())

    def test_build_input_record_rejects_missing_define(self):
        bad = self.root / "build/bad-defines.json"
        write_json(bad, {"SUPABASE_URL": "https://fixture.invalid"})
        with self.assertRaisesRegex(manifest.ManifestError, "required public Dart define"):
            manifest.record_build_inputs(self.root, bad, self.aab,
                                         self.root / "build/bad-inputs.json")

    def test_dirty_tree_rejected(self):
        (self.root / "untracked.txt").write_text("not reviewed")
        with self.assertRaisesRegex(manifest.ManifestError, "clean"):
            self.verify()

    def test_wrong_artifact_rejected(self):
        self.aab.write_bytes(b"different artifact")
        with self.assertRaisesRegex(manifest.ManifestError, "another AAB"):
            self.verify()

    def test_changed_public_build_inputs_rejected(self):
        value = json.loads(self.build_inputs.read_text())
        value["public_define_sha256"]["SUPABASE_URL"] = "0" * 64
        write_json(self.build_inputs, value)
        with self.assertRaisesRegex(manifest.ManifestError, "Candidate differs"):
            self.verify()

    def test_changed_model_manifest_rejected(self):
        policy = json.loads((self.root / manifest.MODEL).read_text())
        policy["version"] = "synthetic-face-v2"
        write_json(self.root / manifest.MODEL, policy)
        self.git("add", ".")
        self.git("commit", "-qm", "Changed model version")
        with self.assertRaisesRegex(manifest.ManifestError, "Candidate differs"):
            self.verify()

    def test_invalid_model_policy_rejected_even_for_new_candidate(self):
        policy = json.loads((self.root / manifest.MODEL).read_text())
        policy["metric"] = "euclidean"
        write_json(self.root / manifest.MODEL, policy)
        self.git("add", ".")
        self.git("commit", "-qm", "Changed model policy")
        with self.assertRaisesRegex(manifest.ManifestError, "Invalid Face model policy fields"):
            manifest.source_state(self.root, self.aab)

    def test_build_override_version_rejected(self):
        value = json.loads(self.build_inputs.read_text())
        value["build_number"] = "99"
        write_json(self.build_inputs, value)
        with self.assertRaisesRegex(manifest.ManifestError, "Build version"):
            self.verify()

    def test_unreviewed_build_environment_rejected(self):
        value = json.loads(self.build_inputs.read_text())
        value["environment"] = "local-unverified"
        write_json(self.build_inputs, value)
        with self.assertRaisesRegex(manifest.ManifestError, "Named reviewed"):
            self.verify()

    def test_wrong_commit_and_prefix_rejected(self):
        value = dict(self.candidate_data)
        value["source"] = dict(value["source"], commit=value["source"]["commit"][:12])
        write_json(self.candidate, value)
        with self.assertRaisesRegex(manifest.ManifestError, "Candidate differs"):
            self.verify()

    def test_stale_candidate_rejected(self):
        value = dict(self.candidate_data)
        value["created_at"] = stamp(datetime.now(timezone.utc) - timedelta(days=15))
        write_json(self.candidate, value)
        with self.assertRaisesRegex(manifest.ManifestError, "stale"):
            self.verify()

    def test_unsigned_or_different_approval_rejected(self):
        value = json.loads(self.approval.read_text())
        value["reviewer"] = "different-reviewer"
        write_json(self.approval, value)
        with self.assertRaisesRegex(manifest.ManifestError, "signature mismatch"):
            self.verify()

    def test_builder_cannot_approve(self):
        self.create_approval({"reviewer": "build-bot"})
        with self.assertRaisesRegex(manifest.ManifestError, "Distinct named"):
            self.verify()

    def test_skipped_required_check_rejected_even_when_signed(self):
        check_id = "mobio_feature_gate"
        path = self.approval.parent / f"{check_id}.json"
        receipt = json.loads(path.read_text())
        receipt["status"] = "skipped"
        write_json(path, receipt)
        value = json.loads(self.approval.read_text())
        for row in value["checks"]:
            if row["id"] == check_id:
                row["sha256"] = manifest.digest(path)
        value.pop("signature_hmac_sha256")
        value["signature_hmac_sha256"] = hmac.new(self.key, manifest.canonical(value), hashlib.sha256).hexdigest()
        write_json(self.approval, value)
        with self.assertRaisesRegex(manifest.ManifestError, "not a passed receipt"):
            self.verify()

    def test_missing_integrated_gate_receipt_rejected_even_when_signed(self):
        value = json.loads(self.approval.read_text())
        value["checks"] = [row for row in value["checks"]
                           if row["id"] != "mobio_feature_gate"]
        value.pop("signature_hmac_sha256")
        value["signature_hmac_sha256"] = hmac.new(
            self.key, manifest.canonical(value), hashlib.sha256
        ).hexdigest()
        write_json(self.approval, value)
        with self.assertRaisesRegex(manifest.ManifestError, "Required check receipts missing"):
            self.verify()

    def test_missing_receipt_rejected(self):
        (self.approval.parent / "flutter_full.json").unlink()
        with self.assertRaisesRegex(manifest.ManifestError, "Required file missing"):
            self.verify()

    def test_wrong_play_track_rejected(self):
        with patch.dict(os.environ, self.env):
            with self.assertRaisesRegex(manifest.ManifestError, "Play track"):
                manifest.verify(self.root, self.aab, self.candidate, self.approval, "production", "draft", "rw.mobi.app")

    def test_wrong_package_rejected(self):
        with patch.dict(os.environ, self.env):
            with self.assertRaisesRegex(manifest.ManifestError, "Play package"):
                manifest.verify(self.root, self.aab, self.candidate, self.approval, "internal", "draft", "wrong.app")

    def test_missing_approval_key_rejected(self):
        with patch.dict(os.environ, self.env):
            del os.environ["MOBIO_RELEASE_APPROVAL_HMAC_KEY_B64"]
            with self.assertRaisesRegex(manifest.ManifestError, "key unavailable"):
                manifest.verify(self.root, self.aab, self.candidate, self.approval, "internal", "draft", "rw.mobi.app")

    def test_unsigned_aab_rejected(self):
        with self.assertRaisesRegex(manifest.ManifestError, "signature did not verify"):
            REAL_VERIFY_AAB_SIGNATURE(self.aab)


if __name__ == "__main__":
    unittest.main()
