#!/usr/bin/env python3
"""Run body10 in a disposable PostgreSQL17 container with synthetic prerequisites.

No host database, DSN, linked project, customer data or mounted repository is used.
Require a reviewed immutable OFFICIAL postgres image through MOBIO_CHAT_POSTGRES_IMAGE.
Auth/Plus and notification-trigger doubles are explicit; passing is component
SQL/concurrency evidence only, NOT full-schema/PostgREST/device acceptance.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

ROOT=Path(__file__).resolve().parents[2]
A='00000000-0000-4000-8000-000000000001'
B='00000000-0000-4000-8000-000000000002'
C='00000000-0000-4000-8000-000000000003'
CONV='00000000-0000-4000-8000-000000000010'
OTHER='00000000-0000-4000-8000-000000000011'

def validate_image(image: str) -> str:
    if not re.fullmatch(r'(?:docker\.io/library/)?postgres@sha256:[0-9a-f]{64}',image):
        raise ValueError('Require a reviewed official postgres image pinned to a complete sha256 digest')
    return image

def main() -> int:
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-tools',action='store_true')
    args=parser.parse_args()
    if not shutil.which('docker'):
        print('UNAVAILABLE: Docker is absent; PostgreSQL chat tests NOT EXECUTED.',file=sys.stderr)
        return 2
    if args.check_tools:
        print('Docker executable found; not test execution or daemon verification.')
        return 0
    image=validate_image(os.environ.get('MOBIO_CHAT_POSTGRES_IMAGE',''))
    name='mobio-chat-test-'+uuid.uuid4().hex
    checks=[]
    def command(argv:list[str],input_text:str|None=None) -> str:
        result=subprocess.run(argv,input=input_text,text=True,capture_output=True,timeout=90)
        if result.returncode:
            # Input contains only explicit synthetic fixtures. Never a real DSN.
            raise RuntimeError(result.stderr[-3000:])
        return result.stdout.strip()
    def sql(statement:str) -> str:
        return command(['docker','exec','-i',name,'psql','-X','-q','-A','-t','-U','postgres',
            '--set','ON_ERROR_STOP=1'],statement)
    def as_user(statement:str,actor:str=A,role:str='authenticated') -> str:
        if actor not in (A,B,C) or role not in ('authenticated','anon','service_role'):
            raise ValueError('Fixture identity only')
        return sql(f"set role {role}; set fixture.actor='{actor}';\n"+statement)
    def value(statement:str,actor:str=A) -> object:
        return json.loads(as_user(statement,actor))
    def record(name:str,condition:bool):
        if not condition:raise AssertionError(name)
        checks.append(name)
    def denied(name:str,statement:str,token:str,actor:str=A,role:str='authenticated'):
        try:as_user(statement,actor,role)
        except RuntimeError as exc:
            if token not in str(exc):raise AssertionError('Unexpected failure for '+name) from exc
            checks.append(name)
        else:raise AssertionError('Unexpected authorization success: '+name)
    def send(op:str,text:str='synthetic',conv:str=CONV):
        # All values are fixture-generated; SQL literal quoting still required.
        body=text.replace("'","''")
        return f"select public.rpc_send_chat_message_v2('{conv}','{op}','{body}')::text;"
    def close(op:str,cancel:bool=False,conv:str=CONV,text:str='synthetic'):
        import hashlib
        digest=hashlib.sha256(text.encode()).hexdigest()
        return f"select public.rpc_close_chat_delivery('{conv}','{op}','{digest}',{'true' if cancel else 'false'})::text;"
    try:
        command(['docker','pull','--quiet',image])
        command(['docker','run','--detach','--rm','--name',name,'--network','none',
            '--tmpfs','/var/lib/postgresql/data','--tmpfs','/tmp',
            '-e','POSTGRES_PASSWORD=synthetic-isolated-fixture',image])
        for _ in range(40):
            try:command(['docker','exec',name,'pg_isready','-U','postgres']);break
            except RuntimeError:time.sleep(.5)
        version=int(sql("select current_setting('server_version_num');"))
        if not 170000<=version<180000:raise RuntimeError('PostgreSQL17 required; image major does not match')
        if sql("select count(*) from pg_tables where schemaname='public';")!='0':
            raise RuntimeError('Expected empty isolated database')
        sql((ROOT/'scripts/tests/sql/chat_fixture_bootstrap.sql').read_text())
        sql((ROOT/'supabase/hardening/2026-09-28/10_chat_delivery_and_pagination.sql').read_text())
        op=str(uuid.uuid4())
        denied('default-off enforcement',send(op),'CHAT_SENDS_PAUSED')
        denied('client cannot enable sends',"select public.rpc_set_chat_sends_enabled(true);",'permission denied')
        as_user("select public.rpc_set_chat_sends_enabled(true);",role='service_role')
        sql('update mobio_private.chat_delivery_policy set min_send_interval_ms=0;')
        first=value(send(op))
        record('atomic sent receipt',isinstance(first,dict) and first['state']=='sent' and first['acknowledged'] is False)
        with ThreadPoolExecutor(max_workers=8) as pool:
            retries=list(pool.map(lambda _:value(send(op)),range(8)))
        record('eight sessions replay one receipt',all(x==first for x in retries))
        record('one persisted message and trigger effect',sql('select count(*) from public.chat_messages;')=='1' and
            sql('select count(*) from public.fixture_insert_events;')=='1')
        denied('different body same id rejected',send(op,'different'),'CHAT_OPERATION_CONFLICT')
        denied('different conversation same id rejected',send(op,conv=OTHER),'CHAT_OPERATION_CONFLICT')
        denied('second unresolved send blocked',send(str(uuid.uuid4())),'CHAT_UNRESOLVED_SEND')
        denied('foreign conversation member rejected',send(str(uuid.uuid4())),'CONVERSATION_NOT_FOUND',actor=C)
        denied('unverified identity rejected',"set fixture.verified='false';"+send(str(uuid.uuid4())),'AUTHENTICATION_REQUIRED')
        record('acknowledgement retains immutable sent receipt',value(close(op))['acknowledged'] is True)
        cancelled=str(uuid.uuid4());value(close(cancelled,True))
        record('cancellation fences late send',value(send(cancelled))['state']=='cancelled')
        # Real SQL interleaving, not a Python model. Either legal linearization wins.
        racing=str(uuid.uuid4())
        with ThreadPoolExecutor(max_workers=2) as pool:
            one=pool.submit(value,send(racing));two=pool.submit(value,close(racing,True))
            outcomes=[one.result(),two.result()]
        record('send/cancel race has one consistent state',outcomes[0]['state']==outcomes[1]['state'])
        record('send/cancel race has at most one effect',sql(f"select count(*) from public.chat_messages where metadata->>'client_message_id'='{racing}';") in ('0','1'))
        denied('no direct message reads',"select body from public.chat_messages;",'permission denied')
        denied('no direct message mutation',"update public.chat_messages set body='unauthorized';",'permission denied')
        denied('no direct participant reassignment',f"update public.chat_conversations set participant_low_id='{C}';",'permission denied')
        denied('anonymous cannot execute send',send(str(uuid.uuid4())),'permission denied',role='anon')
        denied('legacy route retired',f"select public.rpc_send_chat_message('{CONV}','legacy');",'CHAT_CLIENT_UPDATE_REQUIRED')
        # Populate >100 rows, including tied timestamps, in the independent conversation.
        sql(f"""insert into public.chat_messages(conversation_id,sender_id,message_type,body,created_at)
          select '{OTHER}','{B}','text','fixture '||n,'2026-01-01T00:00:00Z'::timestamptz+make_interval(secs=>n/3)
          from generate_series(1,125) n;""")
        query=f"select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)::text from public.rpc_list_chat_messages_page('{OTHER}',50) x;"
        head=value(query);cursor=head[-1]
        rest=value(f"select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)::text from public.rpc_list_chat_messages_page('{OTHER}',100,'{cursor['created_at']}','{cursor['id']}') x;")
        record('keyset pages cover all125 without overlaps',len(head)==50 and len(rest)==75 and len({x['id'] for x in head+rest})==125)
        watermark=head[0]
        record('read watermark covers existing rows',as_user(f"select public.rpc_mark_chat_read('{OTHER}','{watermark['created_at']}','{watermark['id']}');")=='125')
        denied('forged read watermark rejected',f"select public.rpc_mark_chat_read('{OTHER}','2099-01-01T00:00:00Z','{watermark['id']}');",'INVALID_CHAT_CURSOR')
        denied('invalid limit rejected',f"select * from public.rpc_list_chat_messages_page('{OTHER}',100000);",'INVALID_CHAT_CURSOR')
        # Real redaction path with the explicitly synthetic Plus entitlement double.
        trip=str(uuid.uuid4());sql(f"insert into public.trips values('{trip}','{A}','driver'); update public.chat_conversations set trip_id='{trip}' where id='{OTHER}';")
        hidden=value(f"select jsonb_agg(to_jsonb(x))::text from public.rpc_list_chat_messages_page('{OTHER}',50) x;")
        record('Plus redaction applies to body and metadata',all(x['access_redacted'] and x['metadata'].get('redacted') and x['body'].startswith('Mobio Plus required') for x in hidden))
        denied('Plus send denial',send(str(uuid.uuid4()),conv=OTHER),'MOBIO_PLUS_REQUIRED')
        sql(f"insert into public.user_blocks values('{A}','{B}');")
        denied('blocking applies to new sends',send(str(uuid.uuid4())),'USER_BLOCKED')
        # Deleted message must not allow operation replay to resurrect it.
        sql(f"delete from public.chat_messages where id='{first['message_id']}';")
        deleted=value(send(op))
        record('retained tombstone prevents deleted-message replay',deleted['state']=='sent' and deleted['message_id'] is None)
        print(json.dumps({'status':'passed','postgres_version_num':version,'image':image,
            'lane':'actual body10 SQL with synthetic Auth/Plus/trigger prerequisites',
            'checks':checks,'count':len(checks),'full_schema_or_production_acceptance':False},indent=2))
        return 0
    finally:
        subprocess.run(['docker','rm','--force',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=20)

if __name__=='__main__':
    try:sys.exit(main())
    except (ValueError,RuntimeError,AssertionError,subprocess.SubprocessError) as exc:
        print('FAIL: '+str(exc),file=sys.stderr);sys.exit(1)
