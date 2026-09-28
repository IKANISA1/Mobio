"""Explicit source assertions plus executable DSN guard tests. NOT SQL/Flutter runtime tests."""
import importlib.util
from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
def text(path):return (ROOT/path).read_text()
spec=importlib.util.spec_from_file_location('catalog',ROOT/'scripts/qa/check_increment05_catalog.py');catalog=importlib.util.module_from_spec(spec);spec.loader.exec_module(catalog)
class DatabaseTargetGuards(unittest.TestCase):
 def test_loopback_synthetic_target(self):self.assertEqual(catalog.validate_target('postgresql://localhost:54322/mobio_test_i05'),'postgresql://localhost:54322/mobio_test_i05')
 def test_remote_refused(self):self.assertRaises(ValueError,catalog.validate_target,'postgresql://db.example.org:5432/mobio_test_i05')
 def test_default_production_name_refused(self):self.assertRaises(ValueError,catalog.validate_target,'postgresql://localhost:5432/postgres')
 def test_query_host_override_refused(self):self.assertRaises(ValueError,catalog.validate_target,'postgresql://localhost:5432/mobio_test_i05?host=db.example.org')
 def test_missing_port_refused(self):self.assertRaises(ValueError,catalog.validate_target,'postgresql://localhost/mobio_test_i05')
 def test_other_protocol_refused(self):self.assertRaises(ValueError,catalog.validate_target,'https://localhost:5432/mobio_test_i05')
 def test_ipv6_loopback(self):catalog.validate_target('postgresql://[::1]:5432/mobio_test_i05')
class SourceContracts(unittest.TestCase):
 def test_admin_lease_registered_before_response(self):
  s=text('supabase/functions/verify-otp/index.ts');self.assertLess(s.index('dependencies.registerLease ?? registerIssuedAdminLease'),s.index('admin_lease: lease'))
 def test_no_admin_directory_enumeration_or_alias_fallback(self):
  s=text('supabase/functions/_shared/admin-whatsapp.ts');self.assertNotIn('listUsers',s);self.assertIn('rpc_lookup_verified_phone_owner',s)
  s=text('supabase/functions/verify-otp/index.ts');start=s.index('async function loadExistingProfileSeed');end=s.index('async function grantAdminPlatformPermissions',start)
  self.assertIn('.eq("id", authUserId)',s[start:end]);self.assertNotIn('.eq("phone"',s[start:end])
 def test_lease_uses_live_session_consumed_otp_and_allowlist(self):
  s=text('supabase/hardening/2026-09-28/08_admin_session_leases.sql')
  for part in ['auth.sessions','o.verified',"o.purpose = 'admin_login'",'admin_whatsapp_numbers','otp_id text not null unique','l.idle_expires_at >','l.absolute_expires_at >','l.revoked_at is null']:self.assertIn(part,s)
 def test_client_role_alone_does_not_grant(self):
  s=text('lib/app/router/app_router.dart');self.assertNotIn('hasAdminRole || hasActiveAdminSession',s)
  s=text('lib/core/auth/admin_session_guard.dart');self.assertIn('static void grant(String userId) => revoke()',s);self.assertIn('Stopwatch',s)
 def test_actual_admin_ui_requires_restored_lease(self):
  s=text('lib/features/admin/data/otp_service.dart');self.assertIn("(session['user'] as Map)['id'] != lease['user_id']",s);self.assertIn("AccountContext.sessionId(Supabase.instance.client.auth.currentSession) != lease['session_id']",s);self.assertIn('AccountContext.restoreServerSession(ticket, session)',s);self.assertIn('actual.key != expected.key',text('lib/core/auth/account_context.dart'));self.assertIn('AdminSessionService.synchronize()',s)
  self.assertNotIn(".select('role')",s)
  s=text('lib/features/admin/presentation/admin_auth_screen.dart');self.assertNotIn('AdminSessionGuard.grant(',s)
 def test_server_touch_not_timer_keepalive(self):
  s=text('lib/core/auth/admin_session_boundary.dart');self.assertIn('userActivity:true',s);self.assertIn('onPointer',s)
 def test_exit_marker_and_account_generation_are_separate(self):
  s=text('lib/core/auth/account_context.dart');self.assertIn('mobio.auth.exit_requested.v1',s);self.assertIn('_fenceRevision',s);self.assertIn('_synchronizeIdentity',s)
  self.assertIn('AdminSessionGuard.revoke()',s);self.assertIn('scheduleMicrotask',s)
 def test_wallet_server_slot_and_binding(self):
  s=text('supabase/hardening/2026-09-28/09_wallet_operation_journal.sql')
  for part in ['wallet_one_unresolved_operation','where acknowledged_at is null','WALLET_OPERATION_CONFLICT','WALLET_UNRESOLVED_OPERATION','pg_advisory_xact_lock','WALLET_RECEIPT_BINDING_FAILED','RECEIVER_CHANGED']:self.assertIn(part,s)
 def test_legacy_wallet_mutations_are_not_a_journal_bypass(self):
  s=text('supabase/hardening/2026-09-28/09_wallet_operation_journal.sql')
  self.assertIn('public.rpc_redeem_wallet_tokens(bigint,text) from public,anon,authenticated;',s)
 def test_wallet_effect_and_receipt_same_transaction(self):
  s=text('supabase/hardening/2026-09-28/09_wallet_operation_journal.sql');start=s.index('create function public.rpc_execute_wallet_operation');end=s.index('create function public.rpc_wallet_operation_status')
  f=s[start:end];self.assertLess(f.index('public.rpc_transfer_tokens'),f.index("set status='committed'"));self.assertNotIn('exception when',f)
 def test_wallet_client_persists_before_execution(self):
  s=text('lib/features/profile/data/wallet_service.dart');self.assertLess(s.index('WalletOperationJournal.save(operation)'),s.index(".rpc<dynamic>('rpc_execute_wallet_operation'"));self.assertIn('UnknownWalletOutcome',s)
 def test_wallet_read_sequence_owner_bound(self):
  s=text('lib/features/profile/presentation/wallet_screen.dart');start=s.index('Future<void> _load()');end=s.index('Future<void> _shareInvite',start);self.assertIn('AccountContext.requireCurrent(account)',s[start:end]);self.assertIn('revision!=_loadRevision',s[start:end])
 def test_no_ownerless_raw_note_storage(self):
  s=text('lib/features/profile/presentation/wallet_screen.dart');self.assertNotIn('SharedPreferences',s);self.assertNotIn('_transferKeyStorageKey',s)
  s=text('lib/features/profile/data/wallet_operation_journal.dart');self.assertNotIn("'note':",s);self.assertNotIn("'refresh_token':",s)
 def test_no_new_bootstrap_anonymous_request(self):
  s=text('lib/app/bootstrap.dart');self.assertNotIn('ensureAnonymousSession(',s);self.assertIn('runApp(',s);self.assertIn('restoreExitFence',s)
 def test_read_only_reconciliation_has_no_provider(self):
  s=text('scripts/operations/reconcile_receipts.py');self.assertNotIn('requests.',s);self.assertNotIn('urllib.request',s);self.assertIn("'automatic_credit_performed':False",s)
if __name__=='__main__':unittest.main()
