"""Read back the deployed Pages identity, Admin routes and critical public bytes."""
import argparse
import concurrent.futures
import hashlib
import json
import re
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlsplit


def verify(site, origin, output):
    url = urlsplit(origin)
    allowed = url.hostname in {"mobio.ikanisa.com", "mobioadmin.ikanisa.com", "mobio-1h0.pages.dev"} or re.fullmatch(r"[a-z0-9-]+\.mobio-1h0\.pages\.dev", url.hostname or "")
    if url.scheme != "https" or not allowed or url.username or url.password or url.port or url.path not in {"", "/"} or url.query or url.fragment:
        raise ValueError("Expected a Mobio HTTPS origin")
    origin = origin.rstrip("/")
    expected = json.loads((site / "release.json").read_text())
    if expected.get("qa_only"):
        raise ValueError("A synthetic QA cohort cannot be verified as a public release")
    prefix = f"/releases/{expected['asset_version']}/"
    router = Path(__file__).resolve().parents[2] / "lib/app/router/app_router.dart"
    admin_paths = sorted(set(re.findall(r"path:\s*'(/admin[^']*)'", router.read_text())))
    assert "/admin-auth" in admin_paths and "/admin/users" in admin_paths
    assets = [prefix + name for name in ["flutter_bootstrap.js", "main.dart.js", "assets/AssetManifest.bin.json", "canvaskit/chromium/canvaskit.wasm", "style.css"]]
    paths = ["/", *admin_paths, "/release.json", "/admin-manifest.json", "/flutter_service_worker.js", *assets]

    def check(path):
        errors = []
        request = urllib.request.Request(origin + path, headers={"User-Agent": "Mobio-Release-QA/1.0", "Cache-Control": "no-cache"})
        with urllib.request.urlopen(request, timeout=45) as response:
            body = response.read(26 * 1024 * 1024)
            headers = response.headers
            row = {"path": path, "status": response.status, "final_url": response.url, "release": headers.get("x-mobio-release"), "surface": headers.get("x-mobio-surface"), "cache_control": headers.get("cache-control"), "content_type": headers.get("content-type")}
        if row["status"] != 200 or row["release"] != expected["release_id"]:
            errors.append("status/release identity mismatch")
        admin = path in admin_paths or (url.hostname == "mobioadmin.ikanisa.com" and path == "/")
        if admin:
            if b"<title>Mobio Admin</title>" not in body or (prefix + "flutter_bootstrap.js").encode() not in body or row["surface"] != "admin":
                errors.append("incorrect Admin document")
            if headers.get("x-frame-options") != "DENY" or "frame-ancestors 'none'" not in headers.get("content-security-policy", ""):
                errors.append("Admin framing protections missing")
        elif path == "/" and b"<title>Mobio" not in body:
            errors.append("website document missing")
        if path in assets or path in {"/flutter_service_worker.js", "/admin-manifest.json"}:
            row["sha256"] = hashlib.sha256(body).hexdigest()
            if row["sha256"] != expected["files"][path.lstrip("/")]:
                errors.append("public bytes differ from artifact")
        if path == "/release.json" and json.loads(body)["release_id"] != expected["release_id"]:
            errors.append("served release manifest mismatch")
        if path not in assets and "no-store" not in (row["cache_control"] or ""):
            errors.append("stable control/document is cacheable")
        row["errors"] = errors
        return row

    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        rows = list(pool.map(check, paths))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"checked_at": datetime.now(timezone.utc).isoformat(), "origin": origin, "release_id": expected["release_id"], "checks": rows}, indent=2) + "\n")
    failures = [row for row in rows if row["errors"]]
    if failures:
        raise SystemExit(json.dumps(failures, indent=2))
    print(f"Verified {len(rows)} live checks at {origin}: {expected['release_id']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site", type=Path, required=True)
    parser.add_argument("--origin", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    verify(args.site, args.origin, args.output)
