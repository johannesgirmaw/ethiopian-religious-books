import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../providers/catalog_providers.dart';
import '../router/app_navigation.dart';
import '../utils/api_error_message.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_overlay_scaffold.dart';
import '../widgets/app_state_view.dart';
import '../widgets/pdf_document_reader.dart';
import '../widgets/premium_gate.dart';

/// Full-screen PDF reader for books with ``content_format == pdf``.
class PdfReaderScreen extends ConsumerStatefulWidget {
  const PdfReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<PdfReaderScreen> createState() => _PdfReaderScreenState();
}

class _PdfReaderScreenState extends ConsumerState<PdfReaderScreen> {
  var _unlockChecked = false;

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
      popOverlayRoute(context);
      return;
    }
    setState(() => _unlockChecked = true);
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
      body = _PdfReaderBody(bookId: widget.bookId);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOverlayRoute(context);
      },
      child: AppLayoutScopeBuilder(
        child: Builder(
          builder: (context) {
            if (useWebShell(context)) {
              return WebOverlayScaffold(
                title: title,
                currentLocation: GoRouterState.of(context).matchedLocation,
                body: body,
              );
            }
            if (useDesktopShell(context)) {
              return DesktopOverlayScaffold(
                title: title,
                currentLocation: GoRouterState.of(context).matchedLocation,
                body: body,
              );
            }
            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: SafeArea(child: body),
            );
          },
        ),
      ),
    );
  }
}

class _PdfReaderBody extends ConsumerWidget {
  const _PdfReaderBody({required this.bookId});

  final String bookId;

  String _errorText(Object e, AppLocalizations l10n) {
    if (e is DioException) {
      return messageFromDioResponse(e.response?.data) ?? l10n.pdfOpenFailed;
    }
    return l10n.pdfOpenFailed;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncBook = ref.watch(bookDetailProvider(bookId));
    final asyncSource = ref.watch(pdfViewerSourceProvider(bookId));

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
          data: (source) => Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: PdfDocumentReader(
              filePath: source.filePath,
              uri: source.uri,
              loadingLabel: l10n.pdfLoadingLabel,
              errorTitle: l10n.pdfOpenFailed,
            ),
          ),
        );
      },
    );
  }
}
