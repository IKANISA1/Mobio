import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobi_app/core/services/ai_content_service.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Full-screen promotional background that replaces a plain gradient.
///
/// Fetches Rwanda-specific promo images from Supabase Storage and displays
/// them as a full-screen background. Cards and containers sit on top with
/// their own opaque backgrounds — the image shows through the gaps.
///
/// Auto-rotates through images every 10s with a smooth crossfade.
/// Falls back to the classic radial gradient if no media is available.
enum SoftGradientVisibilityMode { balanced, reading }

class SoftGradient extends StatefulWidget {
  final Widget child;

  /// Which promo category to fetch media for.
  /// Defaults to [PromoCategory.nearbyDrivers].
  final PromoCategory category;
  final SoftGradientVisibilityMode visibilityMode;
  final bool allowMotion;

  const SoftGradient({
    super.key,
    required this.child,
    this.category = PromoCategory.nearbyDrivers,
    this.visibilityMode = SoftGradientVisibilityMode.balanced,
    this.allowMotion = true,
  });

  @override
  State<SoftGradient> createState() => _SoftGradientState();
}

class _SoftGradientState extends State<SoftGradient> {
  final _service = AiContentService();

  // Image carousel state
  List<PromoAsset> _imageAssets = [];
  int _currentIndex = 0;
  Timer? _rotationTimer;

  bool get _allowAnimatedMedia =>
      widget.allowMotion &&
      !WidgetsBinding
          .instance
          .platformDispatcher
          .accessibilityFeatures
          .disableAnimations;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMedia() async {
    try {
      final images = await _service.fetchPromoImageAssets(widget.category);
      if (mounted) {
        setState(() {
          _imageAssets = images;
        });
        _startImageRotation();
      }
    } on Object catch (_) {
      // Fall back to the gradient-only background when media cannot be loaded.
    }
  }

  void _startImageRotation() {
    if (_imageAssets.length <= 1 || !_allowAnimatedMedia) {
      return;
    }
    _rotationTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() => _currentIndex = (_currentIndex + 1) % _imageAssets.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final mediaPadding = MediaQuery.paddingOf(context);
    final currentImageAsset = _imageAssets.isEmpty
        ? null
        : _imageAssets[_currentIndex.clamp(0, _imageAssets.length - 1)];
    final hasMedia = currentImageAsset != null;
    final overlay = _overlaySpecFor(widget.visibilityMode);

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Layer 1: Background ──
        if (_imageAssets.isNotEmpty)
          // Image background with crossfade
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: CachedNetworkImage(
              key: ValueKey(_currentIndex),
              imageUrl: currentImageAsset!.url,
              fit: BoxFit.cover,
              alignment: currentImageAsset.focusAlignment,
              width: double.infinity,
              height: double.infinity,
              fadeInDuration: const Duration(milliseconds: 300),
              placeholder: (context, url) =>
                  Container(color: ext.surfaceContainerLow),
              errorWidget: (context, url, error) =>
                  Container(color: cs.surface),
            ),
          )
        else
          // Fallback: classic radial gradient
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.5,
                colors: [ext.surfaceContainerLow, cs.surface],
              ),
            ),
          ),

        // ── Layer 2: Ambient readability overlay ──
        // Keep promo media visible in open space while slightly reinforcing
        // the system chrome zones and safe text area.
        if (hasMedia)
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: overlay.ambientAlpha),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: mediaPadding.top + 56,
                      width: double.infinity,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: overlay.blurSigma,
                            sigmaY: overlay.blurSigma,
                            tileMode: TileMode.clamp,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  cs.surface.withValues(
                                    alpha: overlay.topScrimAlpha,
                                  ),
                                  cs.surface.withValues(
                                    alpha: overlay.topScrimAlpha * 0.42,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.54, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      height: mediaPadding.bottom + 136,
                      width: double.infinity,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: overlay.blurSigma * 0.82,
                            sigmaY: overlay.blurSigma * 0.82,
                            tileMode: TileMode.clamp,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  cs.surface.withValues(
                                    alpha: overlay.bottomScrimAlpha,
                                  ),
                                  cs.surface.withValues(
                                    alpha: overlay.bottomScrimAlpha * 0.34,
                                  ),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.48, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          cs.surface.withValues(alpha: overlay.sideScrimAlpha),
                          cs.surface.withValues(
                            alpha: overlay.sideScrimAlpha * 0.4,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.16, 0.44],
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: currentImageAsset.safeTextAlignment,
                        radius: 0.92,
                        colors: [
                          cs.surface.withValues(alpha: overlay.focusScrimAlpha),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Layer 3: Content ──
        // Cards/containers are opaque; the image shows through the gaps.
        widget.child,
      ],
    );
  }
}

class _SoftGradientOverlaySpec {
  const _SoftGradientOverlaySpec({
    required this.ambientAlpha,
    required this.topScrimAlpha,
    required this.bottomScrimAlpha,
    required this.sideScrimAlpha,
    required this.focusScrimAlpha,
    required this.blurSigma,
  });

  final double ambientAlpha;
  final double topScrimAlpha;
  final double bottomScrimAlpha;
  final double sideScrimAlpha;
  final double focusScrimAlpha;
  final double blurSigma;
}

_SoftGradientOverlaySpec _overlaySpecFor(SoftGradientVisibilityMode mode) {
  switch (mode) {
    case SoftGradientVisibilityMode.reading:
      return const _SoftGradientOverlaySpec(
        ambientAlpha: 0.06,
        topScrimAlpha: 0.30,
        bottomScrimAlpha: 0.24,
        sideScrimAlpha: 0.065,
        focusScrimAlpha: 0.10,
        blurSigma: 1.9,
      );
    case SoftGradientVisibilityMode.balanced:
      return const _SoftGradientOverlaySpec(
        ambientAlpha: 0.03,
        topScrimAlpha: 0.20,
        bottomScrimAlpha: 0.15,
        sideScrimAlpha: 0.04,
        focusScrimAlpha: 0.06,
        blurSigma: 1.25,
      );
  }
}
