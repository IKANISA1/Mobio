import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:mobi_app/core/services/ai_content_service.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';

/// Auto-scrolling image carousel used as promotional background in empty states.
///
/// Displays 1–4 images with crossfade transitions, dark gradient overlay,
/// and optional page indicator dots.
class PromoImageCarousel extends StatefulWidget {
  /// Promotional images to display with focal-point metadata.
  final List<PromoAsset> assets;

  /// Auto-scroll interval between slides.
  final Duration interval;

  /// Height of the carousel container.
  final double height;

  /// Border radius for the container.
  final double borderRadius;

  /// Whether to show page indicator dots.
  final bool showIndicators;

  const PromoImageCarousel({
    super.key,
    required this.assets,
    this.interval = const Duration(seconds: 5),
    this.height = 280,
    this.borderRadius = 40,
    this.showIndicators = true,
  });

  @override
  State<PromoImageCarousel> createState() => _PromoImageCarouselState();
}

class _PromoImageCarouselState extends State<PromoImageCarousel> {
  late final PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (widget.assets.length <= 1) return;
    _autoScrollTimer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % widget.assets.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    if (widget.assets.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: LoadingSkeleton(
          height: widget.height,
          borderRadius: widget.borderRadius,
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image pages
            PageView.builder(
              controller: _pageController,
              itemCount: widget.assets.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final asset = widget.assets[index];
                return CachedNetworkImage(
                  imageUrl: asset.url,
                  fit: BoxFit.cover,
                  alignment: asset.focusAlignment,
                  fadeInDuration: const Duration(milliseconds: 300),
                  fadeInCurve: Curves.easeOutCubic,
                  placeholder: (_, __) => Container(
                    color: ext.surfaceContainer,
                    child: LoadingSkeleton(
                      height: widget.height,
                      borderRadius: 0,
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: ext.surfaceContainerLowest,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      size: 40,
                    ),
                  ),
                );
              },
            ),

            // Dark gradient overlay for text legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.surface.withValues(alpha: 0.35),
                      cs.surface.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // Page indicators
            if (widget.showIndicators && widget.assets.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.assets.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: i == _currentPage ? 16 : 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? cs.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(100),
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
