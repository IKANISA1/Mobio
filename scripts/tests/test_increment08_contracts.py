"""Static integration assertions only; these are NOT Dart or native runtime tests."""
from pathlib import Path
import unittest
import xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[2]
def read(path): return (ROOT / path).read_text()
class SessionContracts(unittest.TestCase):
    def test_bootstrap_uses_custom_storage_before_auth(self):
        s=read('lib/app/bootstrap.dart')
        self.assertLess(s.index('storage.persistence.initialize'),s.index('await Supabase.initialize'))
        self.assertIn('FlutterAuthClientOptions(localStorage: storage)',s)
    def test_adapter_has_no_plaintext_persistence(self):
        s=read('lib/core/auth/auth_session_storage.dart')
        self.assertNotIn('setString(',s);self.assertNotIn('SharedPreferencesLocalStorage(',s)
        self.assertIn("const MethodChannel('rw.mobi.app/secure_session')",s)
    def test_only_known_legacy_slots_removed(self):
        s=read('lib/core/auth/auth_session_storage.dart')
        self.assertIn('{legacyKey, supabasePersistSessionKey}',s)
        self.assertNotIn('await preferences.clear(',s)
    def test_browser_does_not_persist_tokens(self):
        s=read('lib/core/auth/auth_session_storage.dart')
        self.assertIn('!kIsWeb',s);self.assertIn('MemorySessionValueStore()',s)
    def test_http_disallowed_outside_local_debug(self):
        s=read('lib/core/auth/auth_session_storage.dart')
        self.assertIn("uri.scheme == 'http' && (!kDebugMode",s)
    def test_sdk_writes_cannot_establish_new_login(self):
        s=read('lib/core/auth/session_persistence.dart')
        self.assertIn('next.key != _accepted!.key',s)
        self.assertIn('next.issuedAt < _accepted!.issuedAt',s)
        self.assertIn('revision != _generation',s)
    def test_readback_mandatory_before_trust(self):
        s=read('lib/core/auth/session_persistence.dart')
        self.assertGreaterEqual(s.count('await store.read() != value'),2)
    def test_native_channel_registered(self):
        self.assertIn('SecureSessionChannel.register(',read('android/app/src/main/kotlin/rw/mobi/app/MainActivity.kt'))
        self.assertIn('SecureSessionChannel.register(',read('ios/Runner/AppDelegate.swift'))
    def test_android_key_and_file_isolation(self):
        s=read('android/app/src/main/kotlin/rw/mobi/app/SecureSessionChannel.kt')
        for text in ['app.noBackupFilesDir','AndroidKeyStore','AtomicFile(','file.channel.lock()',
                     '.setRandomizedEncryptionRequired(true)','create = false']:
            self.assertIn(text,s)
    def test_android_backup_exclusion_is_wired(self):
        path='android/app/src/main/'
        manifest=ET.fromstring(read(path+'AndroidManifest.xml'))
        android='{http://schemas.android.com/apk/res/android}'
        app=manifest.find('application')
        self.assertEqual(app.get(android+'allowBackup'),'false')
        self.assertEqual(app.get(android+'fullBackupContent'),'@xml/auth_backup_rules')
        self.assertEqual(app.get(android+'dataExtractionRules'),'@xml/auth_data_extraction_rules')
        for f in ['auth_backup_rules.xml','auth_data_extraction_rules.xml']:
            tree=ET.fromstring(read(path+'res/xml/'+f))
            self.assertTrue(all(e.get('path')=='FlutterSharedPreferences.xml' for e in tree.iter('exclude')))
    def test_keychain_device_scope_and_install_reset(self):
        s=read('ios/Runner/AppDelegate.swift')
        for text in ['kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly',
                     'kSecAttrSynchronizable as String: false','isExcludedFromBackup = true',
                     'forceReset || !manager.fileExists','try clear(namespace)']:
            self.assertIn(text,s)
    def test_login_verification_is_service_owned(self):
        for f in ['lib/features/auth/data/whatsapp_login_service.dart','lib/features/admin/data/otp_service.dart']:
            s=read(f)
            for text in ['beginLoginAttempt(', 'prepareLogin(ticket)', 'restoreServerSession(ticket',
                         'completeVerifiedLogin(ticket)', 'abortLogin(ticket)']:self.assertIn(text,s)
            self.assertNotIn('.auth.setSession(',s)
    def test_late_sdk_completion_remains_serialized(self):
        s=read('lib/core/auth/account_context.dart')
        self.assertIn('final work = _sdkTail.then((_) => operation())',s)
        self.assertIn('final response = await restore.timeout',s)
        self.assertIn('expected.sessionId == ticket.previousSession',s)
        self.assertIn('_logoutHolds > 0',s)
    def test_exit_fence_written_and_native_clear_started_together(self):
        s=read('lib/core/auth/account_context.dart')
        self.assertIn('Future.wait<void>([_saveExit(), clear])',s)
        self.assertIn('ticket._committedRevision == _fenceRevision',s)
    def test_cancel_does_not_revoke_a_successful_route_transition(self):
        s=read('lib/core/auth/account_context.dart')
        self.assertIn('ticket != null && identical(_activeLogin, ticket)',s)
        self.assertIn('cancelVerification(owner: _verificationOwner)',read('lib/features/auth/presentation/whatsapp_login_screen.dart'))
        self.assertIn('cancelVerification(owner: _verificationOwner)',read('lib/features/admin/presentation/admin_auth_screen.dart'))
        for service in ['lib/features/auth/data/whatsapp_login_service.dart','lib/features/admin/data/otp_service.dart']:
            self.assertIn('identical(owner, _attemptOwner)',read(service))
    def test_recovery_scope_is_explicit(self):
        s=read('lib/core/auth/auth_storage_recovery_view.dart')
        self.assertIn('showDialog<bool>',s)
        self.assertIn('pending operations will not be deleted',s)
        self.assertNotIn('Supabase.initialize',s)
        self.assertNotIn('.timeout(',s)
    def test_no_raw_login_errors_in_debug_log(self):
        s=read('lib/features/auth/data/whatsapp_login_service.dart')
        self.assertNotIn('failed: $error',s);self.assertNotIn('sendLoginOtp: $e',s)
    def test_ci_includes_actual_new_suites(self):
        s=read('.github/workflows/ci.yml')
        self.assertIn('test_session_cipher.sh',s);self.assertIn('test/increment08',s)
        self.assertIn('test_increment08_contracts.py',s);self.assertIn('test_increment08_applier.py',s)
if __name__=='__main__': unittest.main()
