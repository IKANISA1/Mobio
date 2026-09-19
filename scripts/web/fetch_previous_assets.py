"""Download only the current public, hash-verified asset cohort for retention."""
import concurrent.futures
import hashlib
import json
import sys
import urllib.request
from pathlib import Path, PurePosixPath
from urllib.parse import quote
from version_assets import VERSION

ORIGIN = "https://mobio.ikanisa.com"


def fetch(path, limit):
    request = urllib.request.Request(ORIGIN + "/" + quote(path, safe="/"), headers={
        "User-Agent": "Mobio-Release/1.0", "Cache-Control": "no-cache",
    })
    with urllib.request.urlopen(request, timeout=45) as response:
        if response.url != request.full_url:
            raise ValueError("Unexpected asset redirect")
        data = response.read(limit + 1)
    if len(data) > limit:
        raise ValueError("Public artifact exceeds the release size limit")
    return data


def download(destination):
    if destination.exists():
        raise ValueError("Previous asset destination must be new")
    manifest_bytes = fetch("release.json", 2 * 1024 * 1024)
    manifest = json.loads(manifest_bytes)
    version = manifest.get("asset_version")
    entries = {}
    if version is not None:
        if not VERSION.fullmatch(version):
            raise ValueError("Invalid public asset version")
        prefix = f"releases/{version}/"
        entries = {name: value for name, value in manifest["files"].items() if name.startswith(prefix)}
        if not entries or len(entries) > 2000:
            raise ValueError("Invalid public asset inventory")
        for name, value in entries.items():
            if ".." in PurePosixPath(name).parts or "\\" in name or "%" in name or "?" in name or "#" in name or not VERSION.fullmatch(value):
                raise ValueError("Unsafe public asset path or hash")
    destination.mkdir(parents=True)

    def save(entry):
        name, expected = entry
        data = fetch(name, 25 * 1024 * 1024)
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(f"Public asset hash mismatch: {name}")
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
        list(executor.map(save, entries.items()))
    (destination / "release.json").write_bytes(manifest_bytes)
    print(f"Verified {len(entries)} public files for previous-release retention")


if __name__ == "__main__":
    download(Path(sys.argv[1]))
