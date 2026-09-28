import csv
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('reconcile_receipts',ROOT/'scripts/operations/reconcile_receipts.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)

def rows():
 base={'operator':'operator-fixture','merchant':'merchant-fixture','transaction_ref':'synthetic-001','amount_minor':'1000','currency':'RWF'}
 return {'operator':[{**base,'occurred_at':'2026-09-28T08:00:00Z'}],
 'receipts':[{**base,'receipt_id':'receipt-1','state':'credited','invoice_id':'invoice-1'}],
 'credits':[{**base,'credit_id':'credit-1','invoice_id':'invoice-1'}]}
def run(data):
 data={k:[r.normalize(x,k,i+2) for i,x in enumerate(v)] for k,v in data.items()}
 return r.reconcile(data['operator'],data['receipts'],data['credits'],as_of=r.instant('2026-09-28T09:00:00Z'))
class ReconciliationTests(unittest.TestCase):
 def test_exact_triple_match_is_read_only(self):
  x=run(rows());self.assertEqual(x['counts']['matched'],1);self.assertFalse(x['automatic_credit_performed']);self.assertFalse(x['authenticity_verified']);self.assertEqual(x['release_decision'],'NOT_DETERMINED')
 def test_missing_operator_cannot_match(self):
  d=rows();d['operator']=[];self.assertIn('NO_OPERATOR_EVIDENCE',[i['code'] for i in run(d)['exceptions']])
 def test_missing_receipt_cannot_match(self):
  d=rows();d['receipts']=[];self.assertEqual(run(d)['counts']['matched'],0)
 def test_credited_without_credit_needs_review(self):
  d=rows();d['credits']=[];self.assertIn('NO_CREDIT_REQUIRES_REVIEW',[i['code'] for i in run(d)['exceptions']])
 def test_inflight_is_pending_not_false_failure(self):
  d=rows();d['credits']=[];d['receipts'][0]['state']='processing';x=run(d);self.assertEqual(x['counts']['pending'],1);self.assertEqual(x['exceptions'],[])
 def test_review_is_never_auto_matched(self):
  d=rows();d['receipts'][0]['state']='review';self.assertEqual(run(d)['counts']['matched'],0)
 def test_reference_case_not_fuzzily_matched(self):
  d=rows();d['operator'][0]['transaction_ref']='SYNTHETIC-001';self.assertEqual(run(d)['counts']['matched'],0)
 def test_same_amount_time_not_sufficient(self):
  d=rows();d['operator'][0]['transaction_ref']='different';self.assertEqual(run(d)['counts']['matched'],0)
 def test_wrong_merchant_not_matched(self):
  d=rows();d['credits'][0]['merchant']='other';self.assertEqual(run(d)['counts']['matched'],0)
 def test_wrong_operator_not_matched(self):
  d=rows();d['credits'][0]['operator']='other';self.assertEqual(run(d)['counts']['matched'],0)
 def test_currency_mismatch(self):
  d=rows();d['credits'][0]['currency']='USD';self.assertIn('CURRENCY_MISMATCH',[i['code'] for i in run(d)['exceptions']])
 def test_amount_mismatch(self):
  d=rows();d['credits'][0]['amount_minor']='1001';self.assertIn('AMOUNT_MISMATCH',[i['code'] for i in run(d)['exceptions']])
 def test_invoice_mismatch(self):
  d=rows();d['credits'][0]['invoice_id']='other';self.assertIn('INVOICE_BINDING_MISMATCH',[i['code'] for i in run(d)['exceptions']])
 def test_duplicate_operator_never_collapsed(self):
  d=rows();d['operator'].append(dict(d['operator'][0]));self.assertEqual(run(d)['counts']['matched'],0)
 def test_duplicate_credit_reference(self):
  d=rows();d['credits'].append({**d['credits'][0],'credit_id':'credit-2'});self.assertIn('MULTIPLE_CREDIT_RECORDS',[i['code'] for i in run(d)['exceptions']])
 def test_duplicate_row_identity_rejected(self):
  d=rows();d['receipts'].append(dict(d['receipts'][0]));self.assertRaises(r.InputError,run,d)
 def test_duplicate_invoice_across_references(self):
  d=rows();second=rows()
  for kind in d:
   new=dict(second[kind][0]);new['transaction_ref']='synthetic-002'
   if kind=='receipts':new['receipt_id']='receipt-2'
   if kind=='credits':new['credit_id']='credit-2'
   d[kind].append(new)
  self.assertEqual(run(d)['counts']['matched'],0)
 def test_future_operator_row_rejected(self):
  d=rows();d['operator'][0]['occurred_at']='2026-09-29T00:00:00Z';self.assertRaises(r.InputError,run,d)
 def test_naive_timestamp_rejected(self):self.assertRaises(r.InputError,r.instant,'2026-09-28T08:00:00')
 def test_fractional_amount_rejected(self):
  d=rows();d['operator'][0]['amount_minor']='10.5';self.assertRaises(r.InputError,run,d)
 def test_negative_amount_rejected(self):
  d=rows();d['operator'][0]['amount_minor']='-1';self.assertRaises(r.InputError,run,d)
 def test_unmapped_state_rejected(self):
  d=rows();d['receipts'][0]['state']='success';self.assertRaises(r.InputError,run,d)
 def test_cli_creates_hashed_report_and_refuses_overwrite(self):
  with tempfile.TemporaryDirectory() as temp:
   root=Path(temp);args=[]
   for kind,data in rows().items():
    p=root/(kind+'.csv')
    with p.open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=r.FIELDS[kind]);w.writeheader();w.writerows(data)
    args += ['--'+kind,str(p)]
   args+=['--as-of','2026-09-28T09:00:00Z','--output',str(root/'report')]
   self.assertEqual(r.main(args),0);result=json.loads((root/'report/reconciliation.json').read_text());self.assertEqual(len(result['input_sha256']),3);self.assertEqual(r.main(args),2)
 def test_wrong_headers_rejected(self):
  with tempfile.TemporaryDirectory() as t:
   p=Path(t)/'bad.csv';p.write_text('operator,operator\nx,x\n');self.assertRaises(r.InputError,r.load,p,'operator')
if __name__=='__main__':unittest.main()
