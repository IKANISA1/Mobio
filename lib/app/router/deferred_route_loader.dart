import 'package:flutter/material.dart';
import 'package:mobi_app/core/utils/app_logger.dart';
import 'package:mobi_app/core/utils/navigation_utils.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';
import 'package:mobi_app/shared/widgets/mobi_button.dart';

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
  bool _isLoading = false;
  late Future<void> _loadFuture = _load();

  Future<void> _load() async {
    _isLoading = true;
    try {
      await widget.loadLibrary();
    } on Object catch (error) {
      AppLogger.warning('Deferred screen load failed (${error.runtimeType}).');
      rethrow;
    } finally {
      _isLoading = false;
    }
  }

  void _retry() {
    if (_isLoading || !mounted) {
      return;
    }
    final loadFuture = _load();
    setState(() {
      _loadFuture = loadFuture;
    });
  }

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
          return _DeferredRouteErrorScreen(onRetry: _retry);
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
  const _DeferredRouteErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 36, color: cs.error),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      'Screen failed to load',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your connection and try again, or go back.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  MobiButton(
                    width: double.infinity,
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                  const SizedBox(height: 12),
                  MobiButton(
                    width: double.infinity,
                    variant: MobiButtonVariant.ghost,
                    onPressed: () => safePop(context),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
