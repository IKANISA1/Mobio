import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Skeleton loading shimmer matching transito LoadingSkeleton.
class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 128,
    this.borderRadius = 40,
  });

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * _controller.value, 0),
              end: Alignment(1 + 2 * _controller.value, 0),
              colors: [
                ext.surfaceContainer,
                ext.surfaceContainerHigh,
                ext.surfaceContainer,
              ],
            ),
          ),
        );
      },
    );
  }
}
