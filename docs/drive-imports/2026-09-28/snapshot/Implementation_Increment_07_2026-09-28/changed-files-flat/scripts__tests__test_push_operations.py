"""Executable worker-trigger/input guard tests. No real provider or SQL calls."""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
from types import SimpleNamespace
import unittest
ROOT=Path(__file__).resolve().parents[2]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);m=importlib.util.module_from_spec(spec)
    sys.modules[name]=m;spec.loader.exec_module(m);return m
ops=module('push_ops','scripts/operations/run_push_outbox_worker.py')
pg=module('push_pg','scripts/qa/test_push_postgres.py')
URL='https://synthetic.supabase.co/functions/v1/push-outbox-worker';SECRET='x'*43
class TriggerTests(unittest.TestCase):
    def response(self,**updates):
        return {'status':'batch_finished','claimed':1,'accepted':1,'retry':0,'invalid_token':0,
                'permanent':0,'skipped':0,'unacknowledged':0,**updates}
    def runner(self,data=None,status='200',code=0):
        return lambda *a,**kw:SimpleNamespace(returncode=code,stdout=json.dumps(data or self.response())+'\n'+status,stderr='sensitive-synthetic-error')
    def test_real_request_config_keeps_secret_out_of_argv(self):
        received={}
        def run(argv,**kwargs):
            received.update(argv=argv,**kwargs);return self.runner()(argv,**kwargs)
        value=ops.trigger(URL,SECRET,10,run)
        self.assertNotIn(SECRET,' '.join(received['argv']));self.assertIn(SECRET,received['input'])
        self.assertIn('--disable',received['argv']);self.assertIn('--max-time',received['argv'])
        self.assertEqual(value['accepted'],1);self.assertNotIn('token',value)
    def test_extra_response_fields_are_not_logged(self):
        value=ops.trigger(URL,SECRET,runner=self.runner(self.response(secret='must-not-appear')))
        self.assertNotIn('secret',value)
    def test_zero_jobs_is_valid_but_not_proof_enabled(self):
        value=ops.trigger(URL,SECRET,runner=self.runner(self.response(claimed=0,accepted=0)))
        self.assertEqual(value['claimed'],0);self.assertNotIn('enabled',value)
    def test_http_nonpass_and_transport_error_raise(self):
        for status,code in [('503',0),('401',0),('301',0),('200',28)]:
            with self.subTest(status=status,code=code),self.assertRaises(RuntimeError):
                ops.trigger(URL,SECRET,runner=self.runner(status=status,code=code))
    def test_malformed_json_and_unbounded_responses_rejected(self):
        for stdout in ['not-json\n200','x'*10000,'{}']:
            with self.subTest(length=len(stdout)),self.assertRaises(RuntimeError):
                ops.trigger(URL,SECRET,runner=lambda *a,**kw:SimpleNamespace(returncode=0,stdout=stdout))
    def test_invalid_counters_and_status_rejected(self):
        for update in [{'accepted':True},{'accepted':-1},{'accepted':11},{'accepted':'1'},
            {'accepted':0},{'unacknowledged':1},{'status':'acknowledgement_incomplete'}]:
            with self.subTest(update=update),self.assertRaises(RuntimeError):
                ops.trigger(URL,SECRET,runner=self.runner(self.response(**update)))
    def test_exact_https_worker_path_required(self):
        for url in [URL.replace('https:','http:'),URL+'?x=1',URL+'#x',URL+'/',
            URL.replace('synthetic.supabase.co','attacker.invalid'),URL.replace('https://','https://u:p@'),
            URL.replace('push-outbox-worker','send-push'),URL+'\n']:
            with self.subTest(url=url),self.assertRaises(ValueError):ops.validate_settings(url,SECRET,10)
    def test_secret_format_enforced(self):
        for secret in ['', 'x'*42,'x'*129,'x'*42+'\n','x'*42+'"']:
            with self.subTest(length=len(secret)),self.assertRaises(ValueError):ops.validate_settings(URL,secret,10)
    def test_integer_batch_bounds(self):
        for limit in [0,11,True,1.5,'1']:
            with self.subTest(limit=limit),self.assertRaises(ValueError):ops.validate_settings(URL,SECRET,limit)
    def test_main_failure_never_echoes_secret(self):
        import os
        env={**os.environ,'MOBIO_PUSH_WORKER_URL':'invalid','MOBIO_PUSH_WORKER_SECRET':'PRIVATE-SYNTHETIC'}
        r=subprocess.run([sys.executable,str(ROOT/'scripts/operations/run_push_outbox_worker.py')],env=env,text=True,capture_output=True,timeout=5)
        self.assertEqual(r.returncode,1);self.assertNotIn('PRIVATE-SYNTHETIC',r.stdout+r.stderr)
class DatabaseImageGuards(unittest.TestCase):
    def test_accepts_complete_official_digest_only(self):
        for prefix in ['postgres','docker.io/library/postgres']:
            value=prefix+'@sha256:'+'a'*64;self.assertEqual(pg.validate_image(value),value)
    def test_rejects_unpinned_tag(self):
        with self.assertRaises(ValueError):pg.validate_image('postgres:17')
    def test_rejects_other_registry(self):
        with self.assertRaises(ValueError):pg.validate_image('evil.invalid/postgres@sha256:'+'a'*64)
    def test_rejects_partial_digest(self):
        with self.assertRaises(ValueError):pg.validate_image('postgres@sha256:'+'a'*63)
    def test_rejects_shell_or_whitespace(self):
        for v in ['postgres@sha256:'+'a'*64+';x',' postgres@sha256:'+'a'*64,'postgres@sha256:'+'a'*64+'\n']:
            with self.assertRaises(ValueError):pg.validate_image(v)
    def test_fixture_quote_escapes_literals(self):
        self.assertEqual(pg.quote("it's synthetic"),"'it''s synthetic'")
if __name__=='__main__':unittest.main()
