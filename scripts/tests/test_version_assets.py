import hashlib
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("version_assets", Path(__file__).parents[1] / "web/version_assets.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ReleaseAssetsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def fixture(self, name, code=b"app version one"):
        root = self.root / name
        root.mkdir()
        for path, value in {
            "flutter_bootstrap.js": b'var _flutter={}; _flutter.loader.load({serviceWorkerSettings:{}});',
            "main.dart.js": code,
            "style.css": b'@font-face{src:url("assets/font.woff2")}',
            "assets/font.woff2": b"public font",
            "icons/Icon.png": b"icon",
            "__admin_shell": b'<base href="/"><script src="flutter_bootstrap.js"></script><link rel="manifest" href="/admin-manifest.json">',
            "index.html": b'<link href="style.css"><img src="icons/Icon.png"><a href="/admin/users">Users</a><a href="#trips">Trips</a>',
            "admin-manifest.json": b'{"start_url":"/admin-auth","icons":[{"src":"icons/Icon.png"}]}',
            "_worker.js": b"server control",
            "flutter_service_worker.js": b"recovery control",
        }.items():
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(value)
        return root

    def stamp(self, site, metadata):
        files = {p.relative_to(site).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in site.rglob('*') if p.is_file()}
        (site / 'release.json').write_text(json.dumps({**metadata, 'files': files}))

    def test_consumer_shell_and_manifest_share_the_release_cohort(self):
        site = self.fixture('consumer')
        (site / '__app_shell').write_text('<script src="flutter_bootstrap.js"></script><link rel="manifest" href="/app-manifest.json">')
        (site / 'app-manifest.json').write_text('{"start_url":"/biopay","icons":[{"src":"icons/Icon.png"}]}')
        metadata = module.version_assets(site)
        prefix = f"/releases/{metadata['asset_version']}/"
        shell = (site / '__app_shell').read_text()
        self.assertIn(prefix + 'flutter_bootstrap.js', shell)
        self.assertIn('href="/app-manifest.json"', shell)
        self.assertFalse((site / prefix.lstrip('/') / 'app-manifest.json').exists())
        manifest = json.loads((site / 'app-manifest.json').read_text())
        self.assertEqual(manifest['id'], '/biopay')
        self.assertEqual(manifest['scope'], '/')
        self.assertEqual(manifest['icons'][0]['src'], prefix + 'icons/Icon.png')

    def test_public_asset_cohort_preserves_routes_and_manifest_identity(self):
        site = self.fixture('first')
        result = module.version_assets(site)
        prefix = f"/releases/{result['asset_version']}/"
        self.assertIn(prefix + 'flutter_bootstrap.js', (site/'__admin_shell').read_text())
        self.assertIn('<base href="/">', (site/'__admin_shell').read_text())
        self.assertIn('href="/admin/users"', (site/'index.html').read_text())
        self.assertIn('href="#trips"', (site/'index.html').read_text())
        self.assertIn(prefix + 'style.css', (site/'index.html').read_text())
        manifest = json.loads((site/'admin-manifest.json').read_text())
        self.assertEqual(manifest['id'], '/admin-auth')
        self.assertEqual(manifest['scope'], '/')
        self.assertEqual(manifest['icons'][0]['src'], prefix+'icons/Icon.png')
        self.assertFalse((site/prefix.lstrip('/')/'_worker.js').exists())
        self.assertFalse((site/prefix.lstrip('/')/'flutter_service_worker.js').exists())
        self.assertNotIn('serviceWorkerSettings', (site/'flutter_bootstrap.js').read_text())

    def test_code_change_gets_new_urls_and_retains_previous_bytes(self):
        old = self.fixture('old')
        old_metadata = module.version_assets(old)
        self.stamp(old, old_metadata)
        current = self.fixture('current', b'app version two')
        metadata = module.version_assets(current, old)
        self.assertNotEqual(metadata['asset_version'], old_metadata['asset_version'])
        self.assertEqual(metadata['retained_asset_versions'], [old_metadata['asset_version']])
        self.assertEqual((current/f"releases/{old_metadata['asset_version']}/main.dart.js").read_bytes(), b'app version one')
        self.assertEqual((current/f"releases/{metadata['asset_version']}/main.dart.js").read_bytes(), b'app version two')

    def test_unchanged_input_produces_same_asset_version(self):
        self.assertEqual(module.version_assets(self.fixture('one')), module.version_assets(self.fixture('two')))

    def test_tampered_previous_asset_fails_release(self):
        old = self.fixture('old')
        metadata = module.version_assets(old)
        self.stamp(old, metadata)
        (old/f"releases/{metadata['asset_version']}/main.dart.js").write_text('corrupt')
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            module.version_assets(self.fixture('current'), old)

    def test_previous_inventory_cannot_escape_bundle(self):
        old = self.fixture('old')
        (old/'release.json').write_text(json.dumps({'asset_version':'a'*64,'files':{f"releases/{'a'*64}/../../escape":'b'*64}}))
        with self.assertRaisesRegex(ValueError, 'Unsafe'):
            module.version_assets(self.fixture('current'), old)

    def test_unrecognized_loader_requires_review(self):
        site = self.fixture('bad')
        (site/'flutter_bootstrap.js').write_text('unexpected SDK')
        with self.assertRaisesRegex(ValueError, 'Unexpected Flutter bootstrap'):
            module.version_assets(site)


if __name__ == '__main__':
    unittest.main()
