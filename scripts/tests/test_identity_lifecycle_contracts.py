import hashlib
import json
import re
import unittest
from pathlib import Path
from source_contract_helpers import compact_source

ROOT = Path(__file__).resolve().parents[2]
HARDENING = ROOT / 'supabase/hardening/2026-09-28'


class CanonicalMemberIdTests(unittest.TestCase):
    def setUp(self):
        self.sql = (HARDENING / '04_canonical_member_id.sql').read_text()

    def test_member_id_is_six_digit_unique_and_not_null(self):
        self.assertIn("member_id ~ '^[0-9]{6}$'", self.sql)
        self.assertIn('create unique index if not exists profiles_member_id_unique', self.sql.lower())
        self.assertIn('alter column member_id set not null', self.sql.lower())

    def test_duplicate_historical_ids_require_preserved_identity_remediation(self):
        sql = self.sql.lower()
        self.assertIn('group by member_id having count(*) > 1', sql)
        self.assertIn('invalid_count > 0 or duplicate_count > 0', sql)
        self.assertIn("raise exception 'member_id_remediation_required'", sql)
        self.assertLess(sql.index('lock table public.profiles'), sql.index('do $preflight$'))
        self.assertLess(sql.index("raise exception 'member_id_remediation_required'"), sql.index('do $backfill$'))
        self.assertIn('where member_id is null order by', sql)
        self.assertNotIn('set member_id = null', sql)

    def test_allocator_serializes_check_then_assignment(self):
        self.assertIn('pg_advisory_xact_lock', self.sql)
        self.assertIn('MEMBER_ID_SPACE_EXHAUSTED', self.sql)

    def test_client_cannot_choose_inserted_member_id(self):
        self.assertRegex(self.sql, r"request_role\s*<>\s*'service_role'[\s\S]+new\.member_id\s*:=\s*public\._mobio_allocate_member_id")

    def test_identity_guard_protects_member_id(self):
        guard = (HARDENING / '02_verified_phone_authority.sql').read_text()
        self.assertIn('new.member_id is distinct from old.member_id', guard)

    def test_client_helper_never_hashes_missing_id(self):
        helper = (ROOT / 'lib/core/utils/mobio_member_id.dart').read_text()
        self.assertNotIn('hashCode', helper)
        self.assertNotIn('stableSeed', helper)
        display = compact_source(helper[helper.index('String? displayMobioMemberId'):])
        self.assertIn('if(!isValidMobioMemberId(memberId))returnnull;', display)
        self.assertIn('returnmemberId!.trim();', display)

    def test_production_trip_cards_do_not_fabricate_member_ids(self):
        paths = [
            'lib/shared/widgets/driver_card.dart',
            'lib/features/bookings/presentation/bookings_screen.dart',
            'lib/features/home/presentation/widgets/scheduled_trip_card.dart',
        ]
        for path in paths:
            with self.subTest(path=path):
                text = (ROOT / path).read_text()
                self.assertNotIn('getDriverId(', text)
                self.assertNotRegex(text, r'authorId\.substring\(0,\s*6\)')


class AccountLifecycleTests(unittest.TestCase):
    def test_cleanup_failure_cannot_block_auth_signout(self):
        text = (ROOT / 'lib/core/auth/supabase_session_service.dart').read_text()
        marker = text.index('AccountContext.beginExit()')
        cleanup = text.index('if(cleanup!=null)')
        auth = text.index('await AccountContext.signOutSdkLocally()', cleanup)
        context = (ROOT / 'lib/core/auth/account_context.dart').read_text()
        self.assertIn('auth.signOut(scope: SignOutScope.local)', context)
        self.assertIn('_sdk(() => Supabase.instance.client.auth.signOut', context)
        self.assertIn('AccountContext.beginLogoutOperation()', text)
        self.assertIn('finally { AccountContext.endLogoutOperation(); }', text)
        self.assertLess(marker, cleanup)
        self.assertIn('on Object{AppLogger.warning', text[cleanup:auth])
        self.assertIn('Duration(seconds:5)', text[cleanup:auth])
        self.assertIn('remaining==null || remaining.user.isAnonymous', text[auth:])
        self.assertNotIn('return true', text[auth:])

    def test_user_signout_revokes_account_bound_state_before_auth_loss(self):
        text = (ROOT / 'lib/app/router/screen_wrappers.dart').read_text()
        start = text.index('Future<void> _signOutUser')
        end = text.index('Future<void> _exitAdminSession', start)
        block = text[start:end]
        callback_start = block.index('beforeSignOut: () async {')
        callback_end = block.index('},', callback_start)
        cleanup = block[callback_start:callback_end]
        self.assertIn('unregisterToken()', cleanup)
        self.assertIn('driverLocationSharingServiceProvider', block)
        self.assertIn('BioPayDeviceNfcService().stop()', block)
        self.assertIn("context.go('/login')", block)

    def test_profile_exposes_ordinary_signout(self):
        text = (ROOT / 'lib/features/profile/presentation/profile_screen.dart').read_text()
        self.assertIn('onSignOut', text)
        self.assertIn("title: 'Sign out'", text)

    def test_push_registration_rechecks_owner_after_token_await(self):
        text = compact_source((ROOT / 'lib/features/notifications/data/push_notification_service.dart').read_text())
        token = text.index('await_messaging.getToken()')
        register = text.index("rpc('rpc_push_register'",token)
        self.assertIn('AccountContext.requireCurrent(account)',text[token:register])
        self.assertIn("'p_session_id':account.sessionId",text[register:])

    def test_push_unregister_is_scoped_to_owner_and_token(self):
        text = (ROOT / 'lib/features/notifications/data/push_notification_service.dart').read_text()
        block = text[text.index('Future<void> unregisterToken()'):text.index('void dispose()')]
        self.assertIn('binding.belongsTo(owner, session)', block)
        self.assertIn("'p_binding_id': binding.bindingId", block)
        self.assertIn("'p_session_id': session", block)


