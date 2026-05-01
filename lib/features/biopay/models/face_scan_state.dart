import 'package:mobi_app/features/biopay/models/biopay_models.dart';

enum FaceScanPhase { loading, scanning, processing, matched, noMatch, error }

class FaceScanState {
  final FaceScanPhase phase;
  final String statusMessage;
  final String? errorMessage;
  final MatchResult? matchResult;
  final double stabilityProgress;
  final FaceQualityIssue? activeQualityIssue;
  final bool isCameraDenied;

  const FaceScanState({
    this.phase = FaceScanPhase.loading,
    this.statusMessage = 'Preparing camera...',
    this.errorMessage,
    this.matchResult,
    this.stabilityProgress = 0.0,
    this.activeQualityIssue,
    this.isCameraDenied = false,
  });

  FaceScanState copyWith({
    FaceScanPhase? phase,
    String? statusMessage,
    String? errorMessage,
    MatchResult? matchResult,
    double? stabilityProgress,
    FaceQualityIssue? activeQualityIssue,
    bool? isCameraDenied,
  }) {
    return FaceScanState(
      phase: phase ?? this.phase,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      matchResult: matchResult ?? this.matchResult,
      stabilityProgress: stabilityProgress ?? this.stabilityProgress,
      activeQualityIssue: activeQualityIssue ?? this.activeQualityIssue,
      isCameraDenied: isCameraDenied ?? this.isCameraDenied,
    );
  }
}
