import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobi_design_system/theme/app_typography.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

class ConnectivityOverlay extends StatefulWidget {
  final Widget child;
  final Future<List<ConnectivityResult>> Function()? checkConnectivity;
  final Stream<List<ConnectivityResult>>? connectivityStream;
  final Duration offlineDebounce;

  const ConnectivityOverlay({
    super.key,
    required this.child,
    this.checkConnectivity,
    this.connectivityStream,
    this.offlineDebounce = const Duration(milliseconds: 1500),
  });

  @override
  State<ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<ConnectivityOverlay>
    with SingleTickerProviderStateMixin {
  final Connectivity _connectivity = Connectivity();
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _offlineDebounceTimer;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );

    _checkInitialConnectivity();
    _subscription =
        (widget.connectivityStream ?? _connectivity.onConnectivityChanged)
            .listen(_handleConnectivityChanged);
  }

  Future<void> _checkInitialConnectivity() async {
    final results =
        await (widget.checkConnectivity ?? _connectivity.checkConnectivity)();
    if (!mounted) {
      return;
    }
    _handleConnectivityChanged(results);
  }

  void _handleConnectivityChanged(List<ConnectivityResult> results) {
    final hasKnownConnection = results.any((r) => r != ConnectivityResult.none);
    final shouldShowOffline = results.isNotEmpty && !hasKnownConnection;

    _offlineDebounceTimer?.cancel();

    if (shouldShowOffline) {
      _offlineDebounceTimer = Timer(widget.offlineDebounce, () {
        if (mounted) {
          _setOffline(true);
        }
      });
      return;
    }

    _setOffline(false);
  }

  void _setOffline(bool isOffline) {
    if (isOffline == _isOffline) {
      return;
    }

    setState(() {
      _isOffline = isOffline;
    });

    if (_isOffline) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _offlineDebounceTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return Stack(
      children: [
        widget.child,

        if (_isOffline)
          // Use SafeArea so the banner doesn't overlap the status bar text on newer OS versions.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SlideTransition(
                position: _slideAnimation,
                child: Material(
                  type: MaterialType.transparency,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: ext.borderSubtle.withValues(
                          alpha: ext.surfacePanelBorderAlpha,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: ext.surfacePanelShadowAlpha,
                          ),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.wifiOff,
                          color: cs.onErrorContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No internet connection',
                            style: AppTypography.labelMd.copyWith(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
