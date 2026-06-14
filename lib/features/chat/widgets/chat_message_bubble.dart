import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/features/chat/models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMine;
  final String Function(DateTime?) formatTime;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (message.isSystem) {
      return Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).extension<MobiThemeExtension>()!.surfaceContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shieldCheck, size: 14, color: cs.primary),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message.body,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .animate()
          .fade(duration: 300.ms)
          .scale(
            begin: const Offset(0.9, 0.9),
            duration: 300.ms,
            curve: Curves.easeOutBack,
          );
    }

    final bubbleColor = isMine
        ? cs.primary
        : Theme.of(
            context,
          ).extension<MobiThemeExtension>()!.surfaceContainerHigh;
    final foreground = isMine ? cs.onPrimary : cs.onSurface;
    final alignment = isMine
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final redacted = message.metadata['redacted'] == true;

    return Column(
          crossAxisAlignment: alignment,
          children: [
            Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: redacted
                    ? cs.surfaceContainerHighest.withValues(alpha: 0.86)
                    : bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isMine ? 22 : 8),
                  bottomRight: Radius.circular(isMine ? 8 : 22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: redacted
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.lock, size: 16, color: cs.primary),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            message.body,
                            style: AppTypography.bodyMd.copyWith(
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      message.body,
                      style: AppTypography.bodyMd.copyWith(color: foreground),
                    ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                formatTime(message.createdAt),
                style: AppTypography.labelMd.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        )
        .animate()
        .fade(duration: 300.ms)
        .slideX(
          begin: isMine ? 0.2 : -0.2,
          duration: 300.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
