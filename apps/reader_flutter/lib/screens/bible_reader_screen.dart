import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/bible_models.dart';
import '../providers/bible_providers.dart';
import '../providers/number_system_provider.dart';
import '../utils/geez_numerals.dart';
import '../widgets/app_state_view.dart';
import '../widgets/bible/bible_search.dart';

/// Full-screen Bible chapter reader: section headings + numbered verses, with
/// chapter navigation and an optional highlighted verse (from search/reference).
class BibleReaderScreen extends ConsumerStatefulWidget {
  const BibleReaderScreen({
    super.key,
    required this.bookId,
    this.initialChapter = 1,
    this.highlightVerse,
  });

  final String bookId;
  final int initialChapter;
  final int? highlightVerse;

  @override
  ConsumerState<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends ConsumerState<BibleReaderScreen> {
  late int _chapter = widget.initialChapter < 1 ? 1 : widget.initialChapter;
  late int? _highlight = widget.highlightVerse;
  bool _sidebarOpen = true;

  // Wide screens (web / desktop) get the collapsible chapter rail.
  static const _wideBreakpoint = 840.0;

  void _goChapter(int chapter) {
    setState(() {
      _chapter = chapter;
      _highlight = null; // moving chapters clears a prior verse highlight
    });
  }

  void _exit() => context.go('/bible');

  void _openSearch() {
    final l10n = AppLocalizations.of(context);
    showSearch<void>(
      context: context,
      delegate: BibleSearchDelegate(
        hint: l10n.bibleSearch,
        onPick: (ctx, bookId, chapter, verse) {
          Navigator.of(ctx).pop(); // close the search overlay
          if (bookId == widget.bookId) {
            setState(() {
              _chapter = chapter;
              _highlight = verse;
            });
          } else {
            final uri = Uri(
              path: '/bible/book/$bookId',
              queryParameters: {
                'chapter': '$chapter',
                if (verse != null) 'verse': '$verse',
              },
            );
            context.go(uri.toString());
          }
        },
      ),
    );
  }

  Future<void> _pickChapter(int chapterCount) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => _ChapterPickerSheet(
        count: chapterCount,
        current: _chapter,
        geez: ref.read(useGeezNumeralsProvider),
      ),
    );
    if (picked != null) _goChapter(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final indexAsync = ref.watch(bibleBookIndexProvider(widget.bookId));
    final chapterCount = indexAsync.valueOrNull?.chapters.length ?? 0;
    final chapterAsync = ref.watch(
      bibleChapterProvider((bookId: widget.bookId, chapter: _chapter)),
    );

    final bookTitle =
        chapterAsync.valueOrNull?.book.title ??
        indexAsync.valueOrNull?.book.title ??
        l10n.bibleTitle;

    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final hasChapters = chapterCount > 0;
    final geez = ref.watch(useGeezNumeralsProvider);

    final content = SafeArea(
      child: chapterAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppStateView(
          title: l10n.bibleNoResults,
          message: '$e',
          icon: Icons.menu_book_outlined,
          actionLabel: l10n.retry,
          onAction: () => ref.invalidate(
            bibleChapterProvider((bookId: widget.bookId, chapter: _chapter)),
          ),
        ),
        data: (chapter) => _ChapterView(
          chapter: chapter,
          highlightVerse: _highlight,
          geez: geez,
        ),
      ),
    );

    final back = IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: _exit,
    );
    final railToggle = IconButton(
      tooltip: l10n.bibleChapters,
      icon: Icon(_sidebarOpen ? Icons.menu_open_rounded : Icons.menu_rounded),
      onPressed: () => setState(() => _sidebarOpen = !_sidebarOpen),
    );
    final showRailToggle = wide && hasChapters;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showRailToggle ? 96 : null,
        leading: showRailToggle
            ? Row(mainAxisSize: MainAxisSize.min, children: [back, railToggle])
            : back,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bookTitle, style: const TextStyle(fontSize: 16)),
            Text(
              '${l10n.bibleChapter} ${formatNumber(_chapter, geez: geez)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.bibleSearch,
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
          if (!showRailToggle)
            IconButton(
              tooltip: l10n.bibleChapters,
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: hasChapters ? () => _pickChapter(chapterCount) : null,
            ),
        ],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: AppMotion.short,
                  curve: Curves.easeInOut,
                  child: (_sidebarOpen && hasChapters)
                      ? _ChapterSidebar(
                          count: chapterCount,
                          current: _chapter,
                          geez: geez,
                          onSelect: _goChapter,
                          onCollapse: () =>
                              setState(() => _sidebarOpen = false),
                        )
                      : const SizedBox(width: 0, height: double.infinity),
                ),
                Expanded(child: content),
              ],
            )
          : content,
      bottomNavigationBar: _ChapterNavBar(
        chapter: _chapter,
        chapterCount: chapterCount,
        geez: geez,
        onPrev: _chapter > 1 ? () => _goChapter(_chapter - 1) : null,
        onNext: (chapterCount == 0 || _chapter < chapterCount)
            ? () => _goChapter(_chapter + 1)
            : null,
      ),
    );
  }
}

