#!/usr/bin/env python3
"""Write only public client configuration to a temporary Dart defines file."""

import json
import os
from pathlib import Path
import sys

REQUIRED = (
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "PRIVACY_POLICY_URL",
    "ACCOUNT_DELETION_URL",
)


def parse_dotenv(path):
    """Read literal values without executing shell syntax or expanding secrets."""
    if not path.exists():
        return {}
    values = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[len("export "):].strip()
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip("'\"")
    return values


def public_defines(dotenv, environment):
    values = {key: environment.get(key) or dotenv.get(key) for key in REQUIRED}
    missing = [key for key, value in values.items() if not value]
    if missing:
        raise ValueError(
            "Missing " + ", ".join(missing)
            + ". Add them to .env or export them before building."
        )
    return values


def main():
    if len(sys.argv) != 2:
        print("Usage: runtime_defines.py OUTPUT_FILE", file=sys.stderr)
        return 2
    try:
        values = public_defines(parse_dotenv(Path(".env")), os.environ)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    output = Path(sys.argv[1])
    # mktemp callers already create a private file; also protect direct use.
    descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
        os.fchmod(stream.fileno(), 0o600)
        json.dump(values, stream)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
