import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobi_app/core/location/places_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'stalled native connectivity check cannot block a places query',
    () async {
      const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
      final pending = Completer<List<String>>();
      var nativeChecks = 0;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) {
        nativeChecks++;
        return pending.future;
      });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      var requests = 0;
      final client = SupabaseClient(
        'https://places-test.invalid',
        'synthetic-public-key',
        httpClient: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'place': {
                'placeId': 'test-place',
                'label': 'Kigali',
                'position': {'latitude': -1.94, 'longitude': 30.06},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final service = PlacesService(supabase: client);
      final query = service.geocodeAddress('Kigali');
      expect(requests, 0);
      final result = await query.timeout(const Duration(seconds: 6));
      expect(result!.placeId, 'test-place');
      expect(requests, 1);
      expect(nativeChecks, 1);
      pending.complete(['none']);
      await Future<void>.delayed(Duration.zero);
      expect(requests, 1);
    },
  );
}
