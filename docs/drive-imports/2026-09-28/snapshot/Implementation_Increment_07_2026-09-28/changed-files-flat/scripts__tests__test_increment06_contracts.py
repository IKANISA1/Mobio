"""Executable runner-input guards and STATIC source contracts, reported separately.

Static checks cannot establish Dart compilation, database behavior, or security
of deployed code. The actual SQL and Dart lanes are separate required gates.
"""
import importlib.util
import json
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[2]
_spec=importlib.util.spec_from_file_location('chat_pg_runner',ROOT/'scripts/qa/test_chat_postgres.py')
runner=importlib.util.module_from_spec(_spec);_spec.loader.exec_module(runner)
def text(path):return (ROOT/path).read_text()
SQL='supabase/hardening/2026-09-28/10_chat_delivery_and_pagination.sql'

class RunnerInputGuards(unittest.TestCase):
 def test_official_short_digest(self):self.assertEqual(runner.validate_image('postgres@sha256:'+'a'*64),'postgres@sha256:'+'a'*64)
 def test_official_qualified_digest(self):runner.validate_image('docker.io/library/postgres@sha256:'+'1'*64)
 def test_missing_rejected(self):self.assertRaises(ValueError,runner.validate_image,'')
 def test_mutable_tag_rejected(self):self.assertRaises(ValueError,runner.validate_image,'postgres:17-alpine')
 def test_other_registry_rejected(self):self.assertRaises(ValueError,runner.validate_image,'example.com/postgres@sha256:'+'a'*64)
 def test_other_repository_rejected(self):self.assertRaises(ValueError,runner.validate_image,'other/postgres@sha256:'+'a'*64)
 def test_incomplete_digest_rejected(self):self.assertRaises(ValueError,runner.validate_image,'postgres@sha256:'+'a'*63)
 def test_shell_metacharacters_rejected(self):self.assertRaises(ValueError,runner.validate_image,'postgres@sha256:'+'a'*64+';echo unsafe')
 def test_tag_plus_digest_rejected(self):self.assertRaises(ValueError,runner.validate_image,'postgres:latest@sha256:'+'a'*64)
 def test_whitespace_rejected(self):self.assertRaises(ValueError,runner.validate_image,' postgres@sha256:'+'a'*64)

