import importlib.util
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('privacy_runner',ROOT/'scripts/qa/test_privacy_postgres.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
class RunnerGuards(unittest.TestCase):
    def test_official_short_digest(self):
        value='postgres@sha256:'+'1'*64
        self.assertEqual(runner.validate_image(value),value)
    def test_official_qualified_digest(self):
        value='docker.io/library/postgres@sha256:'+'a'*64
        self.assertEqual(runner.validate_image(value),value)
    def test_floating_tag_rejected(self):
        with self.assertRaises(ValueError):runner.validate_image('postgres:17')
    def test_custom_registry_rejected(self):
        with self.assertRaises(ValueError):runner.validate_image('registry.invalid/postgres@sha256:'+'a'*64)
    def test_missing_configuration_rejected(self):
        with self.assertRaises(ValueError):runner.validate_image('')
    def test_command_suffix_rejected(self):
        with self.assertRaises(ValueError):runner.validate_image('postgres@sha256:'+'a'*64+';command')
    def test_newline_rejected(self):
        with self.assertRaises(ValueError):runner.validate_image('postgres@sha256:'+'a'*64+'\n')
    def test_non_digest_rejected(self):
        with self.assertRaises(ValueError):runner.validate_image('postgres@sha256:'+'z'*64)
    def test_external_database_uri_rejected(self):
        with self.assertRaises(ValueError):runner.validate_image('postgres://example.invalid/db')
    def test_sql_quote_is_literal(self):
        self.assertEqual(runner.quote("a'b"),"'a''b'")
if __name__=='__main__':unittest.main()
