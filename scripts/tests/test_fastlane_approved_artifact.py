#!/usr/bin/env python3
"""Execute the shipped Fastfile with isolated local verifier/upload fakes.

These fixtures exercise staging and lane control flow, not real approval,
credentials, a Fastlane installation, or Google Play. The actual candidate
validator's cryptographic and AAB checks have a separate test suite.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
LANES = ("deploy", "upload_aab")


class FastlaneApprovedArtifactTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        fastlane = self.root / "android/fastlane"
        fastlane.mkdir(parents=True)
        shutil.copyfile(ROOT / "android/fastlane/Fastfile", fastlane / "Fastfile")
        release = self.root / "scripts/release"
        release.mkdir(parents=True)
        self.aab = self.root / "original.aab"
        self.original_bytes = b"synthetic approved AAB bytes"
        self.aab.write_bytes(self.original_bytes)
        self.aab.chmod(0o640)
        self.original_sha = hashlib.sha256(self.original_bytes).hexdigest()
        self.receipt = self.root / "verifier-receipt.json"
        self.events = self.root / "events.jsonl"
        self.staging = self.root / "temporary-staging"
        self.staging.mkdir(mode=0o700)
        self.env = dict(os.environ)
        for key in tuple(self.env):
            if key.startswith(("PLAY_", "MOBIO_ANDROID_")):
                self.env.pop(key)
        self.env.update({
            "ANDROID_RELEASE_AAB": str(self.aab),
            "MOBIO_ANDROID_CANDIDATE_MANIFEST": "candidate.json",
            "MOBIO_ANDROID_RELEASE_APPROVAL": "approval.json",
            "PLAY_STORE_SERVICE_ACCOUNT_JSON": "synthetic-local-fixture",
            "PLAY_RELEASE_TRACK": "beta",
            "PLAY_RELEASE_STATUS": "inProgress",
            "MOBIO_FASTLANE_FIXTURE_ROOT": str(self.root),
            "MOBIO_FASTLANE_FIXTURE_EVENTS": str(self.events),
            "TMPDIR": str(self.staging),
        })
        (release / "android_candidate_manifest.py").write_text('''
import json, os, pathlib, sys
root = pathlib.Path(os.environ["MOBIO_FASTLANE_FIXTURE_ROOT"])
def argument(name):
    return sys.argv[sys.argv.index(name) + 1]
with open(os.environ["MOBIO_FASTLANE_FIXTURE_EVENTS"], "a") as stream:
    stream.write(json.dumps({"kind": "verification", "arguments": sys.argv[1:],
                             "track": argument("--track"),
                             "status": argument("--release-status")}) + "\\n")
if os.environ.get("MOBIO_FASTLANE_FIXTURE_DENIED") == "true":
    print("synthetic denied approval", file=sys.stderr)
    raise SystemExit(2)
mutation = os.environ.get("MOBIO_FASTLANE_FIXTURE_MUTATION")
aab = pathlib.Path(argument("--aab"))
if mutation == "replace":
    aab.write_bytes(b"changed immediately after verifier approval")
elif mutation == "symlink":
    other = root / "other.aab"
    other.write_bytes(b"replacement through symbolic link")
    aab.unlink()
    aab.symlink_to(other)
elif mutation == "fifo":
    aab.unlink()
    os.mkfifo(aab)
sys.stdout.write((root / "verifier-receipt.json").read_text())
''')
        self.harness = self.root / "run_lane.rb"
        self.harness.write_text('''
require "json"
require "digest"
$fixture_lanes = {}
def fixture_event(event)
  File.open(ENV.fetch("MOBIO_FASTLANE_FIXTURE_EVENTS"), "a") do |stream|
    stream.puts(JSON.generate(event))
  end
end
def default_platform(_name); end
def platform(_name); yield; end
def desc(_description); end
def lane(name, &block); $fixture_lanes[name.to_s] = block; end
module UI
  def self.user_error!(message); raise RuntimeError, message; end
end
class << ENV
  alias fixture_original_fetch fetch
  def fetch(name, *defaults, &block)
    fixture_event("kind" => "credentials") if name == "PLAY_STORE_SERVICE_ACCOUNT_JSON"
    fixture_original_fetch(name, *defaults, &block)
  end
end
def upload_to_play_store(options)
  original = ENV.fetch("ANDROID_RELEASE_AAB")
  path = options.fetch(:aab)
  before = Digest::SHA256.file(path).hexdigest
  if ENV["MOBIO_FASTLANE_FIXTURE_MUTATE_ON_UPLOAD"] == "true"
    File.binwrite(original, "changed at provider invocation")
  end
  fixture_event("kind" => "upload", "options" => options,
                "aab_sha256" => Digest::SHA256.file(path).hexdigest,
                "aab_sha256_before" => before,
                "mode" => File.stat(path).mode & 0777,
                "directory_mode" => File.stat(File.dirname(path)).mode & 0777,
                "regular" => File.lstat(path).file?,
                "source_mode" => File.stat(original).mode & 0777)
  raise "synthetic upload failure" if ENV["MOBIO_FASTLANE_FIXTURE_UPLOAD_FAIL"] == "true"
end
begin
  load File.join(ENV.fetch("MOBIO_FASTLANE_FIXTURE_ROOT"), "android/fastlane/Fastfile")
  $fixture_lanes.fetch(ARGV.fetch(0)).call
  puts JSON.generate("status" => "completed")
rescue StandardError => error
  puts JSON.generate("status" => "failed", "error" => error.message)
  exit 1
end
''')

    def run_lane(self, lane, receipt=None, raw_receipt=None):
        self.events.unlink(missing_ok=True)
        track = self.env["PLAY_RELEASE_TRACK"] if lane == "deploy" else "internal"
        if raw_receipt is None:
            if receipt is None:
                receipt = {"status": "BOUND_APPROVAL_VERIFIED",
                           "artifact_sha256": self.original_sha, "track": track}
            raw_receipt = json.dumps(receipt)
        self.receipt.write_text(raw_receipt)
        result = subprocess.run(
            ["ruby", str(self.harness), lane], cwd=self.root / "android",
            env=self.env, text=True, capture_output=True, timeout=10, check=False,
        )
        self.assertEqual(list(self.staging.iterdir()), [], result.stdout + result.stderr)
        events = ([json.loads(row) for row in self.events.read_text().splitlines()]
                  if self.events.exists() else [])
        for event in events:
            if event["kind"] == "upload":
                self.assertFalse(Path(event["options"]["aab"]).parent.exists())
        return result, events

    def assert_blocked(self, result, events):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("credentials", [row["kind"] for row in events])
        self.assertNotIn("upload", [row["kind"] for row in events])

    def assert_upload(self, lane, result, events, *, failed=False):
        self.assertEqual(result.returncode, 1 if failed else 0, result.stdout + result.stderr)
        self.assertEqual([row["kind"] for row in events],
                         ["verification", "credentials", "upload"])
        verification, _, upload = events
        track = self.env["PLAY_RELEASE_TRACK"] if lane == "deploy" else "internal"
        status = self.env["PLAY_RELEASE_STATUS"] if lane == "deploy" else "draft"
        self.assertEqual(verification["track"], track)
        self.assertEqual(verification["status"], status)
        self.assertEqual(upload["options"]["track"], track)
        self.assertEqual(upload["options"]["release_status"], status)
        self.assertEqual(upload["options"]["json_key_data"], "synthetic-local-fixture")
        self.assertEqual(upload["aab_sha256_before"], self.original_sha)
        self.assertEqual(upload["aab_sha256"], self.original_sha)
        self.assertNotEqual(Path(upload["options"]["aab"]), self.aab)
        self.assertEqual(upload["mode"], 0o444)
        self.assertEqual(upload["directory_mode"], 0o700)
        self.assertEqual(upload["source_mode"], 0o640)
        self.assertTrue(upload["regular"])
        for key in ("skip_upload_apk", "skip_upload_metadata", "skip_upload_images",
                    "skip_upload_screenshots"):
            self.assertIs(upload["options"][key], True)

    def test_both_lanes_upload_only_private_verified_copy_and_leave_source_unchanged(self):
        for lane in LANES:
            with self.subTest(lane=lane):
                self.assert_upload(lane, *self.run_lane(lane))
                self.assertEqual(self.aab.read_bytes(), self.original_bytes)
                self.assertEqual(self.aab.stat().st_mode & 0o777, 0o640)

    def test_both_lanes_deny_failed_verification_before_credentials(self):
        self.env["MOBIO_FASTLANE_FIXTURE_DENIED"] = "true"
        for lane in LANES:
            with self.subTest(lane=lane):
                self.assert_blocked(*self.run_lane(lane))
                self.assertEqual(self.aab.read_bytes(), self.original_bytes)

    def test_both_lanes_block_artifact_replaced_immediately_after_verification(self):
        self.env["MOBIO_FASTLANE_FIXTURE_MUTATION"] = "replace"
        for lane in LANES:
            with self.subTest(lane=lane):
                self.aab.write_bytes(self.original_bytes)
                result, events = self.run_lane(lane)
                self.assert_blocked(result, events)
                self.assertIn("changed after verification", result.stdout)

    def test_both_lanes_block_symlink_replacement_and_cleanup(self):
        self.env["MOBIO_FASTLANE_FIXTURE_MUTATION"] = "symlink"
        for lane in LANES:
            with self.subTest(lane=lane):
                if self.aab.is_symlink():
                    self.aab.unlink()
                    self.aab.write_bytes(self.original_bytes)
                self.assert_blocked(*self.run_lane(lane))

    def test_both_lanes_reject_nonregular_source_without_blocking(self):
        self.env["MOBIO_FASTLANE_FIXTURE_MUTATION"] = "fifo"
        for lane in LANES:
            with self.subTest(lane=lane):
                if self.aab.exists() and not self.aab.is_file():
                    self.aab.unlink()
                    self.aab.write_bytes(self.original_bytes)
                self.assert_blocked(*self.run_lane(lane))

    def test_both_lanes_cleanup_when_upload_raises_and_preserve_source(self):
        self.env["MOBIO_FASTLANE_FIXTURE_UPLOAD_FAIL"] = "true"
        for lane in LANES:
            with self.subTest(lane=lane):
                self.assert_upload(lane, *self.run_lane(lane), failed=True)
                self.assertEqual(self.aab.read_bytes(), self.original_bytes)

    def test_both_lanes_staged_copy_survives_original_replacement_at_upload(self):
        self.env["MOBIO_FASTLANE_FIXTURE_MUTATE_ON_UPLOAD"] = "true"
        for lane in LANES:
            with self.subTest(lane=lane):
                self.aab.write_bytes(self.original_bytes)
                self.assert_upload(lane, *self.run_lane(lane))
                self.assertNotEqual(self.aab.read_bytes(), self.original_bytes)

    def test_both_lanes_reject_malformed_or_empty_verifier_output(self):
        for lane in LANES:
            for raw in ("", "not JSON", '{"status":'):
                with self.subTest(lane=lane, receipt=raw):
                    self.assert_blocked(*self.run_lane(lane, raw_receipt=raw))

    def test_both_lanes_reject_missing_or_unusable_digest_receipt(self):
        for lane in LANES:
            track = "beta" if lane == "deploy" else "internal"
            for digest in (None, 123, "a" * 63, "A" * 64, "a" * 64 + "\n"):
                with self.subTest(lane=lane, digest=digest):
                    receipt = {"status": "BOUND_APPROVAL_VERIFIED", "track": track}
                    if digest is not None:
                        receipt["artifact_sha256"] = digest
                    self.assert_blocked(*self.run_lane(lane, receipt=receipt))

    def test_both_lanes_reject_receipt_without_matching_status_track_or_object(self):
        for lane in LANES:
            for receipt in ([], None, True, 12, "approved",
                            {"artifact_sha256": self.original_sha},
                            {"status": "UNAVAILABLE", "artifact_sha256": self.original_sha},
                            {"status": "BOUND_APPROVAL_VERIFIED",
                             "artifact_sha256": self.original_sha, "track": "wrong"}):
                with self.subTest(lane=lane, receipt=receipt):
                    self.assert_blocked(*self.run_lane(lane, raw_receipt=json.dumps(receipt)))

    def test_both_lanes_require_approval_paths_before_verifier_or_credentials(self):
        for missing in ("MOBIO_ANDROID_CANDIDATE_MANIFEST", "MOBIO_ANDROID_RELEASE_APPROVAL"):
            value = self.env.pop(missing)
            for lane in LANES:
                with self.subTest(lane=lane, missing=missing):
                    result, events = self.run_lane(lane)
                    self.assert_blocked(result, events)
                    self.assertEqual(events, [])
            self.env[missing] = value

    def test_both_lanes_cleanup_if_credentials_are_missing(self):
        self.env.pop("PLAY_STORE_SERVICE_ACCOUNT_JSON")
        for lane in LANES:
            with self.subTest(lane=lane):
                result, events = self.run_lane(lane)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual([row["kind"] for row in events], ["verification", "credentials"])
                self.assertEqual(self.aab.read_bytes(), self.original_bytes)

    def test_deploy_passes_production_completed_binding_only_with_explicit_track_authority(self):
        self.env.update({"PLAY_RELEASE_TRACK": "production", "PLAY_RELEASE_STATUS": "completed"})
        result, events = self.run_lane("deploy")
        self.assert_blocked(result, events)
        self.assertEqual(events, [])
        self.env["PLAY_PRODUCTION_APPROVED"] = "true"
        self.assert_upload("deploy", *self.run_lane("deploy"))

    def test_retired_lanes_never_verify_or_upload(self):
        for lane in ("build_and_deploy", "metadata", "promote_to_production"):
            with self.subTest(lane=lane):
                result, events = self.run_lane(lane)
                self.assert_blocked(result, events)
                self.assertEqual(events, [])


if __name__ == "__main__":
    unittest.main()
