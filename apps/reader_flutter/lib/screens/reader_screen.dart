import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../router/app_navigation.dart';
import '../design/app_tokens.dart';
import '../design/reader_typography.dart';
import '../design/reference_assets.dart';
import '../l10n/app_localizations.dart';
import '../models/book_models.dart';
import '../providers/api_client.dart';
import '../providers/catalog_providers.dart';
import '../providers/continue_reading_provider.dart';
import '../providers/study_providers.dart';
import '../storage/book_content_cache_storage.dart';
import '../storage/reader_prefs_storage.dart';
import '../utils/rich_text_codec.dart' show plainTextFromStoredSummary;
import '../common/platform/platform_shell.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/reader/web_reader_chapter_grid.dart';
import '../web/widgets/reader/web_reader_layout.dart';
import '../widgets/highlighted_search_text.dart';
import '../widgets/reader_book_page_view.dart';
import '../widgets/stored_rich_text_view.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.bookId,
    this.initialChapterKey,
    this.initialPageNumber,
    this.showChapterPicker = false,
  });

  final String bookId;
  final String? initialChapterKey;
  final int? initialPageNumber;
  /// When true, open on the chapter list and do not auto-restore cloud progress.
  final bool showChapterPicker;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _pageScrollController = ScrollController();
  bool _showChrome = false;
  bool _autoHideEnabled = true;
  double _progress = 0;
  double _fontSize = 18;
  String _mode = 'light';
  List<ReaderBookmark> _bookmarks = const [];
  final TextEditingController _findController = TextEditingController();
  final FocusNode _findFocusNode = FocusNode();
  bool _showFindBar = false;
  bool _footerExpanded = false;
  bool _pageCurlEnabled = true;
  final ReaderPageController _pageController = ReaderPageController();
  int _currentPageViewIndex = 0;
  bool _searchAllChapters = false;
  String _findQuery = '';
  List<_FindMatch> _findMatches = const [];
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
    _findFocusNode.addListener(_onFindFocusChanged);
    _scheduleAutoHide();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordLastOpened());
  }

  void _onFindFocusChanged() {
    if (!_findFocusNode.hasFocus) return;
    _idleTimer?.cancel();
    if (mounted && (!_showChrome || !_showFindBar)) {
      setState(() {
        _showChrome = true;
        _showFindBar = true;
      });
    }
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
    final restoredPageCurl =
        await ReaderPrefsStorage.readPageCurlMode(widget.bookId);
    if (!mounted) return;
    setState(() {
      _progress = restoredProgress;
      _fontSize = restoredFont;
      _mode = restoredMode;
      _bookmarks = restoredBookmarks;
      _pageCurlEnabled = restoredPageCurl;
      if (restoredPageCurl) _showChrome = false;
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
    if (_showFindBar || _findFocusNode.hasFocus) return;
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

  void _handleReaderBack() {
    if (_hasSelectedChapter) {
      setState(() {
        _selectedChapterKey = null;
        _selectedPageNumber = null;
        _progress = 0;
        _showChrome = true;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      return;
    }
    popOverlayRoute(context);
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

  int _pageIndexFromProgress(int sectionCount) {
    if (sectionCount <= 1) return 0;
    return (_progress.clamp(0, 1) * (sectionCount - 1))
        .round()
        .clamp(0, sectionCount - 1);
  }

  void _syncPageFromProgress(List<_ReaderSection> sections) {
    if (!_pageCurlEnabled || sections.isEmpty) return;
    final index = _pageIndexFromProgress(sections.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_pageController.isAttached) return;
      _pageController.goToPage(index);
      _handlePageChanged(index, sections);
    });
  }

  void _handlePageChanged(int index, List<_ReaderSection> sections) {
    if (index < 0 || index >= sections.length) return;
    final newProgress = sections.length <= 1
        ? 0.0
        : index / (sections.length - 1);
    final page = sections[index].pageNumber;
    if ((newProgress - _progress).abs() < 0.005 &&
        _selectedPageNumber == page) {
      return;
    }
    setState(() {
      _progress = newProgress;
      _selectedPageNumber = page;
    });
    ReaderPrefsStorage.writeProgress(widget.bookId, newProgress);
    _scheduleCloudProgressSync();
  }

  Future<void> _togglePageCurlMode() async {
    final next = !_pageCurlEnabled;
    setState(() {
      _pageCurlEnabled = next;
      _showChrome = false;
      if (next) _footerExpanded = true;
    });
    await ReaderPrefsStorage.writePageCurlMode(widget.bookId, next);
    if (!mounted) return;
    if (next) {
      _idleTimer?.cancel();
      if (_renderedSections.isNotEmpty) {
        _syncPageFromProgress(_renderedSections);
      }
    } else if (_renderedSections.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _jumpToSection(_pageIndexFromProgress(_renderedSections.length));
      });
    }
  }

  void _jumpToSection(int index) {
    if (_pageCurlEnabled && _renderedSections.isNotEmpty) {
      final safe = index.clamp(0, _renderedSections.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pageController.goToPage(safe);
      });
      _handlePageChanged(safe, _renderedSections);
      if (_findQuery.trim().isNotEmpty) {
        _focusFindOnPage(safe);
      } else {
        setState(() => _currentPageViewIndex = safe);
        if (_pageScrollController.hasClients) {
          _pageScrollController.jumpTo(0);
        }
      }
      return;
    }
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

  void _selectChapter(BookContentChapter chapter, BookContentTree contentTree) {
    setState(() {
      _selectedChapterKey = chapter.chapterKey;
      _selectedPageNumber = null;
      _progress = 0;
      if (_pageCurlEnabled) {
        _showChrome = false;
      }
    });
    if (_pageCurlEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncPageFromProgress(
          _buildSectionsFromTree(
            contentTree,
            chapterKey: chapter.chapterKey,
          ),
        );
      });
    }
    unawaited(
      trackReaderEvent(
        ref,
        bookId: widget.bookId,
        eventName: 'chapter_open',
        chapterKey: chapter.chapterKey,
      ),
    );
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
    await ref.read(
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
    final scopeAll = allChapters || !_hasSelectedChapter;
    final sections = scopeAll ? _allSections : _renderedSections;
    setState(() => _findQuery = query.trim());
    _rebuildFindMatches(sections);
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
    final book = ref.read(bookDetailProvider(widget.bookId)).valueOrNull;
    await BookContentCacheStorage.writeBookContent(
      widget.bookId,
      raw,
      meta: BookCacheMeta(
        title: book?.title ??
            BookContentCacheStorage.titleFromContentTree(tree) ??
            widget.bookId,
        authorCompiler: book?.authorCompiler,
        primaryLanguage: book?.primaryLanguage,
        savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    ref.invalidate(offlineDownloadsListProvider);
    ref.invalidate(offlineBookCachedProvider(widget.bookId));
    ref.invalidate(offlineBookCountProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.savedOfflineReading)),
      );
    }
  }

  bool get _hasSelectedChapter =>
      _selectedChapterKey != null && _selectedChapterKey!.isNotEmpty;

  void _updateFindMatches(String value, {bool? allChapters}) {
    if (allChapters != null) {
      setState(() => _searchAllChapters = allChapters);
    }
    final sections = _findScopeSections;
    setState(() => _findQuery = value.trim());
    _rebuildFindMatches(sections);
    if (_pageCurlEnabled &&
        _hasSelectedChapter &&
        _findQuery.trim().isNotEmpty) {
      _focusFindOnPage(_currentPageViewIndex);
    }
  }

  void _rebuildFindMatches(List<_ReaderSection> sections) {
    final matches = _collectFindMatches(sections, _findQuery);
    setState(() {
      _findMatches = matches;
      if (_pageCurlEnabled && _hasSelectedChapter) {
        final section = _pageSectionAt(_currentPageViewIndex);
        _activeMatchPointer = section == null
            ? -1
            : _preferredMatchPointerForSection(section);
      } else {
        _activeMatchPointer = matches.isEmpty ? -1 : 0;
      }
    });
  }

  List<_FindMatch> _collectFindMatches(
    List<_ReaderSection> sections,
    String query,
  ) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final matches = <_FindMatch>[];
    for (final section in sections) {
      _appendFindMatches(
        matches,
        section: section,
        field: _FindMatchField.chapterTitle,
        text: section.chapterTitle,
        query: trimmed,
      );
      if (_readerShowPageSubtitle(section, l10n)) {
        _appendFindMatches(
          matches,
          section: section,
          field: _FindMatchField.pageTitle,
          text: section.pageTitle,
          query: trimmed,
        );
      }
      _appendFindMatches(
        matches,
        section: section,
        field: _FindMatchField.body,
        text: plainTextFromStoredSummary(section.body),
        query: trimmed,
      );
    }
    return matches;
  }

  void _appendFindMatches(
    List<_FindMatch> matches, {
    required _ReaderSection section,
    required _FindMatchField field,
    required String text,
    required String query,
  }) {
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    var start = 0;
    var occurrence = 0;
    while (start < lowerText.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) break;
      matches.add(
        _FindMatch(
          chapterKey: section.chapterKey,
          pageNumber: section.pageNumber,
          field: field,
          occurrenceIndex: occurrence,
        ),
      );
      occurrence++;
      start = index + lowerQuery.length;
    }
  }

  _FindMatch? get _activeFindMatch {
    if (_activeMatchPointer < 0 || _activeMatchPointer >= _findMatches.length) {
      return null;
    }
    return _findMatches[_activeMatchPointer];
  }

  List<_ReaderSection> get _findScopeSections =>
      (_searchAllChapters || !_hasSelectedChapter)
          ? _allSections
          : _renderedSections;

  _ReaderSection? _pageSectionAt(int index) {
    if (index < 0 || index >= _renderedSections.length) return null;
    return _renderedSections[index];
  }

  List<int> _matchIndicesForSection(_ReaderSection section) {
    final indices = <int>[];
    for (var i = 0; i < _findMatches.length; i++) {
      final match = _findMatches[i];
      if (match.chapterKey == section.chapterKey &&
          match.pageNumber == section.pageNumber) {
        indices.add(i);
      }
    }
    return indices;
  }

  List<int> _matchIndicesForCurrentPage() {
    final section = _pageSectionAt(_currentPageViewIndex);
    if (section == null) return const [];
    return _matchIndicesForSection(section);
  }

  int _preferredMatchPointerForSection(_ReaderSection section) {
    final indices = _matchIndicesForSection(section);
    if (indices.isEmpty) return -1;
    for (final index in indices) {
      if (_findMatches[index].field == _FindMatchField.body) {
        return index;
      }
    }
    return indices.first;
  }

  void _focusFindOnPage(int pageIndex) {
    final section = _pageSectionAt(pageIndex);
    if (section == null) return;
    setState(() {
      _currentPageViewIndex = pageIndex;
      _activeMatchPointer = _preferredMatchPointerForSection(section);
    });
    if (_pageScrollController.hasClients) {
      _pageScrollController.jumpTo(0);
    }
    _scheduleScrollToActiveMatch();
  }

  void _cycleFindMatch(int step) {
    if (_findMatches.isEmpty) return;
    if (_pageCurlEnabled && _hasSelectedChapter) {
      final indices = _matchIndicesForCurrentPage();
      if (indices.isEmpty) return;
      var pos = indices.indexOf(_activeMatchPointer);
      if (pos < 0) {
        pos = step >= 0 ? 0 : indices.length - 1;
      } else {
        pos = (pos + step) % indices.length;
        if (pos < 0) pos += indices.length;
      }
      setState(() => _activeMatchPointer = indices[pos]);
      _scheduleScrollToActiveMatch();
      return;
    }
    setState(() {
      final next = (_activeMatchPointer + step) % _findMatches.length;
      _activeMatchPointer = next < 0 ? _findMatches.length - 1 : next;
    });
    _goToActiveMatch();
  }

  int _displayedFindMatchCount() {
    if (_pageCurlEnabled && _hasSelectedChapter) {
      return _matchIndicesForCurrentPage().length;
    }
    return _findMatches.length;
  }

  String _findStatusLabel() {
    if (_findMatches.isEmpty) return l10n.noMatchesYet;
    if (_pageCurlEnabled && _hasSelectedChapter) {
      final onPage = _matchIndicesForCurrentPage().length;
      if (onPage == 0) {
        return l10n.matchCount(_findMatches.length);
      }
      if (onPage == _findMatches.length) {
        return l10n.matchCount(onPage);
      }
      return '$onPage on page · ${_findMatches.length} in chapter';
    }
    return l10n.matchCount(_findMatches.length);
  }

  void _toggleFindBar() {
    setState(() {
      _showFindBar = !_showFindBar;
      _showChrome = true;
      if (_showFindBar) {
        _findController.text = _findQuery;
        _searchAllChapters = !_hasSelectedChapter;
      }
    });
    if (_showFindBar) {
      _idleTimer?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _findFocusNode.requestFocus();
      });
    } else {
      _findFocusNode.unfocus();
      _scheduleAutoHide();
    }
  }

  void _submitFind() {
    final trimmed = _findController.text.trim();
    if (trimmed.isEmpty) {
      _goToActiveMatch();
      return;
    }
    if (_findMatches.isNotEmpty) {
      _goToActiveMatch();
      return;
    }
    _runServerSearch(trimmed, allChapters: _searchAllChapters);
  }

  double _readerTopChromeInset(bool showChrome) {
    if (useWebShell(context)) return webReaderTopInset(context, showChrome);
    if (!showChrome) return 20;
    return 64;
  }

  int _readerFooterActionCount({required bool hasChapter}) {
    var count = 15;
    if (hasChapter) count += 3;
    return count;
  }

  Widget _buildPageViewReader({
    required List<_ReaderSection> sections,
    required bool dark,
    required bool sepia,
    required Color text,
    required ColorScheme colorScheme,
  }) {
    final startIndex = _pageIndexFromProgress(sections.length);
    if (_currentPageViewIndex != startIndex &&
        !_pageController.isAttached) {
      _currentPageViewIndex = startIndex;
    }
    final paper = _readerPaperBase(dark, sepia);
    return ReaderBookPageView(
      key: ValueKey(
        'page-${widget.bookId}-${_selectedChapterKey ?? ''}-${sections.length}',
      ),
      controller: _pageController,
      pageCount: sections.length,
      initialPage: startIndex,
      backgroundColor: paper,
      onTap: _toggleChrome,
      showArrows: _showChrome || _findQuery.trim().isNotEmpty,
      onInteraction: _scheduleAutoHide,
      onPageChanged: (index) {
        _handlePageChanged(index, sections);
        if (_findQuery.trim().isNotEmpty) {
          _focusFindOnPage(index);
        } else {
          setState(() => _currentPageViewIndex = index);
          if (_pageScrollController.hasClients) {
            _pageScrollController.jumpTo(0);
          }
        }
      },
      pageBuilder: (context, index) {
        final section = sections[index];
        final activeFindMatch = _activeFindMatchForSection(section);
        return ColoredBox(
          color: paper,
          child: SingleChildScrollView(
            controller: _pageScrollController,
            physics: const ClampingScrollPhysics(),
            child: _ReaderBookPage(
              section: section,
              dark: dark,
              sepia: sepia,
              textColor: text,
              fontSize: _fontSize,
              lineHeight: _lineHeight,
              findQuery: _findQuery,
              activeFindMatch: activeFindMatch,
              colorScheme: colorScheme,
            ),
          ),
        );
      },
    );
  }

  _FindMatch? _activeFindMatchForSection(_ReaderSection section) {
    final active = _activeFindMatch;
    if (active == null) return null;
    if (active.chapterKey != section.chapterKey ||
        active.pageNumber != section.pageNumber) {
      return null;
    }
    return active;
  }

  double _readerFindPanelHeight({required bool hasChapter}) {
    var h = 52.0 + 44.0;
    if (hasChapter) h += 56;
    return h + 24;
  }

  static const double _readerToolbarCollapsedHeight = 52;

  /// Width of the desktop chapter side-rail (master/detail layout).
  static const double _desktopRailWidth = 300;

  double _readerToolbarHeight({
    required bool hasChapter,
    required bool expanded,
  }) {
    if (!expanded) return _readerToolbarCollapsedHeight + 24;
    const iconsPerRow = 6;
    const rowHeight = 40.0;
    final rows =
        (_readerFooterActionCount(hasChapter: hasChapter) / iconsPerRow).ceil();
    return 28.0 + rows * rowHeight + 16 + 24;
  }

  double _readerBottomChromeInset(
    bool showChrome, {
    required bool hasChapter,
    bool findBar = false,
    bool keyboardOpen = false,
    bool footerExpanded = false,
  }) {
    if (!showChrome) return 28;
    if (keyboardOpen && findBar) {
      return _readerFindPanelHeight(hasChapter: hasChapter) + 16;
    }
    var h = _readerToolbarHeight(
      hasChapter: hasChapter,
      expanded: footerExpanded,
    );
    if (findBar) {
      h += _readerFindPanelHeight(hasChapter: hasChapter) + 8;
    }
    return h + 12;
  }

  void _toggleFooterExpanded() {
    setState(() => _footerExpanded = !_footerExpanded);
    _idleTimer?.cancel();
    if (_footerExpanded) _scheduleAutoHide();
  }

  BoxDecoration _readerChromePanelDecoration({
    required Color bg,
    required Color text,
    required bool dark,
  }) {
    return BoxDecoration(
      color: bg.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: text.withValues(alpha: dark ? 0.22 : 0.14),
      ),
    );
  }

  void _goToActiveMatch() {
    final match = _activeFindMatch;
    if (match == null) return;
    setState(() {
      _selectedChapterKey = match.chapterKey;
      _selectedPageNumber = match.pageNumber;
      _showChrome = true;
    });
    _jumpToChapterAndPage(
      _renderedSections,
      chapterKey: match.chapterKey,
      pageNumber: match.pageNumber,
    );
    if (!(_pageCurlEnabled && _hasSelectedChapter)) {
      _scheduleScrollToActiveMatch();
    }
  }

  void _scheduleScrollToActiveMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToActiveMatchInPage();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToActiveMatchInPage();
      });
    });
  }

  void _scrollToActiveMatchInPage() {
    if (!_pageCurlEnabled || _findQuery.trim().isEmpty) return;
    if (!_pageScrollController.hasClients) return;

    final section = _pageSectionAt(_currentPageViewIndex);
    if (section == null) return;

    final pageIndices = _matchIndicesForSection(section);
    if (pageIndices.isEmpty) {
      _pageScrollController.jumpTo(0);
      return;
    }

    var match = _activeFindMatch;
    if (match == null ||
        match.chapterKey != section.chapterKey ||
        match.pageNumber != section.pageNumber) {
      final pointer = _preferredMatchPointerForSection(section);
      if (pointer < 0) {
        _pageScrollController.jumpTo(0);
        return;
      }
      match = _findMatches[pointer];
    }
    if (match.field != _FindMatchField.body) {
      _pageScrollController.jumpTo(0);
      return;
    }

    final plain = plainTextFromStoredSummary(section.body);
    final width = MediaQuery.sizeOf(context).width - 28;
    final style = ReaderTypography.body(
      fontSize: _fontSize,
      color: _mode == 'dark' ? const Color(0xFFE6EDF7) : const Color(0xFF0F172A),
      height: _lineHeight,
    );
    final target = estimateScrollOffsetForOccurrence(
      text: plain,
      query: _findQuery,
      occurrenceIndex: match.occurrenceIndex,
      style: style,
      maxWidth: width.clamp(200, double.infinity),
    );
    final max = _pageScrollController.position.maxScrollExtent;
    final offset = (target - 120).clamp(0.0, max);
    if ((_pageScrollController.offset - offset).abs() < 8) return;
    _pageScrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
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
    _pageScrollController.dispose();
    _findController.dispose();
    _findFocusNode.dispose();
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
        final bg = _readerPaperBase(dark, sepia);
        final text = dark ? const Color(0xFFE6EDF7) : const Color(0xFF0F172A);

        final hasTree = contentTree != null && contentTree.chapters.isNotEmpty;
        // Desktop reads as a master/detail: chapters in a fixed left rail,
        // the selected chapter's pages fill the right pane.
        final desktopTwoPane = useDesktopShell(context) && hasTree;
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
        if (!widget.showChapterPicker &&
            !_remoteProgressApplied &&
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
        final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
        final findPanelH =
            _readerFindPanelHeight(hasChapter: _hasSelectedChapter);
        final pageViewReading = _pageCurlEnabled &&
            _selectedChapterKey != null &&
            sections.isNotEmpty;
        final showChromeUi = _showChrome || !_hasSelectedChapter;
        final showFindPanel = showChromeUi && _showFindBar;
        final showToolbarPanel =
            showChromeUi && !(keyboardOpen && _showFindBar);
        final findBottom = showChromeUi ? 8.0 : -(findPanelH + 24);
        final toolbarH = _readerToolbarHeight(
          hasChapter: _hasSelectedChapter,
          expanded: _footerExpanded,
        );
        final toolbarBottom = showChromeUi
            ? 8.0 + (showFindPanel ? findPanelH + 8 : 0)
            : -(toolbarH + 24);
        final contentTop =
            showChromeUi ? _readerTopChromeInset(true) : 20.0;
        final contentBottom = showChromeUi
            ? _readerBottomChromeInset(
                true,
                hasChapter: _hasSelectedChapter,
                findBar: _showFindBar,
                keyboardOpen: keyboardOpen,
                footerExpanded: _footerExpanded,
              )
            : 28.0;

        return PopScope(
          canPop: !_hasSelectedChapter,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleReaderBack();
          },
          child: Scaffold(
          backgroundColor: bg,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: _readerPageBackgroundDecoration(dark, sepia),
                  ),
                ),
                if (desktopTwoPane)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: _desktopRailWidth,
                    child: _DesktopChapterRail(
                      chapters: contentTree.chapters,
                      selectedChapterKey: _selectedChapterKey,
                      bookTitle: book.title,
                      chaptersLabel: l10n.chaptersHeading,
                      pageCountLabel: (c) => l10n.pageCount(c.pages.length),
                      dark: dark,
                      sepia: sepia,
                      textColor: text,
                      background: bg,
                      onSelect: (chapter) => _selectChapter(chapter, contentTree),
                    ),
                  ),
                Positioned(
                  left: desktopTwoPane ? _desktopRailWidth : 0,
                  right: 0,
                  top: contentTop,
                  bottom: contentBottom,
                  child: pageViewReading
                      ? ClipRect(
                          child: _buildPageViewReader(
                            sections: sections,
                            dark: dark,
                            sepia: sepia,
                            text: text,
                            colorScheme: Theme.of(context).colorScheme,
                          ),
                        )
                      : GestureDetector(
                  onTap: _toggleChrome,
                  onPanDown: (_) {
                    if (!_showChrome) setState(() => _showChrome = true);
                    _scheduleAutoHide();
                  },
                  child: ListView(
                    controller: _scrollController,
                    padding: EdgeInsets.fromLTRB(
                      _selectedChapterKey != null
                          ? 0
                          : webReaderHorizontalPadding(context),
                      0,
                      _selectedChapterKey != null
                          ? 0
                          : webReaderHorizontalPadding(context),
                      0,
                    ),
                    children: [
                      if (desktopTwoPane && _selectedChapterKey == null) ...[
                        // The rail lists chapters; right pane prompts a choice.
                        _DesktopReaderPlaceholder(
                          message: l10n.selectChapter,
                          textColor: text,
                        ),
                      ] else if (hasTree && _selectedChapterKey == null) ...[
                        if (useWebShell(context)) ...[
                          WebReaderChapterGrid(
                            chapters: contentTree.chapters,
                            pageCountLabel: (chapter) =>
                                l10n.pageCount(chapter.pages.length),
                            onChapterTap: (key) {
                              final chapter = contentTree.chapters.firstWhere(
                                (c) => c.chapterKey == key,
                              );
                              _selectChapter(chapter, contentTree);
                            },
                          ),
                        ] else ...[
                        Text(
                          l10n.chaptersHeading,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: text,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 10),
                        ...contentTree.chapters.map(
                          (chapter) {
                            final cardPaper = _readerPaperForPage(
                              bg,
                              _readerPageAccent(chapter.chapterKey.hashCode, dark, sepia),
                              chapter.chapterKey.hashCode,
                            );
                            final accent = _readerPageAccent(
                              chapter.chapterKey.hashCode,
                              dark,
                              sepia,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Card(
                                color: cardPaper,
                                elevation: 0,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                  side: BorderSide(
                                    color: text.withValues(
                                      alpha: dark ? 0.2 : 0.1,
                                    ),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _selectChapter(chapter, contentTree),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Container(
                                            width: 4,
                                            color: accent,
                                          ),
                                          Expanded(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                12,
                                                12,
                                                8,
                                                12,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top: 2,
                                                  ),
                                                  child: Icon(
                                                    Icons.menu_book_rounded,
                                                    color: text.withValues(
                                                      alpha: 0.7,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        chapter.title,
                                                        style: TextStyle(
                                                          color: text,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 15,
                                                          height: 1.35,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        l10n.pageCount(
                                                          chapter.pages.length,
                                                        ),
                                                        style: TextStyle(
                                                          color: text
                                                              .withValues(
                                                            alpha: 0.65,
                                                          ),
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    top: 2,
                                                  ),
                                                  child: Icon(
                                                    Icons
                                                        .chevron_right_rounded,
                                                    color: text.withValues(
                                                      alpha: 0.5,
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
                                ),
                              ),
                            ),
                            );
                          },
                        ),
                        ],
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
                      webConstrainReaderContent(
                        context,
                        Column(
                          children: sections.map((section) {
                            return _ReaderBookPage(
                              key: _sectionKeyFor(section.index),
                              section: section,
                              dark: dark,
                              sepia: sepia,
                              textColor: text,
                              fontSize: _fontSize,
                              lineHeight: _lineHeight,
                              findQuery: _findQuery,
                              activeFindMatch:
                                  _activeFindMatchForSection(section),
                              colorScheme: Theme.of(context).colorScheme,
                            );
                          }).toList(),
                        ),
                      ),
                      ],
                    ],
                  ),
                ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  top: showChromeUi ? 0 : -72,
                  left: desktopTwoPane ? _desktopRailWidth : 0,
                  right: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Material(
                    color: bg.withValues(alpha: 0.97),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
                          child: Row(
                            children: [
                              _ReaderChromeIcon(
                                onPressed: _handleReaderBack,
                                icon: Icons.arrow_back_rounded,
                                color: text,
                              ),
                              Expanded(
                                child: Text(
                                  book.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        LinearProgressIndicator(
                          value: _progress.clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor: text.withValues(alpha: 0.10),
                          color: AppColors.accent,
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
                if (showFindPanel)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    left: desktopTwoPane ? _desktopRailWidth + 12 : 12,
                    right: 12,
                    bottom: findBottom,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: _readerChromePanelDecoration(
                            bg: bg,
                            text: text,
                            dark: dark,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                focusNode: _findFocusNode,
                                controller: _findController,
                                style: TextStyle(color: text, fontSize: 15),
                                textInputAction: TextInputAction.search,
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: l10n.findInBookHint,
                                  hintStyle: TextStyle(
                                    color: text.withValues(alpha: 0.45),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: text.withValues(alpha: 0.7),
                                    size: 22,
                                  ),
                                  suffixIcon: IconButton(
                                    tooltip: l10n.search,
                                    onPressed: _submitFind,
                                    icon: Icon(
                                      Icons.check_rounded,
                                      color: text,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: dark
                                      ? const Color(0xFF243044)
                                      : text.withValues(alpha: 0.06),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                onChanged: (v) => _updateFindMatches(
                                  v,
                                  allChapters: _searchAllChapters,
                                ),
                                onSubmitted: (_) => _submitFind(),
                              ),
                              if (_hasSelectedChapter)
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  value: _searchAllChapters,
                                  onChanged: (value) {
                                    _updateFindMatches(
                                      _findController.text,
                                      allChapters: value,
                                    );
                                  },
                                  title: Text(
                                    l10n.allChapters,
                                    style: TextStyle(color: text, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    l10n.searchOutsideChapter,
                                    style: TextStyle(
                                      color: text.withValues(alpha: 0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _findQuery.trim().isEmpty
                                          ? l10n.noMatchesYet
                                          : _findStatusLabel(),
                                      style: TextStyle(
                                        color: text.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l10n.previousMatch,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _displayedFindMatchCount() < 2
                                        ? null
                                        : () => _cycleFindMatch(-1),
                                    icon: Icon(
                                      Icons.keyboard_arrow_up_rounded,
                                      color: text,
                                      size: 20,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l10n.nextMatch,
                                    visualDensity: VisualDensity.compact,
                                    onPressed: _displayedFindMatchCount() < 2
                                        ? null
                                        : () => _cycleFindMatch(1),
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: text,
                                      size: 20,
                                    ),
                                  ),
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      setState(() => _showFindBar = false);
                                      _findFocusNode.unfocus();
                                      _scheduleAutoHide();
                                    },
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: text,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showToolbarPanel)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    left: desktopTwoPane ? _desktopRailWidth + 12 : 12,
                    right: 12,
                    bottom: toolbarBottom,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: _readerChromePanelDecoration(
                            bg: bg,
                            text: text,
                            dark: dark,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: _progress.clamp(0, 1),
                                      minHeight: 4,
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${(_progress * 100).round()}%',
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  _ReaderChromeIcon(
                                    tooltip: _footerExpanded
                                        ? l10n.readerCollapseTools
                                        : l10n.readerExpandTools,
                                    onPressed: _toggleFooterExpanded,
                                    icon: _footerExpanded
                                        ? Icons.keyboard_arrow_down_rounded
                                        : Icons.keyboard_arrow_up_rounded,
                                    color: text,
                                  ),
                                ],
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                alignment: Alignment.topCenter,
                                child: _footerExpanded
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 4,
                                            runSpacing: 6,
                                            alignment: WrapAlignment.center,
                                            children: [
                                  if (_hasSelectedChapter)
                                    _ReaderChromeIcon(
                                      tooltip: l10n.backToChaptersTooltip,
                                      onPressed: _returnToChapters,
                                      icon: Icons.grid_view_rounded,
                                      color: text,
                                    ),
                                  _ReaderChromeIcon(
                                    onPressed: () => _openTocSheet(
                                      book.title,
                                      sections,
                                      contentTree,
                                    ),
                                    icon: Icons.toc_rounded,
                                    color: text,
                                  ),
                                  if (_hasSelectedChapter) ...[
                                    _ReaderChromeIcon(
                                      tooltip: l10n.filterChapterTooltip,
                                      onPressed: (contentTree == null ||
                                              contentTree.chapters.isEmpty)
                                          ? null
                                          : () => _pickChapter(
                                                contentTree.chapters,
                                              ),
                                      icon: Icons.swap_horiz_rounded,
                                      color: text,
                                    ),
                                    _ReaderChromeIcon(
                                      tooltip: l10n.filterPageTooltip,
                                      onPressed:
                                          sections.isEmpty ? null : _pickPage,
                                      icon: Icons.tag_rounded,
                                      color: text,
                                    ),
                                  ],
                                  _ReaderChromeIcon(
                                    tooltip: _pageCurlEnabled
                                        ? l10n.readerPageCurlOff
                                        : l10n.readerPageCurlOn,
                                    onPressed: _togglePageCurlMode,
                                    icon: _pageCurlEnabled
                                        ? Icons.view_agenda_outlined
                                        : Icons.menu_book_outlined,
                                    color: _pageCurlEnabled
                                        ? Theme.of(context).colorScheme.primary
                                        : text,
                                  ),
                                  _ReaderChromeIcon(
                                    tooltip: l10n.findInBookLabel,
                                    onPressed: _toggleFindBar,
                                    icon: _showFindBar
                                        ? Icons.search_off_rounded
                                        : Icons.search_rounded,
                                    color: text,
                                  ),
                                  const SizedBox(width: double.infinity),
                                  Container(
                                    width: double.infinity,
                                    height: 1,
                                    color: text.withValues(alpha: 0.14),
                                  ),
                                  _ReaderChromeIcon(
                                    onPressed: _openBookmarksSheet,
                                    icon: Icons.bookmarks_outlined,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
                                    tooltip: offlineCached
                                        ? l10n.removeOfflineCopy
                                        : l10n.saveChaptersOffline,
                                    onPressed: () =>
                                        _toggleOfflineCache(offlineCached),
                                    icon: offlineCached
                                        ? Icons.cloud_done_outlined
                                        : Icons.cloud_download_outlined,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
                                    onPressed: () async {
                                      final next =
                                          (_fontSize - 1).clamp(15, 28);
                                      setState(
                                        () => _fontSize = next.toDouble(),
                                      );
                                      await ReaderPrefsStorage.writeFontSize(
                                        widget.bookId,
                                        _fontSize,
                                      );
                                    },
                                    icon: Icons.text_decrease_rounded,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
                                    onPressed: () async {
                                      final next =
                                          (_fontSize + 1).clamp(15, 28);
                                      setState(
                                        () => _fontSize = next.toDouble(),
                                      );
                                      await ReaderPrefsStorage.writeFontSize(
                                        widget.bookId,
                                        _fontSize,
                                      );
                                    },
                                    icon: Icons.text_increase_rounded,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
                                    tooltip: l10n.typographyPresetsTooltip,
                                    onPressed: _openTypographySheet,
                                    icon: Icons.text_fields_rounded,
                                    color: text,
                                  ),
                                  const SizedBox(width: double.infinity),
                                  Container(
                                    width: double.infinity,
                                    height: 1,
                                    color: text.withValues(alpha: 0.14),
                                  ),
                                  _ReaderChromeIcon(
                                    onPressed: _toggleBookmark,
                                    icon: Icons.bookmark_add_outlined,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
                                    tooltip: l10n.saveCloudBookmarkTooltip,
                                    onPressed: () => _saveCloudBookmark(book),
                                    icon: Icons.cloud_upload_outlined,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
                                    tooltip: l10n.addNoteTooltip,
                                    onPressed: () => _createQuickNote(book),
                                    icon: Icons.sticky_note_2_outlined,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
                                    tooltip: l10n.addHighlightTooltip,
                                    onPressed: () => _addQuickHighlight(book),
                                    icon: Icons.highlight_alt_outlined,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
                                    tooltip: l10n.highlightsTooltip,
                                    onPressed: _openHighlightsSheet,
                                    icon: Icons.format_paint_outlined,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
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
                                    icon: _autoHideEnabled
                                        ? Icons.push_pin_outlined
                                        : Icons.push_pin,
                                    color: text,
                                  ),
                                  _ReaderChromeIcon(
                                    onPressed: () async {
                                      final modes = ['light', 'sepia', 'dark'];
                                      final index = modes.indexOf(_mode);
                                      final next =
                                          modes[(index + 1) % modes.length];
                                      setState(() => _mode = next);
                                      await ReaderPrefsStorage.writeThemeMode(
                                        widget.bookId,
                                        next,
                                      );
                                    },
                                    icon: Icons.palette_outlined,
                                    color: text,
                                  ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (!showChromeUi && _hasSelectedChapter)
                  Positioned(
                    top: 0,
                    left: desktopTwoPane ? _desktopRailWidth : 0,
                    child: SafeArea(
                      child: _ReaderChromeIcon(
                        onPressed: _handleReaderBack,
                        icon: Icons.arrow_back_rounded,
                        color: text.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        );
      },
      loading: () {
        final dark = _mode == 'dark';
        final sepia = _mode == 'sepia';
        return Scaffold(
          backgroundColor: _readerPaperBase(dark, sepia),
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: _readerPageBackgroundDecoration(dark, sepia),
                ),
              ),
              const Center(child: CircularProgressIndicator()),
            ],
          ),
        );
      },
      error: (e, _) {
        final dark = _mode == 'dark';
        final sepia = _mode == 'sepia';
        final bg = _readerPaperBase(dark, sepia);
        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _handleReaderBack,
            ),
            title: Text(l10n.readerTitle),
            backgroundColor: bg.withValues(alpha: 0.97),
            foregroundColor: dark ? const Color(0xFFE6EDF7) : const Color(0xFF0F172A),
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: _readerPageBackgroundDecoration(dark, sepia),
                ),
              ),
              Center(child: Text('$e')),
            ],
          ),
        );
      },
    );
  }
}

/// Compact toolbar control for reader chrome (top and bottom bars).
class _ReaderChromeIcon extends StatelessWidget {
  const _ReaderChromeIcon({
    required this.icon,
    required this.color,
    this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      iconSize: 20,
      icon: Icon(icon, color: color),
    );
  }
}

/// Desktop master/detail left rail: lists chapters; the selected one's pages
/// render in the right reading pane.
class _DesktopChapterRail extends StatelessWidget {
  const _DesktopChapterRail({
    required this.chapters,
    required this.selectedChapterKey,
    required this.bookTitle,
    required this.chaptersLabel,
    required this.pageCountLabel,
    required this.dark,
    required this.sepia,
    required this.textColor,
    required this.background,
    required this.onSelect,
  });

  final List<BookContentChapter> chapters;
  final String? selectedChapterKey;
  final String bookTitle;
  final String chaptersLabel;
  final String Function(BookContentChapter chapter) pageCountLabel;
  final bool dark;
  final bool sepia;
  final Color textColor;
  final Color background;
  final void Function(BookContentChapter chapter) onSelect;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accent;
    final divider = textColor.withValues(alpha: dark ? 0.18 : 0.1);
    final railBg = dark
        ? background.withValues(alpha: 0.6)
        : Color.alphaBlend(textColor.withValues(alpha: 0.03), background);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: railBg,
        border: Border(right: BorderSide(color: divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  chaptersLabel,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: divider),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                final selected = chapter.chapterKey == selectedChapterKey;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Material(
                    color: selected
                        ? accent.withValues(alpha: dark ? 0.24 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      onTap: () => onSelect(chapter),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 3,
                              height: 34,
                              decoration: BoxDecoration(
                                color: selected ? accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    chapter.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                      fontSize: 14,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    pageCountLabel(chapter),
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.6),
                                      fontSize: 12,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-pane prompt shown on desktop before a chapter is chosen.
class _DesktopReaderPlaceholder extends StatelessWidget {
  const _DesktopReaderPlaceholder({
    required this.message,
    required this.textColor,
  });

  final String message;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 56,
            color: textColor.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum _FindMatchField { chapterTitle, pageTitle, body }

class _FindMatch {
  const _FindMatch({
    required this.chapterKey,
    required this.pageNumber,
    required this.field,
    required this.occurrenceIndex,
  });

  final String chapterKey;
  final int pageNumber;
  final _FindMatchField field;
  final int occurrenceIndex;
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

/// Full-page background — reference `bg1` pattern blended with reader paper tone.
BoxDecoration _readerPageBackgroundDecoration(bool dark, bool sepia) {
  final base = _readerPaperBase(dark, sepia);
  return BoxDecoration(
    color: base,
    image: DecorationImage(
      image: const AssetImage(ReferenceAssets.bgPattern),
      fit: BoxFit.cover,
      opacity: dark ? 0.22 : sepia ? 0.42 : 0.5,
      colorFilter: ColorFilter.mode(
        base.withValues(alpha: dark ? 0.78 : 0.58),
        BlendMode.srcATop,
      ),
    ),
  );
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
    required this.findQuery,
    required this.activeFindMatch,
    required this.colorScheme,
  });

  final _ReaderSection section;
  final bool dark;
  final bool sepia;
  final Color textColor;
  final double fontSize;
  final double lineHeight;
  final String findQuery;
  final _FindMatch? activeFindMatch;
  final ColorScheme colorScheme;

  bool get _hasFindQuery => findQuery.trim().isNotEmpty;

  int? _activeOccurrenceFor(_FindMatchField field) {
    final active = activeFindMatch;
    if (active == null || active.field != field) return null;
    return active.occurrenceIndex;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final seed =
        Object.hash(section.chapterKey, section.pageNumber, section.index);
    final accent = _readerPageAccent(seed, dark, sepia);
    final basePaper = _readerPaperBase(dark, sepia);
    final paper = _readerPaperForPage(basePaper, accent, seed);

    final muted = textColor.withValues(alpha: dark ? 0.55 : 0.48);
    final borderColor = accent.withValues(alpha: dark ? 0.42 : 0.32);
    const borderW = 1.0;

    const contentPadH = 14.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: paper,
        border: Border(
          bottom: BorderSide(color: borderColor, width: borderW),
        ),
      ),
      child: Material(
        color: paper,
        child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          padding: EdgeInsets.fromLTRB(
                            contentPadH,
                            14,
                            contentPadH,
                            8,
                          ),
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
                                    _hasFindQuery
                                        ? HighlightedSearchText(
                                            text: section.chapterTitle,
                                            query: findQuery,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            activeOccurrenceIndex:
                                                _activeOccurrenceFor(
                                              _FindMatchField.chapterTitle,
                                            ),
                                            style: ReaderTypography.chapterTitle(
                                              color: textColor.withValues(alpha: 0.92),
                                            ),
                                          )
                                        : Text(
                                            section.chapterTitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: ReaderTypography.chapterTitle(
                                              color: textColor.withValues(alpha: 0.92),
                                            ),
                                          ),
                                    if (_readerShowPageSubtitle(section, l10n)) ...[
                                      const SizedBox(height: 6),
                                      _hasFindQuery
                                          ? HighlightedSearchText(
                                              text: section.pageTitle,
                                              query: findQuery,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              activeOccurrenceIndex:
                                                  _activeOccurrenceFor(
                                                _FindMatchField.pageTitle,
                                              ),
                                              style: ReaderTypography.chapterMeta(
                                                color: muted,
                                              ),
                                            )
                                          : Text(
                                              section.pageTitle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: ReaderTypography.chapterMeta(
                                                color: muted,
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
                                      style: ReaderTypography.chapterTitle(
                                        color: textColor.withValues(alpha: 0.94),
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: contentPadH),
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
                          padding: EdgeInsets.fromLTRB(
                            contentPadH,
                            14,
                            contentPadH,
                            18,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.topStart,
                            child: StoredRichTextView(
                              raw: section.body,
                              findQuery: _hasFindQuery ? findQuery : null,
                              activeOccurrenceIndex: _activeOccurrenceFor(
                                _FindMatchField.body,
                              ),
                              fallbackStyle: ReaderTypography.body(
                                fontSize: fontSize,
                                color: textColor,
                                height: lineHeight,
                              ),
                              paragraphStyle: ReaderTypography.body(
                                fontSize: fontSize,
                                color: textColor,
                                height: lineHeight,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Center(
                            child: Text(
                              '· ${section.pageNumber} ·',
                              style: ReaderTypography.body(
                                fontSize: 13,
                                color: muted,
                                height: 1.2,
                              ).copyWith(letterSpacing: 3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
