import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter clips semantic rectangles at nested scroll view edges. Inspect the
/// owning render object's full bounds before treating a clipped edge as a
/// genuinely undersized control. The initial viewport uses the stock guideline.
class ScrolledTapTargetGuideline extends MinimumTapTargetGuideline {
  ScrolledTapTargetGuideline()
    : super(
        size: const Size(48, 48),
        link: 'https://support.google.com/accessibility/android/answer/7101858',
      );

  final _clippedTargets = <SemanticsNode>{};

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    _clippedTargets.clear();
    void inspect(RenderObject object) {
      final node = object.debugSemantics;
      if (node != null &&
          (node.rect.width < size.width || node.rect.height < size.height) &&
          object.semanticBounds.width >= size.width &&
          object.semanticBounds.height >= size.height) {
        _clippedTargets.add(node);
      }
      object.visitChildren(inspect);
    }

    for (final view in tester.binding.renderViews) {
      inspect(view);
    }
    return super.evaluate(tester);
  }

  @override
  bool shouldSkipNode(SemanticsNode node) =>
      _clippedTargets.contains(node) || super.shouldSkipNode(node);
}
