import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/platform_feature_notice_screen.dart';

class FaceEnrollmentScreen extends StatelessWidget {
  const FaceEnrollmentScreen({
    super.key,
    required this.onBack,
    this.isReEnrollment = false,
  });

  final VoidCallback onBack;
  final bool isReEnrollment;

  @override
  Widget build(BuildContext context) {
    return PlatformFeatureNoticeScreen(
      title: isReEnrollment
          ? 'Face update is mobile-only'
          : 'Face enrollment is mobile-only',
      message:
          'BioPay face enrollment in the Flutter app uses native camera capture plus on-device MobileFaceNet inference, which is not supported in the browser build.',
      note:
          'Use the mobile Flutter app for face registration or re-enrollment. The web build now presents this fallback instead of failing to compile.',
      onBack: onBack,
    );
  }
}
