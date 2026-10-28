import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../design/app_tokens.dart';
import '../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../providers/catalog_providers.dart';
import '../router/app_navigation.dart';
import '../utils/api_error_message.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_overlay_scaffold.dart';
import '../widgets/app_state_view.dart';
import '../widgets/pdf_document_reader.dart';
import '../widgets/protected_content_scope.dart';

/// Look Inside sample reader — no purchase gate; uses the preview PDF only.
class PdfPreviewScreen extends ConsumerWidget {
  const PdfPreviewScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncBook = ref.watch(bookDetailProvider(bookId));
    final title = asyncBook.valueOrNull?.title ?? l10n.lookInsideTitle;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.lookInsideBanner(
                      asyncBook.valueOrNull?.previewPageCount ?? 0,
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/payment/$bookId'),
                  child: Text(l10n.purchaseBook),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _PdfPreviewBody(bookId: bookId)),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leaveReaderToBookDetail(context, bookId);
      },
      child: AppLayoutScopeBuilder(
        child: Builder(
          builder: (context) {
            if (useWebShell(context)) {
              return WebOverlayScaffold(
                title: title,
                currentLocation: GoRouterState.of(context).matchedLocation,
                onBack: () => leaveReaderToBookDetail(context, bookId),
                body: body,
              );
            }
            if (useDesktopShell(context)) {
              return DesktopOverlayScaffold(
                title: title,
                currentLocation: GoRouterState.of(context).matchedLocation,
                onBack: () => leaveReaderToBookDetail(context, bookId),
                body: body,
              );
            }
            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => leaveReaderToBookDetail(context, bookId),
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

class _PdfPreviewBody extends ConsumerWidget {
  const _PdfPreviewBody({required this.bookId});

  final String bookId;

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
    final asyncSource = ref.watch(pdfPreviewViewerSourceProvider(bookId));
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
        if (!book.isPdf || !book.hasPreview) {
          return AppStateView(
            icon: Icons.menu_book_outlined,
            title: l10n.lookInsideUnavailable,
            message: l10n.lookInsideUnavailable,
            actionLabel: l10n.goBack,
            onAction: () => leaveReaderToBookDetail(context, bookId),
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
            onAction: () {
              ref.invalidate(pdfPreviewAccessProvider(bookId));
              ref.invalidate(pdfPreviewViewerSourceProvider(bookId));
            },
          ),
          data: (source) {
            final reader = PdfDocumentReader(
              bookId: bookId,
              bookTitle: book.title,
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
                ref.invalidate(pdfPreviewAccessProvider(bookId));
                ref.invalidate(pdfPreviewViewerSourceProvider(bookId));
              },
            );
            return ContentProtectionLifecycle(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  dense ? 4 : 8,
                  0,
                  dense ? 4 : 8,
                  dense ? 4 : 8,
                ),
                child: reader,
              ),
            );
          },
        );
      },
    );
  }
}
