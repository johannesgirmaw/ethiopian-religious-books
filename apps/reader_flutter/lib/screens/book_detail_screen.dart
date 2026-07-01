import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_decorations.dart';
import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../models/download_job.dart';
import '../providers/catalog_providers.dart';
import '../providers/download_jobs_provider.dart';
import '../providers/payment_providers.dart';
import '../router/app_navigation.dart';
import '../utils/catalog_language_label.dart';
import '../utils/offline_book_download.dart';
import '../common/platform/platform_shell.dart';
import '../desktop/screens/book_detail_body.dart';
import '../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/book_detail_body.dart';
import '../web/widgets/shell/web_overlay_scaffold.dart';
import '../widgets/app_state_view.dart';
import '../widgets/book_reviews_section.dart';
import '../widgets/cover_badges.dart';
import '../widgets/premium_gate.dart';
import '../widgets/primitives/shell_primitives.dart';
import '../widgets/reference/book_detail_cover.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/stored_rich_text_view.dart';

class BookDetailScreen extends ConsumerWidget {
  const BookDetailScreen({super.key, required this.bookId});

  final String bookId;

  Future<void> _downloadSample(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.preparingDownload)),
    );
    final error = await runOfflineBookDownload(ref, bookId, l10n: l10n);
    if (!context.mounted) return;
    ref.invalidate(downloadJobsProvider);
    if (error == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.savedOfflineReading)),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  void _shareBook(BuildContext context, BookSummary book) {
    final l10n = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: book.title));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.bookSharedToClipboard)),
    );
  }

  String _statValue(int? value) => value == null ? '—' : '$value';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final asyncBook = ref.watch(bookDetailProvider(bookId));

    // Cold-open fallback: if this turns out to be a Bible book (e.g. deep link
    // opened before the catalog was cached), send it to the verse reader. The
    // /book/:id route redirect handles the common (catalog-loaded) case.
    final loadedBook = asyncBook.valueOrNull;
    if (loadedBook != null && loadedBook.isBible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/bible/book/$bookId');
      });
    }

    final contentAsync = ref.watch(bookContentProvider(bookId));
    final downloadJobs = ref.watch(downloadJobsProvider);
    DownloadJob? currentJob;
    final jobs = downloadJobs.valueOrNull;
    if (jobs != null) {
      for (final job in jobs.reversed) {
        if (job.bookId == bookId) {
          currentJob = job;
          break;
        }
      }
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
                title: l10n.bookDetailsTitle,
                currentLocation: GoRouterState.of(context).matchedLocation,
                appTitle: l10n.appTitle,
                actions: [
                  asyncBook.maybeWhen(
                    data: (book) => IconButton(
                      tooltip: l10n.shareBookTooltip,
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => _shareBook(context, book),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
                body: BookDetailBody(
                  bookId: bookId,
                  onShare: (book) => _shareBook(context, book),
                ),
              );
            }

            if (useDesktopShell(context)) {
              return DesktopOverlayScaffold(
                title: l10n.bookDetailsTitle,
                currentLocation: GoRouterState.of(context).matchedLocation,
                appTitle: l10n.appTitle,
                actions: [
                  asyncBook.maybeWhen(
                    data: (book) => IconButton(
                      tooltip: l10n.shareBookTooltip,
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => _shareBook(context, book),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
                body: DesktopBookDetailBody(
                  bookId: bookId,
                  onShare: (book) => _shareBook(context, book),
                ),
              );
            }

            return Scaffold(
        backgroundColor: AppColors.referencePageBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => popOverlayRoute(context),
          ),
          title: Text(l10n.bookDetailsTitle),
          backgroundColor: AppColors.referencePageBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          actions: [
            asyncBook.maybeWhen(
              data: (book) => IconButton(
                tooltip: l10n.shareBookTooltip,
                icon: const Icon(Icons.share_outlined),
                onPressed: () => _shareBook(context, book),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.line),
          ),
        ),
        body: asyncBook.when(
          data: (book) {
            final tree = contentAsync.valueOrNull;
            final chapterCount = tree?.chapters.length;
            final pageCount = tree?.totalPages;

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BookDetailCover(book: book),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _LanguagePill(
                                  label: catalogLanguageFilterLabel(
                                    book.primaryLanguage,
                                    l10n,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  book.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                      ),
                                ),
                                if (book.subtitle != null &&
                                    book.subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    book.subtitle!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                ],
                                if (book.authorCompiler != null &&
                                    book.authorCompiler!.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  GestureDetector(
                                    onTap: () => context.push(
                                      '/author/${Uri.encodeComponent(book.authorCompiler!.trim())}',
                                    ),
                                    behavior: HitTestBehavior.opaque,
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.person_outline_rounded,
                                          size: 15,
                                          color: AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            book.authorCompiler!,
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (book.requiresPurchase) ...[
                        const SizedBox(height: 16),
                        BookPriceLabel(book: book),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _BookDetailStatCard(
                            icon: Icons.menu_book_outlined,
                            value: _statValue(chapterCount),
                            label: l10n.bookStatChapters,
                          ),
                          const SizedBox(width: 10),
                          _BookDetailStatCard(
                            icon: Icons.description_outlined,
                            value: _statValue(
                              pageCount != null && pageCount > 0
                                  ? pageCount
                                  : null,
                            ),
                            label: l10n.bookStatPages,
                          ),
                          const SizedBox(width: 10),
                          _BookDetailStatCard(
                            icon: Icons.groups_outlined,
                            value: _statValue(
                              book.readersCount > 0 ? book.readersCount : null,
                            ),
                            label: l10n.bookStatReaders,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      AppSectionAccent(
                        label: l10n.summarySection.toUpperCase(),
                      ),
                      const SizedBox(height: 10),
                      AppPanel(
                        child: book.summary != null &&
                                book.summary!.isNotEmpty
                            ? StoredRichTextView(
                                raw: book.summaryRichRaw ?? book.summary!,
                              )
                            : Text(
                                l10n.noSummaryYet,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                      ),
                      if (currentJob != null) ...[
                        const SizedBox(height: 16),
                        _DownloadStatusCard(job: currentJob),
                      ],
                      const SizedBox(height: 22),
                      BookReviewsSection(bookId: bookId),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _downloadSample(context, ref),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceCard,
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppColors.line),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.cardV2),
                            ),
                          ),
                          icon: const Icon(Icons.download_outlined, size: 20),
                          label: Text(l10n.downloadOffline),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.referencePageBg,
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Builder(
                      builder: (context) {
                        final owned = ref
                                .watch(entitledBookIdsProvider)
                                .valueOrNull
                                ?.contains(bookId) ??
                            false;
                        final mustBuy = book.requiresPurchase && !owned;
                        return FilledButton.icon(
                          onPressed: () async {
                            if (await ensureBookUnlocked(context, ref, book) &&
                                context.mounted) {
                              context.push('/reader/$bookId?pickChapter=1');
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.referencePrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.cardV2),
                            ),
                          ),
                          icon: Icon(
                            mustBuy
                                ? Icons.shopping_cart_outlined
                                : Icons.menu_book_rounded,
                            size: 20,
                          ),
                          label: Text(mustBuy ? l10n.purchaseBook : l10n.readNow),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonCardGroup(count: 4),
          ),
          error: (e, _) {
            var title = l10n.unableToLoadBook;
            var message = l10n.bookLoadErrorMessage;
            if (e is DioException && e.response?.statusCode == 404) {
              title = l10n.bookNotInCatalogTitle;
              message = l10n.bookNotInCatalogMessage;
            }
            return AppStateView(
              title: title,
              message: message,
              icon: Icons.menu_book_outlined,
              actionLabel: l10n.goBack,
              onAction: () => popOverlayRoute(context),
            );
          },
        ),
      );
          },
        ),
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.referencePrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.referencePrimary,
        ),
      ),
    );
  }
}

class _BookDetailStatCard extends StatelessWidget {
  const _BookDetailStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: AppDecorations.listRow(),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.referencePrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: AppColors.referencePrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadStatusCard extends StatelessWidget {
  const _DownloadStatusCard({required this.job});

  final DownloadJob job;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isOk = job.state == 'completed';
    final isFail = job.state == 'failed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isOk
            ? AppColors.successSurface
            : isFail
                ? AppColors.errorSurface
                : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isOk
              ? AppColors.successBorder
              : isFail
                  ? AppColors.errorBorder
                  : AppColors.line,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOk
                ? Icons.check_circle_outline_rounded
                : isFail
                    ? Icons.error_outline_rounded
                    : Icons.downloading_rounded,
            size: 20,
            color: isOk
                ? AppColors.successText
                : isFail
                    ? AppColors.errorText
                    : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              job.state == 'failed'
                  ? displayDownloadJobError(job.errorMessage, l10n)
                  : (job.errorMessage ?? job.state),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
