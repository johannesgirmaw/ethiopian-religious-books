import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/bible_models.dart';
import '../../providers/bible_providers.dart';

/// Tap target navigated to from any Bible search result.
typedef BibleVerseTap = void Function(String bookId, int chapter, {int? verse});

/// All / Old Testament / New Testament scope selector.
class BibleScopeChips extends StatelessWidget {
  const BibleScopeChips({super.key, required this.scope, required this.onChanged});

  final String scope; // "" | "old" | "new"
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget chip(String value, String label) {
      final selected = scope == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: AppColors.primary.withValues(alpha: 0.14),
          backgroundColor: AppColors.surfaceCard,
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.primaryDeep : AppColors.textSecondary,
          ),
          onSelected: (_) => onChanged(value),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('', l10n.bibleSearchScopeAll),
          chip('old', l10n.bibleOldTestament),
          chip('new', l10n.bibleNewTestament),
        ],
      ),
    );
  }
}

/// Results for a Bible query: a reference-jump tile (when the query resolves to
class BibleSearchResultsView extends ConsumerWidget {
  const BibleSearchResultsView({
    super.key,
    required this.query,
    required this.scope,
    required this.onTap,
  });

  final String query;
  final String scope;
  final BibleVerseTap onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final q = query.trim();
    if (q.length < 2) {
      return Center(
        child: Text(
          l10n.bibleSearchHint,
          style: const TextStyle(color: AppColors.textTertiary),
        ),
      );
    }
    final referenceAsync = ref.watch(bibleReferenceProvider(q));
    final searchAsync = ref.watch(bibleSearchProvider((query: q, scope: scope)));

    final reference = referenceAsync.valueOrNull;
    final search = searchAsync.valueOrNull;

    if (searchAsync.isLoading && reference == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final hits = search?.items ?? const <BibleSearchHit>[];
    if (reference == null && hits.isEmpty && !searchAsync.isLoading) {
      return Center(child: Text(l10n.bibleNoResults));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (reference != null && reference.verses.isNotEmpty)
          _ReferenceJumpTile(reference: reference, onTap: onTap),
        if (search != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l10n.bibleResultsCount(search.total),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ),
          for (final hit in hits)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SearchHitTile(hit: hit, onTap: onTap),
            ),
        ],
      ],
    );
  }
}

class _ReferenceJumpTile extends StatelessWidget {
  const _ReferenceJumpTile({required this.reference, required this.onTap});

  final BibleReference reference;
  final BibleVerseTap onTap;

  @override
  Widget build(BuildContext context) {
    final v = reference.verses.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: () => onTap(reference.book.id, reference.chapter, verse: v.verse),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded,
                    size: 18, color: AppColors.primaryDeep),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${reference.book.title} ${reference.chapter}:${v.verse}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDeep,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        v.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchHitTile extends StatelessWidget {
  const _SearchHitTile({required this.hit, required this.onTap});

  final BibleSearchHit hit;
  final BibleVerseTap onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceCard,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: () => onTap(hit.bookId, hit.chapter, verse: hit.verse),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${hit.bookTitle} ${hit.chapter}:${hit.verse}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDeep,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hit.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen advanced search (reference + verse) used from the reader's
/// search action. Carries a testament scope selector.
class BibleSearchDelegate extends SearchDelegate<void> {
  BibleSearchDelegate({required this.onPick, String? hint})
      : super(searchFieldLabel: hint);

  /// Called with the chosen verse; the delegate is responsible for closing.
  final void Function(BuildContext context, String bookId, int chapter, int? verse)
      onPick;

  @override
  List<Widget> buildActions(BuildContext context) => [
        if (query.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => query = '',
          ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _DelegateBody(this);

  @override
  Widget buildSuggestions(BuildContext context) => _DelegateBody(this);
}

class _DelegateBody extends StatefulWidget {
  const _DelegateBody(this.delegate);

  final BibleSearchDelegate delegate;

  @override
  State<_DelegateBody> createState() => _DelegateBodyState();
}

class _DelegateBodyState extends State<_DelegateBody> {
  String _scope = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: BibleScopeChips(
            scope: _scope,
            onChanged: (s) => setState(() => _scope = s),
          ),
        ),
        Expanded(
          child: BibleSearchResultsView(
            query: widget.delegate.query,
            scope: _scope,
            onTap: (bookId, chapter, {verse}) =>
                widget.delegate.onPick(context, bookId, chapter, verse),
          ),
        ),
      ],
    );
  }
}
