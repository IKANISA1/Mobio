#!/usr/bin/env python3
"""Check an exact version declaration. Not proof of upload or release approval."""
import argparse
from pathlib import Path
import re
import sys

PREFIX = re.compile(r'^[ \t]*(?:[-*][ \t]+)?Version code:', re.I)
DECLARATION = re.compile(r'^[ \t]*(?:[-*][ \t]+)?Version code:[ \t]*(?:`([1-9][0-9]*)`|([1-9][0-9]*))[ \t]*$',re.I)

def matches(text: str, expected: str) -> bool:
    if not re.fullmatch(r'[1-9][0-9]*',expected):
        return False
    declarations=[line for line in text.splitlines() if PREFIX.match(line)]
    if len(declarations)!=1:
        return False
    match=DECLARATION.fullmatch(declarations[0])
    return bool(match and (match.group(1) or match.group(2))==expected)

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence',type=Path);parser.add_argument('expected')
    args=parser.parse_args()
    try:
        if args.evidence.is_symlink() or args.evidence.stat().st_size>1_000_000:
            raise ValueError('Evidence must be a bounded regular file')
        valid=matches(args.evidence.read_text(encoding='utf-8'),args.expected)
    except (OSError,ValueError):
        valid=False
    if not valid:
        print('NO-GO: one exact current Version code declaration is required',file=sys.stderr)
        return 1
    print('Version code declaration matches; independent upload proof is still required')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
