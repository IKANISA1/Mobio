"""Run the actual Play shell uploader against executable local provider fakes.

Approval cryptography/compiled AAB identity are covered by the candidate suite.
This fixture isolates the post-upload receipt boundary after a synthetic gate;
it never executes a real provider CLI or contacts Google Play.
"""
import json
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class GooglePlayUploadReceiptTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        release = self.root / "scripts/release"
        release.mkdir(parents=True)
        self.script = release / "upload_google_play_release.sh"
        shutil.copyfile(ROOT / self.script.relative_to(self.root), self.script)
        (self.root / "pubspec.yaml").write_text("version: 1.0.0+17\n")
        self.aab = self.root / "fixture.aab"
        self.aab.write_bytes(b"synthetic already-approved AAB fixture")
        self.artifact_sha = hashlib.sha256(self.aab.read_bytes()).hexdigest()
        self.candidate = self.root / "candidate.json"
        self.candidate.write_text(json.dumps({"source": {"version_code": 17}}))
        self.approval = self.root / "approval.json"
        self.approval.write_text("{}")
        self.events = self.root / "events.jsonl"
        self.receipt = self.root / "bundle-receipt.json"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ)
        for name in ("PLAY_STORE_SERVICE_ACCOUNT_JSON", "PLAY_STORE_JSON_KEY",
                     "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", "GOOGLE_APPLICATION_CREDENTIALS",
                     "GOOGLE_SA_KEY_PATH", "GCLOUD_ACCOUNT"):
            self.env.pop(name, None)
        self.env.update({
            "PATH": str(self.bin) + os.pathsep + self.env["PATH"],
            "ANDROID_RELEASE_AAB": str(self.aab),
            "ANDROID_PACKAGE_NAME": "rw.mobi.app",
            "PLAY_RELEASE_TRACK": "internal", "PLAY_RELEASE_STATUS": "draft",
            "GOOGLE_PLAY_USE_GCLOUD_OAUTH": "true",
            "MOBIO_ANDROID_CANDIDATE_MANIFEST": str(self.candidate),
            "MOBIO_ANDROID_RELEASE_APPROVAL": str(self.approval),
            "MOBIO_FIXTURE_EVENT_LOG": str(self.events),
            "MOBIO_FIXTURE_BUNDLE_RECEIPT": str(self.receipt),
        })
        (release / "android_candidate_manifest.py").write_text('''
import hashlib, json, os, pathlib, sys
with open(os.environ["MOBIO_FIXTURE_EVENT_LOG"], "a") as log:
    log.write(json.dumps({"kind": "approval"}) + "\\n")
assert "verify" in sys.argv
candidate = pathlib.Path(sys.argv[sys.argv.index("--candidate") + 1])
assert json.loads(candidate.read_text())["source"]["version_code"] == 17
if os.environ.get("MOBIO_FIXTURE_REJECT_APPROVAL") == "true":
    raise SystemExit(2)
aab = pathlib.Path(sys.argv[sys.argv.index("--aab") + 1])
if os.environ.get("MOBIO_FIXTURE_BAD_VERIFIER_RECEIPT") == "true":
    print('{"status":"UNAVAILABLE","artifact_sha256":"unconfirmed"}')
    raise SystemExit(0)
print(json.dumps({"status": "BOUND_APPROVAL_VERIFIED",
                  "artifact_sha256": hashlib.sha256(aab.read_bytes()).hexdigest()}))
''')
        self.executable("gcloud", '''
import json, os, pathlib, sys
assert sys.argv[1:3] == ["auth", "print-access-token"]
with open(os.environ["MOBIO_FIXTURE_EVENT_LOG"], "a") as log:
    log.write(json.dumps({"kind": "oauth"}) + "\\n")
if os.environ.get("MOBIO_FIXTURE_REPLACE_CANDIDATE") == "true":
    pathlib.Path(os.environ["MOBIO_ANDROID_CANDIDATE_MANIFEST"]).write_text("not JSON")
print("synthetic-local-fixture-authorization")
''')
        self.executable("curl", '''
import json, os, pathlib, sys
args = sys.argv[1:]
url = args[-1]
if url.endswith("/edits"):
    kind, reply = "edit", '{"id":"fixture_edit"}'
elif "/bundles?uploadType=media" in url:
    kind = "bundle"
    uploaded = args[args.index("--data-binary") + 1]
    assert uploaded.startswith("@")
    assert pathlib.Path(uploaded[1:]).read_bytes() == b"synthetic already-approved AAB fixture"
    reply = pathlib.Path(os.environ["MOBIO_FIXTURE_BUNDLE_RECEIPT"]).read_text()
elif "/tracks/internal" in url:
    kind, reply = "track", "{}"
elif ":commit?" in url:
    kind, reply = "commit", "{}"
else:
    raise SystemExit("Unexpected fake provider invocation")
event = {"kind": kind, "url": url}
if kind == "track":
    assert args[args.index("-X") + 1] == "PUT"
    body = args[args.index("-d") + 1]
    event["body"] = json.loads(pathlib.Path(body[1:]).read_text())
with open(os.environ["MOBIO_FIXTURE_EVENT_LOG"], "a") as log:
    log.write(json.dumps(event) + "\\n")
print(reply)
''')

    def executable(self, name, source):
        target = self.bin / name
        target.write_text("#!" + sys.executable + "\n" + source)
        target.chmod(0o755)

    def run_receipt(self, raw):
        self.events.unlink(missing_ok=True)
        self.receipt.write_text(raw)
        result = subprocess.run(["bash", str(self.script)], cwd=self.root,
                                env=self.env, text=True, capture_output=True,
                                timeout=10, check=False)
        events = [json.loads(line) for line in self.events.read_text().splitlines()]
        return result, events

    def rejected(self, raw):
        result, events = self.run_receipt(raw)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("NO-GO: Google Play bundle receipt", result.stderr)
        self.assertEqual([row["kind"] for row in events],
                         ["approval", "oauth", "edit", "bundle"])
        self.assertNotIn("upload committed", result.stdout)

    def receipt_json(self, **fields):
        return json.dumps({"versionCode": 17, "sha256": self.artifact_sha, **fields})

    def test_matching_integer_receipt_updates_only_the_approved_track_version(self):
        result, events = self.run_receipt(self.receipt_json())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([row["kind"] for row in events],
                         ["approval", "oauth", "edit", "bundle", "track", "commit"])
        self.assertEqual(events[-2]["body"],
                         {"releases": [{"versionCodes": ["17"], "status": "draft"}]})
        self.assertIn("versionCode=17", result.stdout)

    def test_wrong_positive_integer_cannot_update_or_commit_a_track(self):
        self.rejected(self.receipt_json(versionCode=18))

    def test_missing_version_cannot_update_or_commit_a_track(self):
        self.rejected(json.dumps({"sha256": self.artifact_sha}))

    def test_mistyped_version_cannot_be_coerced_into_the_approved_identity(self):
        for value in ("17", True, 17.0, None, [17], {"code": 17}):
            with self.subTest(value=value):
                self.rejected(self.receipt_json(versionCode=value))

    def test_invalid_integer_range_cannot_update_or_commit_a_track(self):
        for value in (0, -17, 2147483648):
            with self.subTest(value=value):
                self.rejected(self.receipt_json(versionCode=value))

    def test_noncanonical_numeric_receipts_cannot_update_or_commit_a_track(self):
        for raw in ('{"versionCode":017,"sha256":"' + self.artifact_sha + '"}',
                    '{"versionCode":1.7e1,"sha256":"' + self.artifact_sha + '"}'):
            with self.subTest(raw=raw):
                self.rejected(raw)

    def test_duplicate_version_cannot_update_or_commit_a_track(self):
        self.rejected('{"versionCode":18,"versionCode":17,"sha256":"' + self.artifact_sha + '"}')

    def test_malformed_or_nonobject_receipt_cannot_update_or_commit_a_track(self):
        for raw in ('not JSON', 'null', '[17]', '17'):
            with self.subTest(raw=raw):
                self.rejected(raw)

    def test_rejected_approval_never_reaches_any_provider_fake(self):
        self.env["MOBIO_FIXTURE_REJECT_APPROVAL"] = "true"
        result, events = self.run_receipt(self.receipt_json())
        self.assertEqual(result.returncode, 2)
        self.assertEqual(events, [{"kind": "approval"}])

    def test_same_version_but_wrong_artifact_hash_cannot_update_or_commit_a_track(self):
        self.rejected(self.receipt_json(sha256="a" * 64))

    def test_missing_artifact_hash_cannot_update_or_commit_a_track(self):
        self.rejected('{"versionCode":17}')

    def test_mistyped_or_noncanonical_artifact_hash_cannot_update_or_commit_a_track(self):
        for value in (None, 17, True, [], {}, "", "a" * 63, "z" * 64, self.artifact_sha.upper()):
            with self.subTest(value=value):
                self.rejected(self.receipt_json(sha256=value))

    def test_approved_hash_comes_from_verifier_before_provider_access(self):
        self.env["MOBIO_FIXTURE_REPLACE_CANDIDATE"] = "true"
        result, events = self.run_receipt(self.receipt_json())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.candidate.read_text(), "not JSON")
        self.assertEqual([row["kind"] for row in events],
                         ["approval", "oauth", "edit", "bundle", "track", "commit"])

    def test_unusable_successful_verifier_receipt_never_reaches_a_provider(self):
        self.env["MOBIO_FIXTURE_BAD_VERIFIER_RECEIPT"] = "true"
        result, events = self.run_receipt(self.receipt_json())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("NO-GO: approved artifact verification receipt", result.stderr)
        self.assertEqual(events, [{"kind": "approval"}])


if __name__ == "__main__":
    unittest.main()
