import 'package:flutter/material.dart';
import 'package:mobi_app/core/theme/mobi_theme_extension.dart';

/// Clay-morphism card matching transito's `.clay-card`.
/// Subtle inner glow + gradient overlay, large border radius.
/// Provides scale + opacity press feedback when tappable.
class ClayCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;

  const ClayCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 40,
    this.onTap,
    this.color,
    this.semanticLabel,
  });

  @override
  State<ClayCard> createState() => _ClayCardState();
}

class _ClayCardState extends State<ClayCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null) _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null) _controller.reverse();
  }

  void _handleTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<MobiThemeExtension>()!;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color ?? ext.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: ext.clayCardShadow,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: ext.cardBorderAlpha),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: ext.clayCardGradientWhiteAlpha),
            Colors.transparent,
          ],
        ),
      ),
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.all(24),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return card;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(opacity: _opacityAnimation.value, child: child),
            );
          },
          child: card,
        ),
      ),
    );
  }
}
