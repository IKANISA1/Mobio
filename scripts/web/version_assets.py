"""Give public release files immutable URLs; retain the preceding asset cohort.

HTML, manifests, association files and the service worker keep stable URLs.
No authenticated responses or browser state enter this package.
"""
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from urllib.parse import urlsplit

BOOTSTRAP = '''
// A release never reloads an open document. A later navigation picks up new HTML.
if ("serviceWorker" in navigator) {
  navigator.serviceWorker.register("/flutter_service_worker.js", {
    scope: "/", updateViaCache: "none"
  }).catch(() => {});
}
_flutter.loader.load({config: {
  entrypointBaseUrl: "__ASSET_BASE__",
  assetBase: "__ASSET_BASE__",
  canvasKitBaseUrl: "__ASSET_BASE__canvaskit/"
}});
'''
VERSION = re.compile(r"[0-9a-f]{64}")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def public_assets(site):
    return {
        p.relative_to(site).as_posix(): p.read_bytes()
        for p in sorted(site.rglob("*"))
        if p.is_file() and not p.is_symlink()
        and not any(part.startswith(("_", ".")) for part in p.relative_to(site).parts)
        and p.suffix != ".html"
        and p.name not in {"release.json", "admin-manifest.json", "app-manifest.json", "manifest.json", "flutter_service_worker.js"}
        and p.relative_to(site).parts[0] != "releases"
    }


def retain_previous(site, previous):
    if previous is None:
        return None
    manifest = json.loads((previous / "release.json").read_text())
    version = manifest.get("asset_version")
    if version is None:  # First migration from stable URLs.
        return None
    if not VERSION.fullmatch(version):
        raise ValueError("Invalid previous asset version")
    prefix = f"releases/{version}/"
    entries = {name: checksum for name, checksum in manifest["files"].items() if name.startswith(prefix)}
    if not entries or len(entries) > 2000:
        raise ValueError("Invalid previous asset inventory")
    for name, checksum in entries.items():
        path = PurePosixPath(name)
        if ".." in path.parts or "\\" in name or not VERSION.fullmatch(checksum):
            raise ValueError("Unsafe previous asset path or hash")
        source = previous / name
        if not source.resolve().is_relative_to(previous.resolve()):
            raise ValueError("Previous asset escapes bundle")
        data = source.read_bytes()
        if digest(data) != checksum:
            raise ValueError(f"Previous asset hash mismatch: {name}")
        destination = site / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    return version


def version_assets(site, previous=None):
    assets = public_assets(site)
    bootstrap = assets["flutter_bootstrap.js"].decode()
    # Keep Flutter's compiled loader/build metadata, replace only its final call.
    marker = "_flutter.loader.load("
    if bootstrap.count(marker) != 1:
        raise ValueError("Unexpected Flutter bootstrap; inspect the SDK output")
    assets["flutter_bootstrap.js"] = (bootstrap.split(marker)[0] + BOOTSTRAP).encode()
    version = digest(json.dumps({name: digest(data) for name, data in assets.items()}, sort_keys=True).encode())
    prefix = f"/releases/{version}/"
    assets["flutter_bootstrap.js"] = assets["flutter_bootstrap.js"].replace(b"__ASSET_BASE__", prefix.encode())
    for name, data in assets.items():
        destination = site / prefix.lstrip("/") / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    # Legacy clients retain working stable URLs, now with the non-reloading loader.
    (site / "flutter_bootstrap.js").write_bytes(assets["flutter_bootstrap.js"])

    for document in [*site.glob("*.html"), site / "__admin_shell", site / "__app_shell"]:
        if not document.is_file():
            continue
        def rewrite(match):
            attribute, quote, value = match.groups()
            parsed = urlsplit(value)
            name = parsed.path.lstrip("/")
            if not parsed.scheme and not parsed.netloc and name in assets:
                return f"{attribute}={quote}{prefix}{value.lstrip('/')}{quote}"
            return match.group(0)
        document.write_text(re.sub(r'(src|href|content)=([\"\'])(.*?)\2', rewrite, document.read_text()))

    for name in ("admin-manifest.json", "app-manifest.json"):
        manifest_path = site / name
        if not manifest_path.is_file():
            continue
        manifest = json.loads(manifest_path.read_text())
        # Keep each installed app's previous implicit start-URL identity.
        manifest["id"] = manifest["start_url"]
        manifest["scope"] = "/"
        for icon in manifest.get("icons", []):
            if icon["src"].lstrip("/") in assets:
                icon["src"] = prefix + icon["src"].lstrip("/")
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    retained = retain_previous(site, previous)
    return {"asset_version": version, "retained_asset_versions": [retained] if retained and retained != version else []}
