import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/bible_models.dart';
import '../../providers/bible_providers.dart';
import '../app_state_view.dart';
import 'bible_search.dart';

/// Book picker + verse/reference search. Shared across platforms; the platform
/// adapters wrap it in their page scaffold.
class BibleBooksBody extends ConsumerStatefulWidget {
  const BibleBooksBody({super.key});

  @override
  ConsumerState<BibleBooksBody> createState() => _BibleBooksBodyState();
}

class _BibleBooksBodyState extends ConsumerState<BibleBooksBody> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _testament = 'old';
  String _scope = ''; // search testament scope: "" | "old" | "new"

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openChapter(String bookId, int chapter, {int? verse}) {
    final q = <String, String>{
      'chapter': '$chapter',
      if (verse != null) 'verse': '$verse',
    };
    final uri = Uri(path: '/bible/book/$bookId', queryParameters: q);
    context.go(uri.toString());
  }

  /// Try resolving the query as a reference and jump; else stay on search.
  Future<void> _onSubmit() async {
    final q = _query.trim();
    if (q.isEmpty) return;
    final resolved = await ref.read(bibleRepositoryProvider).resolveReference(q);
    if (!mounted || resolved == null) return;
    _openChapter(resolved.book.id, resolved.chapter, verse: resolved.firstVerse);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            onSubmitted: (_) => _onSubmit(),
            decoration: InputDecoration(
              hintText: l10n.bibleSearchHint,
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: AppColors.surfaceCard,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
        ),
        if (_query.trim().length >= 2) ...[
          BibleScopeChips(
            scope: _scope,
            onChanged: (s) => setState(() => _scope = s),
          ),
          Expanded(
            child: BibleSearchResultsView(
              query: _query.trim(),
              scope: _scope,
              onTap: _openChapter,
            ),
          ),
        ] else ...[
          _TestamentTabs(
            value: _testament,
            onChanged: (t) => setState(() => _testament = t),
          ),
          Expanded(child: _BookGrid(testament: _testament, onTap: _openChapter)),
        ],
      ],
    );
  }
}

class _TestamentTabs extends StatelessWidget {
  const _TestamentTabs({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget tab(String key, String label) {
      final selected = key == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(key),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppColors.primary : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primaryDeep : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          tab('old', l10n.bibleOldTestament),
          tab('new', l10n.bibleNewTestament),
        ],
      ),
    );
  }
}

class _BookGrid extends ConsumerWidget {
  const _BookGrid({required this.testament, required this.onTap});

  final String testament;
  final void Function(String bookId, int chapter, {int? verse}) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(bibleBooksProvider(testament));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => AppStateView(
        title: l10n.bibleNoResults,
        message: '$e',
        icon: Icons.menu_book_outlined,
        actionLabel: l10n.retry,
        onAction: () => ref.invalidate(bibleBooksProvider(testament)),
      ),
      data: (books) {
        return LayoutBuilder(
          builder: (context, c) {
            final cols = (c.maxWidth ~/ 200).clamp(2, 6);
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.6,
              ),
              itemCount: books.length,
              itemBuilder: (context, i) =>
                  _BookCard(book: books[i], onTap: () => onTap(books[i].id, 1)),
            );
          },
        );
      },
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book, required this.onTap});

  final BibleBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${book.canonicalNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDeep,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (book.nameEn.isNotEmpty)
                      Text(
                        book.nameEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

