import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// Pops a full-screen route pushed above the main shell (book detail, reader, etc.).
void popOverlayRoute(BuildContext context) {
  final rootNav = rootNavigatorKey.currentState;
  if (rootNav != null && rootNav.canPop()) {
    rootNav.pop();
    return;
  }
  if (context.canPop()) {
    context.pop();
    return;
  }
  GoRouter.of(context).go('/home');
}

/// Opens the text reader or PDF reader depending on the book package format.
String readingPathForBook(String bookId, {required bool isPdf, String? query}) {
  if (isPdf) return '/pdf/$bookId';
  final q = (query == null || query.isEmpty) ? '' : '?$query';
  return '/reader/$bookId$q';
}
