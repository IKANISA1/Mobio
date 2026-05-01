import 'package:mobi_app/features/biopay/models/biopay_handle.dart';
import 'package:mobi_app/features/biopay/models/biopay_models.dart';

enum FaceEnrollPhase { loading, ready, capturing, submitting, success, error }

class FaceEnrollmentState {
  final FaceEnrollPhase phase;
  final ScannerState scannerState;
  final String statusMessage;
  final String? errorMessage;
  final EnrollmentResult? result;
  final FaceQualityIssue? activeQualityIssue;
  final int sampleCount;
  final int totalSamples;
  final double stabilityProgress;
  final bool isReEnrollment;
  final BiopayHandleType handleType;
  final ManagedBiopayProfile? managedProfile;

  const FaceEnrollmentState({
    this.phase = FaceEnrollPhase.loading,
    this.scannerState = ScannerState.searching,
    this.statusMessage = 'Preparing...',
    this.errorMessage,
    this.result,
    this.activeQualityIssue,
    this.sampleCount = 0,
    this.totalSamples = 5,
    this.stabilityProgress = 0.0,
    this.isReEnrollment = false,
    this.handleType = BiopayHandleType.number,
    this.managedProfile,
  });

  FaceEnrollmentState copyWith({
    FaceEnrollPhase? phase,
    ScannerState? scannerState,
    String? statusMessage,
    String? errorMessage,
    EnrollmentResult? result,
    FaceQualityIssue? activeQualityIssue,
    int? sampleCount,
    int? totalSamples,
    double? stabilityProgress,
    bool? isReEnrollment,
    BiopayHandleType? handleType,
    ManagedBiopayProfile? managedProfile,
  }) {
    return FaceEnrollmentState(
      phase: phase ?? this.phase,
      scannerState: scannerState ?? this.scannerState,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      result: result ?? this.result,
      activeQualityIssue: activeQualityIssue ?? this.activeQualityIssue,
      sampleCount: sampleCount ?? this.sampleCount,
      totalSamples: totalSamples ?? this.totalSamples,
      stabilityProgress: stabilityProgress ?? this.stabilityProgress,
      isReEnrollment: isReEnrollment ?? this.isReEnrollment,
      handleType: handleType ?? this.handleType,
      managedProfile: managedProfile ?? this.managedProfile,
    );
  }
}
