import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/admin_book.dart';
import '../../providers/admin_providers.dart';
import '../../providers/api_client.dart';
import '../../utils/api_error_message.dart';
import '../../widgets/stored_rich_text_view.dart';

class AdminBookDetailScreen extends ConsumerStatefulWidget {
  const AdminBookDetailScreen({
    super.key,
    required this.bookId,
    this.initialBook,
  });

  final String bookId;
  final AdminBook? initialBook;

  @override
  ConsumerState<AdminBookDetailScreen> createState() =>
      _AdminBookDetailScreenState();
}

class _AdminBookDetailScreenState extends ConsumerState<AdminBookDetailScreen> {
  AdminBook? _book;
  bool _loading = true;
  String? _error;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _book = widget.initialBook;
    if (_book != null) _loading = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_book == null && _loading) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final b = await fetchAdminBookByDio(
        ref.read(apiDioProvider),
        widget.bookId,
      );
      if (!mounted) return;
      setState(() {
        _book = b;
        _loading = false;
        if (b == null) {
          _error = AppLocalizations.of(context).bookNotFound;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _unpublish() async {
    setState(() => _actionBusy = true);
    try {
      final dio = ref.read(apiDioProvider);
      await dio.post<void>('admin/books/${widget.bookId}/unpublish');
      ref.invalidate(adminBooksProvider);
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            messageFromDioResponse(e.response?.data) ??
                e.message ??
                AppLocalizations.of(context).unpublishFailed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _showPublishDialog() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final d = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(d.publishLatestDraftTitle),
          content: Text(
            d.publishLatestDraftBody,
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(d.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(d.publish),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    setState(() => _actionBusy = true);
    try {
      final dio = ref.read(apiDioProvider);
      await dio.post<Map<String, dynamic>>(
        'admin/books/${widget.bookId}/publish',
      );
      ref.invalidate(adminBooksProvider);
      await _load();
      if (mounted) {
        final number = _book?.publishedRevisionNumber;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              number != null
                  ? AppLocalizations.of(context).publishedRevisionNumber(number)
                  : AppLocalizations.of(context).publishedLatestRevision,
            ),
          ),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            messageFromDioResponse(e.response?.data) ??
                publishErrorMessage(e) ??
                e.message ??
                AppLocalizations.of(context).publishFailed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final b = _book;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(b?.title ?? l10n.bookFallbackTitle),
        actions: [
          if (b != null)
            IconButton(
              tooltip: l10n.editMetadataTooltip,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _actionBusy
                  ? null
                  : () => context.push(
                        '/admin/books/${widget.bookId}/edit',
                        extra: b,
                      ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                )
              : b == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: b.isPublished
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.45)
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                b.isPublished
                                    ? Icons.verified_rounded
                                    : Icons.edit_note_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                b.isPublished
                                    ? l10n.publishedVisibleBanner
                                    : l10n.draftOnlyBanner,
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.visibilityTile),
                          subtitle: Text(b.catalogVisibility),
                        ),
                        if (b.authorCompiler != null &&
                            b.authorCompiler!.isNotEmpty)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.authorCompilerTile),
                            subtitle: Text(b.authorCompiler!),
                          ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.languageTile),
                          subtitle: Text(b.primaryLanguage),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.draftChaptersPagesTile),
                          subtitle: Text(
                            b.chaptersDraft.isEmpty
                                ? l10n.noDraftChapters
                                : l10n.draftChapterPageCounts(
                                    b.chaptersDraft.length,
                                    b.chaptersDraft.fold<int>(
                                      0,
                                      (sum, c) => sum + c.pages.length,
                                    ),
                                  ),
                          ),
                        ),
                        if (b.chaptersDraft.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: b.chaptersDraft
                                  .map(
                                    (c) => Chip(
                                      label: Text(
                                        '${c.title} (${c.pages.length})',
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        if (b.summary != null && b.summary!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l10n.summaryLabel),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: StoredRichTextView(raw: b.summary!),
                                ),
                              ],
                            ),
                          ),
                        if (b.publishedRevisionId != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.publishedRevisionTile),
                            subtitle: SelectableText(b.publishedRevisionId!),
                          ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: (_actionBusy || !b.isPublished)
                              ? null
                              : () => context.push('/book/${b.id}'),
                          icon: const Icon(Icons.menu_book_outlined),
                          label: Text(l10n.openInReader),
                        ),
                        if (!b.isPublished)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l10n.publishFirstToOpenReader,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _actionBusy ? null : _showPublishDialog,
                          icon: const Icon(Icons.publish_outlined),
                          label: Text(l10n.publishRevision),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: (_actionBusy || !b.isPublished)
                              ? null
                              : _unpublish,
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: Text(l10n.unpublish),
                        ),
                      ],
                    ),
    );
  }
}
