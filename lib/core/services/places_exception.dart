/// Typed exception for PlacesService failures.
/// Provides actionable error kinds for UI error handling.
enum PlacesErrorKind {
  /// No internet connection detected.
  network,

  /// The request timed out.
  timeout,

  /// The server returned an error (5xx, bad response, etc.).
  serverError,

  /// An unknown or unexpected error occurred.
  unknown,
}

class PlacesException implements Exception {
  final PlacesErrorKind kind;
  final String message;
  final Object? cause;

  const PlacesException({
    required this.kind,
    required this.message,
    this.cause,
  });

  /// User-friendly message suitable for display in a SnackBar.
  String get userMessage {
    switch (kind) {
      case PlacesErrorKind.network:
        return 'No internet connection. Please check your network.';
      case PlacesErrorKind.timeout:
        return 'Request timed out. Please try again.';
      case PlacesErrorKind.serverError:
        return 'Server error. Please try again later.';
      case PlacesErrorKind.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => 'PlacesException($kind): $message';
}
