"""Source/guard regressions only. SQL string checks are NOT database execution."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT=Path(__file__).resolve().parents[2]

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
ops=load('intake_ops','scripts/operations/run_sms_intake_worker.py')
pg=load('intake_pg','scripts/qa/test_sms_intake_postgres.py')
SQL=(ROOT/'supabase/hardening/2026-09-28/07_durable_sms_intake.sql').read_text()
URL='https://synthetic-project.supabase.co/functions/v1/momobio-sms-process'
TOKEN='z'*64

class TriggerTests(unittest.TestCase):
    def test_exact_settings(self): ops.validate_settings(URL,TOKEN)
    def test_untrusted_urls_denied(self):
        for url in ['http://synthetic-project.supabase.co/functions/v1/momobio-sms-process',URL+'?token=bad',URL+'#fragment',
                    'https://supabase.co.attacker.invalid/functions/v1/momobio-sms-process',
                    'https://user:secret@synthetic-project.supabase.co/functions/v1/momobio-sms-process',
                    'https://synthetic-project.supabase.co:8080/functions/v1/momobio-sms-process',URL+'\n']:
            with self.subTest(url=url),self.assertRaises(ValueError): ops.validate_settings(url,TOKEN)
    def test_weak_tokens_denied(self):
        for token in ['', 'short','x'*129,'x'*43+'\n']:
            with self.subTest(length=len(token)),self.assertRaises(ValueError): ops.validate_settings(URL,token)
    def test_process_args_do_not_expose_token(self):
        calls=[]
        def runner(args,**kwargs):
            calls.append((args,kwargs));return subprocess.CompletedProcess(args,0,'{"success":true,"outcome":"processed"}\n200','')
        self.assertEqual(ops.trigger(URL,TOKEN,runner),'processed')
        args,kwargs=calls[0];self.assertNotIn(TOKEN,' '.join(args));self.assertIn(TOKEN,kwargs['input'])
        self.assertIn('--max-time',args);self.assertIn('--max-redirs',args);self.assertEqual(kwargs['timeout'],55)
    def test_no_provider_body_in_exception(self):
        def runner(args,**kwargs): return subprocess.CompletedProcess(args,0,'sensitive SMS\n503','sensitive token')
        with self.assertRaises(RuntimeError) as ctx: ops.trigger(URL,TOKEN,runner)
        self.assertNotIn('sensitive',str(ctx.exception))
    def test_invalid_successes_rejected(self):
        for stdout in ['invalid\n200','{"success":false,"outcome":"processed"}\n200',
                       '{"success":true,"outcome":"unknown"}\n200','{"success":true,"outcome":"processed"}\n302']:
            with self.subTest(stdout=stdout),self.assertRaises(RuntimeError):
                ops.trigger(URL,TOKEN,lambda a,**k:subprocess.CompletedProcess(a,0,stdout,''))
    def test_curl_failure_not_success(self):
        with self.assertRaises(RuntimeError):ops.trigger(URL,TOKEN,lambda a,**k:subprocess.CompletedProcess(a,28,'',''))
    def test_socket_or_deadline_timeout_propagates_to_cli_error(self):
        def runner(args,**kwargs):raise subprocess.TimeoutExpired(args,55)
        with self.assertRaises(subprocess.TimeoutExpired):ops.trigger(URL,TOKEN,runner)
    def test_idle_reply_supported(self):
        self.assertEqual(ops.trigger(URL,TOKEN,lambda a,**k:subprocess.CompletedProcess(a,0,'{"success":true,"outcome":"idle_or_limited"}\n200','')),'idle_or_limited')

class DatabaseHarnessGuardTests(unittest.TestCase):
    def test_only_explicit_local_test_database(self):
        self.assertEqual(pg.validate_dsn('postgresql://127.0.0.1:5432/mobio_intake_test_component'),'mobio_intake_test_component')
    def test_production_and_hosted_targets_rejected(self):
        for dsn in ['', 'postgresql://localhost/postgres','postgresql://db.supabase.co/mobio_intake_test_component',
                    'postgresql://localhost/mobio_intake_test_component?host=remote.invalid',
                    'postgresql://localhost/mobio_intake_test_component#ignored','postgresql://localhost/mobio_intake_test_../x']:
            with self.subTest(dsn=dsn),self.assertRaises(ValueError):pg.validate_dsn(dsn)

class SqlSourceContractTests(unittest.TestCase):
    def test_private_queue_tables(self):
        for table in ('momobio_sms_intake','momobio_sms_intake_config','momobio_sms_intake_budget'):
            self.assertIn(f'alter table public.{table} enable row level security',SQL)
        self.assertIn('from public,anon,authenticated',SQL)
    def test_atomic_admission_unique_key(self):
        self.assertIn('unique (collector_id,message_hash)',SQL)
        self.assertIn('INTAKE_HASH_CONFLICT',SQL);self.assertIn('INTAKE_CAPACITY',SQL)
    def test_no_automatic_processing_enablement(self):self.assertIn('processing_enabled boolean not null default false',SQL)
    def test_stale_fence_precedes_allocator_call(self):
        complete=SQL.split('create function public.rpc_complete_momobio_sms_intake',1)[1].split('create function public.rpc_retry',1)[0]
        self.assertLess(complete.index("'status','stale'"),complete.index('result := public.rpc_ingest_driver_subscription_momo_sms'))
        self.assertIn('job.lease_token is distinct from p_lease_token',complete)
        self.assertIn('job.lease_expires_at<=clock_timestamp()',complete)
    def test_allocator_and_queue_in_same_body(self):
        complete=SQL.split('create function public.rpc_complete_momobio_sms_intake',1)[1].split('create function public.rpc_retry',1)[0]
        self.assertIn('update public.momobio_sms_intake set status=next_status',complete)
        self.assertNotIn('exception when others',complete.lower())
    def test_claim_has_concurrency_budget_and_recovery(self):
        for phrase in ('for update skip locked','max_concurrency','max_attempts_per_hour',"last_error_code='lease_expired'",'max_attempts'):
            self.assertIn(phrase,SQL)
    def test_no_pending_sms_auto_purge(self):
        self.assertNotIn('delete from public.momobio_sms_intake where',SQL)
    def test_no_sync_parser_in_ingest(self):
        source=(ROOT/'supabase/functions/momobio-sms-ingest/index.ts').read_text()
        self.assertNotIn('parseMomoSmsWithOpenAi',source);self.assertNotIn('rpc_ingest_driver_subscription_momo_sms',source)
        self.assertIn('rpc_admit_momobio_sms_batch',source)
    def test_manifest_has_exact_forward_body_hash(self):
        import hashlib
        manifest=json.loads((ROOT/'supabase/hardening/2026-09-28/manifest.json').read_text())
        entry=next(x for x in manifest['bodies'] if x['file']=='07_durable_sms_intake.sql')
        self.assertEqual(entry['sha256'],hashlib.sha256(SQL.encode()).hexdigest())

if __name__=='__main__':unittest.main()
