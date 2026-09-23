import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

/// Skeleton loading shimmer with preset shapes for common UI patterns.
///
/// Uses a horizontal gradient sweep for the shimmer effect, matching
/// the app's surface token colors for a seamless look.
class LoadingSkeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 128,
    this.borderRadius = 28,
    this.margin,
  });

  /// Trip/booking card placeholder — tall card shape.
  const LoadingSkeleton.card({
    super.key,
    this.width,
    this.height = 192,
    this.borderRadius = 32,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  /// Hero card placeholder — wide banner.
  const LoadingSkeleton.hero({
    super.key,
    this.width,
    this.height = 160,
    this.borderRadius = 40,
    this.margin,
  });

  /// List tile placeholder — single row.
  const LoadingSkeleton.listTile({
    super.key,
    this.width,
    this.height = 72,
    this.borderRadius = 20,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  /// Action tile placeholder — square grid item.
  const LoadingSkeleton.actionTile({
    super.key,
    this.width,
    this.height = 100,
    this.borderRadius = 24,
    this.margin,
  });

  /// Inline text block placeholder.
  const LoadingSkeleton.text({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
    this.margin = const EdgeInsets.only(bottom: 8),
  });

  /// Button placeholder.
  const LoadingSkeleton.button({
    super.key,
    this.width,
    this.height = 56,
    this.borderRadius = 999,
    this.margin,
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
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
          margin: widget.margin,
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

/// Composite skeleton layouts for full-screen loading states.
class SkeletonLayouts {
  const SkeletonLayouts._();

  /// Profile form skeleton matching EditProfileScreen structure.
  static Widget profileForm() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 18, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              LoadingSkeleton(width: 52, height: 52, borderRadius: 18),
              SizedBox(width: 16),
              LoadingSkeleton(width: 140, height: 24, borderRadius: 12),
            ],
          ),
          SizedBox(height: 36),
          // WhatsApp label
          LoadingSkeleton.text(width: 160),
          SizedBox(height: 10),
          // WhatsApp input row
          Row(
            children: [
              LoadingSkeleton(width: 96, height: 56, borderRadius: 22),
              SizedBox(width: 12),
              Expanded(child: LoadingSkeleton(height: 56, borderRadius: 22)),
            ],
          ),
          SizedBox(height: 28),
          // MoMo label
          LoadingSkeleton.text(width: 140),
          SizedBox(height: 12),
          // MoMo section
          LoadingSkeleton(height: 160, borderRadius: 32),
          SizedBox(height: 28),
          // Driver toggle
          LoadingSkeleton(height: 96, borderRadius: 32),
          SizedBox(height: 32),
          // Save button
          LoadingSkeleton.button(),
        ],
      ),
    );
  }

  /// Trip list skeleton (2 cards with section label).
  static Widget tripList({int cardCount = 2}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LoadingSkeleton(
            width: 80,
            height: 28,
            borderRadius: 999,
            margin: EdgeInsets.only(bottom: 12),
          ),
          ...List.generate(cardCount, (_) => const LoadingSkeleton.card()),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// User list skeleton for admin screens.
  static Widget userList({int count = 4}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(count, (_) => const LoadingSkeleton.listTile()),
      ),
    );
  }

  /// Grid of action tiles.
  static Widget actionGrid({int count = 4, int crossAxisCount = 2}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(count, (_) {
          return const SizedBox(
            width: 160,
            child: LoadingSkeleton.actionTile(),
          );
        }),
      ),
    );
  }

  /// Chat message list skeleton.
  static Widget chatMessages({int count = 5}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(count, (i) {
          final isRight = i % 2 == 0;
          return Align(
            alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
            child: LoadingSkeleton(
              width: isRight ? 200 : 240,
              height: 48,
              borderRadius: 20,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          );
        }),
      ),
    );
  }
}
