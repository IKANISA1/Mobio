import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:mobi_app/core/services/ai_content_service.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';
import 'package:mobi_app/shared/widgets/loading_skeleton.dart';

/// Looping video player used as promotional background in empty states.
///
/// Plays silently, loops continuously, and shows a dark gradient overlay
/// for text legibility. Falls back to a gradient surface if video fails.
/// Respects the platform's reduced-motion setting.
class PromoVideoPlayer extends StatefulWidget {
  /// Promotional video asset with focal-point metadata.
  final PromoAsset asset;

  /// Height of the video container.
  final double height;

  /// Border radius for the container.
  final double borderRadius;

  /// Widget to show as fallback if video fails to load.
  final Widget? fallback;

  const PromoVideoPlayer({
    super.key,
    required this.asset,
    this.height = 280,
    this.borderRadius = 40,
    this.fallback,
  });

  @override
  State<PromoVideoPlayer> createState() => _PromoVideoPlayerState();
}

class _PromoVideoPlayerState extends State<PromoVideoPlayer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.asset.url),
      );

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0); // Always silent
      _controller!.play();

      if (mounted) {
        setState(() => _initialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    // Respect reduced motion preference
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion || _hasError) {
      return widget.fallback ??
          SizedBox(
            height: widget.height,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [ext.surfaceContainerLow, cs.surface],
                ),
              ),
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
            // Video or loading state
            if (_initialized && _controller != null)
              FittedBox(
                fit: BoxFit.cover,
                alignment: widget.asset.focusAlignment,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              )
            else
              Container(
                color: ext.surfaceContainer,
                child: LoadingSkeleton(height: widget.height, borderRadius: 0),
              ),

            // Dark gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.surface.withValues(alpha: 0.4),
                      cs.surface.withValues(alpha: 0.92),
                    ],
                    stops: const [0.0, 1.0],
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
