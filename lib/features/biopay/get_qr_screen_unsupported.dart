import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/platform_feature_notice_screen.dart';

class GetQrScreen extends StatelessWidget {
  const GetQrScreen({
    super.key,
    required this.onBack,
    this.countryCode = '+250',
  });

  final VoidCallback onBack;
  final String countryCode;

  @override
  Widget build(BuildContext context) {
    return PlatformFeatureNoticeScreen(
      title: 'BioPay QR is mobile-only',
      message:
          'The Flutter BioPay QR flow depends on native gallery save, device permission, and payment integrations that are only supported in the mobile app.',
      note:
          'Use the installable Mobio PWA for web access, or open the iOS/Android app to generate and save a BioPay QR code for $countryCode.',
      onBack: onBack,
    );
  }
}
