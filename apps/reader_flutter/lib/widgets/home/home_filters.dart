import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/book_models.dart';
import '../../providers/catalog_providers.dart';
import '../../utils/catalog_language_label.dart';

/// Sort modes for the home "Explore" grid (shared across platforms).
enum HomeSort { titleAz, newest, oldest, popular, topRated }

String homeSortLabel(AppLocalizations l10n, HomeSort m) => switch (m) {
      HomeSort.titleAz => l10n.sortTitleAz,
      HomeSort.newest => l10n.sortNewest,
      HomeSort.oldest => l10n.sortOldest,
      HomeSort.popular => l10n.sortPopular,
      HomeSort.topRated => l10n.sortTopRated,
    };

/// Sorts [list] in place according to [sort].
void applyHomeSort(List<BookSummary> list, HomeSort sort) {
  int byDate(BookSummary a, BookSummary b) =>
      (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0));
  double pop(BookSummary b) =>
      b.readersCount + b.ratingAverage * b.ratingCount * 2;
  switch (sort) {
    case HomeSort.titleAz:
      list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    case HomeSort.newest:
      list.sort((a, b) => byDate(b, a));
    case HomeSort.oldest:
      list.sort(byDate);
    case HomeSort.popular:
      list.sort((a, b) => pop(b).compareTo(pop(a)));
    case HomeSort.topRated:
      list.sort((a, b) => b.ratingAverage.compareTo(a.ratingAverage));
  }
}

/// Distinct genres present in [books], ordered by [lookup], labelled from it;
/// any legacy slug not in the lookup is appended.
List<GenreOption> genreOptionsFor(
  List<BookSummary> books,
  List<GenreOption> lookup,
) {
  final present = <String>{
    for (final b in books) (b.genre ?? '').trim(),
  }..removeWhere((s) => s.isEmpty);
  final bySlug = {for (final g in lookup) g.slug: g};
  final options = <GenreOption>[
    for (final g in lookup)
      if (present.contains(g.slug)) g,
  ];
  for (final s in present) {
    if (!bySlug.containsKey(s)) options.add(GenreOption(slug: s, label: s));
  }
  return options;
}

/// Distinct languages present in [books] as (key, label) pairs.
List<({String key, String label})> languageOptionsFor(
  List<BookSummary> books,
  AppLocalizations l10n,
) {
  final seen = <String, String>{};
  for (final b in books) {
    final k = catalogLanguageFilterKey(b.primaryLanguage, l10n);
    seen.putIfAbsent(
      k,
      () => catalogLanguageFilterLabel(b.primaryLanguage, l10n),
    );
  }
  final list = seen.entries.map((e) => (key: e.key, label: e.value)).toList();
  list.sort((a, b) => a.label.compareTo(b.label));
  return list;
}

bool bookMatchesLanguage(
  BookSummary book,
  String? languageKey,
  AppLocalizations l10n,
) {
  if (languageKey == null) return true;
  return catalogLanguageFilterKey(book.primaryLanguage, l10n) == languageKey;
}

/// Bottom-sheet with Language + Sort filters (mirrors the mobile home sheet).
Future<void> showHomeFilterSheet({
  required BuildContext context,
  required AppLocalizations l10n,
  required List<({String key, String label})> languages,
  required String? selectedLanguage,
  required HomeSort selectedSort,
  required ValueChanged<String?> onLanguage,
  required ValueChanged<HomeSort> onSort,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) => SafeArea(
      child: StatefulBuilder(
        builder: (context, setSheet) {
          Widget header(String text) => Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.3,
                ),
              );
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (languages.length > 1) ...[
                    header(l10n.languagesMetric),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SheetChip(
                          label: l10n.filterAll,
                          active: selectedLanguage == null,
                          onTap: () {
                            onLanguage(null);
                            setSheet(() => selectedLanguage = null);
                          },
                        ),
                        for (final lang in languages)
                          _SheetChip(
                            label: lang.label,
                            active: selectedLanguage == lang.key,
                            onTap: () {
                              onLanguage(lang.key);
                              setSheet(() => selectedLanguage = lang.key);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                  header(l10n.sortLabel),
                  const SizedBox(height: 4),
                  for (final m in HomeSort.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(homeSortLabel(l10n, m)),
                      trailing: selectedSort == m
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.primary)
                          : null,
                      onTap: () {
                        onSort(m);
                        setSheet(() => selectedSort = m);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: active ? AppColors.primary : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
