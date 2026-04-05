import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

class PlatformFeatureNoticeScreen extends StatelessWidget {
  const PlatformFeatureNoticeScreen({
    super.key,
    required this.title,
    required this.message,
    required this.onBack,
    this.note,
  });

  final String title;
  final String message;
  final String? note;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const platformLabel = kIsWeb ? 'web' : 'this platform';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
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
                        title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Mobio is keeping the Flutter app available on mobile, but this flow is intentionally disabled on $platformLabel to avoid broken camera, gallery, or on-device ML behavior.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
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
                      const SizedBox(height: 24),
                      MobiButton(
                        onPressed: onBack,
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
