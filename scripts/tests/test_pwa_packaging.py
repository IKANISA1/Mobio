"""Exercise the real packager using synthetic precompiled input, without a build."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class PwaPackagingTest(unittest.TestCase):
    def test_bundle_uses_tested_worker_and_coherent_consumer_admin_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory)
            compiled = fixture / "synthetic-web"
            shutil.copytree(ROOT / "web", compiled)
            (compiled / "index.html").write_text(
                (compiled / "index.html").read_text().replace("$FLUTTER_BASE_HREF", "/")
            )
            (compiled / "flutter_bootstrap.js").write_text(
                "// Synthetic packaging fixture; not a Flutter application.\n"
                "var _flutter={}; _flutter.loader.load({});"
            )
            (compiled / "main.dart.js").write_text("// Synthetic packaging fixture.\n")
            output = fixture / "packaged"
            flutter = os.environ.get("FLUTTER_BIN") or shutil.which("flutter")
            if not flutter:
                flutter = "/Users/jeanbosco/Developer/flutter/bin/flutter"
            environment = {
                **os.environ,
                "FLUTTER_BIN": flutter,
                "SKIP_FLUTTER_BUILD": "true",
                "WEB_BUILD_DIR": str(compiled),
                "SUPABASE_URL": "https://synthetic-packaging.invalid",
                "SUPABASE_ANON_KEY": "synthetic-public-key",
                "PRIVACY_POLICY_URL": "https://synthetic-packaging.invalid/privacy",
                "ACCOUNT_DELETION_URL": "https://synthetic-packaging.invalid/delete",
            }
            environment.pop("PREVIOUS_SITE_DIR", None)
            result = subprocess.run(
                ["bash", "scripts/web/prepare_pwa_bundles.sh", str(output)],
                cwd=ROOT, env=environment, capture_output=True, text=True,
                timeout=60,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            site = output / "site"
            release = json.loads((site / "release.json").read_text())
            worker = (ROOT / "scripts/web/pages_worker.mjs").read_text().replace(
                "__MOBIO_RELEASE_ID__", release["release_id"]
            )
            self.assertEqual((site / "_worker.js").read_text(), worker)
            self.assertEqual(
                (site / "flutter_service_worker.js").read_bytes(),
                (ROOT / "scripts/web/admin_service_worker.js").read_bytes(),
            )
            prefix = f"/releases/{release['asset_version']}/"
            for shell, manifest in [("__app_shell", "app-manifest.json"),
                                    ("__admin_shell", "admin-manifest.json")]:
                html = (site / shell).read_text()
                self.assertIn(prefix + "flutter_bootstrap.js", html)
                self.assertIn(f'href="/{manifest}"', html)
                self.assertFalse((site / prefix.lstrip("/") / manifest).exists())
            for name, digest in release["files"].items():
                self.assertEqual(hashlib.sha256((site / name).read_bytes()).hexdigest(), digest, name)


if __name__ == "__main__":
    unittest.main()
