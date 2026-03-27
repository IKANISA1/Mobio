import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:mobi_app/core/services/places_exception.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/models/place.dart';
import 'package:mobi_app/models/route_info.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlacesService {
  final SupabaseClient _supabase;
  final Connectivity _connectivity;

  /// Max retries for transient failures.
  static const _maxRetries = 2;

  /// Base delay for exponential backoff.
  static const _baseDelay = Duration(milliseconds: 800);

  PlacesService({
    SupabaseClient? supabase,
    Connectivity? connectivity,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _connectivity = connectivity ?? Connectivity();

  // ---------------------------------------------------------------------------
  // Resilience helpers
  // ---------------------------------------------------------------------------

  Future<bool> _hasConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.isNotEmpty &&
          !results.every((r) => r == ConnectivityResult.none);
    } on Object catch (_) {
      return true;
    }
  }

  Future<T> _callWithRetry<T>({
    required Future<T> Function() action,
    required Duration timeout,
    required String operationName,
  }) async {
    if (!await _hasConnectivity()) {
      throw const PlacesException(
        kind: PlacesErrorKind.network,
        message: 'No internet connection detected before call.',
      );
    }

    Object? lastError;

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await action().timeout(timeout);
      } on TimeoutException catch (e) {
        lastError = e;
        if (kDebugMode) debugPrint('⏱️ [$operationName] timed out (attempt ${attempt + 1}/$_maxRetries)');
      } on FunctionException catch (e) {
        lastError = e;
        if (kDebugMode) debugPrint('🔴 [$operationName] FunctionException: status=${e.status}, reasonPhrase=${e.reasonPhrase}');
        final status = e.status;
        if (status >= 400 && status < 500) {
          throw PlacesException(
            kind: PlacesErrorKind.serverError,
            message: '$operationName client error ($status): ${e.reasonPhrase}',
            cause: e,
          );
        }
        AppLogger.warning('$operationName server error (attempt ${attempt + 1}/$_maxRetries): $e');
      } on Object catch (e, stack) {
        lastError = e;
        if (kDebugMode) debugPrint('🔴 [$operationName] Unexpected ${e.runtimeType}: $e\n$stack');
      }

      if (attempt < _maxRetries - 1) {
        final delay = _baseDelay * (1 << attempt);
        await Future<void>.delayed(delay);
      }
    }

    if (lastError is TimeoutException) {
      throw PlacesException(
        kind: PlacesErrorKind.timeout,
        message: '$operationName timed out after $_maxRetries attempts.',
        cause: lastError,
      );
    }

    throw PlacesException(
      kind: PlacesErrorKind.unknown,
      message: '$operationName failed after $_maxRetries attempts.',
      cause: lastError,
    );
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Fetches place autocomplete predictions for the given [input].
  ///
  /// If [nearLat] and [nearLng] are provided, results are biased by proximity
  /// to that location (closest first).
  ///
  /// Throws [PlacesException] on persistent failure.
  Future<List<PlacePrediction>> getAutocompletePredictions(
    String input, {
    double? nearLat,
    double? nearLng,
  }) async {
    if (input.trim().isEmpty) return [];

    return _callWithRetry<List<PlacePrediction>>(
      operationName: 'autocomplete',
      timeout: const Duration(seconds: 6),
      action: () async {
        // Verify session is present (anonymous auth from splash)
        final session = _supabase.auth.currentSession;
        if (session == null) {
          if (kDebugMode) debugPrint('⚠️ [autocomplete] NO AUTH SESSION — edge function will reject');
        }

        final body = <String, dynamic>{
          'action': 'autocomplete',
          'query': input,
        };

        // Pass user location for proximity bias
        if (nearLat != null && nearLng != null) {
          body['near'] = {
            'latitude': nearLat,
            'longitude': nearLng,
          };
        }


        final response = await _supabase.functions.invoke(
          'maps-gateway',
          body: body,
        );

        final data = response.data;

        if (data == null) return [];

        if (data is! Map) {
          if (kDebugMode) debugPrint('⚠️ [autocomplete] unexpected response type: ${data.runtimeType}');
          return [];
        }

        if (data['success'] == false) return [];

        if (data['suggestions'] == null) return [];

        final suggestions = data['suggestions'] as List;

        final List<PlacePrediction> predictions = [];
        for (final suggestion in suggestions) {
          predictions.add(PlacePrediction(
            placeId: suggestion['placeId']?.toString() ?? '',
            description: suggestion['label']?.toString() ?? '',
            primaryText: suggestion['primaryText'] as String?,
            secondaryText: suggestion['secondaryText'] as String?,
            distanceMeters: (suggestion['distanceMeters'] as num?)?.toInt(),
            predictionType: suggestion['type']?.toString() ?? 'place',
          ));
        }
        return predictions;
      },
    );
  }

  /// Fetches place details (geometry/address) for a specific [placeId].
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    return _callWithRetry<PlaceDetails?>(
      operationName: 'placeDetails',
      timeout: const Duration(seconds: 10),
      action: () async {
        final response = await _supabase.functions.invoke(
          'maps-gateway',
          body: {
            'action': 'place_details',
            'placeId': placeId,
          },
        );

        final data = response.data;
        if (data == null || data['place'] == null) return null;

        final place = data['place'];
        return PlaceDetails(
          placeId: (place['placeId'] as String?) ?? '',
          formattedAddress: (place['label'] as String?) ?? '',
          latitude: (place['position']?['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (place['position']?['longitude'] as num?)?.toDouble() ?? 0.0,
        );
      },
    );
  }

  /// Reverse geocodes a lat/lng pair into a place name.
  Future<PlaceDetails?> reverseGeocode(double lat, double lng) async {
    return _callWithRetry<PlaceDetails?>(
      operationName: 'reverseGeocode',
      timeout: const Duration(seconds: 10),
      action: () async {
        final response = await _supabase.functions.invoke(
          'maps-gateway',
          body: {
            'action': 'reverse_geocode',
            'location': {'latitude': lat, 'longitude': lng},
          },
        );

        final data = response.data;
        if (data == null || data['place'] == null) return null;

        final place = data['place'];
        return PlaceDetails(
          placeId: (place['placeId'] as String?) ?? '',
          formattedAddress: (place['label'] as String?) ?? '',
          latitude: (place['position']?['latitude'] as num?)?.toDouble() ?? lat,
          longitude: (place['position']?['longitude'] as num?)?.toDouble() ?? lng,
        );
      },
    );
  }

  /// Computes a route between origin and destination.
  Future<RouteInfo?> computeRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String travelMode = 'DRIVE',
  }) async {
    return _callWithRetry<RouteInfo?>(
      operationName: 'computeRoute',
      timeout: const Duration(seconds: 10),
      action: () async {
        final response = await _supabase.functions.invoke(
          'maps-gateway',
          body: {
            'action': 'compute_route',
            'origin': {'latitude': originLat, 'longitude': originLng},
            'destination': {'latitude': destLat, 'longitude': destLng},
            'travelMode': travelMode,
          },
        );

        final data = response.data;
        if (data == null || data['route'] == null) return null;

        final route = data['route'];
        return RouteInfo(
          distanceMeters: (route['distanceMeters'] as num?)?.toInt() ?? 0,
          duration: route['duration']?.toString() ?? '0s',
          encodedPolyline: route['encodedPolyline']?.toString() ?? '',
          travelMode: route['travelMode']?.toString() ?? travelMode,
        );
      },
    );
  }
}
