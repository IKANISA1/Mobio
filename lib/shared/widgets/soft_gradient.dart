import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobi_design_system/theme/mobi_visual_family.dart';

enum SoftGradientTone {
  neutral,
  shell,
  nearby,
  profile,
  success,
  alert,
  trips,
  biopay,
  wallet,
  authentication,
}

/// The overview wash scrolls away; focused tasks keep their neutral canvas.
class SoftGradient extends StatefulWidget {
  const SoftGradient({
    super.key,
    required this.child,
    this.tone = SoftGradientTone.neutral,
  });
  final Widget child;
  final SoftGradientTone tone;
  @override
  State<SoftGradient> createState() => _SoftGradientState();
}

class _SoftGradientState extends State<SoftGradient> {
  double _offset = 0;
  @override
  void didUpdateWidget(covariant SoftGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tone != widget.tone) _offset = 0;
  }

  @override
  Widget build(BuildContext context) {
    final family = switch (widget.tone) {
      SoftGradientTone.shell => MobiVisualFamily.home,
      SoftGradientTone.nearby ||
      SoftGradientTone.trips => MobiVisualFamily.payments,
      SoftGradientTone.profile => MobiVisualFamily.rewards,
      SoftGradientTone.biopay => MobiVisualFamily.teal,
      SoftGradientTone.wallet => MobiVisualFamily.value,
      SoftGradientTone.authentication => MobiVisualFamily.authentication,
      _ => MobiVisualFamily.neutral,
    };
    if (family == MobiVisualFamily.neutral) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SizedBox.expand(child: widget.child),
      );
    }
    final palette = MobiFamilyPalette.resolve(
      family,
      Theme.of(context).brightness,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return ColoredBox(
          color: palette.colors.last,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                top: -math.min(_offset, height),
                left: 0,
                right: 0,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: palette.colors,
                      stops: MobiFamilyPalette.stops,
                    ),
                  ),
                ),
              ),
              NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
                    final next = math.max(0.0, n.metrics.pixels);
                    if (next != _offset) setState(() => _offset = next);
                  }
                  return false;
                },
                child: SizedBox.expand(child: widget.child),
              ),
            ],
          ),
        );
      },
    );
  }
}
