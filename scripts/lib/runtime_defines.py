#!/usr/bin/env python3
"""Write only public client configuration to a temporary Dart defines file."""

import argparse
import json
import os
from pathlib import Path
import re
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


def public_defines(dotenv, environment, platform=None):
    required = REQUIRED + (("FIREBASE_IOS_APP_ID",) if platform == "ios" else ())
    values = {key: environment.get(key) or dotenv.get(key) for key in required}
    missing = [key for key, value in values.items() if not value]
    if missing:
        raise ValueError(
            "Missing " + ", ".join(missing)
            + ". Add them to .env or export them before building."
        )
    if platform == "ios":
        if not re.fullmatch(r"1:[0-9]+:ios:[0-9a-f]+", values["FIREBASE_IOS_APP_ID"]):
            raise ValueError("FIREBASE_IOS_APP_ID must be a registered iOS Firebase App ID.")
        for key in ("FIREBASE_IOS_API_KEY", "FIREBASE_IOS_BUNDLE_ID"):
            value = environment.get(key) or dotenv.get(key)
            if value:
                values[key] = value
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output_file", type=Path)
    parser.add_argument("--platform", choices=("ios",))
    args = parser.parse_args()
    try:
        values = public_defines(parse_dotenv(Path(".env")), os.environ, args.platform)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 1
    output = args.output_file
    # mktemp callers already create a private file; also protect direct use.
    descriptor = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
        os.fchmod(stream.fileno(), 0o600)
        json.dump(values, stream)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
