import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/shared/widgets/mobi_surface_panel.dart';
import 'package:mobi_app/shared/widgets/tappable_icon_button.dart';

class ChatHeader extends StatelessWidget {
  final VoidCallback onBack;
  final String title;
  final String subtitle;

  const ChatHeader({
    super.key,
    required this.onBack,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: MobiSurfacePanel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        borderRadius: 30,
        child: Row(
          children: [
            TappableIconButton(icon: LucideIcons.chevronLeft, onTap: onBack),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headlineMd.copyWith(color: cs.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySm.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shieldCheck, size: 14, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    'PRIVATE',
                    style: AppTypography.labelSm.copyWith(color: cs.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
