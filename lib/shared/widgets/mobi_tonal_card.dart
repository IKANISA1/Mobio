import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/app_radii.dart';
import 'package:mobi_design_system/theme/app_spacing.dart';
import 'package:mobi_design_system/theme/mobi_theme_extension.dart';

/// Revolut-reference tonal content group with optional target navigation.
class MobiTonalCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final String? semanticLabel;

  const MobiTonalCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = AppRadii.xxl,
    this.onTap,
    this.color,
    this.semanticLabel,
  });

  @override
  State<MobiTonalCard> createState() => _MobiTonalCardState();
}

class _MobiTonalCardState extends State<MobiTonalCard>
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
      end: 0.985,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
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
    final radius = BorderRadius.circular(widget.borderRadius);
    final surfaceColor = widget.color ?? ext.surfaceContainer;

    final card = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(color: surfaceColor, borderRadius: radius),
        child: Padding(
          padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
          child: widget.child,
        ),
      ),
    );

    if (widget.onTap == null) return card;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: MediaQuery.disableAnimationsOf(context)
                ? 1
                : _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onTapDown: _handleTapDown,
                  onTapUp: _handleTapUp,
                  onTapCancel: _handleTapCancel,
                  borderRadius: radius,
                  splashColor: cs.primary.withValues(alpha: 0.12),
                  highlightColor: Colors.transparent,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: card,
      ),
    );
  }
}