class _ChapterView extends StatelessWidget {
  const _ChapterView({
    required this.chapter,
    required this.geez,
    this.highlightVerse,
  });

  final BibleChapter chapter;
  final bool geez;
  final int? highlightVerse;

  @override
  Widget build(BuildContext context) {
    // Build a flat list: a heading widget whenever the section changes, then
    // each verse.
    final children = <Widget>[];
    int? lastSection;
    for (final v in chapter.verses) {
      if (v.sectionOrdinal != lastSection) {
        lastSection = v.sectionOrdinal;
        final heading = v.sectionOrdinal == null
            ? null
            : chapter.headingForSeq(v.sectionOrdinal!);
        if (heading != null && heading.isNotEmpty) {
          children.add(
            Padding(
              padding: EdgeInsets.only(
                top: children.isEmpty ? 0 : 20,
                bottom: 8,
              ),
              child: Text(
                heading,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDeep,
                  height: 1.3,
                ),
              ),
            ),
          );
        }
      }
      children.add(
        _VerseRow(verse: v, geez: geez, highlight: v.verse == highlightVerse),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _VerseRow extends StatelessWidget {
  const _VerseRow({
    required this.verse,
    required this.geez,
    this.highlight = false,
  });

  final BibleVerse verse;
  final bool geez;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: highlight
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : EdgeInsets.zero,
      decoration: highlight
          ? BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            )
          : null,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${formatNumber(verse.verse, geez: geez)} ',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            TextSpan(
              text: verse.text,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChapterNavBar extends StatelessWidget {
  const _ChapterNavBar({
    required this.chapter,
    required this.chapterCount,
    required this.geez,
    required this.onPrev,
    required this.onNext,
  });

  final int chapter;
  final int chapterCount;
  final bool geez;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 56,
        decoration: const BoxDecoration(
          color: AppColors.surfaceCard,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: onPrev,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Prev'),
              ),
            ),
            Text(
              chapterCount > 0
                  ? '${formatNumber(chapter, geez: geez)} / ${formatNumber(chapterCount, geez: geez)}'
                  : formatNumber(chapter, geez: geez),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Collapsible chapter rail for wide (web / desktop) layouts.
class _ChapterSidebar extends StatelessWidget {
  const _ChapterSidebar({
    required this.count,
    required this.current,
    required this.geez,
    required this.onSelect,
    required this.onCollapse,
  });

  final int count;
  final int current;
  final bool geez;
  final ValueChanged<int> onSelect;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.bibleChapters,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.chevron_left, size: 20),
                  visualDensity: VisualDensity.compact,
                  onPressed: onCollapse,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.2,
              ),
              itemCount: count,
              itemBuilder: (context, i) {
                final n = i + 1;
                final selected = n == current;
                return Material(
                  color: selected ? AppColors.primary : AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: InkWell(
                    onTap: () => onSelect(n),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Center(
                      child: Text(
                        formatNumber(n, geez: geez),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapterPickerSheet extends StatelessWidget {
  const _ChapterPickerSheet({
    required this.count,
    required this.current,
    required this.geez,
  });

  final int count;
  final int current;
  final bool geez;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 6,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.2,
          ),
          itemCount: count,
          itemBuilder: (context, i) {
            final n = i + 1;
            final selected = n == current;
            return Material(
              color: selected ? AppColors.primary : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(n),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Center(
                  child: Text(
                    formatNumber(n, geez: geez),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
