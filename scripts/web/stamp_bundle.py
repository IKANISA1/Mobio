"""Identify the exact public bundle without including runtime credentials."""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from version_assets import version_assets

site = Path(sys.argv[1])
previous = os.environ.get("PREVIOUS_SITE_DIR")
metadata = version_assets(site, Path(previous) if previous else None)
worker = site / "_worker.js"
files = {p.relative_to(site).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
         for p in sorted(site.rglob("*")) if p.is_file() and p.name not in {"release.json", "_worker.js"}}
source = worker.read_text()
identity = hashlib.sha256((json.dumps(files, sort_keys=True) + source).encode()).hexdigest()
worker.write_text(source.replace("__MOBIO_RELEASE_ID__", identity))
files["_worker.js"] = hashlib.sha256(worker.read_bytes()).hexdigest()
commit = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()
dirty = bool(subprocess.check_output(["git", "status", "--porcelain"], text=True).strip())
(site / "release.json").write_text(json.dumps({
    "release_id": identity, "commit": commit, "working_tree_dirty": dirty, "files": files,
    **metadata,
}, indent=2, sort_keys=True) + "\n")
