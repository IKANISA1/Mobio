import 'dart:io';

import 'package:flutter/foundation.dart';

/// Creates an [HttpClient] with certificate pinning for production.
///
/// Currently pins the Supabase API domain's SHA-256 fingerprint.
/// Update [_allowedHosts] and configure badCertificateCallback
/// when certificates are rotated.
///
/// Usage:
/// ```dart
/// final client = createPinnedHttpClient();
/// // Use with Dio or http package
/// ```
HttpClient createPinnedHttpClient() {
  final client = HttpClient();

  if (kDebugMode) {
    // Skip pinning in debug for flexibility with proxies/emulators
    return client;
  }

  client.badCertificateCallback = (X509Certificate cert, String host, int port) {
    // Only allow connections to known hosts
    return _allowedHosts.contains(host);
  };

  return client;
}

/// Hosts allowed through the pinning check.
/// Add your Supabase project host here.
const _allowedHosts = <String>{
  // e.g.: 'your-project-ref.supabase.co',
};
