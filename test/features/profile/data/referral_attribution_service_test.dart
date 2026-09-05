import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobi_app/features/profile/data/referral_attribution_service.dart';

void main() {
  group('ReferralAttributionService', () {
    test('creates iOS install proof only for Universal Link app opens', () {
      expect(
        ReferralAttributionService.shouldCreateIosUniversalLinkInstallId(
          platform: TargetPlatform.iOS,
          source: 'initial_app_link',
          kIsWeb: false,
        ),
        isTrue,
      );
      expect(
        ReferralAttributionService.shouldCreateIosUniversalLinkInstallId(
          platform: TargetPlatform.iOS,
          source: 'app_link_stream',
          kIsWeb: false,
        ),
        isTrue,
      );
      expect(
        ReferralAttributionService.shouldCreateIosUniversalLinkInstallId(
          platform: TargetPlatform.android,
          source: 'initial_app_link',
          kIsWeb: false,
        ),
        isFalse,
      );
      expect(
        ReferralAttributionService.shouldCreateIosUniversalLinkInstallId(
          platform: TargetPlatform.iOS,
          source: 'play_install_referrer',
          kIsWeb: false,
        ),
        isFalse,
      );
      expect(
        ReferralAttributionService.shouldCreateIosUniversalLinkInstallId(
          platform: TargetPlatform.iOS,
          source: 'initial_app_link',
          kIsWeb: true,
        ),
        isFalse,
      );
    });
  });
}
