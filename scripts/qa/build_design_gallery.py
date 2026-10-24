#!/usr/bin/env python3
"""Launch the external revolut-design gallery with Mobio's evidence config."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
REPORT_KEYS = (
    "component_report", "supplement_report", "website_report",
    "behavior_report", "keyboard_report", "matrix_report",
)
ADMIN_REPORTS = {
    "admin_browser_report": "exhaustive-admin/admin_browser_qa.json",
    "admin_flow_report": "exhaustive-admin-flows/summary.json",
}


def preflight_reports(root: Path, config: dict, source_sha256: str) -> list[str]:
    """Reject report media that predates any actual Mobio UI source change."""
    evidence = Path(config.get("evidence", "build/qa/design-review"))
    if not evidence.is_absolute():
        evidence = root / evidence
    missing = []
    errors = []
    reports = [(key, config.get(key)) for key in REPORT_KEYS]
    reports.extend((key, evidence / value) for key, value in ADMIN_REPORTS.items())
    for key, value in reports:
        if not value:
            continue
        path = Path(value)
        if not path.is_absolute():
            base = root if path.parts[0] in {".cache", "docs", "assets", "output", "build"} else evidence
            path = base / path
        if not path.exists():
            missing.append(key)
            continue
        try:
            report = json.loads(path.read_text(encoding="utf-8"))
            current = isinstance(report, dict) and report.get("source_sha256") == source_sha256
        except (OSError, ValueError):
            current = False
        if not current:
            errors.append(
                f"{key} ({path}): missing or stale source_sha256. Rerun or recapture this review "
                "against current Mobio sources and bind its top-level source_sha256 to the output "
                "of scripts/qa/design_source_fingerprint.py."
            )
    if errors:
        raise ValueError("\n".join(errors))
    return missing


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("docs/design/review-gallery-config.json"))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--website-mobile", type=Path, help=argparse.SUPPRESS)
    parser.add_argument("--website-desktop", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.website_mobile or args.website_desktop:
        parser.error("Loose website captures are no longer supported. Record current captures in the configured website_report with their review evidence.")

    try:
        binding = json.loads((ROOT / "docs/design/authority.json").read_text(encoding="utf-8"))["authority"]
        if binding["skill_id"] != "revolut-design" or binding["role"] != "sole_design_authority":
            raise ValueError("Mobio must bind revolut-design as sole_design_authority")
        entrypoint = Path(binding["entrypoint"]["path"])
        if not entrypoint.is_absolute() or entrypoint.resolve().is_relative_to(ROOT.resolve()):
            raise ValueError("The design skill must remain outside the repository")
        if entrypoint.parent.name != "revolut-design" or entrypoint.name != "SKILL.md":
            raise ValueError("Invalid revolut-design entrypoint")
        generator = entrypoint.parent / "scripts/build_review_gallery.py"
        if not entrypoint.is_file() or not generator.is_file():
            raise ValueError(f"External revolut-design gallery unavailable: {generator}")
        config_path = args.config if args.config.is_absolute() else ROOT / args.config
        config = json.loads(config_path.read_text(encoding="utf-8"))
        inventory = Path(config["inventory"])
        inventory_path = inventory if inventory.is_absolute() else ROOT / inventory
        if not inventory_path.is_file():
            raise ValueError(f"Current product review inventory unavailable: {inventory_path}")
        source_result = subprocess.run(
            [sys.executable, str(ROOT / "scripts/qa/design_source_fingerprint.py")],
            cwd=ROOT, check=True, capture_output=True, text=True,
        )
        source_sha256 = json.loads(source_result.stdout)["source_sha256"]
        missing = preflight_reports(ROOT, config, source_sha256)
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        parser.error(str(error))

    if missing:
        print("Review evidence unverified; absent configured reports: " + ", ".join(missing), file=sys.stderr)
    command = [sys.executable, str(generator), "--project-root", str(ROOT), "--config", str(config_path)]
    if args.output:
        command.extend(["--output", str(args.output.resolve())])
    return subprocess.run(command, cwd=ROOT, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
