"""Regression tests for shipped release scripts; no mobile/device claims."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[2]
SHA = 'a' * 40

class ActionPinTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.workflows = self.root / '.github/workflows'
        self.workflows.mkdir(parents=True)
        self.script = ROOT / 'scripts/ci/check_github_actions_pinned.py'

    def run_yaml(self, text):
        (self.workflows / 'caller.yml').write_text(text)
        return subprocess.run(['python3', str(self.script), '--root', str(self.root)],
                              text=True, capture_output=True, timeout=10, check=False)

    def run_ref(self, ref, job=False):
        prefix = 'jobs:\n  build:\n    uses: ' if job else 'jobs:\n  build:\n    steps:\n      - uses: '
        return self.run_yaml(prefix + ref + '\n')

    def test_pinned_action(self):
        self.assertEqual(self.run_ref('actions/checkout@' + SHA).returncode, 0)

    def test_quoted_pinned_action(self):
        self.assertEqual(self.run_ref('"actions/checkout@' + SHA + '"').returncode, 0)

    def test_tag_rejected(self):
        self.assertEqual(self.run_ref('actions/checkout@v4').returncode, 1)

    def test_short_sha_rejected(self):
        self.assertEqual(self.run_ref('actions/checkout@' + SHA[:12]).returncode, 1)

    def test_flow_style_is_checked(self):
        result = self.run_yaml('jobs: {build: {steps: [{uses: "actions/checkout@v4"}]}}\n')
        self.assertEqual(result.returncode, 1)

    def test_run_block_does_not_create_false_action(self):
        result = self.run_yaml('jobs:\n  build:\n    steps:\n      - run: |\n          uses: example/unpinned@v1\n')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_local_reusable_workflow(self):
        (self.workflows / 'child.yml').write_text('jobs: {build: {steps: [{run: echo ok}]}}\n')
        result = self.run_ref('./.github/workflows/child.yml', job=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_local_dollar_workflow(self):
        (self.workflows / 'child.yml').write_text('jobs: {build: {steps: [{run: echo ok}]}}\n')
        result = self.run_ref('$/.github/workflows/child.yml', job=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_github_ancestor_symlink_rejected(self):
        original = self.root / '.github'
        destination = self.root / 'alternate'
        original.rename(destination)
        original.symlink_to(destination, target_is_directory=True)
        self.assertEqual(self.run_ref('actions/checkout@' + SHA).returncode, 1)

    def test_dollar_step_path_rejected(self):
        self.assertEqual(self.run_ref('$/.github/workflows/child.yml').returncode, 1)

    def test_local_action_directory(self):
        action = self.root / '.github/actions/setup'
        action.mkdir(parents=True)
        (action / 'action.yml').write_text('name: Setup\nruns: {using: composite, steps: []}\n')
        self.assertEqual(self.run_ref('./.github/actions/setup').returncode, 0)

    def test_local_action_without_metadata_rejected(self):
        (self.root / 'empty').mkdir()
        self.assertEqual(self.run_ref('./empty').returncode, 1)

    def test_missing_local_workflow_rejected(self):
        self.assertEqual(self.run_ref('./.github/workflows/missing.yml', job=True).returncode, 1)

    def test_traversal_rejected(self):
        self.assertEqual(self.run_ref('./.github/workflows/../escape.yml', job=True).returncode, 1)

    def test_local_symlink_rejected(self):
        (self.root / 'other.yml').write_text('jobs: {}')
        (self.workflows / 'child.yml').symlink_to(self.root / 'other.yml')
        self.assertEqual(self.run_ref('./.github/workflows/child.yml', job=True).returncode, 1)

    def test_docker_digest(self):
        self.assertEqual(self.run_ref('docker://alpine@sha256:' + 'a' * 64).returncode, 0)

    def test_docker_tag_rejected(self):
        self.assertEqual(self.run_ref('docker://alpine:3').returncode, 1)

    def test_dynamic_reference_rejected(self):
        self.assertEqual(self.run_ref('"${{ inputs.action }}"').returncode, 1)

    def test_duplicate_keys_rejected(self):
        self.assertEqual(self.run_yaml('jobs: {build: {steps: [], steps: []}}').returncode, 1)

    def test_malformed_yaml_rejected(self):
        self.assertEqual(self.run_yaml('jobs: {').returncode, 1)

    def test_non_string_reference_rejected(self):
        self.assertEqual(self.run_ref('null').returncode, 1)

    def test_remote_workflow_path_required(self):
        self.assertEqual(self.run_ref('actions/checkout@' + SHA, job=True).returncode, 1)
        self.assertEqual(self.run_ref('owner/repo/.github/workflows/build.yml@' + SHA, job=True).returncode, 0)

    def test_empty_workflow_directory_rejected(self):
        result = subprocess.run(['python3', str(self.script), '--root', str(self.root)],
                                text=True, capture_output=True, timeout=10, check=False)
        self.assertEqual(result.returncode, 1)

class IntegratedGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.script = self.root / 'scripts/qa/verify_mobio_feature_readiness.sh'
        self.script.parent.mkdir(parents=True)
        shutil.copyfile(ROOT / 'scripts/qa/verify_mobio_feature_readiness.sh', self.script)
        self.env = dict(os.environ)
        self.env.update(RUN_MOBIO_CONTRACT_TESTS='true', RUN_MOBIO_BIOPAY_FEATURE_GATE='true')

    def run_script(self):
        return subprocess.run(['bash', str(self.script)], env=self.env, text=True,
                              capture_output=True, timeout=10, check=False)

    def install_fixtures(self, flutter_exit=0, biopay_exit=0):
        lib = self.root / 'scripts/lib/flutter.sh'
        lib.parent.mkdir(parents=True)
        lib.write_text('FLUTTER_BIN="' + str(self.root / 'fixture-flutter') + '"\n')
        binary = self.root / 'fixture-flutter'
        binary.write_text('#!/bin/sh\nexit ' + str(flutter_exit) + '\n')
        binary.chmod(0o755)
        child = self.root / 'scripts/qa/verify_biopay_live_readiness.sh'
        child.write_text('#!/bin/sh\nexit ' + str(biopay_exit) + '\n')
        child.chmod(0o755)

    def test_disabled_invalid_and_empty_rejected_before_flutter(self):
        for variable in ('RUN_MOBIO_CONTRACT_TESTS', 'RUN_MOBIO_BIOPAY_FEATURE_GATE'):
            for value in ('false', '0', 'yes', ''):
                with self.subTest(variable=variable, value=value):
                    self.env.update(RUN_MOBIO_CONTRACT_TESTS='true', RUN_MOBIO_BIOPAY_FEATURE_GATE='true')
                    self.env[variable] = value
                    result = self.run_script()
                    self.assertEqual(result.returncode, 2, result.stderr)
                    self.assertIn('INCOMPLETE:', result.stderr)
                    self.assertNotIn('PASS:', result.stdout)

    def test_both_disabled_rejected(self):
        self.env.update(RUN_MOBIO_CONTRACT_TESTS='false', RUN_MOBIO_BIOPAY_FEATURE_GATE='false')
        self.assertEqual(self.run_script().returncode, 2)

    def test_required_fixture_checks_pass(self):
        self.install_fixtures()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('PASS: Mobio integrated feature readiness gates passed.', result.stdout)

    def test_failing_flutter_blocks(self):
        self.install_fixtures(flutter_exit=1)
        result = self.run_script()
        self.assertEqual(result.returncode, 1)
        self.assertNotIn('PASS: Mobio integrated', result.stdout)

    def test_incomplete_child_blocks(self):
        self.install_fixtures(biopay_exit=2)
        self.assertEqual(self.run_script().returncode, 1)

    def test_missing_tool_blocks(self):
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('PASS:', result.stdout)

class CiRequiredGateTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.workflow = yaml.safe_load((ROOT / '.github/workflows/ci.yml').read_text())

    def test_signed_android_build_is_unavailable_without_signing_material(self):
        steps = self.workflow['jobs']['flutter']['steps']
        step = next(step for step in steps if step.get('name') == 'Build AAB (release)')
        with tempfile.TemporaryDirectory() as directory:
            environment = dict(os.environ)
            environment.update({
                'SUPABASE_URL': 'https://fixture.invalid',
                'SUPABASE_ANON_KEY': 'fixture-public-anon',
                'PRIVACY_POLICY_URL': 'https://fixture.invalid/privacy',
                'ACCOUNT_DELETION_URL': 'https://fixture.invalid/delete',
                'KEYSTORE_BASE64': '', 'KEY_ALIAS': '',
                'KEY_PASSWORD': '', 'STORE_PASSWORD': '',
            })
            result = subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', step['run']],
                                    cwd=directory, env=environment, text=True,
                                    capture_output=True, timeout=10, check=False)
        self.assertEqual(result.returncode, 2)
        self.assertIn('UNAVAILABLE: signed release AAB', result.stderr)

    def test_backend_ci_requires_linked_security_checks(self):
        steps = self.workflow['jobs']['backend']['steps']
        step = next(step for step in steps if step.get('name') == 'Verify backend contract')
        self.assertEqual(step['env']['REQUIRE_LINKED_SUPABASE'], 'true')

if __name__ == '__main__':
    unittest.main()
