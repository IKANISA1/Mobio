"""Static integration assertions only; NOT SQL or Flutter execution."""
from pathlib import Path
import json
import tomllib
import unittest
ROOT=Path(__file__).resolve().parents[2]
class SourceContracts(unittest.TestCase):
    def text(self,path):return (ROOT/path).read_text()
    def test_only_dedicated_worker_disables_gateway_jwt_for_custom_auth(self):
        cfg=tomllib.loads(self.text('supabase/config.toml'))
        self.assertIs(cfg['functions']['push-outbox-worker']['verify_jwt'],False)
        self.assertIn('MOBIO_PUSH_WORKER_SECRET',self.text('supabase/functions/push-outbox-worker/index.ts'))
    def test_flutter_registration_and_revocation_use_exact_session_rpc(self):
        s=self.text('lib/features/notifications/data/push_notification_service.dart')
        self.assertIn("rpc('rpc_push_register'",s);self.assertIn("rpc('rpc_push_unregister'",s)
        self.assertNotIn(".from('fcm_tokens')",s)
        self.assertIn("'p_session_id': account.sessionId",s);self.assertIn("'p_binding_id': binding.bindingId",s)
    def test_flutter_disposal_fences_pending_registration(self):
        s=self.text('lib/features/notifications/data/push_notification_service.dart')
        self.assertIn('_lifecycle++;',s);self.assertGreater(s.count('_requireLifecycle(lifecycle)'),5)
    def test_push_routes_and_presentations_validate_binding(self):
        s=self.text('lib/features/notifications/data/push_notification_service.dart')
        self.assertGreaterEqual(s.count('_binding!.accepts('),2)
        self.assertNotIn('message.notification?.body',s);self.assertNotIn('message.notification?.title',s)
        self.assertIn("GoRouter.of(context).push('/notifications')",s)
    def test_native_cleanup_does_not_prevent_server_revocation(self):
        s=self.text('lib/features/notifications/data/push_notification_service.dart')
        block=s[s.index('Future<void> _revokeBinding'):]
        self.assertIn('on Object { localCleanupFailed = true; }',block)
        self.assertIn("rpc('rpc_push_unregister'",block)
    def test_admin_health_card_is_wired_to_existing_screen(self):
        self.assertIn('PushDeliveryHealthCard()',self.text('lib/features/admin/presentation/admin_operational_health_screen.dart'))
        s=self.text('lib/features/admin/presentation/widgets/push_delivery_health_card.dart')
        self.assertIn("rpc('rpc_push_health')",s);self.assertIn('AccountContext.requireCurrent(account)',s)
        self.assertIn('provider_accepted_not_device_delivered',s)
    def test_worker_entry_retains_old_route_retirement(self):
        s=self.text('supabase/functions/send-push/index.ts')
        self.assertIn('410',s);self.assertNotIn('createClient',s);self.assertNotIn('fetch(',s)
    def test_runner_never_accepts_external_dsn_or_host_mount(self):
        s=self.text('scripts/qa/test_push_postgres.py')
        self.assertIn("'--network','none'",s);self.assertIn("'--memory','512m'",s)
        self.assertNotIn("add_argument('--dsn",s);self.assertNotIn("'--volume'",s)
    def test_ci_wires_new_runtime_checks(self):
        s=self.text('.github/workflows/ci.yml')
        self.assertIn('scripts/tests/push/*.test.mjs',s);self.assertIn('test_push_operations.py',s)
        self.assertIn('MOBIO_PUSH_POSTGRES_IMAGE',s);self.assertIn('test_push_postgres.py',s)
    def test_sql_manifest_includes_source_body_without_applied_claim(self):
        m=json.loads(self.text('supabase/hardening/2026-09-28/manifest.json'))
        self.assertIs(m['database_applied'],False)
        self.assertEqual(m['bodies'][10]['file'],'11_notification_outbox.sql')
if __name__=='__main__':unittest.main()
