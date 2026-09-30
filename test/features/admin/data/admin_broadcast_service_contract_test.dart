import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/errors/app_exception.dart';
import 'package:mobi_app/features/admin/data/admin_broadcast_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

AdminBroadcastService fixture(Object? response) {
  final client = SupabaseClient(
    'https://admin-contract.invalid',
    'mock-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      expect(request.url.host, 'admin-contract.invalid');
      return http.Response(
        jsonEncode(response),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  return AdminBroadcastService(supabase: client);
}

void main() {
  test(
    'invalid campaign approval ID is not reported as blank success',
    () async {
      final service = fixture(null);
      await expectLater(
        service.requestCampaignApproval(campaignType: 'promo', title: 'Test'),
        throwsA(isA<MutationOutcomeUnknownException>()),
      );
    },
  );

  test('malformed campaign rows are not silently dropped', () async {
    final service = fixture([7]);
    await expectLater(service.listCampaignApprovals(), throwsFormatException);
  });

  test('missing send count is not treated as zero recipients', () async {
    final service = fixture(null);
    await expectLater(
      service.sendPromo(title: 'Test'),
      throwsA(isA<MutationOutcomeUnknownException>()),
    );
  });

  test('confirmed zero send count remains valid', () async {
    final service = fixture(0);
    expect(await service.sendPromo(title: 'Test'), 0);
  });

  test('missing audience preview is not an empty preview', () async {
    final service = fixture([]);
    await expectLater(
      service.getCampaignAudiencePreview(campaignId: 'campaign-1'),
      throwsFormatException,
    );
  });
}
