import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/glass_card.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

enum BiopayConsentDialogAction { continueFlow, viewPrivacyCenter, cancel }

class BiopayConsentDialog extends StatefulWidget {
  const BiopayConsentDialog({super.key});

  static Future<BiopayConsentDialogAction> show(BuildContext context) async {
    final action =
        await showGeneralDialog<BiopayConsentDialogAction>(
          context: context,
          barrierDismissible: true,
          barrierLabel: 'BioPay face data consent',
          barrierColor: Colors.black.withValues(alpha: 0.72),
          pageBuilder: (context, animation, secondaryAnimation) {
            return const SafeArea(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Material(
                    color: Colors.transparent,
                    child: BiopayConsentDialog(),
                  ),
                ),
              ),
            );
          },
          transitionBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                child: child,
              ),
            );
          },
        ) ??
        BiopayConsentDialogAction.cancel;

    return action;
  }

  @override
  State<BiopayConsentDialog> createState() => _BiopayConsentDialogState();
}

class _BiopayConsentDialogState extends State<BiopayConsentDialog> {
  bool _hasAccepted = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClayCard(
      padding: const EdgeInsets.all(28),
      borderRadius: 32,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    LucideIcons.scanFace,
                    size: 30,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'BIOPAY FACE DATA',
                    style: AppTypography.titleLg.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Before you capture your face for BioPay, please confirm how Mobio uses it.',
              style: AppTypography.bodyMd.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            const _DisclosureRow(
              icon: LucideIcons.cpu,
              title: 'Created on-device',
              body:
                  'Mobio uses your camera to create a numeric face embedding on your device. Raw face photos are not stored after processing.',
            ),
            const SizedBox(height: 12),
            const _DisclosureRow(
              icon: LucideIcons.server,
              title: 'Sent to Mobio for matching',
              body:
                  'The embedding is sent securely to Mobio so BioPay can enroll your Face ID and match BioPay recipients during face scans.',
            ),
            const SizedBox(height: 12),
            const _DisclosureRow(
              icon: LucideIcons.shieldCheck,
              title: 'Under your control',
              body:
                  'You can delete your BioPay Face ID from the app later and revoke camera permission at any time from device settings.',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _hasAccepted,
                    onChanged: (value) {
                      setState(() => _hasAccepted = value ?? false);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'I understand that Mobio will create, transmit, and store my BioPay face embedding so I can use Face ID payments.',
                        style: AppTypography.bodySm.copyWith(
                          color: cs.onSurface,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 160),
              opacity: _hasAccepted ? 1 : 0.45,
              child: MobiButton(
                width: double.infinity,
                onPressed: _hasAccepted
                    ? () => Navigator.of(
                        context,
                      ).pop(BiopayConsentDialogAction.continueFlow)
                    : null,
                child: const Text('I AGREE AND CONTINUE'),
              ),
            ),
            const SizedBox(height: 12),
            MobiButton(
              width: double.infinity,
              variant: MobiButtonVariant.ghost,
              onPressed: () => Navigator.of(
                context,
              ).pop(BiopayConsentDialogAction.viewPrivacyCenter),
              child: const Text('VIEW PRIVACY CENTER'),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).pop(BiopayConsentDialogAction.cancel),
                child: Text(
                  'Not now',
                  style: AppTypography.labelMd.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: cs.onSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMd.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: AppTypography.bodySm.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
