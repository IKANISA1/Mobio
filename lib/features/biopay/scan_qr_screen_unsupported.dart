import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/platform_feature_notice_screen.dart';

class ScanQrScreen extends StatelessWidget {
  const ScanQrScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return PlatformFeatureNoticeScreen(
      title: 'QR scanning is mobile-only',
      message:
          'The Flutter QR scanner uses native camera capture and payment handoff integrations that are not enabled in the browser build.',
      note:
          'Use the installable Mobio PWA for web routes, or continue this BioPay payment scan in the Android/iOS app.',
      onBack: onBack,
    );
  }
}
