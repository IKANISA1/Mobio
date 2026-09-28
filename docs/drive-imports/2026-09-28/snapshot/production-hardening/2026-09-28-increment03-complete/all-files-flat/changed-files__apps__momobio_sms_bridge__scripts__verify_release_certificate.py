#!/usr/bin/env python3
"""Verify apksigner output against an independently approved SHA-256 (no signing)."""
import re
import sys
from pathlib import Path


def verify(text: str, expected: str) -> None:
    digest = expected.replace(":", "").strip().lower()
    if not re.fullmatch(r"[0-9a-f]{64}", digest):
        raise ValueError("An exact approved SHA-256 certificate digest is required")
    found = re.findall(r"^Signer #\d+ certificate SHA-256 digest: ([0-9A-Fa-f]{64})\s*$", text, re.M)
    if len(found) != 1 or found[0].lower() != digest:
        raise ValueError("Release certificate mismatch or ambiguous signer set")
    if re.search(r"^Signer #\d+ certificate DN:.*(?:CN=Android Debug|OU=Android)", text, re.M | re.I):
        raise ValueError("Debug certificate is forbidden for operational collection")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("Usage: verify_release_certificate.py apksigner-output expected-sha256")
        verify(Path(sys.argv[1]).read_text(encoding="utf-8"), sys.argv[2])
    except (ValueError, OSError) as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(1)
    print("Approved release certificate verified")