class TransportIntegrityTests(unittest.TestCase):
    def setUp(self):
        self.sql = (HARDENING / '05_transport_hold_receipt_integrity.sql').read_text()

    def test_equivalent_active_hold_is_returned_without_second_decrement(self):
        self.assertIn('An active hold already exists for this schedule.', self.sql)
        existing = self.sql.index("b.status='held'")
        decrement = self.sql.index('available_seats=i.available_seats-p_seat_count')
        self.assertLess(existing, decrement)

    def test_expired_hold_release_restores_inventory(self):
        self.assertIn('_mobio_release_expired_bus_holds', self.sql)
        self.assertIn('available_seats = least(i.total_seats, i.available_seats + hold_row.seat_count)', self.sql)
        self.assertIn("set status = 'expired'", self.sql)

    def test_receipt_reference_cannot_cross_booking(self):
        self.assertIn('PAYMENT_REFERENCE_ALREADY_USED', self.sql)
        self.assertIn('v_existing_payment.booking_id <> v_booking.id', self.sql)
        self.assertNotIn('on conflict (provider, provider_reference) do update', self.sql.lower())

    def test_expired_confirmation_returns_durable_expired_state(self):
        self.assertIn("v_booking.status := 'expired'", self.sql)
        service = (ROOT / 'lib/features/bookings/data/public_transport_service.dart').read_text()
        self.assertIn("confirmation.status != 'confirmed'", service)
        self.assertIn('This booking hold expired. Choose seats again.', service)

    def test_sweeper_is_service_role_only(self):
        self.assertIn('rpc_expire_bus_holds', self.sql)
        self.assertIn("raise exception 'SERVICE_ROLE_REQUIRED'", self.sql)
        self.assertIn('grant execute on function public.rpc_expire_bus_holds(integer) to service_role', self.sql.lower())


class HardeningManifestTests(unittest.TestCase):
    def test_manifest_hashes_all_bodies_exactly(self):
        manifest = json.loads((HARDENING / 'manifest.json').read_text())
        names = [b['file'] for b in manifest['bodies']]
        self.assertEqual(names, [
            '01_booking_write_authority.sql',
            '02_verified_phone_authority.sql',
            '03_strict_receipt_allocation.sql',
            '04_canonical_member_id.sql',
            '05_transport_hold_receipt_integrity.sql',
            '06_bounded_driver_discovery.sql',
            '07_durable_sms_intake.sql',
            '08_admin_session_leases.sql',
            '09_wallet_operation_journal.sql',
            '10_chat_delivery_and_pagination.sql',
            '11_notification_outbox.sql',
        '12_privacy_request_workflow.sql',
        ])
        for body in manifest['bodies']:
            digest = hashlib.sha256((HARDENING / body['file']).read_bytes()).hexdigest()
            self.assertEqual(body['sha256'], digest)


class DiscoveryAndStatusTests(unittest.TestCase):
    def test_nearby_rpc_has_freshness_radius_and_hard_cap(self):
        sql = (HARDENING / '06_bounded_driver_discovery.sql').read_text()
        self.assertIn("interval '2 minutes'", sql)
        self.assertIn('where c.distance_km <= 10', sql)
        self.assertIn('least(greatest(coalesce(p_limit,20),1),50)', sql)

    def test_direct_location_policy_is_not_global_online_read(self):
        sql = (HARDENING / '06_bounded_driver_discovery.sql').read_text()
        policy = sql[sql.index('create policy driver_locations_online_read_authenticated'):]
        self.assertIn('driver_id=(select public.verified_app_user_id())', policy)
        self.assertNotIn('is_online = true', policy)

    def test_face_service_failure_is_not_reported_as_not_started(self):
        profile = (ROOT / 'lib/features/profile/presentation/profile_screen.dart').read_text()
        copy = (ROOT / 'lib/features/biopay/presentation/face_copy.dart').read_text()
        self.assertIn("BioPayEnrollmentStatus(status: 'unavailable')", profile)
        self.assertIn("'unavailable' => l.faceUnavailable", copy)


class PostInstallAssertionTests(unittest.TestCase):
    def test_assertions_cover_new_identity_transport_and_discovery_invariants(self):
        sql = (HARDENING / 'post_install_assertions.sql').read_text()
        for expected in (
            'profiles_member_id_unique',
            'assign_mobio_member_id',
            'Duplicate canonical member ID remains',
            'rpc_expire_bus_holds(integer)',
            'rpc_search_nearby_drivers(double precision,double precision,text,text,integer)',
            'driver_locations_online_read_authenticated',
        ):
            with self.subTest(expected=expected):
                self.assertIn(expected, sql)



if __name__ == '__main__':
    unittest.main()
