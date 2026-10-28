import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/book_models.dart';
import '../models/payment_models.dart';
import '../providers/payment_providers.dart';
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
String readingPathForBook(
  String bookId, {
  required bool isPdf,
  String? query,
  int? page,
}) {
  if (isPdf) {
    final parts = <String>[
      if (page != null && page > 0) 'page=$page',
      if (query != null && query.isNotEmpty) query,
    ];
    final q = parts.isEmpty ? '' : '?${parts.join('&')}';
    return '/pdf/$bookId$q';
  }
  final q = (query == null || query.isEmpty) ? '' : '?$query';
  return '/reader/$bookId$q';
}

/// Catalog book-detail path (Bible books use the verse reader instead).
String bookDetailPathForBook(String bookId, {required bool isBible}) {
  return isBible ? '/bible/book/$bookId' : '/book/$bookId';
}

/// Opens a catalog book. A checkout the buyer started but did not submit
/// resumes on the payment form; everything else opens the book page.
Future<void> openCatalogBook(
  BuildContext context,
  WidgetRef ref,
  BookSummary book,
) async {
  if (book.isBible) {
    if (!context.mounted) return;
    context.push('/bible/book/${book.id}');
    return;
  }
  if (book.requiresPurchase) {
    try {
      final txns = await ref.read(myTransactionsProvider.future);
      final active = activePurchaseForBook(txns, book.id);
      if (!context.mounted) return;
      if (active != null && active.status == PaymentStatus.pending) {
        context.push('/payment/${book.id}');
        return;
      }
    } catch (_) {
      // Book detail still offers "Continue payment" once purchases load.
    }
  }
  if (!context.mounted) return;
  context.push('/book/${book.id}');
}

/// Opens the Look Inside sample PDF (no purchase required).
void openBookLookInside(BuildContext context, String bookId) {
  context.push('/pdf/$bookId/preview');
}

/// True when catalog/detail UIs should offer Look Inside for [book].
bool bookOffersLookInside(BookSummary book) =>
    book.isPdf && book.hasPreview;

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

/// Leaves the reader.
///
/// Opened from Downloads: return to that list. Opened from book detail: pop
/// back to detail. Otherwise replace this route with book detail.
void leaveReaderToBookDetail(BuildContext context, String bookId) {
  final router = GoRouter.of(context);
  String? from;
  try {
    from = GoRouterState.of(context).uri.queryParameters['from'];
  } catch (_) {}
  if (from == 'downloads') {
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go('/downloads');
    return;
  }
  final detailPath = '/book/$bookId';
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
