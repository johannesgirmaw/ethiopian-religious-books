import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/api_client.dart';
import '../providers/catalog_providers.dart';
import '../providers/continue_reading_provider.dart';
import '../providers/study_providers.dart';
import '../storage/book_content_cache_storage.dart';
import '../storage/reader_prefs_storage.dart';
import '../utils/rich_text_codec.dart' show plainTextFromStoredSummary;
import '../widgets/stored_rich_text_view.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
    this.initialChapterKey,
    this.initialPageNumber,
  });

  final String bookId;
  final String? initialChapterKey;
  final int? initialPageNumber;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final ScrollController _scrollController = ScrollController();
  bool _showChrome = true;
  bool _autoHideEnabled = true;
  double _progress = 0;
  double _fontSize = 18;
  String _mode = 'light';
  List<ReaderBookmark> _bookmarks = const [];
  final TextEditingController _findController = TextEditingController();
  String _findQuery = '';
  List<String> _matchedLocations = const [];
  List<BookSearchHit> _searchHits = const [];
  int _activeMatchPointer = -1;
  String? _selectedChapterKey;
  int? _selectedPageNumber;
  List<_ReaderSection> _allSections = const [];
  List<_ReaderSection> _renderedSections = const [];
  bool _remoteProgressApplied = false;
  Timer? _progressSyncTimer;
  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _selectedChapterKey = widget.initialChapterKey;
    _selectedPageNumber = widget.initialPageNumber;
    _restoreReaderState();
    _scrollController.addListener(_onScroll);
    _scheduleAutoHide();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordLastOpened());
  }

  Future<void> _recordLastOpened() async {
    try {
      final book = await ref.read(bookDetailProvider(widget.bookId).future);
      await ReaderPrefsStorage.writeLastOpenedBook(
        LastOpenedBook(
          bookId: widget.bookId,
          title: book.title,
          updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      ref.invalidate(lastOpenedBookProvider);
    } catch (_) {
      await ReaderPrefsStorage.writeLastOpenedBook(
        LastOpenedBook(
          bookId: widget.bookId,
          title: widget.bookId,
          updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  Future<void> _restoreReaderState() async {
    final restoredProgress =
        await ReaderPrefsStorage.readProgress(widget.bookId);
    final restoredFont = await ReaderPrefsStorage.readFontSize(widget.bookId);
    final restoredMode = await ReaderPrefsStorage.readThemeMode(widget.bookId);
    final restoredBookmarks =
        await ReaderPrefsStorage.readBookmarks(widget.bookId);
    if (!mounted) return;
    setState(() {
      _progress = restoredProgress;
      _fontSize = restoredFont;
      _mode = restoredMode;
      _bookmarks = restoredBookmarks;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(max * _progress.clamp(0, 1));
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) return;
    final progress = (_scrollController.offset / max).clamp(0, 1).toDouble();
    if ((progress - _progress).abs() >= 0.01) {
      setState(() => _progress = progress);
      ReaderPrefsStorage.writeProgress(widget.bookId, progress);
      _scheduleCloudProgressSync();
    }
  }

  void _scheduleCloudProgressSync() {
    _progressSyncTimer?.cancel();
    _progressSyncTimer = Timer(const Duration(milliseconds: 900), () {
      final section = _currentSectionFromProgress();
      saveReadingProgress(
        ref,
        widget.bookId,
        chapterKey: section?.chapterKey ?? (_selectedChapterKey ?? ''),
        pageNumber: section?.pageNumber ?? _selectedPageNumber,
        progressPercent: (_progress * 100).round(),
      );
    });
  }

  _ReaderSection? _currentSectionFromProgress() {
    if (_renderedSections.isEmpty) return null;
    final index = (_progress.clamp(0, 1) * (_renderedSections.length - 1))
        .round()
        .clamp(0, _renderedSections.length - 1);
    return _renderedSections[index];
  }

  void _scheduleAutoHide() {
    if (!_autoHideEnabled) return;
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showChrome = false);
    });
  }

  void _toggleChrome() {
    setState(() => _showChrome = !_showChrome);
    if (_showChrome) _scheduleAutoHide();
  }

  Future<void> _toggleBookmark() async {
    final label = l10n.bookmarkSavedAt((_progress * 100).round());
    final existing = _bookmarks.any(
      (b) => (b.progress - _progress).abs() < 0.02,
    );
    final next = existing
        ? _bookmarks
            .where((b) => (b.progress - _progress).abs() >= 0.02)
            .toList()
        : [
            ReaderBookmark(
              progress: _progress,
              label: label,
              snippet: _currentSectionLabel(),
              savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
            ),
            ..._bookmarks,
          ];
    setState(() => _bookmarks = next);
    await ReaderPrefsStorage.writeBookmarks(widget.bookId, next);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing ? l10n.bookmarkRemoved : l10n.bookmarkSaved),
      ),
    );
    if (!existing) {
      final section = _currentSectionFromProgress();
      unawaited(
        trackReaderEvent(
          ref,
          bookId: widget.bookId,
          eventName: 'bookmark_add',
          chapterKey: section?.chapterKey,
          pageNumber: section?.pageNumber,
          payload: {'progress_percent': (_progress * 100).round()},
        ),
      );
    }
  }

  Future<void> _openBookmarksSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        if (_bookmarks.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(l10n.noBookmarksYet),
            ),
          );
        }
        return SafeArea(
          child: ListView.builder(
            itemCount: _bookmarks.length,
            itemBuilder: (context, index) {
              final b = _bookmarks[index];
              return ListTile(
                leading: const Icon(Icons.bookmark_outline_rounded),
                title: Text(b.label),
                subtitle: Text(
                  '${(b.progress * 100).round()}% · ${b.snippet?.trim().isNotEmpty == true ? b.snippet : l10n.savedLocation}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: l10n.removeTooltip,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    final next = [..._bookmarks]..removeAt(index);
                    setState(() => _bookmarks = next);
                    await ReaderPrefsStorage.writeBookmarks(widget.bookId, next);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  if (!_scrollController.hasClients) return;
                  final max = _scrollController.position.maxScrollExtent;
                  _scrollController.animateTo(
                    max * b.progress,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _openTocSheet(
    String title,
    List<_ReaderSection> sections,
    BookContentTree? tree,
  ) async {
    if (tree == null || tree.chapters.isEmpty) return;
    BookContentChapter? selectedChapter;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: selectedChapter == null
                    ? null
                    : IconButton(
                        onPressed: () => setSheetState(() => selectedChapter = null),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                title: Text(
                  selectedChapter?.title ?? title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  selectedChapter == null
                      ? l10n.selectChapter
                      : l10n.selectPage,
                ),
              ),
              const Divider(height: 1),
              if (selectedChapter == null)
                ...tree.chapters.map(
                  (chapter) => ListTile(
                    leading: const Icon(Icons.menu_book_rounded),
                    title: Text(chapter.title),
                    subtitle: Text(l10n.pageCount(chapter.pages.length)),
                    onTap: () => setSheetState(() => selectedChapter = chapter),
                  ),
                )
              else
                ...selectedChapter!.pages.map(
                  (page) => ListTile(
                    leading: const Icon(Icons.article_outlined),
                    title: Text(l10n.pageNumberTitle(page.pageNumber)),
                    subtitle: Text(
                      page.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _selectedChapterKey = selectedChapter!.chapterKey;
                        _selectedPageNumber = page.pageNumber;
                      });
                      _jumpToChapterAndPage(
                        sections,
                        chapterKey: selectedChapter!.chapterKey,
                        pageNumber: page.pageNumber,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _currentSectionLabel() {
    if (!_scrollController.hasClients) return l10n.readerPosition;
    return l10n.readingPosition;
  }

  GlobalKey _sectionKeyFor(int index) {
    return _sectionKeys.putIfAbsent(
      index,
      () => GlobalKey(debugLabel: 'reader-section-$index'),
    );
  }

  void _pruneSectionKeys(int sectionCount) {
    final stale = _sectionKeys.keys.where((k) => k >= sectionCount).toList();
    for (final key in stale) {
      _sectionKeys.remove(key);
    }
  }

  String _locationId(String chapterKey, int pageNumber) {
    return '$chapterKey::$pageNumber';
  }

  void _jumpToSection(int index) {
    final sectionKey = _sectionKeys[index];
    if (sectionKey == null) return;
    final sectionContext = sectionKey.currentContext;
    if (sectionContext == null || !_scrollController.hasClients) return;
    final box = sectionContext.findRenderObject() as RenderBox?;
    final listBox = context.findRenderObject() as RenderBox?;
    if (box == null || listBox == null) return;
    final offset = box.localToGlobal(Offset.zero, ancestor: listBox).dy;
    final target = (_scrollController.offset + offset - 84).clamp(
      0,
      _scrollController.position.maxScrollExtent,
    ).toDouble();
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _returnToChapters() {
    setState(() {
      _selectedChapterKey = null;
      _selectedPageNumber = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickChapter(List<BookContentChapter> chapters) async {
    if (chapters.isEmpty) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          children: chapters
              .map(
                (c) => ListTile(
                  title: Text(c.title),
                  subtitle: Text(c.chapterKey),
                  trailing: _selectedChapterKey == c.chapterKey
                      ? const Icon(Icons.check_circle_outline_rounded)
                      : null,
                  onTap: () => Navigator.of(context).pop(c.chapterKey),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected == null) return;
    setState(() {
      _selectedChapterKey = selected;
      _selectedPageNumber = null;
    });
    _jumpToChapterAndPage(_renderedSections, chapterKey: selected);
    unawaited(
      trackReaderEvent(
        ref,
        bookId: widget.bookId,
        eventName: 'chapter_open',
        chapterKey: selected,
      ),
    );
  }

  Future<void> _pickPage() async {
    final hasSelectedChapter =
        _selectedChapterKey != null && _selectedChapterKey!.isNotEmpty;
    if (_renderedSections.isEmpty && _allSections.isEmpty) return;
    var allChapters = !hasSelectedChapter;
    final selected = await showModalBottomSheet<_ReaderSection>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final pageScope = allChapters ? _allSections : _renderedSections;
          return SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: pageScope.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    title: Text(l10n.choosePage),
                    subtitle: Text(l10n.jumpToPageSubtitle),
                  );
                }
                if (index == 1) {
                  return SwitchListTile(
                    value: allChapters,
                    onChanged: hasSelectedChapter
                        ? (value) => setSheetState(() => allChapters = value)
                        : null,
                    title: Text(l10n.allChapters),
                    subtitle: Text(
                      hasSelectedChapter
                          ? l10n.searchPagesWholeBook
                          : l10n.noChapterSelected,
                    ),
                  );
                }
                final p = pageScope[index - 2];
                return ListTile(
                  title: Text(l10n.pageNumberTitle(p.pageNumber)),
                  subtitle: Text(
                    allChapters ? '${p.chapterTitle} · ${p.title}' : p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop(p),
                );
              },
            ),
          );
        },
      ),
    );
    if (selected != null && selected.pageNumber > 0) {
      setState(() {
        _selectedChapterKey = selected.chapterKey;
        _selectedPageNumber = selected.pageNumber;
      });
      _jumpToChapterAndPage(
        _renderedSections,
        chapterKey: selected.chapterKey,
        pageNumber: selected.pageNumber,
      );
      unawaited(
        trackReaderEvent(
          ref,
          bookId: widget.bookId,
          eventName: 'page_jump',
          chapterKey: selected.chapterKey,
          pageNumber: selected.pageNumber,
        ),
      );
    }
  }

  Future<void> _runServerSearch(String query, {required bool allChapters}) async {
    final hits = await ref.read(
      bookSearchProvider(
        BookSearchFilters(
          bookId: widget.bookId,
          query: query,
          chapter: allChapters ? null : _selectedChapterKey,
          page: allChapters ? null : _selectedPageNumber,
        ),
      ).future,
    );
    if (!mounted) return;
    setState(() {
      _searchHits = hits;
      _matchedLocations = hits
          .map((h) => _locationId(h.chapterKey, h.pageNumber))
          .toList();
      _activeMatchPointer = hits.isEmpty ? -1 : 0;
    });
    unawaited(
      trackReaderEvent(
        ref,
        bookId: widget.bookId,
        eventName: 'search_query',
        chapterKey: allChapters ? '' : _selectedChapterKey,
        pageNumber: allChapters ? null : _selectedPageNumber,
        payload: {'query': query, 'scope': allChapters ? 'all' : 'chapter'},
      ),
    );
  }

  void _jumpToChapterAndPage(
    List<_ReaderSection> sections, {
    String? chapterKey,
    int? pageNumber,
  }) {
    if (chapterKey != null &&
        chapterKey.isNotEmpty &&
        chapterKey != _selectedChapterKey) {
      setState(() {
        _selectedChapterKey = chapterKey;
        _selectedPageNumber = pageNumber;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToChapterAndPage(_renderedSections, pageNumber: pageNumber);
      });
      return;
    }
    final target = sections.indexWhere((s) {
      final chapterOk = chapterKey == null || s.chapterKey == chapterKey;
      final pageOk = pageNumber == null || s.pageNumber == pageNumber;
      return chapterOk && pageOk;
    });
    if (target >= 0) {
      _jumpToSection(target);
      final s = sections[target];
      unawaited(
        saveReadingProgress(
          ref,
          widget.bookId,
          chapterKey: s.chapterKey,
          pageNumber: s.pageNumber,
          progressPercent: (_progress * 100).round(),
        ),
      );
    }
  }

  Future<void> _saveCloudBookmark(BookSummary book) async {
    final dio = ref.read(apiDioProvider);
    await dio.post<void>(
      'study/bookmarks',
      data: {
        'book': book.id,
        if (book.publishedRevision?.id.isNotEmpty == true)
          'revision': book.publishedRevision!.id,
        'chapter_key': _selectedChapterKey ?? '',
        'page_number': _selectedPageNumber,
        'label': l10n.bookmarkSavedAt((_progress * 100).round()),
        'snippet': _currentSectionLabel(),
      },
    );
    ref.invalidate(studyBookmarksProvider(widget.bookId));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.cloudBookmarkSaved)));
  }

  Future<void> _createQuickNote(BookSummary book) async {
    final controller = TextEditingController();
    final body = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.quickNoteLabel,
                  hintText: l10n.quickNoteHint,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                  child: Text(l10n.saveNote),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (body == null || body.isEmpty) return;
    final dio = ref.read(apiDioProvider);
    await dio.post<void>(
      'study/notes',
      data: {
        'book': book.id,
        if (book.publishedRevision?.id.isNotEmpty == true)
          'revision': book.publishedRevision!.id,
        'chapter_key': _selectedChapterKey ?? '',
        'page_number': _selectedPageNumber,
        'body': body,
      },
    );
    ref.invalidate(studyNotesProvider(widget.bookId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.noteSaved)));
  }

  Future<void> _addQuickHighlight(BookSummary book) async {
    final section = _currentSectionFromProgress();
    if (section == null) return;
    final excerpt = plainTextFromStoredSummary(section.body).trim();
    final sample = excerpt.length > 160 ? '${excerpt.substring(0, 160)}...' : excerpt;
    final dio = ref.read(apiDioProvider);
    await dio.post<void>(
      'study/highlights',
      data: {
        'book': book.id,
        if (book.publishedRevision?.id.isNotEmpty == true)
          'revision': book.publishedRevision!.id,
        'chapter_key': section.chapterKey,
        'page_number': section.pageNumber,
        'excerpt': sample,
        'start_offset': 0,
        'end_offset': sample.length.clamp(0, 5000),
        'color': 'yellow',
      },
    );
    ref.invalidate(studyHighlightsProvider(widget.bookId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.highlightSavedOnPage(section.pageNumber))),
    );
  }

  Future<void> _openHighlightsSheet() async {
    List<Map<String, dynamic>> items = const [];
    try {
      items = await ref.read(studyHighlightsProvider(widget.bookId).future);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.highlightsUnavailable)),
      );
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: items.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l10n.noHighlightsYet),
              )
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final chapter = item['chapter_key'] as String? ?? '';
                  final page = (item['page_number'] as num?)?.toInt();
                  final excerpt = item['excerpt'] as String? ?? '';
                  return ListTile(
                    leading: const Icon(Icons.highlight_alt_rounded),
                    title: Text(
                      excerpt.isEmpty ? l10n.highlightDefaultTitle : excerpt,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      l10n.highlightChapterPage(
                        chapter.isEmpty ? '-' : chapter,
                        page?.toString() ?? '-',
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _jumpToChapterAndPage(
                        _renderedSections,
                        chapterKey: chapter.isEmpty ? null : chapter,
                        pageNumber: page,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  Future<void> _toggleOfflineCache(bool currentlyCached) async {
    if (currentlyCached) {
      await BookContentCacheStorage.removeBookContent(widget.bookId);
      ref.invalidate(offlineBookCachedProvider(widget.bookId));
      ref.invalidate(offlineBookCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.offlineCopyRemoved)),
        );
      }
      return;
    }
    final tree = await ref.read(bookContentProvider(widget.bookId).future);
    final raw = {
      'chapters': tree.chapters
          .map(
            (c) => {
              'chapter_key': c.chapterKey,
              'title': c.title,
              'ordinal': c.ordinal,
              'pages': c.pages
                  .map(
                    (p) => {
                      'page_number': p.pageNumber,
                      'title': p.title,
                      'body': p.body,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'total_pages': tree.totalPages,
    };
    await BookContentCacheStorage.writeBookContent(widget.bookId, raw);
    ref.invalidate(offlineBookCachedProvider(widget.bookId));
    ref.invalidate(offlineBookCountProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.savedOfflineReading)),
      );
    }
  }

  Future<void> _openFindSheet() async {
    _findController.text = _findQuery;
    final hasSelectedChapter =
        _selectedChapterKey != null && _selectedChapterKey!.isNotEmpty;
    var allChapters = !hasSelectedChapter;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          List<_ReaderSection> scopeSections() {
            return allChapters ? _allSections : _renderedSections;
          }

          void updateLocalMatches(String value) {
            final query = value.trim().toLowerCase();
            final matches = <String>[];
            for (final section in scopeSections()) {
              final all =
                  '${section.title} ${plainTextFromStoredSummary(section.body)}'
                      .toLowerCase();
              if (query.isNotEmpty && all.contains(query)) {
                matches.add(_locationId(section.chapterKey, section.pageNumber));
              }
            }
            setState(() {
              _findQuery = value.trim();
              _matchedLocations = matches;
              _searchHits = const [];
              _activeMatchPointer = matches.isEmpty ? -1 : 0;
            });
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _findController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: l10n.findInBookLabel,
                      hintText: l10n.findInBookHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                    onChanged: updateLocalMatches,
                    onSubmitted: (_) {
                      Navigator.of(context).pop();
                      final trimmed = _findController.text.trim();
                      if (trimmed.isNotEmpty) {
                        _runServerSearch(trimmed, allChapters: allChapters);
                      } else {
                        _goToActiveMatch();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allChapters,
                    onChanged: hasSelectedChapter
                        ? (value) {
                            setSheetState(() => allChapters = value);
                            updateLocalMatches(_findController.text);
                          }
                        : null,
                    title: Text(l10n.allChapters),
                    subtitle: Text(
                      hasSelectedChapter
                          ? l10n.searchOutsideChapter
                          : l10n.noChapterSelected,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _matchedLocations.isEmpty
                              ? l10n.noMatchesYet
                              : l10n.matchCount(_matchedLocations.length),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.previousMatch,
                        onPressed: _matchedLocations.length < 2
                            ? null
                            : () => _cycleMatch(-1),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      IconButton(
                        tooltip: l10n.nextMatch,
                        onPressed: _matchedLocations.length < 2
                            ? null
                            : () => _cycleMatch(1),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      FilledButton(
                        onPressed: _matchedLocations.isEmpty
                            ? (_findController.text.trim().isEmpty
                                  ? null
                                  : () {
                                      Navigator.of(context).pop();
                                      _runServerSearch(
                                        _findController.text.trim(),
                                        allChapters: allChapters,
                                      );
                                    })
                            : () {
                                Navigator.of(context).pop();
                                _goToActiveMatch();
                              },
                        child: Text(l10n.search),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _cycleMatch(int step) {
    if (_matchedLocations.isEmpty) return;
    setState(() {
      final next = (_activeMatchPointer + step) % _matchedLocations.length;
      _activeMatchPointer = next < 0 ? _matchedLocations.length - 1 : next;
    });
  }

  void _goToActiveMatch() {
    if (_matchedLocations.isEmpty || _activeMatchPointer < 0) return;
    if (_searchHits.isNotEmpty && _activeMatchPointer < _searchHits.length) {
      final hit = _searchHits[_activeMatchPointer];
      setState(() {
        _selectedChapterKey = hit.chapterKey;
        _selectedPageNumber = hit.pageNumber;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.matchOnPage(hit.pageNumber, hit.snippet)),
          ),
        );
      }
      _jumpToChapterAndPage(
        _renderedSections,
        chapterKey: hit.chapterKey.isEmpty ? null : hit.chapterKey,
        pageNumber: hit.pageNumber,
      );
      return;
    }
    final targetId = _matchedLocations[_activeMatchPointer];
    _ReaderSection? target;
    for (final section in _allSections) {
      if (_locationId(section.chapterKey, section.pageNumber) == targetId) {
        target = section;
        break;
      }
    }
    if (target == null) return;
    _jumpToChapterAndPage(
      _renderedSections,
      chapterKey: target.chapterKey,
      pageNumber: target.pageNumber,
    );
  }

  Future<void> _openTypographySheet() async {
    final presets = <({String label, double size, double lineHeight})>[
      (label: l10n.typographyCompact, size: 16, lineHeight: 1.65),
      (label: l10n.typographyComfort, size: 18, lineHeight: 1.8),
      (label: l10n.typographyLarge, size: 21, lineHeight: 1.95),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                l10n.typographyPresetsTitle,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(l10n.typographyPresetsSubtitle),
            ),
            ...presets.map(
              (preset) => ListTile(
                leading: Icon(
                  (_fontSize - preset.size).abs() < 0.1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                ),
                title: Text(preset.label),
                subtitle: Text(
                  l10n.typographySizeLine(
                    preset.size.toInt(),
                    preset.lineHeight.toStringAsFixed(2),
                  ),
                ),
                onTap: () async {
                  setState(() {
                    _fontSize = preset.size;
                    _lineHeight = preset.lineHeight;
                  });
                  await ReaderPrefsStorage.writeFontSize(
                    widget.bookId,
                    preset.size,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  final Map<int, GlobalKey> _sectionKeys = {};
  double _lineHeight = 1.8;

  @override
  void dispose() {
    _idleTimer?.cancel();
    _progressSyncTimer?.cancel();
    _scrollController.dispose();
    _findController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncBook = ref.watch(bookDetailProvider(widget.bookId));
    final asyncContentTree = ref.watch(bookContentProvider(widget.bookId));
    final asyncCloudProgress = ref.watch(readingProgressProvider(widget.bookId));
    final offlineCached = ref.watch(offlineBookCachedProvider(widget.bookId)).valueOrNull ?? false;
    final contentTree = asyncContentTree.valueOrNull;

    return asyncBook.when(
      data: (book) {
        final dark = _mode == 'dark';
        final sepia = _mode == 'sepia';
        final bg = dark
            ? const Color(0xFF121826)
            : sepia
                ? const Color(0xFFF6E9D1)
                : Colors.white;
        final text = dark ? const Color(0xFFE6EDF7) : const Color(0xFF0F172A);

        final hasTree = contentTree != null && contentTree.chapters.isNotEmpty;
        BookContentChapter? selectedChapter;
        if (hasTree) {
          for (final chapter in contentTree.chapters) {
            if (chapter.chapterKey == _selectedChapterKey) {
              selectedChapter = chapter;
              break;
            }
          }
        }
        final sections = hasTree
            ? _buildSectionsFromTree(
                contentTree,
                chapterKey: selectedChapter?.chapterKey,
              )
            : const <_ReaderSection>[];
        _allSections = hasTree
            ? _buildSectionsFromTree(contentTree)
            : const <_ReaderSection>[];
        _renderedSections = sections;
        _pruneSectionKeys(sections.length);
        final cloud = asyncCloudProgress.valueOrNull;
        if (!_remoteProgressApplied &&
            cloud != null &&
            (cloud.chapterKey.isNotEmpty || cloud.pageNumber != null || cloud.progressPercent > 0)) {
          _remoteProgressApplied = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              if (_selectedChapterKey == null || _selectedChapterKey!.isEmpty) {
                _selectedChapterKey = cloud.chapterKey.isEmpty ? null : cloud.chapterKey;
              }
              _selectedPageNumber ??= cloud.pageNumber;
              _progress = (cloud.progressPercent / 100).clamp(0, 1).toDouble();
            });
            _jumpToChapterAndPage(
              _renderedSections,
              chapterKey: _selectedChapterKey,
              pageNumber: _selectedPageNumber,
            );
          });
        }
        final currentSection = sections.isEmpty
            ? null
            : sections[(_progress.clamp(0, 1) * (sections.length - 1))
                .round()
                .clamp(0, sections.length - 1)];

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _toggleChrome,
                  onPanDown: (_) {
                    if (!_showChrome) setState(() => _showChrome = true);
                    _scheduleAutoHide();
                  },
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      _showChrome ? 78 : 20,
                      20,
                      _showChrome ? 100 : 28,
                    ),
                    children: [
                      Text(
                        book.title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: text,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      if (book.subtitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          book.subtitle!,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: text.withValues(alpha: 0.8),
                                  ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (hasTree && _selectedChapterKey == null) ...[
                        Text(
                          l10n.chaptersHeading,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        ...contentTree.chapters.map(
                          (chapter) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.menu_book_rounded),
                              title: Text(chapter.title),
                              subtitle: Text(l10n.pageCount(chapter.pages.length)),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                setState(() {
                                  _selectedChapterKey = chapter.chapterKey;
                                  _selectedPageNumber = null;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ] else if (asyncContentTree.isLoading) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        const SizedBox(height: 80),
                      ] else if (!hasTree) ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(
                              l10n.noChapterContentYet,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ] else ...[
                      if (_selectedChapterKey != null || _selectedPageNumber != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              if (_selectedChapterKey != null)
                                Chip(
                                  label: Text(
                                    selectedChapter == null
                                        ? l10n.chapterChipRaw(_selectedChapterKey!)
                                        : l10n.chapterChipRaw(selectedChapter.title),
                                  ),
                                  onDeleted: _returnToChapters,
                                ),
                              if (_selectedPageNumber != null)
                                Chip(
                                  label: Text(
                                    l10n.pageChipShort(_selectedPageNumber!),
                                  ),
                                  onDeleted: () => setState(() => _selectedPageNumber = null),
                                ),
                            ],
                          ),
                        ),
                      ...sections.map((section) {
                        final locationId =
                            _locationId(section.chapterKey, section.pageNumber);
                        final isMatch = _matchedLocations.contains(locationId);
                        final isActiveMatch = isMatch &&
                            _activeMatchPointer >= 0 &&
                            _matchedLocations[_activeMatchPointer] == locationId;
                        return _ReaderBookPage(
                          key: _sectionKeyFor(section.index),
                          section: section,
                          dark: dark,
                          sepia: sepia,
                          textColor: text,
                          fontSize: _fontSize,
                          lineHeight: _lineHeight,
                          isMatch: isMatch,
                          isActiveMatch: isActiveMatch,
                          colorScheme: Theme.of(context).colorScheme,
                        );
                      }),
                      ],
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  top: _showChrome ? 0 : -84,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: bg.withValues(alpha: 0.97),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: Icon(Icons.arrow_back_rounded, color: text),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          fit: FlexFit.loose,
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _openTocSheet(
                                      book.title,
                                      sections,
                                      contentTree,
                                    ),
                                    icon: Icon(Icons.toc_rounded, color: text),
                                  ),
                                  IconButton(
                                    tooltip: l10n.backToChaptersTooltip,
                                    onPressed: _selectedChapterKey == null
                                        ? null
                                        : _returnToChapters,
                                    icon: Icon(Icons.view_list_rounded, color: text),
                                  ),
                                  IconButton(
                                    tooltip: l10n.filterChapterTooltip,
                                    onPressed: (contentTree == null ||
                                            contentTree.chapters.isEmpty)
                                        ? null
                                        : () => _pickChapter(contentTree.chapters),
                                    icon: Icon(Icons.menu_book_outlined, color: text),
                                  ),
                                  IconButton(
                                    tooltip: l10n.filterPageTooltip,
                                    onPressed: sections.isEmpty ? null : _pickPage,
                                    icon: Icon(Icons.filter_1_rounded, color: text),
                                  ),
                                  IconButton(
                                    onPressed: _openFindSheet,
                                    icon: Icon(Icons.find_in_page_outlined, color: text),
                                  ),
                                  IconButton(
                                    onPressed: _openBookmarksSheet,
                                    icon: Icon(Icons.bookmarks_outlined, color: text),
                                  ),
                                  IconButton(
                                    tooltip: offlineCached
                                        ? l10n.removeOfflineCopy
                                        : l10n.saveChaptersOffline,
                                    onPressed: () => _toggleOfflineCache(offlineCached),
                                    icon: Icon(
                                      offlineCached
                                          ? Icons.cloud_done_outlined
                                          : Icons.cloud_download_outlined,
                                      color: text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_selectedChapterKey != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    left: 12,
                    right: 12,
                    bottom: _showChrome ? 128 : 18,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _returnToChapters,
                        icon: const Icon(Icons.view_list_rounded),
                        label: Text(l10n.backToChapters),
                      ),
                    ),
                  ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  left: 12,
                  right: 12,
                  bottom: _showChrome ? 8 : -120,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEAF3FF).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: dark
                            ? const Color(0xFF334155)
                            : const Color(0xFFC4D7F2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentSection == null
                                    ? l10n.noChapterSelectedShort
                                    : '${currentSection.chapterTitle} · p.${currentSection.pageNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: text),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(_progress * 100).round()}%',
                              style: TextStyle(color: text),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: _progress.clamp(0, 1),
                                minHeight: 6,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 48,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    final next = (_fontSize - 1).clamp(15, 28);
                                    setState(() => _fontSize = next.toDouble());
                                    await ReaderPrefsStorage.writeFontSize(
                                      widget.bookId,
                                      _fontSize,
                                    );
                                  },
                                  icon: const Icon(Icons.text_decrease_rounded),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final next = (_fontSize + 1).clamp(15, 28);
                                    setState(() => _fontSize = next.toDouble());
                                    await ReaderPrefsStorage.writeFontSize(
                                      widget.bookId,
                                      _fontSize,
                                    );
                                  },
                                  icon: const Icon(Icons.text_increase_rounded),
                                ),
                                IconButton(
                                  tooltip: l10n.typographyPresetsTooltip,
                                  onPressed: _openTypographySheet,
                                  icon: const Icon(Icons.text_fields_rounded),
                                ),
                                IconButton(
                                  onPressed: _toggleBookmark,
                                  icon: const Icon(Icons.bookmark_add_outlined),
                                ),
                                IconButton(
                                  tooltip: l10n.saveCloudBookmarkTooltip,
                                  onPressed: () => _saveCloudBookmark(book),
                                  icon: const Icon(Icons.cloud_upload_outlined),
                                ),
                                IconButton(
                                  tooltip: l10n.addNoteTooltip,
                                  onPressed: () => _createQuickNote(book),
                                  icon: const Icon(Icons.sticky_note_2_outlined),
                                ),
                                IconButton(
                                  tooltip: l10n.addHighlightTooltip,
                                  onPressed: () => _addQuickHighlight(book),
                                  icon: const Icon(Icons.highlight_alt_outlined),
                                ),
                                IconButton(
                                  tooltip: l10n.highlightsTooltip,
                                  onPressed: _openHighlightsSheet,
                                  icon: const Icon(Icons.format_paint_outlined),
                                ),
                                IconButton(
                                  tooltip: _autoHideEnabled
                                      ? l10n.pinControls
                                      : l10n.autoHideControls,
                                  onPressed: () {
                                    setState(() {
                                      _autoHideEnabled = !_autoHideEnabled;
                                      _showChrome = true;
                                    });
                                    if (_autoHideEnabled) _scheduleAutoHide();
                                  },
                                  icon: Icon(
                                    _autoHideEnabled
                                        ? Icons.push_pin_outlined
                                        : Icons.push_pin,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final modes = ['light', 'sepia', 'dark'];
                                    final index = modes.indexOf(_mode);
                                    final next = modes[(index + 1) % modes.length];
                                    setState(() => _mode = next);
                                    await ReaderPrefsStorage.writeThemeMode(
                                      widget.bookId,
                                      next,
                                    );
                                  },
                                  icon: const Icon(Icons.palette_outlined),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.readerTitle)),
        body: Center(child: Text('$e')),
      ),
    );
  }
}

class _ReaderSection {
  const _ReaderSection({
    required this.index,
    required this.chapterKey,
    required this.chapterTitle,
    required this.pageNumber,
    required this.pageTitle,
    required this.title,
    required this.preview,
    required this.body,
  });

  final int index;
  final String chapterKey;
  final String chapterTitle;
  final int pageNumber;
  final String pageTitle;
  final String title;
  final String preview;
  final String body;
}

List<_ReaderSection> _buildSectionsFromTree(
  BookContentTree tree, {
  String? chapterKey,
}) {
  final sections = <_ReaderSection>[];
  var index = 0;
  for (final chapter in tree.chapters) {
    if (chapterKey != null && chapterKey.isNotEmpty && chapter.chapterKey != chapterKey) {
      continue;
    }
    for (final page in chapter.pages) {
      final body = page.body.trim();
      final plainBody = plainTextFromStoredSummary(body).trim();
      final preview =
          plainBody.length > 56 ? '${plainBody.substring(0, 56)}...' : plainBody;
      sections.add(
        _ReaderSection(
          index: index,
          chapterKey: chapter.chapterKey,
          chapterTitle: chapter.title,
          pageNumber: page.pageNumber,
          pageTitle: page.title,
          title: '${chapter.title} · ${page.title}',
          preview: preview,
          body: body.isEmpty ? page.title : body,
        ),
      );
      index += 1;
    }
  }
  return sections;
}

Color _readerPageAccent(int seed, bool dark, bool sepia) {
  final hues = sepia
      ? <double>[30, 24, 40, 18, 44, 33, 12, 48]
      : dark
          ? <double>[208, 172, 265, 148, 318, 188, 230, 195]
          : <double>[212, 168, 142, 235, 352, 195, 265, 28];
  final h = hues[seed.abs() % hues.length];
  final s = sepia ? 0.38 : (dark ? 0.26 : 0.32);
  final l = dark ? 0.48 : (sepia ? 0.36 : 0.38);
  return HSLColor.fromAHSL(1, h, s, l).toColor();
}

Color _readerPaperBase(bool dark, bool sepia) {
  if (dark) return const Color(0xFF1A2130);
  if (sepia) return const Color(0xFFFDF7EE);
  return const Color(0xFFFFFCF8);
}

Color _readerPaperForPage(Color base, Color accent, int seed) {
  final mix = 0.028 + (seed % 7) * 0.005;
  return Color.lerp(base, accent, mix.clamp(0.0, 0.07)) ?? base;
}

bool _readerShowPageSubtitle(_ReaderSection s, AppLocalizations l10n) {
  final t = s.pageTitle.trim();
  if (t.isEmpty) return false;
  if (t == 'Page ${s.pageNumber}') return false;
  if (t == l10n.pageTitleFallback(s.pageNumber)) return false;
  return true;
}

class _ReaderBookPage extends StatelessWidget {
  const _ReaderBookPage({
    super.key,
    required this.section,
    required this.dark,
    required this.sepia,
    required this.textColor,
    required this.fontSize,
    required this.lineHeight,
    required this.isMatch,
    required this.isActiveMatch,
    required this.colorScheme,
  });

  final _ReaderSection section;
  final bool dark;
  final bool sepia;
  final Color textColor;
  final double fontSize;
  final double lineHeight;
  final bool isMatch;
  final bool isActiveMatch;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final seed =
        Object.hash(section.chapterKey, section.pageNumber, section.index);
    final accent = _readerPageAccent(seed, dark, sepia);
    final basePaper = _readerPaperBase(dark, sepia);
    var paper = _readerPaperForPage(basePaper, accent, seed);
    if (isActiveMatch) {
      paper = Color.alphaBlend(
        colorScheme.primaryContainer.withValues(alpha: dark ? 0.34 : 0.5),
        paper,
      );
    } else if (isMatch) {
      paper = Color.alphaBlend(
        colorScheme.surfaceContainerHighest.withValues(alpha: dark ? 0.22 : 0.38),
        paper,
      );
    }

    final muted = textColor.withValues(alpha: dark ? 0.55 : 0.48);
    final borderColor = isActiveMatch
        ? colorScheme.primary.withValues(alpha: 0.82)
        : isMatch
            ? colorScheme.tertiary.withValues(alpha: 0.55)
            : accent.withValues(alpha: dark ? 0.42 : 0.32);
    final borderW = isActiveMatch ? 2.0 : 1.0;
    final radius = 4.0 + (seed % 4);

    const serif = 'serif';

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: borderW),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.42 : 0.08),
              blurRadius: dark ? 16 : 11,
              offset: const Offset(0, 6),
              spreadRadius: dark ? 0 : -1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Material(
            color: paper,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(accent, Colors.white, dark ? 0.08 : 0.18) ??
                              accent,
                          accent,
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.readerChapterLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1.35,
                                        color: muted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      section.chapterTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: serif,
                                        fontSize: 15,
                                        height: 1.25,
                                        color: textColor.withValues(alpha: 0.92),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (_readerShowPageSubtitle(section, l10n)) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        section.pageTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: serif,
                                          fontSize: 13,
                                          height: 1.3,
                                          color: muted,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    l10n.readerPageLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      letterSpacing: 1.2,
                                      color: muted,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.62),
                                      ),
                                      borderRadius: BorderRadius.circular(3),
                                      color: accent.withValues(alpha: dark ? 0.12 : 0.08),
                                    ),
                                    child: Text(
                                      '${section.pageNumber}',
                                      style: TextStyle(
                                        fontFamily: serif,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: textColor.withValues(alpha: 0.94),
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                accent.withValues(alpha: 0.45),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(26, 16, 28, 20),
                          child: Align(
                            alignment: AlignmentDirectional.topStart,
                            child: StoredRichTextView(
                              raw: section.body,
                              fallbackStyle: TextStyle(
                                fontFamily: serif,
                                color: textColor,
                                fontSize: fontSize,
                                height: lineHeight,
                                letterSpacing: 0.2,
                              ),
                              paragraphStyle: TextStyle(
                                fontFamily: serif,
                                color: textColor,
                                fontSize: fontSize,
                                height: lineHeight,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Center(
                            child: Text(
                              '· ${section.pageNumber} ·',
                              style: TextStyle(
                                fontFamily: serif,
                                fontSize: 13,
                                color: muted,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