class StaticSourceContracts(unittest.TestCase):
 def test_source_is_forward_body_not_applied_history(self):
  m=json.loads(text('supabase/hardening/2026-09-28/manifest.json'));self.assertIs(m['database_applied'],False)
  self.assertEqual(m['bodies'][9]['file'],'10_chat_delivery_and_pagination.sql')
 def test_all_new_client_rpc_grants_are_explicit(self):
  s=text(SQL);self.assertIn(' from public,anon;',s);self.assertIn(' to authenticated;',s)
  for fn in ['rpc_send_chat_message_v2','rpc_chat_delivery_status','rpc_close_chat_delivery','rpc_list_chat_messages_page','rpc_mark_chat_read']:
   self.assertGreaterEqual(s.count('public.'+fn),3)
 def test_real_identity_boundary_is_explicit(self):
  s=text(SQL);self.assertIn('public.verified_app_user_id()',s);self.assertNotIn('user_metadata',s)
  self.assertIn('actor in(participant_low_id,participant_high_id)',s)
 def test_exact_utf8_hash_and_owner_lock(self):
  s=text(SQL);self.assertIn("sha256(convert_to(p_body,'UTF8'))",s)
  self.assertIn("hashtextextended('mobio.chat.owner:'||actor::text,0)",s)
  self.assertIn('primary key(owner_id, client_message_id)',s)
 def test_private_queue_rls_and_no_client_direct_writes(self):
  s=text(SQL)
  for table in ['chat_delivery_operations','chat_send_clock','chat_delivery_policy']:
   self.assertIn('alter table mobio_private.'+table+' enable row level security',s)
  self.assertIn('revoke select,insert,update,delete on public.chat_messages',s)
  self.assertIn('revoke insert,update,delete on public.chat_conversations',s)
  self.assertIn('pg_attribute',s)
 def test_legacy_send_cutover_is_explicit(self):
  self.assertIn("'PT410' using message='CHAT_CLIENT_UPDATE_REQUIRED'",text(SQL))
 def test_cursor_uses_both_time_and_id(self):
  s=text(SQL);self.assertIn('(m.created_at,m.id)<(p_before_created_at,p_before_id)',s)
  self.assertIn('order by m.created_at desc,m.id desc limit p_limit',s)
  self.assertIn('p_limit>100',s)
 def test_minimization_and_bounded_controls(self):
  s=text(SQL);self.assertIn('sends_enabled boolean not null default false',s)
  self.assertIn('max_retained_operations',s);self.assertIn('CHAT_RATE_LIMITED',s)
  self.assertNotIn('body text',s[s.index('create table mobio_private.chat_delivery_operations'):s.index('create unique index')])
 def test_plus_body_and_metadata_remain_redacted(self):
  s=text(SQL);self.assertIn("jsonb_build_object('redacted',true,'redaction_reason','mobio_plus_required')",s)
  self.assertIn("MOBIO_PLUS_REQUIRED",s);self.assertIn('public.user_blocks',s)
 def test_mutation_receipt_is_atomic_in_source(self):
  s=text(SQL);a=s.index('create function public.rpc_send_chat_message_v2');b=s.index('create function public.rpc_close_chat_delivery')
  part=s[a:b];self.assertLess(part.index('insert into public.chat_messages'),part.index('insert into mobio_private.chat_delivery_operations'))
  self.assertNotIn('exception when',part)
 def test_cancel_tombstone_and_deleted_message_binding(self):
  s=text(SQL);self.assertIn("'cancelled',clock_timestamp()",s);self.assertIn('on delete set null',s)
  self.assertIn('CHAT_OPERATION_CONFLICT',s)
 def test_client_does_not_persist_raw_text(self):
  s=text('lib/features/chat/data/chat_delivery_store.dart');self.assertIn('p.toJson()',s)
  d=text('lib/features/chat/domain/chat_delivery.dart');self.assertIn("'body_sha256':bodySha256",d)
  self.assertNotIn("'body':",d)
 def test_coordinator_persists_before_dispatch_and_clears_after_close(self):
  s=text('lib/features/chat/application/chat_delivery_coordinator.dart')
  self.assertLess(s.index('await store.write(p)'),s.index("_call('rpc_send_chat_message_v2'"))
  self.assertLess(s.index("_call('rpc_close_chat_delivery'"),s.index('await store.remove(p)'))
 def test_account_fence_reaches_render_and_delayed_read_mark(self):
  s=text('lib/features/chat/presentation/chat_screen.dart');self.assertIn('_accountLost',s)
  self.assertGreaterEqual(s.count('requireCurrent: () => AccountContext.requireCurrent(_account!)'),2)
  s=text('lib/features/chat/presentation/widgets/chat_history_view.dart');self.assertIn('||!_current)return;',s)
 def test_stream_teardown_is_independent_of_done_consumption(self):
  s=text('lib/features/chat/data/chat_service.dart');self.assertIn('unawaited(stop());',s)
  self.assertIn('onCancel:stop',s);self.assertIn('AccountContext.changes.removeListener',s)
 def test_ci_includes_actual_component_gate(self):
  s=text('.github/workflows/ci.yml');self.assertIn('python3 scripts/qa/test_chat_postgres.py',s)
  self.assertIn('MOBIO_CHAT_POSTGRES_IMAGE',s)
 def test_read_marker_uses_existing_row_not_client_now(self):
  s=text(SQL);self.assertIn('created_at=p_through_created_at',s)
  s=text('lib/features/chat/data/chat_service.dart');self.assertNotIn(".from('chat_messages').update",s)
  self.assertIn('if(through==null)return',s)
 def test_no_placeholder_uuid_or_false_failed_timeout(self):
  s=text('lib/features/chat/domain/chat_delivery.dart');self.assertIn('Random.secure()',s)
  self.assertIn('notObserved',s)

if __name__=='__main__':unittest.main()
