"""Cross-project deletion prevention and owned-resource absence checks."""
import importlib.util
import json
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'qa/cleanup_supabase_fixture.py'
SPEC = importlib.util.spec_from_file_location('mobio_fixture_cleanup', SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class FakeDocker:
    def __init__(self, project='mobio_replay_123'):
        self.project = project
        self.resources = {'container': ['c123'], 'volume': ['v123'], 'network': ['n123']}
        self.names = {'c123': 'supabase_db_' + project,
                      'v123': 'supabase_db_' + project,
                      'n123': 'supabase_network_' + project}
        self.labels = {key: project for key in self.names}
        self.calls = []
        self.removed = []

    def __call__(self, args):
        self.calls.append(args)
        if '--filter' in args:
            if args[args.index('--filter') + 1] != 'label=com.supabase.cli.project=' + self.project:
                raise AssertionError('Unscoped Docker list')
            kind = 'container' if args[0] == 'ps' else args[0]
            return '\n'.join(self.resources[kind])
        if 'inspect' in args:
            identifier = args[-1]
            if args[args.index('--format') + 1] == '{{.Name}}':
                return self.names[identifier]
            return json.dumps({'com.supabase.cli.project': self.labels[identifier]})
        identifier = args[-1]
        for kind, items in self.resources.items():
            if identifier in items:
                items.remove(identifier)
                self.removed.append(identifier)
                return identifier
        raise AssertionError('Unselected resource removal')


class DisposableFixtureCleanupTests(unittest.TestCase):
    def test_exact_owned_resources_removed_without_daemon_prune(self):
        docker = FakeDocker()
        result = MODULE.cleanup_fixture(docker.project, docker)
        self.assertEqual(docker.removed, ['c123', 'v123', 'n123'])
        self.assertFalse(any(result['remaining_owned'].values()))
        self.assertFalse(any('prune' in args for args in docker.calls))

    def test_foreign_label_or_name_aborts_before_any_removal(self):
        for change in ('label', 'name'):
            with self.subTest(change=change):
                docker = FakeDocker()
                if change == 'label':
                    docker.labels['n123'] = 'unrelated_project'
                else:
                    docker.names['n123'] = 'supabase_network_unrelated_project'
                with self.assertRaises(MODULE.FixtureCleanupError):
                    MODULE.cleanup_fixture(docker.project, docker)
                self.assertEqual(docker.removed, [])

    def test_invalid_project_rejected_before_docker_access(self):
        for project in ('', 'other_project', 'mobio_123;docker prune', '../mobio_123'):
            with self.subTest(project=project):
                docker = FakeDocker()
                with self.assertRaises(MODULE.FixtureCleanupError):
                    MODULE.cleanup_fixture(project, docker)
                self.assertEqual(docker.calls, [])


if __name__ == '__main__':
    unittest.main()
