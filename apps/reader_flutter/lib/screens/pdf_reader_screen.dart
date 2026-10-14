import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/catalog_providers.dart';
import '../providers/continue_reading_provider.dart';
import '../providers/study_providers.dart';
import '../router/app_navigation.dart';
import '../storage/reader_prefs_storage.dart';
import '../utils/api_error_message.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_overlay_scaffold.dart';
import '../widgets/app_state_view.dart';
import '../widgets/pdf_document_reader.dart';
import '../widgets/premium_gate.dart';
import '../widgets/protected_content_scope.dart';

/// Full-screen PDF reader for books with ``content_format == pdf``.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  var _unlockChecked = false;
  int? _initialPage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureUnlocked());
  }

  Future<void> _ensureUnlocked() async {
    final book = await ref.read(bookDetailProvider(widget.bookId).future);
    if (!mounted) return;
    final ok = await ensureBookUnlocked(context, ref, book);
    if (!mounted) return;
    if (!ok) {
      leaveReaderToBookDetail(context, widget.bookId);
      return;
    }
    final page = await _resolveInitialPage();
    if (!mounted) return;
    setState(() {
      _unlockChecked = true;
      _initialPage = page;
    });
    unawaited(_recordOpened(book));
  }

  Future<int?> _resolveInitialPage() async {
    final query = GoRouterState.of(context).uri.queryParameters['page'];
    final fromQuery = int.tryParse(query ?? '');
    if (fromQuery != null && fromQuery > 0) return fromQuery;

    try {
      final cloud = await ref.read(
        readingProgressProvider(widget.bookId).future,
      );
      if (cloud.chapterKey == 'pdf' &&
          cloud.pageNumber != null &&
          cloud.pageNumber! > 0) {
        return cloud.pageNumber;
      }
    } catch (_) {}

    return ReaderPrefsStorage.readPdfPage(widget.bookId);
  }

  Future<void> _recordOpened(BookSummary book) async {
    try {
      await ReaderPrefsStorage.writeLastOpenedBook(
        LastOpenedBook(
          bookId: book.id,
          title: book.title,
          updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
          isPdf: true,
        ),
      );
      if (mounted) ref.invalidate(lastOpenedBookProvider);
    } catch (_) {}
    unawaited(
      trackReaderEvent(
        ref,
        bookId: book.id,
        eventName: 'chapter_open',
        chapterKey: 'pdf',
        pageNumber: _initialPage ?? 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final asyncBook = ref.watch(bookDetailProvider(widget.bookId));
    final title = asyncBook.valueOrNull?.title ?? l10n.pdfReaderTitle;

    Widget body;
    if (!_unlockChecked) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _PdfReaderBody(
        bookId: widget.bookId,
        bookTitle: asyncBook.valueOrNull?.title,
        initialPage: _initialPage,
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leaveReaderToBookDetail(context, widget.bookId);
      },
      child: AppLayoutScopeBuilder(
        child: Builder(
          builder: (context) {
            if (useWebShell(context)) {
              return WebOverlayScaffold(
                title: title,
                currentLocation: GoRouterState.of(context).matchedLocation,
                onBack: () => leaveReaderToBookDetail(context, widget.bookId),
                body: body,
              );
            }
            if (useDesktopShell(context)) {
              return DesktopOverlayScaffold(
                title: title,
                currentLocation: GoRouterState.of(context).matchedLocation,
                onBack: () => leaveReaderToBookDetail(context, widget.bookId),
                body: body,
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () =>
                      leaveReaderToBookDetail(context, widget.bookId),
                ),
              ),
              body: SafeArea(child: body),
            );
          },
        ),
      ),
    );
  }
}

class _PdfReaderBody extends ConsumerWidget {
  const _PdfReaderBody({
    required this.bookId,
    this.bookTitle,
    this.initialPage,
  });

  final String bookId;
  final String? bookTitle;
  final int? initialPage;

  String _errorText(Object e, AppLocalizations l10n) {
    if (e is DioException) {
      final parsed = messageFromDioResponse(e.response?.data);
      if (parsed != null) return parsed;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.sendTimeout) {
        return l10n.pdfConnectionFailed;
      }
      return l10n.pdfOpenFailed;
    }
    return l10n.pdfOpenFailed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncBook = ref.watch(bookDetailProvider(bookId));
    final asyncSource = ref.watch(pdfViewerSourceProvider(bookId));
    final dense = useMobileShell(context);

    return asyncBook.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppStateView(
        icon: Icons.error_outline,
        title: l10n.pdfOpenFailed,
        message: _errorText(e, l10n),
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(bookDetailProvider(bookId)),
      ),
      data: (book) {
        if (!book.isPdf) {
          return AppStateView(
            icon: Icons.picture_as_pdf_outlined,
            title: l10n.pdfNotAPdfBook,
            message: l10n.pdfNotAPdfBook,
            actionLabel: l10n.goBack,
            onAction: () => context.go('/book/$bookId'),
          );
        }
        return asyncSource.when(
          loading: () => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(l10n.pdfLoadingLabel),
              ],
            ),
          ),
          error: (e, _) => AppStateView(
            icon: Icons.error_outline,
            title: l10n.pdfOpenFailed,
            message: _errorText(e, l10n),
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(pdfViewerSourceProvider(bookId)),
          ),
          data: (source) {
            final reader = PdfDocumentReader(
              bookId: bookId,
              bookTitle: bookTitle ?? book.title,
              initialPage: initialPage,
              filePath: source.filePath,
              uri: source.uri,
              bytes: source.bytes,
              fileSize: source.fileSize,
              read: source.read,
              sourceName: source.sourceName,
              headers: source.headers,
              preferRangeAccess: source.preferRangeAccess,
              nativeCacheAccess: null,
              loadingLabel: l10n.pdfLoadingLabel,
              errorTitle: l10n.pdfOpenFailed,
              onRetry: () {
                ref.invalidate(pdfBookAccessProvider(bookId));
                ref.invalidate(pdfViewerSourceProvider(bookId));
              },
            );
            // Cap extreme wide desktop/web canvases so pages stay readable.
            final wide = useWebShell(context) || useDesktopShell(context);
            final padded = Padding(
              padding: EdgeInsets.fromLTRB(
                dense ? 4 : 8,
                0,
                dense ? 4 : 8,
                dense ? 4 : 8,
              ),
              child: wide
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth > 1400
                            ? 1400.0
                            : constraints.maxWidth;
                        return Center(
                          child: SizedBox(
                            width: width,
                            height: constraints.maxHeight,
                            child: reader,
                          ),
                        );
                      },
                    )
                  : reader,
            );
            return ContentProtectionLifecycle(child: padded);
          },
        );
      },
    );
  }
}
