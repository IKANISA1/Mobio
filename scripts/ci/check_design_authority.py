#!/usr/bin/env python3
"""Enforce the external Revolut authority boundary, not visual acceptance."""

from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
AUTHORITY_DOCUMENTS = (
    "AGENTS.md",
    "CRITICAL_RULES.md",
    "docs/design/README.md",
    "packages/design-system/README.md",
)
RETIRED_SPEC_NAMES = frozenset({
    "design.md",
    "admin_design_system.md",
    "design_system_audit.md",
    "revolut_secondary_palette_critical_analysis_2026-06-09.md",
})
TEXT_SUFFIXES = frozenset({".md", ".dart", ".html", ".css", ".json", ".yaml", ".yml", ".sh"})
# Source snapshots, hash inventories and raw release captures record prior facts.
# They are deliberately excluded from instructions, not promoted to authority.
FACTUAL_EVIDENCE_PREFIXES = (
    "docs/drive-imports/",
    "docs/release/evidence/",
)
COMPETING_INSPIRATION = re.compile(
    r"soft\s+liquid\s+glass|sovereign\s+architect|claymorph(?:ism|ic)?|neumorph(?:ism|ic)?"
    r"|(?:uber|bolt|stripe|apple|material)\s*[- ]\s*(?:style|inspired|like)"
    r"|(?:inspired\s+by|design\s+(?:reference|authority)\s*[:=])\s*(?:uber|bolt|stripe|apple|material)\b"
    r"|material\s+design\s+(?:reference|authority|inspiration)",
    re.I,
)
LOCAL_SPEC_INSTRUCTION = re.compile(
    r"(?:follow|update|source\s+of\s+truth|sole\s+(?:source|authority))[^\n]{0,100}"
    r"(?:design\.md|admin_design_system\.md)",
    re.I,
)
MARKDOWN_TARGET = re.compile(r"\]\(<?([^\n)]*?)>?\)")


def authority_binding_errors(root: Path) -> list[str]:
    errors = []
    registry = root / "docs/design/authority.json"
    try:
        record = json.loads(registry.read_text(encoding="utf-8"))
        authority = record["authority"]
        if authority["skill_id"] != "revolut-design" or authority["role"] != "sole_design_authority":
            errors.append("docs/design/authority.json: must bind revolut-design as sole design authority")
        bindings = [authority["entrypoint"], *authority["bundled_references"]]
        if not bindings[0]["path"].endswith("/revolut-design/SKILL.md"):
            errors.append("docs/design/authority.json: invalid external skill entrypoint")
        for binding in bindings:
            path = Path(binding["path"])
            digest = binding["sha256"]
            if not re.fullmatch(r"[a-f0-9]{64}", digest):
                errors.append(f"docs/design/authority.json: invalid SHA-256 for {path.name}")
                continue
            if not path.is_absolute() or path.resolve().is_relative_to(root.resolve()):
                errors.append(f"docs/design/authority.json: authority must remain external ({path.name})")
                continue
            if path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                errors.append(f"docs/design/authority.json: external authority hash changed ({path.name})")
        if not {"native_android", "native_ios", "consumer_web", "public_website", "admin_web"}.issubset(record["declared_surfaces"]):
            errors.append("docs/design/authority.json: declared surfaces are incomplete")
        if record["acceptance"]["mobile_rule"] != "MOBILE-DESIGN-100":
            errors.append("docs/design/authority.json: mobile acceptance rule must remain MOBILE-DESIGN-100")
    except (OSError, ValueError, KeyError, TypeError) as error:
        errors.append(f"docs/design/authority.json: missing or invalid authority binding ({error})")
    return errors


def authority_errors(root: Path, files: list[str]) -> list[str]:
    """Inspect live instructions and references while preserving factual records."""
    errors = authority_binding_errors(root)
    for relative in AUTHORITY_DOCUMENTS:
        path = root / relative
        if not path.is_file():
            errors.append(f"{relative}: missing design-authority entry point")
            continue
        source = path.read_text(encoding="utf-8")
        if "revolut-design/SKILL.md" not in source or not re.search(
            r"sole\s+(?:visual\s+)?design\s+authority", source, re.I
        ):
            errors.append(f"{relative}: must identify the external skill as sole design authority")
        if not all(re.search(rf"\b{surface}\b", source, re.I) for surface in ("app", "web", "admin")):
            errors.append(f"{relative}: authority must cover app, web and admin")

    for relative in sorted(set(files)):
        path = root / relative
        if not path.is_file():
            continue
        if path.name.lower() in RETIRED_SPEC_NAMES:
            errors.append(f"{relative}: deleted local design specification must not be restored")
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES or relative.startswith(FACTUAL_EVIDENCE_PREFIXES):
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        for line_number, line in enumerate(source.splitlines(), 1):
            if COMPETING_INSPIRATION.search(line):
                errors.append(f"{relative}:{line_number}: competing design inspiration")
            for target in MARKDOWN_TARGET.findall(line):
                target_name = target.rstrip(">").split("#", 1)[0].rsplit("/", 1)[-1].lower()
                if target_name in RETIRED_SPEC_NAMES:
                    errors.append(f"{relative}:{line_number}: active link to deleted local specification")
            if LOCAL_SPEC_INSTRUCTION.search(line):
                errors.append(f"{relative}:{line_number}: local specification used as an instruction")
    return errors


def main() -> int:
    files = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-files", "-z", "--cached", "--others", "--exclude-standard"]
    ).decode().split("\0")
    files = [path for path in files if path]
    errors = authority_errors(ROOT, files)
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"Design authority passed: external revolut-design; {len(set(files))} indexed paths. Visual acceptance remains separate.")
    record = json.loads((ROOT / "docs/design/authority.json").read_text())
    bindings = [record["authority"]["entrypoint"], *record["authority"]["bundled_references"]]
    verified = sum(Path(binding["path"]).is_file() for binding in bindings)
    print(f"External authority hashes verified locally: {verified}/{len(bindings)}; unavailable external files remain unverified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
