#!/usr/bin/env python3
"""Run real OTP rate-limit transactions in an explicitly owned disposable DB."""
import argparse
import concurrent.futures
import hashlib
import io
import json
from pathlib import Path
import subprocess
import threading
import time
import unittest
import uuid


class RateLimitDatabaseTests(unittest.TestCase):
    database_container = None
    evidence = []

    def setUp(self):
        self.keys = []

    def tearDown(self):
        for key in self.keys:
            self.sql(f"delete from public.otp_rate_limits where bucket_key='{key}';")

    def key(self):
        key = hashlib.sha256(uuid.uuid4().bytes).hexdigest()
        self.keys.append(key)
        return key

    def sql(self, statement):
        started = time.monotonic()
        result = subprocess.run(
            ['docker', 'exec', '-i', self.database_container, 'sh', '-c',
             'PGPASSWORD="$POSTGRES_PASSWORD" exec psql "$@"', 'sh', '-X', '-qAt',
             '-U', 'postgres', '-d', 'postgres', '-v', 'ON_ERROR_STOP=1'],
            input=statement, text=True, capture_output=True, timeout=20,
        )
        self.evidence.append({'test': self.id().split('.')[-1], 'sql': statement,
                              'exit_code': result.returncode, 'stdout': result.stdout,
                              'stderr': result.stderr,
                              'elapsed_seconds': round(time.monotonic() - started, 4)})
        return result

    def parsed(self, result):
        self.assertEqual(result.returncode, 0, result.stderr)
        return [json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')]

    def request(self, key, window=60, maximum=5, role='service_role', prefix=''):
        result = self.sql(f"begin; {prefix} set local role {role}; "
                          f"select row_to_json(r) from public.consume_otp_rate_limit('{key}',{window},{maximum}) r; commit;")
        return self.parsed(result)[0]

    def wait_for_activity(self, application, wait_type):
        for _ in range(35):
            result = self.sql("select count(*) from pg_stat_activity where "
                              f"application_name='{application}' and wait_event_type='{wait_type}';")
            self.assertEqual(result.returncode, 0, result.stderr)
            if result.stdout.strip() != '0':
                return True
            time.sleep(0.02)
        return False

    def concurrent_requests(self, key, count, maximum, hold=0.1, observe_lock=False):
        barrier = threading.Barrier(count + 1)
        prefix = 'mobio-qa-rate-' + uuid.uuid4().hex[:10]

        def request(index):
            barrier.wait(timeout=10)
            return self.sql(f"begin; set local role service_role; set local application_name='{prefix}-{index}'; "
                            f"select row_to_json(r) from public.consume_otp_rate_limit('{key}',60,{maximum}) r; "
                            f"select pg_sleep({hold}); commit;")

        with concurrent.futures.ThreadPoolExecutor(max_workers=count) as pool:
            jobs = [pool.submit(request, i) for i in range(count)]
            barrier.wait(timeout=10)
            waited = False
            if observe_lock:
                for _ in range(30):
                    result = self.sql("select count(*) from pg_stat_activity where "
                                      f"application_name like '{prefix}-%' and wait_event_type='Lock';")
                    self.assertEqual(result.returncode, 0, result.stderr)
                    if result.stdout.strip() != '0':
                        waited = True
                        break
                    if all(job.done() for job in jobs):
                        break
                    time.sleep(0.02)
            results = [job.result() for job in jobs]
        if observe_lock:
            self.assertTrue(waited, 'No actual lock wait was observed; concurrency is unverified')
        return [self.parsed(result)[0] for result in results]

    def test_two_first_requests_create_one_bucket_without_errors(self):
        key = self.key()
        results = self.concurrent_requests(key, 2, 5, hold=0.4, observe_lock=True)
        self.assertTrue(all(row['allowed'] for row in results))
        self.assertEqual(sorted(row['request_count'] for row in results), [1, 2])
        final = self.sql(f"select count(*),max(request_count) from public.otp_rate_limits where bucket_key='{key}';")
        self.assertEqual(final.stdout.strip(), '1|2')

    def test_concurrent_requests_cannot_exceed_cap(self):
        results = self.concurrent_requests(self.key(), 8, 3)
        self.assertEqual(sum(row['allowed'] for row in results), 3)
        self.assertTrue(all(row['request_count'] <= 3 for row in results))
        self.assertTrue(all(row['retry_after_seconds'] >= 1 for row in results if not row['allowed']))

    def test_expired_window_resets_counter(self):
        key = self.key()
        self.request(key, maximum=1)
        self.sql(f"update public.otp_rate_limits set window_started_at=clock_timestamp()-interval '2 minutes' where bucket_key='{key}';")
        self.assertEqual(self.request(key, maximum=1), {'allowed': True, 'request_count': 1, 'retry_after_seconds': 0})

    def test_window_that_expires_while_waiting_uses_clock_after_lock(self):
        key = self.key()
        self.request(key, window=1, maximum=1)
        application = 'mobio-qa-rate-blocker-' + uuid.uuid4().hex[:8]
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            blocker = pool.submit(self.sql, f"begin; set local application_name='{application}'; "
                                  f"select bucket_key from public.otp_rate_limits where bucket_key='{key}' for update; "
                                  "select pg_sleep(1.4); commit;")
            self.assertTrue(self.wait_for_activity(application, 'Timeout'))
            result = self.request(key, window=1, maximum=1)
            self.assertEqual(blocker.result().returncode, 0)
        self.assertEqual(result, {'allowed': True, 'request_count': 1, 'retry_after_seconds': 0})

    def test_timezone_does_not_shift_window_instant(self):
        key = self.key()
        self.request(key, prefix="set local timezone='Pacific/Auckland';")
        result = self.sql(f"select abs(extract(epoch from (clock_timestamp()-window_started_at))) < 5 from public.otp_rate_limits where bucket_key='{key}';")
        self.assertEqual(result.stdout.strip(), 't')

    def test_invalid_arguments_fail_before_creating_bucket(self):
        key = self.key()
        for window, maximum in [('null', '5'), ('60', 'null'), ('0', '5'), ('60', '0'), ('-1', '5')]:
            with self.subTest(window=window, maximum=maximum):
                result = self.sql(f"set role service_role; select * from public.consume_otp_rate_limit('{key}',{window},{maximum});")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Invalid OTP rate limit parameters.', result.stderr)
        self.assertEqual(self.sql(f"select count(*) from public.otp_rate_limits where bucket_key='{key}';").stdout.strip(), '0')

    def test_client_roles_cannot_call_rpc_or_read_buckets(self):
        key = self.key()
        for role in ['anon', 'authenticated']:
            for statement in [f"select * from public.consume_otp_rate_limit('{key}',60,5);", 'select * from public.otp_rate_limits;']:
                with self.subTest(role=role, statement=statement):
                    result = self.sql(f'set role {role}; ' + statement)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn('permission denied', result.stderr)

    def test_independent_buckets_have_independent_limits(self):
        first, second = self.key(), self.key()
        self.assertTrue(self.request(first, maximum=1)['allowed'])
        self.assertTrue(self.request(second, maximum=1)['allowed'])
        self.assertFalse(self.request(first, maximum=1)['allowed'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--container', required=True)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    container = json.loads(subprocess.check_output(['docker', 'inspect', args.container]))[0]
    labels = container['Config'].get('Labels') or {}
    project = labels.get('com.supabase.cli.project', '')
    owned = labels.get('mobio.qa.thread') == '01a0a06c-2e40-7e81-b4da-b004eb1af370'
    cli_fixture = project.startswith('mobio_replay_') and args.container == 'supabase_db_' + project
    if not container['State']['Running'] or not (owned or cli_fixture):
        raise SystemExit('Refusing a database outside the explicitly owned Mobio QA fixtures')
    if owned and container['HostConfig']['NetworkMode'] != 'none':
        raise SystemExit('Owned QA fixture must retain network isolation')
    RateLimitDatabaseTests.database_container = args.container
    output = io.StringIO()
    result = unittest.TextTestRunner(stream=output, verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(RateLimitDatabaseTests))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'tests_run': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors),
                                       'summary': output.getvalue(), 'queries': RateLimitDatabaseTests.evidence,
                                       'scope': 'Real isolated SQL transactions and roles; no OTP delivery or external service'}, indent=2) + '\n')
    print(output.getvalue(), end='')
    return 0 if result.wasSuccessful() else 1


if __name__ == '__main__':
    raise SystemExit(main())
