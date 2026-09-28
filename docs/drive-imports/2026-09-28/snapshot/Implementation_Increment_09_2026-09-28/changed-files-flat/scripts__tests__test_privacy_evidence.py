import copy
from datetime import datetime,timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
P=Path(__file__).resolve().parents[1]/'privacy'/'verify_completion_manifest.py'
s=importlib.util.spec_from_file_location('privacy_evidence',P);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
NOW=datetime(2026,9,28,12,tzinfo=timezone.utc)
class EvidenceTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.root=Path(self.tmp.name);self.path=self.root/'manifest.json'
  self.manifest={'schema_version':1,'request_id':'00000000-0000-4000-8000-000000000001','subject_id':'00000000-0000-4000-8000-000000000002',
   'notice_version':'v1','inventory_sha256':'1'*64,'plan_sha256':'2'*64,'generated_at':'2026-09-28T11:00:00Z','receipts':[]}
  for category in sorted(m.CATEGORIES):
   evidence={'request_id':self.manifest['request_id'],'subject_id':self.manifest['subject_id'],'category':category,
    'outcome':'retained' if category=='privacy_case_records' else 'deleted','observed_at':'2026-09-28T10:00:00Z','verification_mode':'operator_attestation',
    'retention_until':'2027-01-01T00:00:00Z' if category=='privacy_case_records' else None,
    'basis_reference':'synthetic-case-retention' if category=='privacy_case_records' else None}
   path=self.root/(category+'.json');path.write_text(json.dumps(evidence))
   self.manifest['receipts'].append({'category':category,'outcome':evidence['outcome'],'evidence_file':path.name,
     'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'retention_until':evidence['retention_until'],'basis_reference':evidence['basis_reference']})
 def tearDown(self):self.tmp.cleanup()
 def write(self):self.path.write_text(json.dumps(self.manifest));return self.path
 def validate(self):return m.validate_manifest(self.write(),now=NOW)
 def reject(self,code):
  with self.assertRaisesRegex(m.EvidenceError,code):self.validate()
 def receipt(self,key):return next(r for r in self.manifest['receipts'] if r['category']==key)
 def modify_evidence(self,target,**values):
  row=self.receipt(target);p=self.root/row['evidence_file'];data=json.loads(p.read_text());data.update(values);p.write_text(json.dumps(data));row['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
 def test_complete_structural_evidence(self):
  result=self.validate();self.assertEqual(result['category_count'],10);self.assertFalse(result['provider_deletion_independently_verified']);self.assertFalse(result['database_case_changed'])
 def test_retention_requires_matching_bounded_evidence(self):
  row=self.receipt('backups');row.update(outcome='retained',retention_until='2027-01-01T00:00:00Z',basis_reference='policy/backup-expiry-1')
  self.modify_evidence('backups',outcome='retained',retention_until=row['retention_until'],basis_reference=row['basis_reference'])
  self.assertEqual(self.validate()['retained_categories'],['backups','privacy_case_records'])
 def test_missing_category(self):self.manifest['receipts'].pop();self.reject('INCOMPLETE_CATEGORY')
 def test_duplicate_category(self):self.manifest['receipts'][1]=copy.deepcopy(self.manifest['receipts'][0]);self.reject('DUPLICATE_OR_UNKNOWN')
 def test_unknown_category(self):self.manifest['receipts'][0]['category']='imaginary';self.reject('UNKNOWN_CATEGORY')
 def test_auth_not_applicable(self):self.receipt('auth')['outcome']='not_applicable';self.reject('AUTH_ERASURE_REQUIRED')
 def test_sessions_retained(self):self.receipt('sessions')['outcome']='retained';self.reject('AUTH_ERASURE_REQUIRED')
 def test_unknown_outcome(self):self.receipt('storage')['outcome']='probably';self.reject('INVALID_OUTCOME')
 def test_wrong_identity(self):self.manifest['subject_id']='abc';self.reject('INVALID_IDENTITY')
 def test_wrong_request_binding(self):self.modify_evidence('storage',request_id='00000000-0000-4000-8000-000000000099');self.reject('EVIDENCE_BINDING')
 def test_wrong_subject_binding(self):self.modify_evidence('storage',subject_id='00000000-0000-4000-8000-000000000099');self.reject('EVIDENCE_BINDING')
 def test_wrong_category_binding(self):self.modify_evidence('storage',category='backups');self.reject('EVIDENCE_BINDING')
 def test_wrong_outcome_binding(self):self.modify_evidence('storage',outcome='retained');self.reject('EVIDENCE_BINDING')
 def test_hash_does_not_match(self):self.receipt('storage')['sha256']='0'*64;self.reject('DIGEST_MISMATCH')
 def test_file_missing(self):(self.root/'storage.json').unlink();self.reject('FILE_UNAVAILABLE')
 def test_path_escape(self):self.receipt('storage')['evidence_file']='../secret';self.reject('INVALID_EVIDENCE_PATH')
 def test_absolute_path(self):self.receipt('storage')['evidence_file']='/etc/passwd';self.reject('INVALID_EVIDENCE_PATH')
 def test_backslash_path(self):self.receipt('storage')['evidence_file']='a\\b';self.reject('INVALID_EVIDENCE_PATH')
 def test_symlink(self):
  (self.root/'alias').symlink_to(self.root/'storage.json');self.receipt('storage')['evidence_file']='alias';self.reject('SYMLINK')
 def test_symlink_parent(self):
  (self.root/'aliasdir').symlink_to(self.root,target_is_directory=True);self.receipt('storage')['evidence_file']='aliasdir/storage.json';self.reject('SYMLINK')
 def test_oversized_file(self):(self.root/'storage.json').write_bytes(b'x'*(1024*1024+1));self.reject('TOO_LARGE')
 def test_extra_manifest_key(self):self.manifest['secret']='should not be admitted';self.reject('INVALID_MANIFEST_SCHEMA')
 def test_boolean_schema_version(self):self.manifest['schema_version']=True;self.reject('INVALID_MANIFEST_SCHEMA')
 def test_invalid_digest(self):self.manifest['plan_sha256']='short';self.reject('INVALID_PLAN_DIGEST')
 def test_invalid_notice(self):self.manifest['notice_version']='<html>';self.reject('INVALID_NOTICE')
 def test_timezone_missing(self):self.manifest['generated_at']='2026-09-28T10:00:00';self.reject('TIMEZONE_REQUIRED')
 def test_future_manifest(self):self.manifest['generated_at']='2027-01-01T00:00:00Z';self.reject('FUTURE_MANIFEST')
 def test_future_observation(self):self.modify_evidence('storage',observed_at='2026-09-28T12:00:00Z');self.reject('EVIDENCE_AFTER_MANIFEST')
 def test_verification_mode_missing(self):self.modify_evidence('storage',verification_mode=None);self.reject('VERIFICATION_MODE')
 def test_expired_retention(self):
  self.receipt('backups').update(outcome='retained',retention_until='2025-01-01T00:00:00Z',basis_reference='policy1');self.reject('INVALID_RETENTION')
 def test_retention_basis_missing(self):
  self.receipt('backups').update(outcome='retained',retention_until='2027-01-01T00:00:00Z');self.reject('INVALID_RETENTION')
 def test_retention_binding_mismatch(self):
  self.receipt('backups').update(outcome='retained',retention_until='2027-01-01T00:00:00Z',basis_reference='policy1')
  self.modify_evidence('backups',outcome='retained');self.reject('RETENTION_BINDING')
 def test_deleted_cannot_include_retention(self):self.receipt('storage')['retention_until']='2027-01-01T00:00:00Z';self.reject('UNEXPECTED_RETENTION')
 def test_duplicate_json_keys(self):
  with self.assertRaisesRegex(m.EvidenceError,'DUPLICATE_JSON_KEY'):m.parse_json(b'{"a":1,"a":2}')
 def test_nan_json_rejected(self):
  with self.assertRaisesRegex(m.EvidenceError,'NONFINITE_JSON'):m.parse_json(b'{"a":NaN}')
 def test_invalid_utf8(self):
  with self.assertRaisesRegex(m.EvidenceError,'INVALID_JSON'):m.parse_json(b'\xff')
 def test_case_records_cannot_be_declared_erased(self):
  self.receipt('privacy_case_records').update(outcome='deleted',retention_until=None,basis_reference=None);self.reject('PRIVACY_CASE_RETENTION_REQUIRED')
 def test_case_records_cannot_be_omitted_as_inapplicable(self):
  self.receipt('privacy_case_records').update(outcome='not_applicable',retention_until=None,basis_reference=None);self.reject('PRIVACY_CASE_RETENTION_REQUIRED')
 def test_deep_json_is_bounded_error(self):
  with self.assertRaisesRegex(m.EvidenceError,'JSON_NESTING_TOO_DEEP'):m.parse_json(b'['*2000+b']'*2000)
 def test_manifest_is_read_only(self):
  self.write();before={p.name:p.read_bytes() for p in self.root.iterdir()};m.validate_manifest(self.path,now=NOW)
  self.assertEqual(before,{p.name:p.read_bytes() for p in self.root.iterdir()})
if __name__=='__main__':unittest.main()
