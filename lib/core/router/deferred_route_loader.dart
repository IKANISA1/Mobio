import 'package:flutter/material.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';

class DeferredRouteLoader extends StatefulWidget {
  const DeferredRouteLoader({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.loadingBuilder,
  });

  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;
  final WidgetBuilder? loadingBuilder;

  @override
  State<DeferredRouteLoader> createState() => _DeferredRouteLoaderState();
}

class _DeferredRouteLoaderState extends State<DeferredRouteLoader> {
  late final Future<void> _loadFuture = widget.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ??
              const _DeferredRouteLoadingScreen();
        }

        if (snapshot.hasError) {
          return _DeferredRouteErrorScreen(error: snapshot.error);
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          switchInCurve: Curves.easeOutCubic,
          child: Builder(
            key: const ValueKey('loaded'),
            builder: widget.builder,
          ),
        );
      },
    );
  }
}

class _DeferredRouteLoadingScreen extends StatelessWidget {
  const _DeferredRouteLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: const SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton(width: 52, height: 52, borderRadius: 18),
                SizedBox(height: 28),
                LoadingSkeleton(width: 180, height: 30, borderRadius: 14),
                SizedBox(height: 18),
                LoadingSkeleton(height: 112, borderRadius: 28),
                SizedBox(height: 14),
                LoadingSkeleton(height: 180, borderRadius: 32),
                SizedBox(height: 14),
                LoadingSkeleton(height: 96, borderRadius: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeferredRouteErrorScreen extends StatelessWidget {
  const _DeferredRouteErrorScreen({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 36, color: cs.error),
                const SizedBox(height: 16),
                Text(
                  'Screen failed to load',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
