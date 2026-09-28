import importlib.util,json,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('applier',ROOT/'scripts/ci/apply_increment07.py');applier=importlib.util.module_from_spec(spec);spec.loader.exec_module(applier)
class ApplierTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.base=Path(self.temp.name);self.repo=self.base/'repo';self.repo.mkdir();(self.repo/'.git').mkdir()
        self.bundle=self.base/'bundle';(self.bundle/'delta-files').mkdir(parents=True)
        (self.repo/'one.txt').write_bytes(b'before');(self.bundle/'delta-files/one.txt').write_bytes(b'after')
        self.manifest={'schema_version':1,'files':[{'path':'one.txt','before_sha256':applier.sha(b'before'),'after_sha256':applier.sha(b'after'),'after_mode':420}]};self.save()
    def save(self):(self.bundle/'DELTA_MANIFEST.json').write_text(json.dumps(self.manifest))
    def test_default_plan_does_not_mutate(self):self.assertEqual(len(applier.plan(self.repo,self.bundle)),1);self.assertEqual((self.repo/'one.txt').read_bytes(),b'before')
    def test_apply_and_idempotency(self):self.assertEqual(applier.apply(self.repo,self.bundle),1);self.assertEqual(applier.apply(self.repo,self.bundle),0)
    def test_modified_baseline_refused(self):
        (self.repo/'one.txt').write_bytes(b'user edits')
        with self.assertRaises(ValueError):applier.apply(self.repo,self.bundle)
        self.assertEqual((self.repo/'one.txt').read_bytes(),b'user edits')
    def test_payload_tamper_refused(self):
        (self.bundle/'delta-files/one.txt').write_bytes(b'tampered')
        with self.assertRaises(ValueError):applier.apply(self.repo,self.bundle)
        self.assertEqual((self.repo/'one.txt').read_bytes(),b'before')
    def test_symlink_refused(self):
        (self.repo/'one.txt').unlink();(self.repo/'one.txt').symlink_to(self.bundle/'delta-files/one.txt')
        with self.assertRaises(ValueError):applier.plan(self.repo,self.bundle)
    def test_path_traversal_refused(self):
        self.manifest['files'][0]['path']='../escape';self.save()
        with self.assertRaises(ValueError):applier.plan(self.repo,self.bundle)
    def test_duplicate_path_refused(self):
        self.manifest['files']*=2;self.save()
        with self.assertRaises(ValueError):applier.plan(self.repo,self.bundle)
    def test_new_file_conflict_prevents_all_writes(self):
        (self.repo/'new.txt').write_bytes(b'local');(self.bundle/'delta-files/new.txt').write_bytes(b'new')
        self.manifest['files'].append({'path':'new.txt','before_sha256':None,'after_sha256':applier.sha(b'new'),'after_mode':420});self.save()
        with self.assertRaises(ValueError):applier.apply(self.repo,self.bundle)
        self.assertEqual((self.repo/'one.txt').read_bytes(),b'before')
    def test_symlinked_bundle_root_refused(self):
        linked=self.base/'linked';linked.symlink_to(self.bundle,target_is_directory=True)
        with self.assertRaises(ValueError):applier.plan(self.repo,linked)
    def test_symlinked_checkout_root_refused(self):
        linked=self.base/'linked';linked.symlink_to(self.repo,target_is_directory=True)
        with self.assertRaises(ValueError):applier.plan(linked,self.bundle)
    def test_symlinked_manifest_refused(self):
        manifest=self.bundle/'DELTA_MANIFEST.json';copy=self.base/'manifest.json';copy.write_bytes(manifest.read_bytes())
        manifest.unlink();manifest.symlink_to(copy)
        with self.assertRaises(ValueError):applier.plan(self.repo,self.bundle)
if __name__=='__main__':unittest.main()
