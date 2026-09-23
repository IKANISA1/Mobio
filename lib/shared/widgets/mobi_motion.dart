import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Decorative entry effects must reveal content immediately when motion is off.
extension MobiWidgetMotion on Widget {
  Animate animateAccessible(BuildContext context, {Duration? delay}) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return animate(
      autoPlay: !reduce,
      value: reduce ? 1 : null,
      delay: reduce ? Duration.zero : delay,
    );
  }
}

extension MobiListMotion on List<Widget> {
  AnimateList animateAccessible(
    BuildContext context, {
    Duration? delay,
    Duration? interval,
  }) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return animate(
      autoPlay: !reduce,
      onInit: reduce ? (controller) => controller.value = 1 : null,
      delay: reduce ? Duration.zero : delay,
      interval: reduce ? Duration.zero : interval,
    );
  }
}
