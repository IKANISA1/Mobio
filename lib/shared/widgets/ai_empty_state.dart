import 'package:flutter/material.dart';


import 'package:mobi_app/core/theme/app_typography.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/core/services/ai_content_service.dart';
import 'package:mobi_app/shared/widgets/promo_image_carousel.dart';
import 'package:mobi_app/shared/widgets/promo_video_player.dart';

/// Unified empty state widget with AI-generated promotional backgrounds.
///
/// Replaces static "no data" containers across the app with dynamic
/// image carousels or video backgrounds, turning empty screens into
/// engaging, brand-reinforcing moments.
///
/// Falls back gracefully to a simple gradient if content is unavailable.
class AiEmptyState extends StatefulWidget {
  /// The promotional content category to display.
  final PromoCategory category;

  /// Primary empty state text (e.g., "No nearby drivers found.").
  final String title;

  /// Optional subtitle text (e.g., "Pull down to refresh.").
  final String? subtitle;

  /// Optional icon to display above the title.
  final IconData? icon;

  /// Whether to try loading a video background (only for full-screen surfaces).
  final bool useVideo;

  /// Height of the container. Null = intrinsic sizing.
  final double? height;

  /// Optional action callback (e.g., for retry or navigate).
  final VoidCallback? onAction;

  /// Optional action label text.
  final String? actionLabel;

  const AiEmptyState({
    super.key,
    required this.category,
    required this.title,
    this.subtitle,
    this.icon,
    this.useVideo = false,
    this.height,
    this.onAction,
    this.actionLabel,
  });

  @override
  State<AiEmptyState> createState() => _AiEmptyStateState();
}

class _AiEmptyStateState extends State<AiEmptyState> {
  final _service = AiContentService();
  List<String> _imageUrls = [];
  String? _videoUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final images = await _service.fetchPromoImages(widget.category);

      String? video;
      if (widget.useVideo) {
        video = await _service.fetchPromoVideo(widget.category);
      }

      if (mounted) {
        setState(() {
          _imageUrls = images;
          _videoUrl = video;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;
    final containerHeight = widget.height ?? 260;

    return Container(
      height: containerHeight,
      decoration: BoxDecoration(
        color: ext.surfaceContainerLowest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: cs.outlineVariant,
          width: 1,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background: video, image carousel, or gradient fallback
          _buildBackground(cs, ext, containerHeight),

          // Content overlay
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 40,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  if (widget.onAction != null && widget.actionLabel != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: widget.onAction,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: cs.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          widget.actionLabel!,
                          style: AppTypography.labelLg.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground(ColorScheme cs, MobiThemeExtension ext, double height) {
    // Loading state
    if (_isLoading) {
      return _buildGradientFallback(cs, ext);
    }

    // Video background (if available and requested)
    if (widget.useVideo && _videoUrl != null) {
      return PromoVideoPlayer(
        videoUrl: _videoUrl!,
        height: height,
        borderRadius: 0, // Parent already clips
        fallback: _imageUrls.isNotEmpty
            ? PromoImageCarousel(
                imageUrls: _imageUrls,
                height: height,
                borderRadius: 0,
                showIndicators: false,
              )
            : _buildGradientFallback(cs, ext),
      );
    }

    // Image carousel
    if (_imageUrls.isNotEmpty) {
      return PromoImageCarousel(
        imageUrls: _imageUrls,
        height: height,
        borderRadius: 0, // Parent already clips
        showIndicators: _imageUrls.length > 1,
      );
    }

    // Gradient-only fallback for no content
    return _buildGradientFallback(cs, ext);
  }

  Widget _buildGradientFallback(ColorScheme cs, MobiThemeExtension ext) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ext.surfaceContainerLow,
            cs.surface,
          ],
        ),
      ),
    );
  }
}
