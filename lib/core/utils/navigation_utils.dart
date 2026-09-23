import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Safely pops the current route, falling back to the home route to prevent
/// black-screen states when there is no route to pop.
void safePop(BuildContext context, {String fallback = '/home'}) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(fallback);
    }
  } else {
    Navigator.maybeOf(context)?.maybePop();
  }
}
