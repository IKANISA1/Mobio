"""Fixture validation of the preparer; never calls Supabase or a database."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/ci/prepare_hardening_migrations.py'
spec = importlib.util.spec_from_file_location('prepare', SCRIPT)
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)

class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bundle = self.root / prepare.BUNDLE
        self.bundle.mkdir(parents=True)
        self.migrations = self.root / 'supabase/migrations'
        self.migrations.mkdir()
        self.entries = []
        for i, name in enumerate(('alpha', 'beta'), 1):
            body = f'-- body {name}\nselect 1;\n'
            filename = f'{i:02}_{name}.sql'
            (self.bundle / filename).write_text(body)
            self.entries.append({'file':filename, 'migration_name':'mobio_hardening_'+name,
                                 'sha256':hashlib.sha256(body.encode()).hexdigest()})
        self.write_manifest()

    def write_manifest(self):
        (self.bundle / 'manifest.json').write_text(json.dumps({'schema_version':1,'bodies':self.entries}))

    def install(self, index, timestamp):
        row = self.entries[index]
        target = self.migrations / f'{timestamp}_{row["migration_name"]}.sql'
        target.write_bytes((self.bundle / row['file']).read_bytes())
        return target

    def test_missing_bodies_remain_pending(self):
        self.assertEqual([r['installed'] for r in prepare.plan(self.root)], [None, None])

    def test_exact_ordered_migrations_accepted(self):
        self.install(0, '20260928010101')
        self.install(1, '20260928010102')
        self.assertTrue(all(r['installed'] for r in prepare.plan(self.root)))

    def test_modified_body_rejected(self):
        (self.bundle / self.entries[0]['file']).write_text('altered')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            prepare.plan(self.root)

    def test_modified_generated_migration_never_overwritten(self):
        target = self.install(0, '20260928010101')
        target.write_text('existing applied migration')
        with self.assertRaisesRegex(ValueError, 'do not overwrite'):
            prepare.plan(self.root)
        self.assertEqual(target.read_text(), 'existing applied migration')

    def test_duplicate_generated_migration_rejected(self):
        self.install(0, '20260928010101')
        self.install(0, '20260928010102')
        with self.assertRaisesRegex(ValueError, 'Multiple migrations'):
            prepare.plan(self.root)

    def test_reverse_order_rejected(self):
        self.install(0, '20260928010102')
        self.install(1, '20260928010101')
        with self.assertRaisesRegex(ValueError, 'order'):
            prepare.plan(self.root)

    def test_later_body_without_prior_rejected(self):
        self.install(1, '20260928010102')
        with self.assertRaisesRegex(ValueError, 'order'):
            prepare.plan(self.root)

    def test_duplicate_existing_timestamp_rejected(self):
        (self.migrations/'20260928010101_foo.sql').write_text('')
        (self.migrations/'20260928010101_bar.sql').write_text('')
        with self.assertRaisesRegex(ValueError, 'Duplicate existing'):
            prepare.plan(self.root)

    def test_body_symlink_rejected(self):
        target=self.bundle/self.entries[0]['file']
        copy=self.root/'external.sql'; copy.write_bytes(target.read_bytes())
        target.unlink();target.symlink_to(copy)
        with self.assertRaisesRegex(ValueError,'Symlink'):
            prepare.plan(self.root)

    def test_missing_cli_is_not_success(self):
        with patch.object(prepare.shutil,'which',return_value=None):
            with self.assertRaisesRegex(RuntimeError,'CLI unavailable'):
                prepare.generate(self.root,'supabase',prepare.plan(self.root))
        self.assertEqual(list(self.migrations.glob('*.sql')),[])

    def test_cli_filename_generation_protocol_without_database(self):
        commands=[]
        def fixture_run(command, **kwargs):
            commands.append(command)
            if command[-1]!='--help':
                timestamp='2026092801010'+str(len(commands))
                (self.migrations/f'{timestamp}_{command[-1]}.sql').write_text('')
        with patch.object(prepare.shutil,'which',return_value='/fixture/supabase'), \
             patch.object(prepare.subprocess,'run',side_effect=fixture_run), \
             patch.object(prepare.time,'sleep'):
            prepare.generate(self.root,'supabase',prepare.plan(self.root))
        self.assertEqual(len(commands),3)
        self.assertTrue(all(c[1:3]==['migration','new'] for c in commands))
        self.assertTrue(all(r['installed'] for r in prepare.plan(self.root)))

    def test_nonempty_cli_result_not_overwritten(self):
        def fixture_run(command, **kwargs):
            if command[-1]!='--help':
                (self.migrations/f'20260928010101_{command[-1]}.sql').write_text('unexpected content')
        with patch.object(prepare.shutil,'which',return_value='/fixture/supabase'), \
             patch.object(prepare.subprocess,'run',side_effect=fixture_run):
            with self.assertRaisesRegex(RuntimeError,'not an empty'):
                prepare.generate(self.root,'supabase',prepare.plan(self.root))
        self.assertEqual(next(self.migrations.glob('*.sql')).read_text(),'unexpected content')

if __name__=='__main__':
    unittest.main()
