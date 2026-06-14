import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const Duration mobiRouteTransitionDuration = Duration(milliseconds: 220);
const Duration mobiRouteReverseTransitionDuration = Duration(milliseconds: 170);

Page<void> mobiRoutePage(
  GoRouterState state,
  Widget child, {
  bool fullscreenDialog = false,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    fullscreenDialog: fullscreenDialog,
    transitionDuration: mobiRouteTransitionDuration,
    reverseTransitionDuration: mobiRouteReverseTransitionDuration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
