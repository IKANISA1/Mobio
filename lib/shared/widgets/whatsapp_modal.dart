import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/whatsapp_icon.dart';

/// WhatsApp modal bottom sheet matching transito overlay.
class WhatsAppModal extends StatelessWidget {
  final String driverName;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const WhatsAppModal({
    super.key,
    required this.driverName,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.onSurface.withValues(alpha: 0.4),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ClayCard(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                borderRadius: 48,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // WhatsApp icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(40),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: WhatsAppIcon(size: 40, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    Text(
                      'Connect with $driverName',
                      style: AppTypography.displayMd.copyWith(
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Continue the conversation on WhatsApp to coordinate your trip.',
                      style: AppTypography.bodyLg.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // Buttons
                    MobiButton(
                      variant: MobiButtonVariant.whatsapp,
                      width: double.infinity,
                      onPressed: onOpen,
                      child: const Text('Open WhatsApp'),
                    ),
                    const SizedBox(height: 16),
                    MobiButton(
                      variant: MobiButtonVariant.ghost,
                      width: double.infinity,
                      onPressed: onDismiss,
                      child: Text(
                        'Maybe Later',
                        style: AppTypography.titleMd.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
