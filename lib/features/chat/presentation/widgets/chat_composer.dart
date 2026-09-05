import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSendMessage;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            return DecoratedBox(
              decoration: BoxDecoration(
                color: ext.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: AppTypography.bodyMd,
                            decoration: InputDecoration(
                              hintText:
                                  'Message about fare, pickup, time, or luggage',
                              hintStyle: AppTypography.bodyMd.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              border: InputBorder.none,
                              isCollapsed: true,
                            ),
                            onSubmitted: isSending
                                ? null
                                : (_) => onSendMessage(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Material(
                          color: cs.primary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: isSending ? null : onSendMessage,
                            customBorder: const CircleBorder(),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: isSending
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cs.onPrimary,
                                        ),
                                      )
                                    : Icon(
                                        LucideIcons.send,
                                        size: 18,
                                        color: cs.onPrimary,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
