import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_app/core/theme/app_radii.dart';
import 'package:mobi_app/core/theme/app_spacing.dart';
import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';
import 'package:mobi_app/shared/widgets/mobi_info_chip.dart';
import 'package:mobi_app/shared/widgets/mobi_input_field.dart';

class ChatReportDraft {
  const ChatReportDraft({required this.category, required this.details});

  final String category;
  final String details;
}

Future<ChatReportDraft?> showChatReportSheet(BuildContext context) {
  return showModalBottomSheet<ChatReportDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _ChatReportSheet(),
  );
}

class _ChatReportSheet extends StatefulWidget {
  const _ChatReportSheet();

  @override
  State<_ChatReportSheet> createState() => _ChatReportSheetState();
}

class _ChatReportSheetState extends State<_ChatReportSheet> {
  static const _categories = <String, String>{
    'harassment': 'Harassment',
    'spam': 'Spam',
    'unsafe_behavior': 'Unsafe behavior',
    'route_mismatch': 'Route mismatch',
    'fraud': 'Fraud',
    'other': 'Other',
  };

  final _detailsController = TextEditingController();
  String _selectedCategory = 'other';

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Material(
        color: ext.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.hero),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.paddingOf(context).bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.flag, color: cs.error, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Report user',
                      style: AppTypography.titleLg.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final entry in _categories.entries)
                    MobiInfoChip(
                      label: entry.value,
                      icon: _selectedCategory == entry.key
                          ? LucideIcons.check
                          : null,
                      onTap: () => setState(() {
                        _selectedCategory = entry.key;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              MobiInputField(
                label: 'Details',
                hint: 'Describe what happened',
                controller: _detailsController,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: MobiButton(
                      variant: MobiButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MobiButton(
                      variant: MobiButtonVariant.danger,
                      onPressed: () => Navigator.of(context).pop(
                        ChatReportDraft(
                          category: _selectedCategory,
                          details: _detailsController.text.trim(),
                        ),
                      ),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
