import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

class ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGeneratingSuggestions;
  final bool isAutocompleting;
  final bool isSending;
  final List<String> replySuggestions;
  final VoidCallback onRequestReplySuggestions;
  final VoidCallback onAutocompleteDraft;
  final ValueChanged<String> onApplySuggestion;
  final VoidCallback onSendMessage;

  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isGeneratingSuggestions,
    required this.isAutocompleting,
    required this.isSending,
    required this.replySuggestions,
    required this.onRequestReplySuggestions,
    required this.onAutocompleteDraft,
    required this.onApplySuggestion,
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
            final hasDraftText = value.text.trim().isNotEmpty;

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
                padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(LucideIcons.sparkles, size: 14, color: cs.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Gemini input assist',
                          style: AppTypography.labelSm.copyWith(
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          backgroundColor: cs.primaryContainer,
                          side: BorderSide.none,
                          label: Text(
                            isGeneratingSuggestions
                                ? 'Suggesting...'
                                : 'Suggest replies',
                            style: AppTypography.bodySm.copyWith(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: (isSending || isGeneratingSuggestions)
                              ? null
                              : onRequestReplySuggestions,
                        ),
                        ActionChip(
                          backgroundColor: ext.surfaceContainer,
                          side: BorderSide.none,
                          label: Text(
                            isAutocompleting
                                ? 'Completing...'
                                : 'Complete draft',
                            style: AppTypography.bodySm.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed:
                              (isSending || isAutocompleting || !hasDraftText)
                              ? null
                              : onAutocompleteDraft,
                        ),
                        ...replySuggestions.map(
                          (suggestion) => ActionChip(
                            backgroundColor: cs.secondaryContainer,
                            side: BorderSide.none,
                            label: Text(
                              suggestion,
                              style: AppTypography.bodySm.copyWith(
                                color: cs.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: isSending
                                ? null
                                : () => onApplySuggestion(suggestion),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                                  'Message about price, pickup, time, or luggage',
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
