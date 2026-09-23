import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/mobi_page_header.dart';

class PlatformFeatureNoticeScreen extends StatelessWidget {
  const PlatformFeatureNoticeScreen({
    super.key,
    required this.title,
    required this.message,
    required this.onBack,
    this.note,
    this.showPlatformNote = true,
  });

  final String title;
  final String message;
  final String? note;
  final bool showPlatformNote;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            MobiPageHeader(title: title, onBack: onBack),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                            ),
                            if (showPlatformNote) ...[
                              const SizedBox(height: 12),
                              Text(
                                'This feature is unavailable on this device. You can continue using the other features in Mobio.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                            if (note != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                note!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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
