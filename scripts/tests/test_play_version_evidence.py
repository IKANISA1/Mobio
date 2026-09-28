import importlib.util
from pathlib import Path
import unittest
spec=importlib.util.spec_from_file_location('version_check',Path(__file__).resolve().parents[2]/'scripts/release/check_play_version_evidence.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class VersionEvidenceTests(unittest.TestCase):
    def test_exact(self): self.assertTrue(module.matches('Version code: 16\n','16'))
    def test_markdown(self): self.assertTrue(module.matches('- Version code: `16`\n','16'))
    def test_prefix_rejected(self): self.assertFalse(module.matches('Version code: 160\n','16'))
    def test_suffix_rejected(self): self.assertFalse(module.matches('Version code: 16-unverified\n','16'))
    def test_conflicting_declarations_rejected(self): self.assertFalse(module.matches('Version code: 16\nVersion code: 17','16'))
    def test_missing_rejected(self): self.assertFalse(module.matches('16','16'))
    def test_invalid_expected_rejected(self): self.assertFalse(module.matches('Version code: 16\n','16|17'))
    def test_unmatched_quote_rejected(self): self.assertFalse(module.matches('Version code: `16\n','16'))
if __name__=='__main__': unittest.main()
