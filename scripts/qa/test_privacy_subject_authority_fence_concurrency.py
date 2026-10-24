#!/usr/bin/env python3
"""STAGED / UNEXECUTED. Real SQL connections in an already owned fixture only.

Does not start Docker/Supabase, apply migrations, contact providers or claim
signed-JWT acceptance. Synthetic UUID/case rows persist until the parent removes
its disposable project. Policy rows are restored by this narrow runner.
"""
from concurrent.futures import ThreadPoolExecutor
import json
import os
import re
import subprocess
import sys
import time
import uuid


def main():
    if len(sys.argv) != 2 or not re.fullmatch(
        r"supabase_db_mobio_(?:privacy_fence|replay)_\d+", sys.argv[1]
    ):
        raise SystemExit("Expected exact, uniquely owned privacy-fence/replay container")
    container = sys.argv[1]
    docker = os.environ.get(
        "DOCKER_BIN", "/Volumes/PRO-G40/Applications/Docker.app/Contents/Resources/bin/docker"
    )
    argv = [
        docker, "exec", "-i", container, "sh", "-c",
        'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U postgres -d postgres -qAt -v ON_ERROR_STOP=1',
    ]
    check_labels = []
    holders = []
    sequence = 0
    plan, inventory = "a" * 64, "b" * 64

    def quote(value):
        return "'" + value.replace("'", "''") + "'"

    def sql(statement):
        proc = subprocess.run(argv, input=statement, text=True, capture_output=True, timeout=45)
        if proc.returncode:
            # Only known fixture SQL/error contracts are used. No DB credential
            # value is interpolated into statements, logs or exception text.
            raise RuntimeError(proc.stderr[-1800:])
        return proc.stdout.strip().splitlines()

    def last_json(lines):
        return next(json.loads(line) for line in reversed(lines) if line.startswith("{"))

    def record(label):
        check_labels.append(label)
        print("PASS: " + label, flush=True)

    def wait_state(label, state=None, locked=False, marker=None):
        predicate = "application_name=" + quote(label)
        if state:
            predicate += " and state=" + quote(state)
        if locked:
            predicate += " and wait_event_type='Lock'"
        if marker:
            predicate += " and strpos(query," + quote(marker) + ")>0"
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            if sql("select exists(select 1 from pg_stat_activity where " + predicate + ")") == ["t"]:
                return
            time.sleep(0.025)
        raise AssertionError("Owned deterministic barrier not reached: " + label)

    def holder(statement, label, claims=None):
        proc = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, text=True)
        holders.append(proc)
        prefix = "set application_name=" + quote(label) + ";begin;"
        if claims:
            prefix += "set request.jwt.claims=" + quote(claims) + ";"
        proc.stdin.write(prefix + statement + ";select 'HELD';\n")
        proc.stdin.flush()
        wait_state(label, "idle in transaction")
        return proc

    def finish(proc, statement="commit;", expected_error=None):
        proc.stdin.write(statement + "\n\\q\n")
        proc.stdin.close()
        proc.wait(timeout=15)
        error = proc.stderr.read()
        proc.stdout.close()
        proc.stderr.close()
        holders.remove(proc)
        if expected_error:
            assert proc.returncode != 0 and expected_error in error, "Wrong held-writer denial"
        else:
            assert proc.returncode == 0, "Held writer failed unexpectedly"

    def call(expression, app="mobio_fence_rpc"):
        return last_json(sql("set application_name=" + quote(app) + ";begin;"
                             "set request.jwt.claims='{\"role\":\"service_role\"}';"
                             "set local role service_role;select " + expression + ";commit;"))

    def expect_error(fn, message):
        try:
            fn()
        except RuntimeError as exc:
            assert message in str(exc), "Unexpected SQL denial contract"
            return
        raise AssertionError("Unexpected accepted operation: " + message)

    def fixture(*, present=True, proved=True):
        nonlocal sequence
        sequence += 1
        result = dict(id=str(uuid.uuid4()), sid=str(uuid.uuid4()), otp=str(uuid.uuid4()),
                      request=str(uuid.uuid4()), action=str(uuid.uuid4()),
                      phone="+25077" + str(uuid.uuid4().int % 10000000).zfill(7))
        if present:
            sql("begin;set request.jwt.claims='{\"role\":\"service_role\"}';"
                "insert into auth.users(id,phone,phone_confirmed_at,is_anonymous,raw_app_meta_data,raw_user_meta_data)"
                f"values('{result['id']}','{result['phone']}',now(),false,'{{\"provider\":\"whatsapp_cloud_otp\"}}','{{}}');"
                f"insert into auth.sessions(id,user_id,created_at,not_after) values('{result['sid']}','{result['id']}',now(),now()+interval '1 hour');"
                "insert into public.otp_codes(id,phone,purpose,code,code_hash,verified,expires_at)"
                f"values('{result['otp']}','{result['phone']}','app_login','000000',repeat('c',64),true,now()+interval '5 minutes');commit;")
            if proved:
                call(f"public.rpc_register_app_whatsapp_session('{result['id']}','{result['sid']}','{result['otp']}')")
        sql("insert into mobio_private.privacy_requests(request_id,owner_id,originating_session_id,notice_version,"
            "status,revision,started_at,plan_sha256,inventory_sha256) values("
            f"'{result['request']}','{result['id']}','{result['sid']}','qa-fence-v1','processing',1,now(),'{plan}','{inventory}')")
        result["label"] = "mobio_fence_" + str(os.getpid()) + "_" + str(sequence)
        return result

    def activation(actor):
        return (f"public.rpc_privacy_activate_subject_fence('{actor['request']}','{actor['action']}',1,"
                f"'{plan}','{inventory}','qa/concurrency')")

    def denied_now(actor):
        return sql("select not mobio_private.verified_interactive_account_is_eligible("
                   + quote(actor["id"]) + "::uuid)") == ["t"]

    assert sql("select to_regprocedure('public.rpc_privacy_activate_subject_fence(uuid,uuid,integer,text,text,text)') is not null") == ["t"]
    privacy_backup = last_json(sql("select to_jsonb(p) from mobio_private.privacy_policy p where singleton"))
    push_backup = last_json(sql("select to_jsonb(p) from mobio_private.push_policy p where singleton"))
    sql("update mobio_private.privacy_policy set intake_enabled=true,processing_enabled=true,"
        "notice_version='qa-fence-v1',approval_reference='qa/concurrency',inventory_sha256=" + quote(inventory) + " where singleton")
    try:
        # A real locked-sensitive admission holds S through the transaction;
        # activation waits X, then denies all future authority after that commit.
        actor = fixture()
        held = holder("select mobio_private.require_verified_interactive_session("
                      f"'{actor['id']}','{actor['sid']}',false);"
                      f"update public.profiles set name='pre-fence committed' where id='{actor['id']}'",
                      actor["label"] + "_sensitive")
        with ThreadPoolExecutor(max_workers=2) as pool:
            pending = pool.submit(call, activation(actor), actor["label"] + "_activation")
            wait_state(actor["label"] + "_activation", locked=True)
            assert sql("select revision from mobio_private.privacy_requests where request_id=" + quote(actor["request"])) == ["1"]
            finish(held)
            receipt = pending.result()
        assert receipt["receipt"]["subject_user_id"] == actor["id"] and denied_now(actor)
        record("actual sensitive mutation commits before waiting subject fence; future authority denies")

        # A composed S-holder then configures policy. Activation must not hold
        # the policy row while waiting X; after the wait it must see disablement.
        actor = fixture()
        label = actor["label"] + "_policy_writer"
        held = holder("select mobio_private.require_verified_interactive_session("
                      f"'{actor['id']}','{actor['sid']}',false)", label)
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(call, activation(actor), actor["label"] + "_activation")
            wait_state(actor["label"] + "_activation", locked=True)
            held.stdin.write("set request.jwt.claims='{\"role\":\"service_role\"}';"
                             "select public.rpc_privacy_configure(true,false,'qa-fence-v1',"
                             + quote(inventory) + ",'qa/policy-recheck');select 'POLICY_UPDATED';\n")
            held.stdin.flush()
            wait_state(label, "idle in transaction", marker="POLICY_UPDATED")
            finish(held)
            expect_error(pending.result, "PRIVACY_PROCESSING_DISABLED")
        assert sql(f"select revision=1 and not exists(select 1 from mobio_private.privacy_subject_authority_fences where subject_user_id='{actor['id']}') from mobio_private.privacy_requests where request_id='{actor['request']}'") == ["t"]
        sql("update mobio_private.privacy_policy set processing_enabled=true where singleton")
        record("subject-held service policy change avoids row inversion; waiting activation rechecks disabled policy")

        # An unguarded row-only lock cannot delay activation. A later write in
        # that row-first transaction enters the trigger and rejects after X.
        actor = fixture()
        held = holder(f"select 1 from auth.users where id='{actor['id']}' for update", actor["label"] + "_row")
        with ThreadPoolExecutor(max_workers=1) as pool:
            result = pool.submit(call, activation(actor), actor["label"] + "_activation").result(timeout=10)
        assert result["replayed"] is False and denied_now(actor)
        assert sql("begin read only;select not mobio_private.verified_interactive_account_is_eligible("
                   + quote(actor["id"]) + "::uuid);rollback;") == ["t"]
        finish(held, f"update auth.users set raw_user_meta_data='{{}}' where id='{actor['id']}';commit;",
               "SUBJECT_AUTHORITY_FENCED")
        record("activation completes with Auth row already locked; late row-first Auth update denies without inversion")

        actor = fixture()
        held = holder(f"update public.profiles set name='row-first before fence' where id='{actor['id']}'",
                      actor["label"] + "_profile")
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(call, activation(actor), actor["label"] + "_activation")
            wait_state(actor["label"] + "_activation", locked=True)
            finish(held)
            pending.result()
        assert denied_now(actor)
        record("actual profile BEFORE trigger holds shared subject fence until row-first writer commits")

        # X first, no Auth row: a future INSERT waits and then rejects before the
        # original handle_new_user AFTER trigger can produce a profile.
        actor = fixture(present=False)
        held = holder("set request.jwt.claims='{\"role\":\"service_role\"}';select " + activation(actor),
                      actor["label"] + "_activation")
        statement = ("set application_name=" + quote(actor["label"] + "_insert") + ";begin;"
                     "set request.jwt.claims='{\"role\":\"service_role\"}';"
                     "insert into auth.users(id,phone,phone_confirmed_at,is_anonymous,raw_app_meta_data,raw_user_meta_data)"
                     f"values('{actor['id']}','{actor['phone']}',now(),false,'{{\"provider\":\"whatsapp_cloud_otp\"}}','{{}}');commit;")
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(sql, statement)
            wait_state(actor["label"] + "_insert", locked=True)
            finish(held)
            expect_error(pending.result, "SUBJECT_AUTHORITY_FENCED")
        assert sql(f"select not exists(select 1 from auth.users where id='{actor['id']}') and not exists(select 1 from public.profiles where id='{actor['id']}')") == ["t"]
        record("missing-row X fence blocks held future Auth insertion and automatic profile materialization")

        # INSERT first: activation waits the BEFORE-trigger S even though its
        # case owner had no Auth row when the case was captured.
        actor = fixture(present=False)
        held = holder("set request.jwt.claims='{\"role\":\"service_role\"}';"
                      "insert into auth.users(id,phone,phone_confirmed_at,is_anonymous,raw_app_meta_data,raw_user_meta_data)"
                      f"values('{actor['id']}','{actor['phone']}',now(),false,'{{\"provider\":\"whatsapp_cloud_otp\"}}','{{}}')",
                      actor["label"] + "_insert")
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(call, activation(actor), actor["label"] + "_activation")
            wait_state(actor["label"] + "_activation", locked=True)
            finish(held)
            pending.result()
        assert sql(f"select exists(select 1 from public.profiles where id='{actor['id']}')") == ["t"]
        expect_error(lambda: sql(f"update public.profiles set name='late' where id='{actor['id']}'"),
                     "SUBJECT_AUTHORITY_FENCED")
        record("missing-row Auth/profile insertion admitted first commits before fence; later service write denies")

        # Real register/bind RPC acquires S before waiting on an Auth row lock.
        actor = fixture(proved=False)
        held = holder(f"select 1 from auth.users where id='{actor['id']}' for update", actor["label"] + "_auth")
        with ThreadPoolExecutor(max_workers=2) as pool:
            proof = pool.submit(call,
                                f"public.rpc_register_app_whatsapp_session('{actor['id']}','{actor['sid']}','{actor['otp']}')",
                                actor["label"] + "_proof")
            wait_state(actor["label"] + "_proof", locked=True)
            fence = pool.submit(call, activation(actor), actor["label"] + "_activation")
            wait_state(actor["label"] + "_activation", locked=True)
            finish(held)
            proved = proof.result()
            fence.result()
        assert proved["session_id"] == actor["sid"] and denied_now(actor)
        record("actual contextual OTP binding/proof holds shared subject before Auth row wait and fence linearization")

        actor = fixture(proved=False)
        held = holder("set request.jwt.claims='{\"role\":\"service_role\"}';select " + activation(actor),
                      actor["label"] + "_activation")
        with ThreadPoolExecutor(max_workers=1) as pool:
            proof = pool.submit(call,
                                f"public.rpc_register_app_whatsapp_session('{actor['id']}','{actor['sid']}','{actor['otp']}')",
                                actor["label"] + "_proof")
            wait_state(actor["label"] + "_proof", locked=True)
            finish(held)
            expect_error(proof.result, "WHATSAPP_BINDING_REJECTED")
        assert sql(f"select not exists(select 1 from mobio_private.whatsapp_identity_bindings where user_id='{actor['id']}') and not exists(select 1 from mobio_private.consumer_session_proofs where user_id='{actor['id']}')") == ["t"]
        record("held fence commits before late OTP proof; no binding or exact-session proof materializes")

        actor = fixture()
        with ThreadPoolExecutor(max_workers=8) as pool:
            responses = list(pool.map(lambda _: call(activation(actor)), range(8)))
        receipts = [result["receipt"] for result in responses]
        assert all(receipt == receipts[0] for receipt in receipts)
        assert sum(result["replayed"] is False for result in responses) == 1
        assert sql(f"select count(*) from mobio_private.privacy_actions where action_id='{actor['action']}'") == ["1"]
        assert sql(f"select revision from mobio_private.privacy_requests where request_id='{actor['request']}'") == ["2"]
        record("eight concurrent duplicate activations yield one revision, ledger event and immutable receipt")

        # Actual public proof -> owner RPC in one authenticated transaction.
        # X must wait before acquiring the case row, so this owner retry is free
        # to obtain owner/case locks and commit its pre-fence truthful status.
        actor = fixture()
        claims = json.dumps(dict(sub=actor["id"], session_id=actor["sid"], role="authenticated",
                                 is_anonymous=False, app_metadata=dict(provider="whatsapp_cloud_otp")))
        label = actor["label"] + "_owner"
        held = holder("set local role authenticated;select public.rpc_verified_interactive_session()", label, claims)
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(call, activation(actor), actor["label"] + "_activation")
            wait_state(actor["label"] + "_activation", locked=True)
            held.stdin.write(f"select public.rpc_privacy_user('request','{actor['request']}','qa-fence-v1',true);"
                             "select 'OWNER_RPC_RETURNED';\n")
            held.stdin.flush()
            wait_state(label, "idle in transaction", marker="OWNER_RPC_RETURNED")
            finish(held)
            pending.result()
        assert denied_now(actor)
        record("two connections: actual public proof plus owner request retry finishes while activation waits before case lock")

        actor = fixture()
        claims = json.dumps(dict(sub=actor["id"], session_id=actor["sid"], role="authenticated",
                                 is_anonymous=False, app_metadata=dict(provider="whatsapp_cloud_otp")))
        label = actor["label"] + "_cancel"
        held = holder("set local role authenticated;select public.rpc_verified_interactive_session()", label, claims)
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(call, activation(actor), actor["label"] + "_activation")
            wait_state(actor["label"] + "_activation", locked=True)
            held.stdin.write("do $owner_cancel$ begin begin "
                             f"perform public.rpc_privacy_user('cancel','{actor['request']}');"
                             "raise exception 'UNEXPECTED_CANCEL_ACCEPTED';"
                             "exception when sqlstate 'P0001' then "
                             "if sqlerrm<>'PRIVACY_NOT_CANCELLABLE' then raise; end if;"
                             "end;end $owner_cancel$;select 'CANCEL_RPC_RETURNED';\n")
            held.stdin.flush()
            wait_state(label, "idle in transaction", marker="CANCEL_RPC_RETURNED")
            finish(held)
            pending.result()
        assert denied_now(actor)
        assert sql(f"select status from mobio_private.privacy_requests where request_id='{actor['request']}'") == ["processing"]
        record("two connections: actual owner cancel keeps precise processing denial without subject/case inversion")

        # Service fulfil must use S -> owner -> case too, but cannot require
        # ordinary admission: evidence/completion remains possible after fence.
        actor = fixture()
        fulfil_action = str(uuid.uuid4())
        held = holder("set request.jwt.claims='{\"role\":\"service_role\"}';"
                      f"select public.rpc_privacy_fulfil('{actor['request']}','{fulfil_action}',1,'block',"
                      "'{\"code\":\"inventory_incomplete\"}','qa/fulfil')", actor["label"] + "_fulfil")
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(call, activation(actor), actor["label"] + "_activation")
            wait_state(actor["label"] + "_activation", locked=True)
            finish(held)
            expect_error(pending.result, "PRIVACY_REVISION_CONFLICT")
        assert sql(f"select revision=2 and status='blocked' and not exists(select 1 from mobio_private.privacy_subject_authority_fences where subject_user_id='{actor['id']}') from mobio_private.privacy_requests where request_id='{actor['request']}'") == ["t"]
        record("actual service fulfil precedes waiting activation with common subject/owner/case order and revision recheck")

        # Pure admission creates no hidden subject lock. A subsequent Edge-like
        # service materialization rejects after activation; no signed HTTP claim.
        actor = fixture()
        claims = json.dumps(dict(sub=actor["id"], session_id=actor["sid"], role="authenticated",
                                 is_anonymous=False, app_metadata=dict(provider="whatsapp_cloud_otp")))
        held = holder("select public.verified_app_user_id()", actor["label"] + "_read", claims)
        with ThreadPoolExecutor(max_workers=1) as pool:
            pool.submit(call, activation(actor)).result(timeout=10)
        finish(held, "set request.jwt.claims='{\"role\":\"service_role\"}';"
               f"update public.profiles set name='late after pure admission' where id='{actor['id']}';commit;",
               "SUBJECT_AUTHORITY_FENCED")
        record("pure admission remains lock-free; post-admission service materialization denies after fence")

        # The real push final-authorization body takes S before its budget row
        # wait. An already authorized external send remains an explicit limit.
        actor = fixture()
        sql("update mobio_private.push_policy set enabled=true where singleton")
        token = "qa-fence-token-" + str(uuid.uuid4())
        notification, lease = str(uuid.uuid4()), str(uuid.uuid4())
        sql("begin;set request.jwt.claims='{\"role\":\"service_role\"}';"
            f"insert into public.fcm_tokens(user_id,token,platform,session_id) values('{actor['id']}','{token}','android','{actor['sid']}');"
            "insert into public.notifications(id,user_id,title,body,type,metadata)"
            f"values('{notification}','{actor['id']}','Synthetic fence','Synthetic SQL fixture','system_announcement','{{\"channels\":[\"push\"]}}');"
            f"update mobio_private.push_jobs set state='leased',attempts=1,lease_id='{lease}',lease_until=clock_timestamp()+interval '2 minutes' where notification_id='{notification}';"
            "insert into mobio_private.push_hour_budget(hour_start) values(date_trunc('hour',clock_timestamp(),'UTC')) on conflict do nothing;commit;")
        jobs = sql(f"select id from mobio_private.push_jobs where notification_id='{notification}'")
        assert len(jobs) == 1, "Expected exact synthetic notification job"
        job = jobs[0]
        held = holder("select 1 from mobio_private.push_hour_budget where hour_start=date_trunc('hour',clock_timestamp(),'UTC') for update",
                      actor["label"] + "_budget")
        with ThreadPoolExecutor(max_workers=2) as pool:
            authorized = pool.submit(call, f"public.rpc_push_authorize('{job}','{lease}')", actor["label"] + "_push")
            wait_state(actor["label"] + "_push", locked=True)
            fence = pool.submit(call, activation(actor), actor["label"] + "_activation")
            wait_state(actor["label"] + "_activation", locked=True)
            finish(held)
            allowed = authorized.result()
            fence.result()
        assert allowed["allowed"] is True and denied_now(actor)
        # No send is attempted, and returned synthetic token is never printed.
        record("actual final push authorization commits before waiting fence; external in-flight limit remains explicit")

        print(json.dumps(dict(passed=True, matrices=len(check_labels), checks=check_labels,
                              actual_sql_connections=True, signed_http=False,
                              provider_calls=0, automation_installed=False,
                              production_acceptance=False,
                              cleanup="parent must destroy exact disposable project")), flush=True)
    finally:
        for proc in list(holders):
            try:
                finish(proc, "rollback;")
            except Exception:
                proc.kill()
                proc.wait(timeout=5)
        # No secret values enter these policy copies. Only this disposable
        # fixture was mutated; root owns final case/subject/container cleanup.
        for table, backup in [("privacy_policy", privacy_backup), ("push_policy", push_backup)]:
            assignments = ",".join('"' + key + '"=restored."' + key + '"' for key in backup)
            sql(f"update mobio_private.{table} live_policy set {assignments} from jsonb_populate_record("
                f"null::mobio_private.{table},{quote(json.dumps(backup))}::jsonb) restored where live_policy.singleton")


if __name__ == "__main__":
    main()
