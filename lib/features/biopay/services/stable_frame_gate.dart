/// Stable-frame gating for BioPay face capture.
///
/// Prevents jittery captures by requiring multiple consecutive frames
/// with acceptable face quality before signaling "stable".
///
/// - Scan mode: 3 consecutive stable frames
/// - Enrollment mode: 5 consecutive stable frames (higher bar)
class StableFrameGate {
  final int requiredFrames;
  int _consecutiveStableCount = 0;
  int? _lastTrackingId;

  /// [requiredFrames] — 3 for scan, 5 for enrollment.
  StableFrameGate({required this.requiredFrames});

  /// Factory for scan mode (3 frames).
  factory StableFrameGate.scan() => StableFrameGate(requiredFrames: 3);

  /// Factory for enrollment mode (5 frames).
  factory StableFrameGate.enrollment() => StableFrameGate(requiredFrames: 5);

  /// Feed a frame into the gate.
  ///
  /// Returns `true` when the required number of consecutive stable frames
  /// has been reached.
  bool onFrame({required bool isQualityAcceptable, required int? trackingId}) {
    // If face lost or changed, reset counter
    if (!isQualityAcceptable ||
        (trackingId != null &&
            _lastTrackingId != null &&
            trackingId != _lastTrackingId)) {
      reset();
      _lastTrackingId = trackingId;
      return false;
    }

    _lastTrackingId = trackingId;
    _consecutiveStableCount++;

    return _consecutiveStableCount >= requiredFrames;
  }

  /// Reset the stability counter.
  void reset() {
    _consecutiveStableCount = 0;
  }

  /// Current consecutive stable frame count.
  int get stableCount => _consecutiveStableCount;

  /// Progress ratio (0..1).
  double get progress =>
      (_consecutiveStableCount / requiredFrames).clamp(0.0, 1.0);
}
