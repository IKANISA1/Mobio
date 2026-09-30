import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/data/admin_dashboard_service.dart';
import 'package:mobi_app/features/admin/data/admin_trip_service.dart';
import 'package:mobi_app/features/admin/data/admin_user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const owner = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';

SupabaseClient fixture(Object? raw) {
  final client = SupabaseClient(
    'https://admin-contract.invalid',
    'mock-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode(raw),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      ),
    ),
  );
  addTearDown(client.dispose);
  return client;
}

Map<String, dynamic> userRow() => {
  'id': owner,
  'name': '',
  'display_name': null,
  'phone': '',
  'role': 'passenger',
  'is_driver': false,
  'vehicle_type': 'cab',
  'member_id': null,
  'has_face_id': false,
  'is_online': false,
  'created_at': '2026-09-30T08:00:00Z',
};

Map<String, dynamic> tripRow() => {
  'id': other,
  'author_id': owner,
  'author_name': '',
  'origin': 'Kigali',
  'destination': 'Musanze',
  'departure_date': '2026-10-01',
  'role': 'driver',
  'vehicle_type': 'cab',
  'status': 'active',
  'is_active': true,
  'created_at': '2026-09-30T08:00:00Z',
  'member_id': '482013',
};

void main() {
  test(
    'valid user response preserves empty display values and nullable member ID',
    () async {
      final users = await AdminUserService(
        supabase: fixture([userRow()]),
      ).listUsers();
      expect(users.single.id, owner);
      expect(users.single.memberId, isNull);
      expect(users.single.name, 'Unnamed member');
    },
  );

  test(
    'missing identity, role and flags reject the whole admin user response',
    () async {
      for (final row in [
        {...userRow()}..remove('id'),
        {...userRow()}..remove('role'),
        {...userRow()}..remove('is_online'),
        {...userRow(), 'member_id': 'M482013'},
      ]) {
        await expectLater(
          AdminUserService(supabase: fixture([row])).listUsers(),
          throwsFormatException,
        );
      }
    },
  );

  test('valid trip rows preserve both trip and author identities', () async {
    final trips = await AdminTripService(
      supabase: fixture([tripRow()]),
    ).listTrips();
    expect(trips.single.id, other);
    expect(trips.single.authorId, owner);
    expect(trips.single.memberId, '482013');
  });

  test(
    'missing trip identities and active state cannot inherit defaults',
    () async {
      for (final row in [
        {...tripRow()}..remove('author_id'),
        {...tripRow()}..remove('is_active'),
        {...tripRow(), 'member_id': '48201'},
        {...tripRow(), 'status': 'completed'},
      ]) {
        await expectLater(
          AdminTripService(supabase: fixture([row])).listTrips(),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'dashboard rejects missing counts while valid zero counts remain visible',
    () async {
      final row = <String, dynamic>{
        'total_users': 0,
        'active_drivers': 0,
        'active_passengers': 0,
        'total_trips': 0,
        'active_trips': 0,
        'cancelled_trips': 0,
      };
      expect(
        (await AdminDashboardService(
          supabase: fixture(row),
        ).getDashboardStats()).totalUsers,
        0,
      );
      for (final value in [null, -1, 1.5, '0']) {
        await expectLater(
          AdminDashboardService(
            supabase: fixture({...row, 'total_users': value}),
          ).getDashboardStats(),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'token credit receipt is bound to requested owner and exact amount',
    () async {
      final row = <String, dynamic>{
        'ledger_entry_id': other,
        'profile_id': owner,
        'amount_tokens': 100,
        'status': 'completed',
      };
      final valid = await AdminUserService(
        supabase: fixture(row),
      ).adjustUserTokens(userId: owner, amountTokens: 100);
      expect(valid.ledgerEntryId, other);
      for (final wrong in [
        {...row, 'profile_id': other},
        {...row, 'amount_tokens': 200},
        {...row, 'amount_tokens': 100.9},
        {...row}..remove('status'),
        {...row}..remove('ledger_entry_id'),
      ]) {
        await expectLater(
          AdminUserService(
            supabase: fixture(wrong),
          ).adjustUserTokens(userId: owner, amountTokens: 100),
          throwsA(isA<MutationOutcomeUnknownException>()),
        );
      }
    },
  );

  test(
    'settings response must explicitly include both configuration values',
    () async {
      final row = <String, dynamic>{
        'insurance_agent_whatsapp_e164': '+250795588248',
        'token_redemption_admin_member_id': '',
      };
      final settings = await AdminDashboardService(
        supabase: fixture(row),
      ).getPlatformSettings();
      expect(settings.tokenRedemptionAdminMemberId, '');
      await expectLater(
        AdminDashboardService(supabase: fixture({})).getPlatformSettings(),
        throwsFormatException,
      );
    },
  );

  test(
    'whatsapp upsert must return one exact row rather than selecting first',
    () async {
      final row = <String, dynamic>{
        'id': owner,
        'phone_e164': '+250795588248',
        'country_code': '+250',
        'display_name': null,
        'is_active': true,
        'created_at': '2026-09-30T08:00:00Z',
        'updated_at': '2026-09-30T08:00:00Z',
      };
      await expectLater(
        AdminUserService(
          supabase: fixture([row, row]),
        ).upsertWhatsappAdminNumber(
          phoneE164: '+250795588248',
          countryCode: '+250',
        ),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );
}
