"""Formatting-neutral source tokens for explicitly static integration checks.

Keep quoted values intact and remove comments, so formatting changes cannot fail
an assertion and a comment cannot substitute for an executable guard. These
checks complement the Dart/SQL behavior suites; they do not execute Dart.
"""
import re

_TOKENS = re.compile(
    r"r?'(?:\\.|[^'\\])*'|r?\"(?:\\.|[^\"\\])*\"|//[^\n]*|/\*.*?\*/|\s+|.",
    re.DOTALL,
)


def compact_source(source):
    return ''.join(
        token for token in _TOKENS.findall(source)
        if not token.isspace() and not token.startswith(('//', '/*'))
    )
