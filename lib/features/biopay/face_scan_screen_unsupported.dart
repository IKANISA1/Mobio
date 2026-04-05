import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/platform_feature_notice_screen.dart';

class FaceScanScreen extends StatelessWidget {
  const FaceScanScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return PlatformFeatureNoticeScreen(
      title: 'BioPay face scan is mobile-only',
      message:
          'This face-scanning flow relies on the device camera plus on-device biometric matching, which are only enabled in the native Flutter app on iOS and Android.',
      note:
          'The web build now degrades cleanly instead of loading unsupported camera or ML components.',
      onBack: onBack,
    );
  }
}
