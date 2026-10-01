#!/usr/bin/env python3
"""Index a completed Flutter expanded log without accepting visual differences."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import tempfile
from urllib.parse import unquote

ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
BLOCK = re.compile(r"^══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK[^\n]*\n"
                   r"(.*?)^═{20,}[ \t]*$", re.M | re.S)
PIXEL = re.compile(r'Golden "([^"\n]+)":\s*Pixel test failed,\s*'
                   r"([0-9]+(?:\.[0-9]+)?)%,\s*(\d+)px\s+diff\s+detected\.")
PROGRESS = r"(?P<elapsed>\d+(?::\d+){1,2}) \+(?P<passed>\d+)" \
           r"(?: ~(?P<skipped>\d+))?(?: -(?P<failed>\d+))?: "
ERROR = re.compile(r"^" + PROGRESS + r"(?P<file>.+?\.dart): (?P<name>.*?) \[E\]$", re.M)
TERMINAL = re.compile(r"^" + PROGRESS + r"Some tests failed\.$", re.M)
STATUS = "unclassified_pending_visual_review"
IMAGE_ROLES = ("masterImage", "testImage", "isolatedDiff", "maskedDiff")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative_file(root: Path, name: str, *, required: bool = True) -> Path:
    parts = PurePosixPath(name)
    if (not name or parts.is_absolute() or str(parts) != name
            or any(p in (".", "..") for p in parts.parts) or "\\" in name):
        raise ValueError(f"Unsafe relative path: {name!r}")
    path = root / name
    if not path.resolve().is_relative_to(root):
        raise ValueError(f"Path escapes the repository: {name}")
    if any((root.joinpath(*parts.parts[:i])).is_symlink()
           for i in range(1, len(parts.parts) + 1)):
        raise ValueError(f"Symlink is not regular evidence: {name}")
    if required and not path.is_file():
        raise ValueError(f"Missing regular file: {name}")
    return path


def test_file(root: Path, value: str) -> Path:
    path = Path(unquote(value))
    if not path.is_absolute() or not path.is_relative_to(root):
        raise ValueError(f"Test file is outside the repository: {value}")
    relative = path.relative_to(root).as_posix()
    if not relative.startswith("test/") or not relative.endswith("_test.dart"):
        raise ValueError(f"Unsupported test identity: {value}")
    return relative_file(root, relative)


def build_index(root: Path, log: Path, source_manifest: Path) -> dict:
    root = root.resolve()
    raw = log.read_bytes()
    text = ANSI.sub("", raw.decode("utf-8"))
    manifest_bytes = source_manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    if not re.fullmatch(r"[0-9a-f]{40}", manifest.get("head", "")):
        raise ValueError("Source manifest requires an exact recorded commit")
    recorded = {}
    for item in manifest.get("files", []):
        name, sha = item.get("file", ""), item.get("sha256", "")
        relative_file(root, name, required=False)
        if name in recorded or not re.fullmatch(r"[0-9a-f]{64}", sha):
            raise ValueError("Invalid or duplicate source-manifest record")
        recorded[name] = sha
    if not recorded:
        raise ValueError("Source manifest has no recorded files")
    terminals = list(TERMINAL.finditer(text))
    blocks, errors = list(BLOCK.finditer(text)), list(ERROR.finditer(text))
    if len(terminals) != 1 or not errors or not blocks:
        raise ValueError("Missing unique completed failure summary or failed cases")
    terminal = terminals[0]
    if (text.count("══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK") != len(blocks)
            or len(PIXEL.findall(text)) != len(blocks)
            or len(re.findall(r"^.* \[E\]$", text, re.M)) != len(errors)
            or any(m.end() > terminal.start() for m in blocks + errors)):
        raise ValueError("Truncated, unmatched or nonvisual failure evidence")
    pending, rows, seen_tests = {}, [], set()
    for _, kind, match in sorted([(m.start(), "block", m) for m in blocks]
                                 + [(m.start(), "error", m) for m in errors]):
        if kind == "block":
            body = match.group(1)
            diagnostics = PIXEL.findall(body)
            stack_files = set(re.findall(r"file://([^\s()]*_test\.dart):\d+:\d+", body))
            if len(diagnostics) != 1 or len(stack_files) != 1:
                raise ValueError("Failure must have one pixel diagnostic and one originating test file")
            owner = test_file(root, stack_files.pop())
            pending.setdefault(owner, []).append(diagnostics[0])
            continue
        owner = test_file(root, match.group("file"))
        identity = (owner, match.group("name"))
        queue = pending.get(owner, [])
        if len(queue) != 1 or identity in seen_tests:
            raise ValueError("Failed case has no unique preceding golden exception")
        seen_tests.add(identity)
        golden, pct, pixels = queue.pop()
        if not re.fullmatch(r"goldens/[A-Za-z0-9_./-]+\.png", golden):
            raise ValueError(f"Unsupported golden path: {golden!r}")
        relative_file(owner.parent, golden)
        baseline = relative_file(root, (owner.parent / golden).relative_to(root).as_posix())
        name, sha = baseline.relative_to(root).as_posix(), digest(baseline)
        if recorded.get(name) != sha or not 0 <= float(pct) <= 100 or int(pixels) <= 0:
            raise ValueError(f"Invalid pixel data or baseline differs from recorded source: {name}")
        rows.append({"baseline_path": name, "pixel_diff_pct": pct,
                     "review_status": STATUS, "baseline_sha256": sha,
                     "different_pixels": int(pixels), "test_file": owner.relative_to(root).as_posix(),
                     "test_name": match.group("name")})
    if (any(pending.values()) or len(rows) != int(terminal.group("failed") or 0)
            or len({r["baseline_path"] for r in rows}) != len(rows)):
        raise ValueError("Summary counts, exceptions, failed cases or unique baselines do not reconcile")
    rows.sort(key=lambda row: row["baseline_path"])
    keys = [(str(Path(r["test_file"]).parent / "failures"), Path(r["baseline_path"]).stem)
            for r in rows]
    for row, key in zip(rows, keys):
        images = {}
        for role in IMAGE_ROLES:
            name = f"{key[0]}/{key[1]}_{role}.png"
            try:
                path = relative_file(root, name)
                images[role] = {"path": name, "sha256": digest(path), "status": "present_unverified_run"}
            except ValueError:
                images[role] = {"path": name, "status": "unavailable"}
        row["image_evidence_status"] = ("ambiguous_basename_collision" if keys.count(key) > 1
            else "unavailable" if any(i["status"] == "unavailable" for i in images.values())
            else "present_unverified_run")
        row["images"] = images
    return {"schema_version": 1, "status": "visual_review_pending", "accepted": False,
            "passed": int(terminal.group("passed")), "failed": len(rows),
            "skipped": int(terminal.group("skipped") or 0), "elapsed": terminal.group("elapsed"),
            "log_sha256": hashlib.sha256(raw).hexdigest(),
            "recorded_source_head": manifest["head"],
            "source_manifest_sha256": hashlib.sha256(manifest_bytes).hexdigest(),
            "source_manifest_recorded_at_utc": manifest.get("recorded_at_utc"),
            "source_scope": "Recorded manifest and selected baseline hashes; current checkout source is not attested.",
            "image_scope": "Retained image presence has no run provenance; no capture manifest was supplied.",
            "failures": rows}


def write_outputs(outputs: dict[Path, str]) -> None:
    """Prepare both complete files before replacing either destination."""
    staged = {}
    try:
        for path, content in outputs.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.exists() and not path.is_file():
                raise ValueError(f"Output is not a regular file: {path}")
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent,
                                             prefix=f".{path.name}.", delete=False) as handle:
                staged[path] = Path(handle.name)
                handle.write(content)
        for path, temporary in staged.items():
            os.replace(temporary, path)
    finally:
        for temporary in staged.values():
            temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("root", "log", "source-manifest", "tsv", "json"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    args = parser.parse_args()
    try:
        destinations = {args.tsv.resolve(), args.json.resolve()}
        inputs = {args.log.resolve(), args.source_manifest.resolve()}
        if (args.tsv.suffix != ".tsv" or args.json.suffix != ".json"
                or len(destinations) != 2 or destinations & inputs):
            raise ValueError("Outputs require separate TSV/JSON paths and cannot replace input evidence")
        result = build_index(args.root, args.log, args.source_manifest)
        buffer = io.StringIO()
        fields = ("baseline_path", "pixel_diff_pct", "review_status", "baseline_sha256",
                  "image_evidence_status", "test_file", "test_name", "different_pixels")
        writer = csv.DictWriter(buffer, fieldnames=fields, delimiter="\t", lineterminator="\n", extrasaction="ignore")
        writer.writeheader()
        writer.writerows(result["failures"])
        write_outputs({args.tsv: buffer.getvalue(),
                       args.json: json.dumps(result, indent=2, sort_keys=True) + "\n"})
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, f"ERROR: {error}\n")
    print(f"Indexed {result['failed']} visual failures; review remains pending.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
