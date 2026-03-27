import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Safely pops the current route, falling back to the home route to prevent
/// black-screen states when there is no route to pop.
void safePop(BuildContext context) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).pop();
  } else {
    context.go('/');
  }
}
