"""Exercise real PWA candidate verification and the gated publishing process.

The prepared site comes from the actual packager/stamper with synthetic compiled
input. Evidence/signatures and the deployment adapter are explicitly fixtures.
No provider, live approval key, Flutter build or deployment is used.
"""
import base64
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("pwa_candidate", ROOT / "scripts/web/pwa_candidate_manifest.py")
MANIFEST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MANIFEST)
KEY = b"synthetic-pwa-approval-key-for-tests-only"
TARGET = {"account": "a" * 32, "project": "synthetic-mobio", "branch": "main", "environment": "Fixture"}


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, sort_keys=True) + "\n")


def timestamp(value):
    return value.replace(microsecond=0).isoformat().replace("+00:00", "Z")


class PwaCandidateManifestTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base_temp = tempfile.TemporaryDirectory(prefix="mobio-pwa-base-")
        cls.base = Path(cls.base_temp.name).resolve()
        for directory in ("landing", "web"):
            shutil.copytree(ROOT / directory, cls.base / directory)
        for name in (
            "scripts/web/pwa_candidate_manifest.py", "scripts/web/deploy_cloudflare_pwas.sh",
            "scripts/web/prepare_pwa_bundles.sh", "scripts/web/verify_pwa_bundles.sh",
            "scripts/web/stamp_bundle.py", "scripts/web/version_assets.py",
            "scripts/web/pages_worker.mjs", "scripts/web/admin_service_worker.js",
            "scripts/lib/flutter.sh", "scripts/lib/runtime_defines.py", "pubspec.yaml",
            "supabase/hardening/2026-09-28/manifest.json", "services/face-inference/model-manifest.json",
        ):
            destination = cls.base / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, destination)
        (cls.base / ".gitignore").write_text("build/\n__pycache__/\n*.pyc\n")
        cls.git(cls.base, "init", "--quiet")
        cls.git(cls.base, "config", "user.email", "synthetic@example.invalid")
        cls.git(cls.base, "config", "user.name", "Synthetic PWA Fixture")
        cls.git(cls.base, "add", ".")
        cls.git(cls.base, "commit", "--quiet", "-m", "Synthetic source fixture")
        compiled = cls.base / "build/synthetic-web"
        shutil.copytree(cls.base / "web", compiled)
        (compiled / "index.html").write_text(
            (compiled / "index.html").read_text().replace("$FLUTTER_BASE_HREF", "/"))
        (compiled / "flutter_bootstrap.js").write_text(
            "// Explicit synthetic compiled fixture.\nvar _flutter={}; _flutter.loader.load({});")
        (compiled / "main.dart.js").write_text("// Explicit synthetic compiled fixture.\n")
        flutter = cls.base / "build/tools/flutter"
        flutter.parent.mkdir(parents=True)
        flutter.write_text("#!/bin/sh\nexit 0\n")
        flutter.chmod(0o700)
        environment = {
            **os.environ, "FLUTTER_BIN": str(flutter), "SKIP_FLUTTER_BUILD": "true",
            "WEB_BUILD_DIR": str(compiled), "SUPABASE_URL": "https://synthetic.invalid",
            "SUPABASE_ANON_KEY": "synthetic-public-key",
            "PRIVACY_POLICY_URL": "https://synthetic.invalid/privacy",
            "ACCOUNT_DELETION_URL": "https://synthetic.invalid/delete",
        }
        environment.pop("PREVIOUS_SITE_DIR", None)
        environment.pop("APPLE_TEAM_ID", None)
        result = subprocess.run(["bash", "scripts/web/prepare_pwa_bundles.sh", "build/pwa"],
                                cwd=cls.base, env=environment, text=True, capture_output=True, timeout=60)
        if result.returncode:
            raise AssertionError(result.stdout + result.stderr)
        cls.base_site = cls.base / "build/pwa/site"
        cls.release = json.loads((cls.base_site / "release.json").read_text())
        assert cls.release["working_tree_dirty"] is False
        assert "_worker.js" in cls.release["files"]

    @classmethod
    def tearDownClass(cls):
        cls.base_temp.cleanup()

    @staticmethod
    def git(root, *args):
        return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mobio-pwa-case-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve() / "repo"
        shutil.copytree(self.base, self.root)
        self.site = self.root / "build/pwa/site"
        self.candidate_path = self.root / "build/pwa-candidate.json"
        self.approval_path = self.root / "build/approval/approval.json"
        self.log = self.root / "build/npx-publish.json"
        adapter = self.root / "build/tools/npx"
        adapter.write_text('''#!/usr/bin/env python3
import hashlib,json,os,pathlib,sys
if sys.argv[1:] == ['--no-install','wrangler','--version']:
    print(os.environ.get('SYNTHETIC_WRANGLER_VERSION','4.135.0'))
    raise SystemExit(0)
assert sys.argv[1:5] == ['--no-install','wrangler','pages','deploy'], sys.argv
site=pathlib.Path(sys.argv[5]); files=[]
for p in sorted(site.rglob('*')):
    if p.is_file():
        data=p.read_bytes()
        files.append({'file':p.relative_to(site).as_posix(),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
files.sort(key=lambda row:row['file'])
digest=hashlib.sha256(json.dumps(files,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()).hexdigest()
pathlib.Path(os.environ['SYNTHETIC_PUBLISH_LOG']).write_text(json.dumps({
    'argv':sys.argv[1:],'artifact_sha256':digest,'account':os.environ['CLOUDFLARE_ACCOUNT_ID'],
    'approval_key_forwarded':'MOBIO_PWA_RELEASE_APPROVAL_HMAC_KEY_B64' in os.environ,
    'site':str(site),'read_only':all((p.stat().st_mode & 0o222)==0 for p in site.rglob('*'))}))
''')
        adapter.chmod(0o700)
        self.environment = {
            **os.environ, "PATH": str(adapter.parent) + os.pathsep + os.environ["PATH"],
            "GITHUB_ACTOR": "fixture-builder", "GITHUB_RUN_ID": "fixture-run",
            "MOBIO_PWA_RELEASE_APPROVAL_HMAC_KEY_B64": base64.b64encode(KEY).decode(),
            "CLOUDFLARE_API_TOKEN": "synthetic-never-sent-to-provider",
            "SYNTHETIC_PUBLISH_LOG": str(self.log),
        }
        self.environment.pop("APPLE_TEAM_ID", None)
        result = self.cli("create", "--out", str(self.candidate_path))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.candidate = json.loads(self.candidate_path.read_text())
        self.candidate_sha = MANIFEST.checksum(self.candidate_path)
        self.created = MANIFEST.parsed_time(self.candidate["created_at"], "fixture")
        self.approval = {
            "schema_version": 1, "candidate_sha256": self.candidate_sha,
            "reviewer": "fixture-release-owner", "approved_at": timestamp(self.created + timedelta(seconds=1)),
            "destination": dict(TARGET), "checks": [],
        }
        for check_id in sorted(MANIFEST.CHECKS):
            path = self.approval_path.parent / (check_id + ".json")
            write_json(path, {
                "schema_version": 1, "check_id": check_id, "status": "passed",
                "commit": self.candidate["source"]["commit"],
                "artifact_sha256": self.candidate["source"]["artifact"]["sha256"],
                "candidate_sha256": self.candidate_sha, "destination": dict(TARGET),
                "completed_at": timestamp(self.created),
                "evidence_ref": "https://synthetic.invalid/observations/" + check_id,
            })
            self.approval["checks"].append({"id": check_id, "file": path.name, "sha256": MANIFEST.checksum(path)})
        self.sign_approval()

    def sign_approval(self):
        self.approval.pop("signature_hmac_sha256", None)
        self.approval["signature_hmac_sha256"] = hmac.new(
            KEY, MANIFEST.canonical(self.approval), hashlib.sha256).hexdigest()
        write_json(self.approval_path, self.approval)

    def cli(self, command, *extra, target=None, shell=False):
        arguments = ["--site", str(self.site)]
        for key, value in (target or TARGET).items():
            arguments.extend(["--" + key, value])
        if command != "create":
            arguments.extend(["--candidate", str(self.candidate_path), "--approval", str(self.approval_path)])
        if shell:
            process = ["bash", str(self.root / "scripts/web/deploy_cloudflare_pwas.sh")]
        else:
            process = ["python3", str(self.root / "scripts/web/pwa_candidate_manifest.py"),
                       "--root", str(self.root), command]
        return subprocess.run(process + arguments + list(extra), cwd=self.root, env=self.environment,
                              text=True, capture_output=True, timeout=60)

    def reject(self, **kwargs):
        result = self.cli("promote", **kwargs)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.log.exists(), "Invalid candidate reached the publish adapter")
        return result

    def receipt(self, mutate, check_id="flutter_full"):
        pointer = next(row for row in self.approval["checks"] if row["id"] == check_id)
        path = self.approval_path.parent / pointer["file"]
        value = json.loads(path.read_text())
        mutate(value)
        write_json(path, value)
        pointer["sha256"] = MANIFEST.checksum(path)
        self.sign_approval()

    def test_actual_packaged_site_validates_then_publishes_exact_readonly_copy(self):
        result = self.cli("verify")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(json.loads(result.stdout)["checks"], 12)
        result = self.cli("promote", shell=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        published = json.loads(self.log.read_text())
        self.assertEqual(published["artifact_sha256"], self.candidate["source"]["artifact"]["sha256"])
        self.assertEqual(published["account"], TARGET["account"])
        self.assertIn("--project-name=" + TARGET["project"], published["argv"])
        self.assertIn("--branch=main", published["argv"])
        self.assertNotEqual(published["site"], str(self.site))
        self.assertTrue(published["read_only"])
        self.assertFalse(published["approval_key_forwarded"])
        self.assertFalse(Path(published["site"]).exists())
        self.assertEqual(MANIFEST.tree_state(self.site), self.candidate["source"]["artifact"])

    def test_missing_approval_blocks_real_shell_entrypoint(self):
        self.approval_path.unlink()
        self.reject(shell=True)

    def test_missing_candidate_blocks(self):
        self.candidate_path.unlink()
        self.reject()

    def test_missing_receipt_blocks(self):
        (self.approval_path.parent / "pwa_browser.json").unlink()
        self.reject()

    def test_missing_required_check_blocks(self):
        self.approval["checks"].pop()
        self.sign_approval()
        self.reject()

    def test_example_candidate_or_approval_is_ineligible_even_with_matching_hashes(self):
        previous = self.approval_path
        self.approval_path = previous.with_name("approval.example.json")
        shutil.copy2(previous, self.approval_path)
        self.reject()
        self.approval_path = previous
        previous = self.candidate_path
        self.candidate_path = previous.with_name("candidate.example.json")
        shutil.copy2(previous, self.candidate_path)
        self.reject()

    def test_duplicate_or_unknown_check_blocks(self):
        for check_id in (self.approval["checks"][0]["id"], "optional-substitute"):
            with self.subTest(check_id=check_id):
                self.approval["checks"][-1]["id"] = check_id
                self.sign_approval()
                self.reject()

    def test_nonpassed_required_statuses_block(self):
        for status in ("failed", "skipped", "unavailable", "not_applicable", "PASS", None):
            with self.subTest(status=status):
                self.receipt(lambda row: row.update(status=status))
                self.reject()

    def test_each_missing_required_gate_blocks(self):
        original = list(self.approval["checks"])
        for check_id in MANIFEST.CHECKS:
            with self.subTest(check_id=check_id):
                self.approval["checks"] = [row for row in original if row["id"] != check_id]
                self.sign_approval()
                self.reject()

    def test_wrong_receipt_commit_artifact_candidate_and_destination_block(self):
        for field, wrong in (
            ("commit", "b" * 40), ("artifact_sha256", "b" * 64),
            ("candidate_sha256", "b" * 64), ("destination", {**TARGET, "branch": "preview"}),
        ):
            with self.subTest(field=field):
                original = json.loads((self.approval_path.parent / "flutter_full.json").read_text())[field]
                self.receipt(lambda row: row.update({field: wrong}))
                self.reject()
                self.receipt(lambda row: row.update({field: original}))

    def test_wrong_requested_destination_blocks(self):
        for key, wrong in (("account", "b" * 32), ("project", "other-site"),
                           ("branch", "preview"), ("environment", "Other")):
            with self.subTest(key=key):
                self.reject(target={**TARGET, key: wrong})

    def test_wrong_signed_approval_destination_blocks(self):
        self.approval["destination"]["branch"] = "preview"
        self.sign_approval()
        self.reject()

    def test_self_approval_case_insensitive_blocks(self):
        self.approval["reviewer"] = "FIXTURE-BUILDER"
        self.sign_approval()
        self.reject()

    def test_tampered_signature_and_missing_key_block(self):
        self.approval["signature_hmac_sha256"] = "0" * 64
        write_json(self.approval_path, self.approval)
        self.reject()
        self.sign_approval()
        self.environment.pop("MOBIO_PWA_RELEASE_APPROVAL_HMAC_KEY_B64")
        self.reject()

    def test_stale_or_future_candidate_blocks(self):
        for offset in (-15, 1):
            with self.subTest(days=offset):
                self.candidate["created_at"] = timestamp(datetime.now(timezone.utc) + timedelta(days=offset))
                write_json(self.candidate_path, self.candidate)
                self.reject()

    def test_stale_predating_or_future_approval_blocks(self):
        for offset in (-8, -1, 1):
            with self.subTest(days=offset):
                self.approval["approved_at"] = timestamp(self.created + timedelta(days=offset))
                self.sign_approval()
                self.reject()

    def test_receipt_outside_candidate_review_window_blocks(self):
        for offset in (-1, 60):
            with self.subTest(seconds=offset):
                self.receipt(lambda row: row.update(completed_at=timestamp(self.created + timedelta(seconds=offset))))
                self.reject()

    def test_receipt_hash_tamper_blocks(self):
        path = self.approval_path.parent / "pwa_browser.json"
        path.write_text(path.read_text() + " ")
        self.reject()

    def test_unsafe_example_parent_and_symlink_evidence_paths_block(self):
        pointer = self.approval["checks"][0]
        for name in ("../outside.json", "/absolute.json", "./receipt.json", "receipt.example.json", "a\\b.json"):
            with self.subTest(name=name):
                pointer["file"] = name
                self.sign_approval()
                self.reject()

    def test_symlink_parent_evidence_blocks(self):
        path = self.approval_path.parent / "pwa_browser.json"
        alias = self.approval_path.parent / "alias"
        alias.symlink_to(path.parent, target_is_directory=True)
        pointer = next(row for row in self.approval["checks"] if row["id"] == "pwa_browser")
        pointer["file"] = "alias/pwa_browser.json"
        self.sign_approval()
        self.reject()

    def test_duplicate_json_key_and_unknown_schema_fields_block(self):
        self.approval_path.write_text(self.approval_path.read_text().replace(
            '"schema_version": 1', '"schema_version": 1, "schema_version": 1'))
        self.reject()
        self.approval["disable_gate"] = True
        self.sign_approval()
        self.reject()

    def test_unknown_or_abbreviated_flags_block(self):
        for flag in ("--skip-checks", "--appro"):
            result = self.cli("promote", flag, "anything", shell=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(self.log.exists())

    def test_legacy_positional_deployment_call_cannot_rebuild_or_publish(self):
        result = subprocess.run(["bash", str(self.root / "scripts/web/deploy_cloudflare_pwas.sh"), "main", "build/pwa"],
                                cwd=self.root, env=self.environment, text=True, capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.log.exists())

    def test_modified_added_or_missing_site_file_blocks(self):
        original = (self.site / "main.dart.js").read_bytes()
        for mutation in ("changed", "extra", "missing"):
            with self.subTest(mutation=mutation):
                if mutation == "changed":
                    (self.site / "main.dart.js").write_text("tampered compiled application")
                elif mutation == "extra":
                    (self.site / "extra.js").write_text("unreviewed file")
                else:
                    (self.site / "main.dart.js").unlink()
                self.reject()
                (self.site / "main.dart.js").write_bytes(original)
                (self.site / "extra.js").unlink(missing_ok=True)

    def test_restamped_incomplete_or_misrouted_site_cannot_become_a_candidate(self):
        # Hashing a changed manifest is insufficient: candidate creation must
        # independently reject a structurally valid but misrouted consumer app.
        path = self.site / "app-manifest.json"
        value = json.loads(path.read_text())
        value["start_url"] = "/admin-auth"
        write_json(path, value)
        release = json.loads((self.site / "release.json").read_text())
        release["files"]["app-manifest.json"] = MANIFEST.checksum(path)
        write_json(self.site / "release.json", release)
        result = self.cli("create", "--out", str(self.root / "build/wrong-route-candidate.json"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("bundle contract", result.stderr)
        self.assertFalse(self.log.exists())

    def test_forged_worker_or_release_inventory_cannot_become_a_candidate(self):
        path = self.site / "_worker.js"
        path.write_text("// different route security implementation\n")
        release = json.loads((self.site / "release.json").read_text())
        release["files"]["_worker.js"] = MANIFEST.checksum(path)
        write_json(self.site / "release.json", release)
        result = self.cli("create", "--out", str(self.root / "build/wrong-worker-candidate.json"))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("worker differs", result.stderr)
        self.assertFalse(self.log.exists())

    def test_dirty_source_blocks(self):
        (self.root / "pubspec.yaml").write_text((self.root / "pubspec.yaml").read_text() + "\n# changed\n")
        self.reject()

    def test_clean_new_commit_blocks_old_candidate(self):
        (self.root / "source-change.txt").write_text("different committed source\n")
        self.git(self.root, "add", ".")
        self.git(self.root, "commit", "--quiet", "-m", "Different source")
        self.reject()

    def test_symlink_hardlink_and_fifo_in_site_block(self):
        added = self.site / "unsafe"
        for kind in ("symlink", "hardlink", "fifo"):
            with self.subTest(kind=kind):
                if kind == "symlink":
                    added.symlink_to(self.site / "main.dart.js")
                elif kind == "hardlink":
                    os.link(self.site / "main.dart.js", added)
                else:
                    os.mkfifo(added)
                self.reject()
                added.unlink()

    def test_symlink_site_directory_blocks(self):
        actual = self.site.with_name("actual-site")
        self.site.rename(actual)
        self.site.symlink_to(actual, target_is_directory=True)
        self.reject()

    def test_oversized_file_and_json_block_without_reading_unbounded_input(self):
        oversized = self.site / "oversized.bin"
        with oversized.open("wb") as stream:
            stream.truncate(MANIFEST.MAX_FILE_BYTES + 1)
        self.reject()
        oversized.unlink()
        with self.approval_path.open("wb") as stream:
            stream.truncate(MANIFEST.MAX_JSON_BYTES + 1)
        self.reject()

    def test_missing_or_wrong_local_deployment_tool_blocks(self):
        self.environment["SYNTHETIC_WRANGLER_VERSION"] = "4.0.0"
        self.reject()

    def test_missing_deployment_credential_blocks_after_local_verification(self):
        self.environment.pop("CLOUDFLARE_API_TOKEN")
        self.reject()

    def test_required_set_cannot_be_changed_by_environment(self):
        self.environment["SKIP_PWA_BROWSER"] = "true"
        self.approval["checks"] = [row for row in self.approval["checks"] if row["id"] != "pwa_browser"]
        self.sign_approval()
        self.reject()

    def test_workflow_entrypoints_build_and_upload_without_publishing_credentials(self):
        workflow = (ROOT / ".github/workflows/cloudflare-pwa.yml").read_text()
        self.assertIn("./scripts/ci/verify_flutter.sh", workflow)
        self.assertIn("REQUIRE_LINKED_SUPABASE: 'true'", workflow)
        self.assertIn("pwa_candidate_manifest.py create", workflow)
        self.assertIn("pages-release-candidate", workflow)
        self.assertIn("include-hidden-files: true", workflow)
        self.assertNotIn("pages deploy", workflow)
        self.assertNotIn("CLOUDFLARE_API_TOKEN", workflow)
        self.assertNotIn("continue-on-error", workflow)
        self.assertIn("uses: ./.github/workflows/cloudflare-pwa.yml",
                      (ROOT / ".github/workflows/cloudflare-pages.yml").read_text())


if __name__ == "__main__":
    unittest.main()
