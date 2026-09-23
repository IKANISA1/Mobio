import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mobi_app/features/biopay/data/biopay_face_service.dart';
import 'package:mobi_app/features/biopay/presentation/payment_widgets.dart';

String faceErrorCopy(BuildContext context, Object error) {
  final l = paymentCopy(context);
  if (error is CameraException) {
    return error.code == 'IMAGE_TOO_LARGE'
        ? l.facePoorCapture
        : l.faceCameraError;
  }
  final code = error is FaceServiceException ? error.code : '';
  return switch (code) {
    'NO_MATCH' => l.faceNoMatch,
    'AMBIGUOUS_MATCH' => l.faceAmbiguous,
    'NO_FACE' => l.faceNoFace,
    'MULTIPLE_FACES' => l.faceMultiple,
    'POOR_CAPTURE' || 'INVALID_IMAGE' || 'IMAGE_TOO_LARGE' => l.facePoorCapture,
    'AUTH_EXPIRED' => l.faceSignIn,
    'TIMEOUT' => l.faceTimeout,
    'RECEIVING_METHOD_REQUIRED' => l.faceSelectMethod,
    'RECIPIENT_UNAVAILABLE' => l.faceRecipientUnavailable,
    _ => l.faceUnavailable,
  };
}

String faceStatusCopy(BuildContext context, BioPayEnrollmentStatus status) {
  final l = paymentCopy(context);
  if (status.pending) return l.faceProcessing;
  return switch (status.status) {
    'active' => l.faceReady,
    'paused' => l.facePaused,
    'deleted' => l.faceRemoved,
    'reenrollment_required' => l.faceReenroll,
    'processing' => l.faceProcessing,
    'receiving_method_required' => l.faceSelectMethod,
    _ => l.faceSetUp,
  };
}
