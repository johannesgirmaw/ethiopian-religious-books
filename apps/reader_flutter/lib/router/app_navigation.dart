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

/// Catalog book-detail path (Bible books use the verse reader instead).
String bookDetailPathForBook(String bookId, {required bool isBible}) {
  return isBible ? '/bible/book/$bookId' : '/book/$bookId';
}

/// Opens a book in the reader from manage-books (reviewer preview included).
void openBookInReader(
  BuildContext context, {
  required String bookId,
  required bool isBible,
  required bool isPdf,
}) {
  if (isBible) {
    context.push('/bible/book/$bookId');
    return;
  }
  context.push(
    readingPathForBook(
      bookId,
      isPdf: isPdf,
      query: isPdf ? null : 'pickChapter=1',
    ),
  );
}

/// Leaves the reader and lands on book detail.
///
/// If detail is already the previous overlay, just pop so the stack stays
/// intact (admin list → detail → reader → detail → admin list).
void leaveReaderToBookDetail(BuildContext context, String bookId) {
  final detailPath = '/book/$bookId';
  final router = GoRouter.of(context);
  try {
    final matches = router.routerDelegate.currentConfiguration.matches;
    if (matches.length >= 2) {
      final prev = matches[matches.length - 2].matchedLocation;
      if (prev == detailPath || prev.startsWith('$detailPath?')) {
        if (router.canPop()) {
          router.pop();
          return;
        }
      }
    }
  } catch (_) {}
  router.pushReplacement(detailPath);
}
