import unittest

from source_contract_helpers import compact_source


class SourceTokenTests(unittest.TestCase):
    def test_code_whitespace_is_neutral(self):
        self.assertEqual(compact_source('requireCurrent(\n account\n);'), 'requireCurrent(account);')

    def test_comments_cannot_substitute_for_a_guard(self):
        self.assertEqual(compact_source('// requireCurrent(account);\n/* revoke(); */ return;'), 'return;')

    def test_quoted_values_retain_whitespace_and_comment_markers(self):
        self.assertEqual(compact_source("const url = 'https://example.test/a b';"), "consturl='https://example.test/a b';")


if __name__ == '__main__':
    unittest.main()
