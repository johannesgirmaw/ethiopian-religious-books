import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import '../common/platform/platform_shell.dart';
import '../design/app_tokens.dart';
import '../design/pdf_reader_theme.dart';
import '../l10n/app_localizations.dart';
import '../web/layout/app_layout_scope.dart';
import '../providers/api_client.dart';
import '../providers/catalog_providers.dart';
import '../providers/study_providers.dart';
import '../storage/reader_prefs_storage.dart';
import '../utils/book_share.dart';
import '../utils/browser_fullscreen.dart';
import '../utils/pdf_book_loader.dart';
import '../utils/pdf_cache_stub.dart'
    if (dart.library.io) '../utils/pdf_cache_io.dart'
    as pdf_cache;
import 'protected_content_scope.dart';

enum _PdfFitMode { custom, width, page }

/// In-app PDF reader with navigation, zoom, search, themes, and study tools.
///
/// Provide exactly one of [filePath], [uri], [bytes], or [read].
class PdfDocumentReader extends ConsumerStatefulWidget {
  const PdfDocumentReader({
    super.key,
    this.bookId,
    this.bookTitle,
    this.filePath,
    this.uri,
    this.bytes,
    this.fileSize,
    this.read,
    this.sourceName,
    this.headers,
    this.preferRangeAccess = true,
    this.nativeCacheAccess,
    this.initialPage,
    this.preferFitWidth = false,
    this.onlyPages,
    this.padding = EdgeInsets.zero,
    this.loadingLabel = 'Loading PDF…',
    this.errorTitle = 'Could not open PDF',
    this.onRetry,
  }) : assert(
         (filePath != null ? 1 : 0) +
                 (uri != null ? 1 : 0) +
                 (bytes != null ? 1 : 0) +
                 (read != null ? 1 : 0) ==
             1,
         'Provide exactly one of filePath, uri, bytes, or read',
       ),
       assert(
         bytes == null || sourceName != null,
         'bytes requires a sourceName',
       ),
       assert(
         read == null || (fileSize != null && sourceName != null),
         'read requires a fileSize and sourceName',
       );

  final String? bookId;
  final String? bookTitle;
  final String? filePath;
  final Uri? uri;
  final Uint8List? bytes;
  final int? fileSize;
  final PdfByteReader? read;
  final String? sourceName;
  final Map<String, String>? headers;
  final bool preferRangeAccess;
  final PdfBookAccess? nativeCacheAccess;

  /// Preferred start page from cloud progress or deep link (overrides local
  /// prefs when greater than 1).
  final int? initialPage;

  /// When true (e.g. admin embeds), first open fits page width instead of
  /// fit-page so the document uses the full viewer width.
  final bool preferFitWidth;

  /// Optional 1-based page numbers to show (Look Inside live preview).
  /// Other pages are laid out off-screen so only these appear in the scroll.
  final List<int>? onlyPages;
  final EdgeInsets padding;
  final String loadingLabel;
  final String errorTitle;
  final VoidCallback? onRetry;

  @override
  ConsumerState<PdfDocumentReader> createState() => _PdfDocumentReaderState();
}

class _PdfDocumentReaderState extends ConsumerState<PdfDocumentReader> {
  static const _minZoom = 0.25;
  static const _maxZoom = 8.0;
  static const _progressDebounce = Duration(seconds: 1);

  static const _autoScrollTick = Duration(milliseconds: 16);
  static const _autoScrollMinPx = 8.0;
  static const _autoScrollMaxPx = 80.0;
  static const _autoScrollDefaultPx = 40.0;

  late final PdfViewerController _controller;
  final TextEditingController _pageField = TextEditingController();
  final TextEditingController _searchField = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final FocusNode _keysFocus = FocusNode();
  PdfTextSearcher? _searcher;
  VoidCallback? _removeSearchListener;
  Timer? _persistTimer;
  Timer? _progressTimer;
  Timer? _autoScrollTimer;

  var _ready = false;
  var _showSearch = false;
  /// Stays visible until the user hides it; never auto-hides.
  var _chromeVisible = true;
  var _restoringPrefs = false;
  var _applyingFit = false;
  var _searchHadNoTextLayer = false;
  var _autoScrollActive = false;
  var _autoScrollPaused = false;
  /// Target on-screen scroll rate in viewport px/sec (slider range).
  double _autoScrollSpeed = _autoScrollDefaultPx;
  var _fullscreen = false;
  OverlayEntry? _fullscreenEntry;
  int _pageNumber = 1;
  int _pageCount = 1;
  double _zoom = 1;
  _PdfFitMode _fitMode = _PdfFitMode.custom;
  String _themeMode = 'light';
  String _pageMode = 'scroll';
  List<PdfPageBookmark> _bookmarks = const [];
  List<PdfOutlineNode> _outline = const [];
  int _lastTrackedPage = 0;

  Object get _sourceKey =>
      widget.filePath ?? widget.uri ?? widget.sourceName ?? '';

  PdfReaderTheme get _theme => PdfReaderTheme.forMode(_themeMode);

  bool get _narrow {
    // Compact web, phones, and narrow windows default to fit-width.
    if (useMobileShell(context)) return true;
    final width = MediaQuery.sizeOf(context).width;
    if (kIsWeb) {
      final scoped = AppLayoutScope.maybeOf(context)?.width;
      final w = (scoped != null && scoped > 0) ? scoped : width;
      return tierForWidth(w) != AppLayoutTier.expanded;
    }
    return width < 900;
  }

  bool get _isBookmarked => _bookmarks.any((b) => b.pageNumber == _pageNumber);

  bool get _canCycleMatches {
    final searcher = _searcher;
    return searcher != null && searcher.matches.length > 1;
  }

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _controller.addListener(_onControllerChanged);
    if (widget.bookId != null) {
      unawaited(_loadLocalMeta());
    }
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _fullscreenEntry?.markNeedsBuild();
  }

  @override
  void dispose() {
    _fullscreenEntry?.remove();
    _fullscreenEntry = null;
    if (_fullscreen && !kIsWeb) {
      unawaited(
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
      );
    }
    _autoScrollTimer?.cancel();
    _persistTimer?.cancel();
    _progressTimer?.cancel();
    unawaited(_persistViewPrefs(immediate: true));
    unawaited(_flushReadingProgress(force: true));
    _controller.removeListener(_onControllerChanged);
    _removeSearchListener?.call();
    _searcher?.dispose();
    _pageField.dispose();
    _searchField.dispose();
    _searchFocus.dispose();
    _keysFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PdfDocumentReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = oldWidget.filePath ?? oldWidget.uri ?? oldWidget.sourceName;
    if (oldKey != _sourceKey) {
      _stopAutoScroll();
      _teardownSearch();
      setState(() {
        _ready = false;
        _showSearch = false;
        _pageNumber = 1;
        _pageCount = 1;
        _zoom = 1;
        _fitMode = _PdfFitMode.custom;
        _outline = const [];
        _searchHadNoTextLayer = false;
      });
      _pageField.text = '1';
      _searchField.clear();
      if (widget.bookId != null) unawaited(_loadLocalMeta());
    }
  }

  Future<void> _loadLocalMeta() async {
    final bookId = widget.bookId;
    if (bookId == null) return;
    final theme = await ReaderPrefsStorage.readPdfTheme(bookId);
    final mode = await ReaderPrefsStorage.readPdfPageMode(bookId);
    final marks = await ReaderPrefsStorage.readPdfBookmarks(bookId);
    if (!mounted) return;
    setState(() {
      _themeMode = theme;
      _pageMode = mode;
      _bookmarks = marks;
    });
  }

  void _onControllerChanged() {
    if (!_controller.isReady || !mounted) return;
    final page = _controller.pageNumber ?? _pageNumber;
    final count = _controller.pageCount;
    final zoom = _controller.currentZoom;
    if (page == _pageNumber &&
        count == _pageCount &&
        (zoom - _zoom).abs() < 0.001) {
      return;
    }
    final zoomChanged = (zoom - _zoom).abs() >= 0.001;
    final pageChanged = page != _pageNumber;
    setState(() {
      _ready = true;
      _pageNumber = page;
      _pageCount = count;
      _zoom = zoom;
      // Pinch/scroll zoom clears Max/Min; programmatic fit must keep the mode.
      if (!_restoringPrefs &&
          !_applyingFit &&
          zoomChanged &&
          _fitMode != _PdfFitMode.custom) {
        _fitMode = _PdfFitMode.custom;
      }
    });
    if (_pageField.text != '$page') {
      _pageField.text = '$page';
    }
    if (!_restoringPrefs) {
      _schedulePersistViewPrefs();
      if (pageChanged) _scheduleReadingProgress();
    }
  }

  void _schedulePersistViewPrefs() {
    if (widget.bookId == null || !_ready) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(_persistViewPrefs());
    });
  }

  Future<void> _persistViewPrefs({bool immediate = false}) async {
    final bookId = widget.bookId;
    if (bookId == null || !_ready) return;
    final fit = switch (_fitMode) {
      _PdfFitMode.width => 'width',
      _PdfFitMode.page => 'page',
      _PdfFitMode.custom => 'custom',
    };
    await ReaderPrefsStorage.writePdfFit(bookId, fit);
    await ReaderPrefsStorage.writePdfZoom(bookId, _zoom);
    await ReaderPrefsStorage.writePdfPage(bookId, _pageNumber);
    await ReaderPrefsStorage.writePdfTheme(bookId, _themeMode);
    await ReaderPrefsStorage.writePdfPageMode(bookId, _pageMode);
  }

  void _scheduleReadingProgress() {
    if (widget.bookId == null || !_ready || _pageCount < 1) return;
    _progressTimer?.cancel();
    _progressTimer = Timer(_progressDebounce, () {
      unawaited(_flushReadingProgress());
    });
  }

  Future<void> _flushReadingProgress({bool force = false}) async {
    final bookId = widget.bookId;
    if (bookId == null || !_ready || _pageCount < 1) return;
    final percent = ((_pageNumber / _pageCount) * 100).round().clamp(0, 100);
    final fraction = (_pageNumber / _pageCount).clamp(0.0, 1.0);
    await ReaderPrefsStorage.writePdfPage(bookId, _pageNumber);
    await ReaderPrefsStorage.writeProgress(bookId, fraction);
    try {
      ref.invalidate(catalogBookMetaProvider(bookId));
    } catch (_) {}
    try {
      await saveReadingProgress(
        ref,
        bookId,
        chapterKey: 'pdf',
        pageNumber: _pageNumber,
        progressPercent: percent == 0 && _pageNumber > 0 ? 1 : percent,
      );
    } catch (_) {}
    if (force || (_pageNumber - _lastTrackedPage).abs() >= 5) {
      _lastTrackedPage = _pageNumber;
      unawaited(
        trackReaderEvent(
          ref,
          bookId: bookId,
          eventName: 'page_jump',
          chapterKey: 'pdf',
          pageNumber: _pageNumber,
          payload: {'page_count': _pageCount, 'percent': percent},
        ),
      );
    }
  }

  Future<void> _restoreViewPrefs() async {
    final bookId = widget.bookId;
    if (!_controller.isReady) return;
    _restoringPrefs = true;
    try {
      var targetPage = widget.initialPage;
      String? fitRaw;
      double? zoom;
      if (bookId != null) {
        fitRaw = await ReaderPrefsStorage.readPdfFitOrNull(bookId);
        zoom = await ReaderPrefsStorage.readPdfZoom(bookId);
        final localPage = await ReaderPrefsStorage.readPdfPage(bookId);
        if (targetPage == null || targetPage < 1) {
          targetPage = localPage;
        }
      }
      if (!mounted || !_controller.isReady) return;

      final only = widget.onlyPages;
      if (only != null && only.isNotEmpty) {
        targetPage = only.first;
      }
      if (targetPage != null && targetPage > 1) {
        await _controller.goToPage(pageNumber: targetPage);
      }

      if (widget.preferFitWidth) {
        // Admin embeds always fill the viewer width.
        setState(() => _fitMode = _PdfFitMode.width);
        await _applyFitWidth();
      } else if (fitRaw == 'width') {
        setState(() => _fitMode = _PdfFitMode.width);
        await _applyFitWidth();
      } else if (fitRaw == 'page') {
        setState(() => _fitMode = _PdfFitMode.page);
        await _applyFitPage();
      } else if (fitRaw == 'custom' && zoom != null && zoom > 0) {
        setState(() => _fitMode = _PdfFitMode.custom);
        await _controller.setZoom(
          _controller.centerPosition,
          zoom.clamp(_minZoom, _maxZoom),
        );
      } else if (fitRaw == null) {
        // First open: fit width on phone / narrow web; fit page on desktop.
        if (_narrow) {
          setState(() => _fitMode = _PdfFitMode.width);
          await _applyFitWidth();
        } else {
          setState(() => _fitMode = _PdfFitMode.page);
          await _applyFitPage();
        }
      }

      await _loadOutline();
      _scheduleReadingProgress();
    } finally {
      _restoringPrefs = false;
    }
  }

  Future<void> _loadOutline() async {
    if (!_controller.isReady) return;
    try {
      final nodes = await _controller.useDocument((doc) => doc.loadOutline());
      if (!mounted) return;
      setState(() => _outline = nodes ?? const []);
    } catch (_) {
      if (mounted) setState(() => _outline = const []);
    }
  }

  void _setupSearch() {
    if (!_controller.isReady) return;
    _teardownSearch();
    final searcher = PdfTextSearcher(_controller);
    _removeSearchListener = searcher.addListener(() {
      if (mounted) setState(() {});
    });
    _searcher = searcher;
  }

  void _teardownSearch() {
    _removeSearchListener?.call();
    _removeSearchListener = null;
    _searcher?.dispose();
    _searcher = null;
  }

  void _onSearchChanged([String? _]) {
    final query = _searchField.text;
    final searcher = _searcher;
    if (searcher == null) return;
    if (query.trim().isEmpty) {
      searcher.resetTextSearch();
      setState(() => _searchHadNoTextLayer = false);
      return;
    }
    searcher.startTextSearch(
      query,
      caseInsensitive: true,
      goToFirstMatch: true,
    );
    // After a tick, if search finished with zero matches, hint about scans.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || _searcher != searcher) return;
      if (!searcher.isSearching &&
          searcher.matches.isEmpty &&
          query.trim().isNotEmpty) {
        setState(() => _searchHadNoTextLayer = true);
      }
    });
  }

  void _toggleSearch() {
    if (_showSearch) {
      _searcher?.resetTextSearch();
      _searchField.clear();
      _searchFocus.unfocus();
      setState(() {
        _showSearch = false;
        _searchHadNoTextLayer = false;
      });
      return;
    }
    setState(() {
      _showSearch = true;
      _chromeVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  String _searchStatusLabel(AppLocalizations l10n) {
    final query = _searchField.text.trim();
    if (query.isEmpty) return l10n.noMatchesYet;
    final searcher = _searcher;
    if (searcher == null) return l10n.noMatchesYet;
    final total = searcher.matches.length;
    if (total == 0) {
      if (searcher.isSearching) return l10n.pdfSearching;
      if (_searchHadNoTextLayer) return l10n.pdfNoTextLayer;
      return l10n.noMatchesYet;
    }
    final index = (searcher.currentIndex ?? 0) + 1;
    return l10n.matchPosition(index, total);
  }

  List<int>? get _onlyPagesSorted {
    final only = widget.onlyPages;
    if (only == null || only.isEmpty) return null;
    return [...only]..sort();
  }

  int get _navPageCount {
    final only = _onlyPagesSorted;
    return only?.length ?? _pageCount;
  }

  /// 1-based index within [onlyPages], or absolute page when unfiltered.
  int get _navPageNumber {
    final only = _onlyPagesSorted;
    if (only == null) return _pageNumber;
    final i = only.indexOf(_pageNumber);
    if (i >= 0) return i + 1;
    for (var i = 0; i < only.length; i++) {
      if (only[i] >= _pageNumber) return i + 1;
    }
    return only.length;
  }

  Future<void> _goToPage(int page) async {
    if (!_controller.isReady) return;
    final only = _onlyPagesSorted;
    if (only != null) {
      // [page] is a 1-based index into the filtered set when filtering.
      final idx = page.clamp(1, only.length) - 1;
      await _controller.goToPage(pageNumber: only[idx]);
      return;
    }
    final target = page.clamp(1, _controller.pageCount);
    await _controller.goToPage(pageNumber: target);
  }

  Future<void> _goToAbsolutePage(int page) async {
    if (!_controller.isReady) return;
    final only = _onlyPagesSorted;
    if (only != null) {
      if (!only.contains(page)) return;
      await _controller.goToPage(pageNumber: page);
      return;
    }
    await _goToPage(page);
  }

  void _submitPageField() {
    final parsed = int.tryParse(_pageField.text.trim());
    if (parsed == null) {
      _pageField.text = '$_navPageNumber';
      return;
    }
    unawaited(_goToPage(parsed));
  }

  Future<void> _zoomIn() async {
    if (!_controller.isReady) return;
    setState(() => _fitMode = _PdfFitMode.custom);
    final next = (_controller.currentZoom + 0.25).clamp(_minZoom, _maxZoom);
    await _controller.setZoom(_controller.centerPosition, next);
  }

  Future<void> _zoomOut() async {
    if (!_controller.isReady) return;
    setState(() => _fitMode = _PdfFitMode.custom);
    final next = (_controller.currentZoom - 0.25).clamp(_minZoom, _maxZoom);
    await _controller.setZoom(_controller.centerPosition, next);
  }

  Future<void> _resetZoom() async {
    if (!_controller.isReady) return;
    setState(() => _fitMode = _PdfFitMode.custom);
    await _controller.setZoom(_controller.centerPosition, 1.0);
  }

  Future<void> _applyFitWidth() async {
    if (!_controller.isReady) return;
    final page = _controller.pageNumber ?? 1;
    // Fit the current page to the full viewer width and lock horizontally.
    final matrix = _controller.calcMatrixFitWidthForPage(pageNumber: page);
    if (matrix == null) return;
    _applyingFit = true;
    try {
      await _controller.goTo(matrix);
    } finally {
      _applyingFit = false;
    }
  }

  Future<void> _applyFitPage() async {
    if (!_controller.isReady) return;
    final page = _controller.pageNumber ?? 1;
    final zoom = _controller.alternativeFitScale;
    if (zoom == null) return;
    final pageRect = _controller.layout.pageLayouts[page - 1];
    final matrix = _controller.calcMatrixFor(pageRect.center, zoom: zoom);
    _applyingFit = true;
    try {
      await _controller.goTo(matrix);
    } finally {
      _applyingFit = false;
    }
  }

  Future<void> _fitWidth() async {
    setState(() => _fitMode = _PdfFitMode.width);
    // Wait a frame so the viewer uses the full pane after layout.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _applyFitWidth();
    _schedulePersistViewPrefs();
  }

  Future<void> _fitPage() async {
    setState(() => _fitMode = _PdfFitMode.page);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    await _applyFitPage();
    _schedulePersistViewPrefs();
  }

  void _showChrome() {
    if (_chromeVisible) return;
    setState(() => _chromeVisible = true);
  }

  void _hideChrome() {
    if (!_chromeVisible) return;
    setState(() {
      _chromeVisible = false;
      _showSearch = false;
    });
  }

  Future<void> _toggleFullscreen() async {
    if (_fullscreen) {
      await _exitFullscreen();
    } else {
      await _enterFullscreen();
    }
  }

  Future<void> _enterFullscreen() async {
    if (_fullscreen) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    setState(() => _fullscreen = true);
    _fullscreenEntry = OverlayEntry(
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        final theme = _theme;
        final dense = useMobileShell(ctx);
        return Material(
          color: theme.canvas,
          child: SafeArea(
            child: _buildReaderShell(l10n, theme, dense),
          ),
        );
      },
    );
    overlay.insert(_fullscreenEntry!);
    await enterBrowserFullscreen();
    if (!kIsWeb) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  Future<void> _exitFullscreen() async {
    _fullscreenEntry?.remove();
    _fullscreenEntry = null;
    if (_fullscreen && mounted) {
      setState(() => _fullscreen = false);
    } else {
      _fullscreen = false;
    }
    await exitBrowserFullscreen();
    if (!kIsWeb) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Future<void> _cycleTheme() async {
    final next = switch (_themeMode) {
      'light' => 'sepia',
      'sepia' => 'dark',
      _ => 'light',
    };
    setState(() => _themeMode = next);
    final bookId = widget.bookId;
    if (bookId != null) {
      await ReaderPrefsStorage.writePdfTheme(bookId, next);
    }
  }

  Future<void> _togglePageMode() async {
    final next = _pageMode == 'scroll' ? 'single' : 'scroll';
    if (next == 'single') _stopAutoScroll();
    setState(() => _pageMode = next);
    final bookId = widget.bookId;
    if (bookId != null) {
      await ReaderPrefsStorage.writePdfPageMode(bookId, next);
    }
    if (_controller.isReady) {
      _controller.invalidate();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_pageMode == 'single') {
        await _fitPage();
      } else if (_narrow) {
        await _fitWidth();
      }
    }
  }

  /// Target on-screen scroll rate (viewport px/sec). Matrix translate is in
  /// document space, so [_autoScrollStep] divides by current zoom.
  double get _autoScrollScreenPxPerSec => _autoScrollSpeed;

  String _autoScrollSpeedLabel(AppLocalizations l10n) {
    final v = _autoScrollSpeed;
    if (v <= 13) return l10n.pdfAutoScrollSpeedVerySlow;
    if (v <= 29) return l10n.pdfAutoScrollSpeedSlow;
    if (v <= 60) return l10n.pdfAutoScrollSpeedMedium;
    return l10n.pdfAutoScrollSpeedFast;
  }

  Future<void> _toggleAutoScroll() async {
    if (!_ready) return;
    if (_autoScrollActive) {
      _stopAutoScroll();
      return;
    }
    // Continuous vertical scroll needs stacked pages, not single-page strip.
    if (_pageMode == 'single') {
      await _togglePageMode();
      if (!mounted || _pageMode != 'scroll') return;
    }
    setState(() {
      _autoScrollActive = true;
      _autoScrollPaused = false;
      _chromeVisible = true;
    });
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollTick, (_) => _autoScrollStep());
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    if (!_autoScrollActive && !_autoScrollPaused) return;
    if (!mounted) {
      _autoScrollActive = false;
      _autoScrollPaused = false;
      return;
    }
    setState(() {
      _autoScrollActive = false;
      _autoScrollPaused = false;
    });
  }

  void _setAutoScrollSpeed(double value) {
    setState(() {
      _autoScrollSpeed = value.clamp(_autoScrollMinPx, _autoScrollMaxPx);
    });
  }

  void _autoScrollStep() {
    if (!mounted || !_autoScrollActive || _autoScrollPaused) return;
    if (!_controller.isReady) return;
    final visible = _controller.visibleRect;
    final docHeight = _controller.documentSize.height;
    if (visible.bottom >= docHeight - 1) {
      _stopAutoScroll();
      return;
    }
    // Same units as pdfrx arrow-key scroll: negative Y advances downward.
    // Translate is document-space; divide by zoom so Slow/Med/Fast stay
    // constant in viewport pixels (otherwise 271% zoom ~3× real speed).
    final zoom = _controller.currentZoom;
    final safeZoom = zoom > 0.01 ? zoom : 1.0;
    final delta = _autoScrollScreenPxPerSec *
        (_autoScrollTick.inMilliseconds / 1000) /
        safeZoom;
    final matrix = _controller.value.clone()..translate(0.0, -delta);
    _controller.value = matrix;
  }

  void _onAutoScrollInteractionStart(ScaleStartDetails _) {
    if (_autoScrollActive) {
      _autoScrollPaused = true;
    }
  }

  void _onAutoScrollInteractionEnd(ScaleEndDetails _) {
    if (_autoScrollActive && _autoScrollPaused) {
      _autoScrollPaused = false;
    }
  }

  Future<void> _toggleBookmark() async {
    final bookId = widget.bookId;
    if (bookId == null || !_ready) return;
    final l10n = AppLocalizations.of(context);
    final existing = _bookmarks.where((b) => b.pageNumber == _pageNumber);
    if (existing.isNotEmpty) {
      final next = _bookmarks
          .where((b) => b.pageNumber != _pageNumber)
          .toList();
      setState(() => _bookmarks = next);
      await ReaderPrefsStorage.writePdfBookmarks(bookId, next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 5),
            content: Text(l10n.pdfBookmarkRemoved),
          ),
        );
      }
      return;
    }
    final mark = PdfPageBookmark(
      pageNumber: _pageNumber,
      label: l10n.pdfBookmarkLabel(_pageNumber),
      snippet: widget.bookTitle,
      savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    final next = [..._bookmarks, mark]
      ..sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    setState(() => _bookmarks = next);
    await ReaderPrefsStorage.writePdfBookmarks(bookId, next);
    try {
      final dio = ref.read(apiDioProvider);
      await dio.post<void>(
        'study/bookmarks',
        data: {
          'book': bookId,
          'chapter_key': 'pdf',
          'page_number': _pageNumber,
          'label': mark.label,
          'snippet': mark.snippet ?? '',
        },
      );
      ref.invalidate(studyBookmarksProvider(bookId));
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text(l10n.pdfBookmarkAdded(_pageNumber)),
        ),
      );
    }
  }

  Future<void> _shareCite() async {
    final l10n = AppLocalizations.of(context);
    final title = (widget.bookTitle ?? '').trim().isEmpty
        ? l10n.pdfReaderTitle
        : widget.bookTitle!.trim();
    final id = widget.bookId ?? '';
    final link = id.isEmpty
        ? kReaderWebAppOrigin
        : '$kReaderWebAppOrigin/#/pdf/$id?page=$_pageNumber';
    final body = l10n.pdfCiteShareBody(title, _pageNumber, link);
    await SharePlus.instance.share(ShareParams(text: body));
  }

  void _openBookmarksSheet() {
    final l10n = AppLocalizations.of(context);
    final theme = _theme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.toolbarBg,
      builder: (context) {
        if (_bookmarks.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.pdfNoBookmarksYet,
              style: TextStyle(color: theme.toolbarMuted),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: _bookmarks.length,
          itemBuilder: (context, index) {
            final mark = _bookmarks[index];
            return ListTile(
              leading: Icon(Icons.bookmark, color: theme.toolbarFg),
              title: Text(mark.label, style: TextStyle(color: theme.toolbarFg)),
              subtitle: mark.snippet == null
                  ? null
                  : Text(
                      mark.snippet!,
                      style: TextStyle(color: theme.toolbarMuted),
                    ),
              onTap: () {
                Navigator.pop(context);
                unawaited(_goToAbsolutePage(mark.pageNumber));
              },
            );
          },
        );
      },
    );
  }

  void _openOutlineSheet() {
    final l10n = AppLocalizations.of(context);
    final theme = _theme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: theme.toolbarBg,
      builder: (context) {
        if (_outline.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.pdfOutlineEmpty,
              style: TextStyle(color: theme.toolbarMuted),
            ),
          );
        }
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    l10n.pdfOutlineTitle,
                    style: TextStyle(
                      color: theme.toolbarFg,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                ..._flattenOutline(_outline, 0, theme),
              ],
            );
          },
        );
      },
    );
  }

  List<Widget> _flattenOutline(
    List<PdfOutlineNode> nodes,
    int depth,
    PdfReaderTheme theme,
  ) {
    final out = <Widget>[];
    for (final node in nodes) {
      final page = node.dest?.pageNumber;
      out.add(
        ListTile(
          contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
          title: Text(
            node.title.trim().isEmpty ? '—' : node.title,
            style: TextStyle(color: theme.toolbarFg),
          ),
          subtitle: page == null
              ? null
              : Text(
                  AppLocalizations.of(context).pdfBookmarkLabel(page),
                  style: TextStyle(color: theme.toolbarMuted, fontSize: 12),
                ),
          onTap: page == null
              ? null
              : () {
                  Navigator.pop(context);
                  unawaited(_goToAbsolutePage(page));
                },
        ),
      );
      if (node.children.isNotEmpty) {
        out.addAll(_flattenOutline(node.children, depth + 1, theme));
      }
    }
    return out;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_ready) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape && _fullscreen) {
      unawaited(_exitFullscreen());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF &&
        !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isMetaPressed &&
        !_showSearch) {
      unawaited(_toggleFullscreen());
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.pageDown ||
        key == LogicalKeyboardKey.audioVolumeDown) {
      unawaited(_goToPage(_navPageNumber + 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.pageUp ||
        key == LogicalKeyboardKey.audioVolumeUp) {
      unawaited(_goToPage(_navPageNumber - 1));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      if (_chromeVisible) {
        _hideChrome();
      } else {
        _showChrome();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space && !_showSearch) {
      unawaited(_toggleAutoScroll());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  PdfPageLayout _singlePageLayout(List<PdfPage> pages, PdfViewerParams params) {
    final height =
        pages.fold<double>(0, (prev, page) => math.max(prev, page.height)) +
        params.margin * 2;
    final layouts = <Rect>[];
    var x = params.margin;
    for (final page in pages) {
      layouts.add(
        Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height),
      );
      x += page.width + params.margin;
    }
    return PdfPageLayout(pageLayouts: layouts, documentSize: Size(x, height));
  }

  /// Stack only [only] (1-based) pages; park the rest off-screen.
  PdfPageLayout _onlyPagesLayout(
    List<PdfPage> pages,
    PdfViewerParams params,
    List<int> only,
  ) {
    final selected = only.where((n) => n >= 1 && n <= pages.length).toSet();
    final width =
        pages.fold<double>(0, (w, p) => math.max(w, p.width)) +
        params.margin * 2;
    final pageLayout = List<Rect>.filled(pages.length, Rect.zero);
    var y = params.margin;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (selected.contains(i + 1)) {
        pageLayout[i] = Rect.fromLTWH(
          (width - page.width) / 2,
          y,
          page.width,
          page.height,
        );
        y += page.height + params.margin;
      } else {
        pageLayout[i] = const Rect.fromLTWH(-100000, -100000, 0, 0);
      }
    }
    return PdfPageLayout(
      pageLayouts: pageLayout,
      documentSize: Size(width, math.max(y, params.margin * 2)),
    );
  }

  Widget _buildViewer() {
    final searcher = _searcher;
    final theme = _theme;
    final params = PdfViewerParams(
      // Transparent so the outer desk color stays unfiltered by page themes.
      backgroundColor: Colors.transparent,
      // Soft paper lift in both windowed and fullscreen.
      pageDropShadow: BoxShadow(
        color: theme.isDark
            ? Colors.black.withValues(alpha: _fullscreen ? 0.28 : 0.4)
            : Colors.black.withValues(alpha: _fullscreen ? 0.05 : 0.08),
        blurRadius: _fullscreen ? 8 : 10,
        spreadRadius: 0,
        offset: const Offset(0, 2),
      ),
      panEnabled: true,
      scaleEnabled: true,
      minScale: _minZoom,
      maxScale: _maxZoom,
      useAlternativeFitScaleAsMinScale: false,
      scrollByMouseWheel: 0.25,
      enableKeyboardNavigation: true,
      onInteractionStart: _onAutoScrollInteractionStart,
      onInteractionEnd: _onAutoScrollInteractionEnd,
      margin: _pageMode == 'single' ? 24 : 16,
      matchTextColor: AppColors.accent.withValues(alpha: 0.45),
      activeMatchTextColor: AppColors.primary.withValues(alpha: 0.55),
      textSelectionParams: const PdfTextSelectionParams(enabled: false),
      pagePaintCallbacks: searcher == null
          ? null
          : [searcher.pageTextMatchPaintCallback],
      calculateInitialZoom: (document, controller, fitZoom, coverZoom) => 1.0,
      layoutPages: () {
        final only = widget.onlyPages;
        if (only != null && only.isNotEmpty) {
          return (List<PdfPage> pages, PdfViewerParams p) =>
              _onlyPagesLayout(pages, p, only);
        }
        return _pageMode == 'single' ? _singlePageLayout : null;
      }(),
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
        final l10n = AppLocalizations.of(context);
        final label = _downloadLabel(l10n, bytesDownloaded, totalBytes);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: AppSpace.sm),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: theme.toolbarMuted),
              ),
            ],
          ),
        );
      },
      errorBannerBuilder: (context, error, stackTrace, documentRef) {
        final l10n = AppLocalizations.of(context);
        final raw = '$error';
        final message =
            raw.contains('Failed to download') ||
                raw.contains('Timeout') ||
                raw.contains('SocketException')
            ? l10n.pdfConnectionFailed
            : raw;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 48,
                  color: AppColors.errorText,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(
                  widget.errorTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: theme.toolbarFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: theme.toolbarMuted),
                ),
                if (widget.onRetry != null) ...[
                  const SizedBox(height: AppSpace.md),
                  FilledButton(
                    onPressed: widget.onRetry,
                    child: Text(l10n.retry),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      onViewerReady: (document, controller) {
        if (!mounted) return;
        _setupSearch();
        setState(() {
          _ready = true;
          _pageCount = document.pages.length;
          _pageNumber = controller.pageNumber ?? 1;
          _zoom = controller.currentZoom;
        });
        _pageField.text = '$_navPageNumber';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_restoreViewPrefs());
        });
        final cacheAccess = widget.nativeCacheAccess;
        final uri = widget.uri;
        if (cacheAccess != null && uri != null) {
          unawaited(
            pdf_cache.cachePdfFromNetwork(
              cacheAccess,
              uri,
              headers: widget.headers,
            ),
          );
        }
      },
      onPageChanged: (pageNumber) {
        if (!mounted || pageNumber == null) return;
        setState(() => _pageNumber = pageNumber);
        final display = '$_navPageNumber';
        if (_pageField.text != display) {
          _pageField.text = display;
        }
        // Do not re-apply Max/Min on every page — that shifts pages left/right.
        // Zoom stays locked until the user clicks Max/Min or pinches.
        // Look Inside live preview must not overwrite the reader's position.
        if (!_restoringPrefs && widget.onlyPages == null) {
          _schedulePersistViewPrefs();
          _scheduleReadingProgress();
        }
      },
      viewerOverlayBuilder: (context, size, handleLinkTap) => [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (details) {
            handleLinkTap(details.localPosition);
          },
          onDoubleTap: () {
            if (_fitMode == _PdfFitMode.width) {
              unawaited(_fitPage());
            } else {
              unawaited(_fitWidth());
            }
          },
          child: const SizedBox.expand(),
        ),
        PdfViewerScrollThumb(
          controller: _controller,
          thumbSize: const Size(8, 44),
          thumbBuilder: (context, thumbSize, pageNumber, controller) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            );
          },
        ),
        PdfViewerScrollThumb(
          controller: _controller,
          orientation: ScrollbarOrientation.bottom,
          thumbSize: const Size(44, 8),
          thumbBuilder: (context, thumbSize, pageNumber, controller) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            );
          },
        ),
      ],
    );

    if (widget.read != null) {
      return PdfViewer.custom(
        fileSize: widget.fileSize!,
        read: widget.read!,
        sourceName: widget.sourceName!,
        key: ValueKey('${widget.sourceName}|$_pageMode'),
        controller: _controller,
        params: params,
        useProgressiveLoading: true,
      );
    }
    if (widget.bytes != null) {
      return PdfViewer.data(
        widget.bytes!,
        sourceName: widget.sourceName!,
        key: ValueKey('${widget.sourceName}|$_pageMode'),
        controller: _controller,
        params: params,
        useProgressiveLoading: true,
      );
    }
    if (widget.filePath != null) {
      return PdfViewer.file(
        widget.filePath!,
        key: ValueKey('${widget.filePath}|$_pageMode'),
        controller: _controller,
        params: params,
        useProgressiveLoading: true,
      );
    }
    final authPresent = widget.headers?.containsKey('Authorization') ?? false;
    return PdfViewer.uri(
      widget.uri!,
      key: ValueKey(
        '${widget.uri}|auth=$authPresent|range=${widget.preferRangeAccess}|$_pageMode',
      ),
      controller: _controller,
      params: params,
      preferRangeAccess: widget.preferRangeAccess,
      useProgressiveLoading: true,
      headers: widget.headers,
      timeout: const Duration(minutes: 5),
    );
  }

  String _downloadLabel(AppLocalizations l10n, int downloaded, int? total) {
    if (total == null || total <= 0) return widget.loadingLabel;
    var percent = ((downloaded * 100) / total).round();
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;
    return l10n.pdfDownloadProgress(percent);
  }

  Widget _viewerPane(PdfReaderTheme theme) {
    Widget viewer = _buildViewer();
    final pageFilter = theme.pageColorFilter;
    if (pageFilter != null) {
      viewer = ColorFiltered(colorFilter: pageFilter, child: viewer);
    }
    // Join the toolbar as one block: square top when chrome is open.
    final BorderRadius radius;
    if (_fullscreen) {
      radius = BorderRadius.zero;
    } else if (_chromeVisible) {
      radius = BorderRadius.zero;
    } else {
      radius = BorderRadius.circular(AppRadius.sm);
    }
    final Border? border;
    if (_fullscreen) {
      border = null;
    } else if (_chromeVisible) {
      // No top edge — toolbar already draws the outer frame above.
      border = Border(
        left: BorderSide(color: theme.border),
        right: BorderSide(color: theme.border),
        bottom: BorderSide(color: theme.border),
      );
    } else {
      border = Border.all(color: theme.border);
    }
    return CopyProtectedContent(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.canvas,
          borderRadius: radius,
          border: border,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: viewer,
        ),
      ),
    );
  }

  Widget _chromePanel(AppLocalizations l10n, PdfReaderTheme theme, bool dense) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PdfToolbar(
          theme: theme,
          dense: dense,
          enabled: _ready,
          pageNumber: _navPageNumber,
          pageCount: _navPageCount,
          zoom: _zoom,
          fitWidthActive: _fitMode == _PdfFitMode.width,
          fitPageActive: _fitMode == _PdfFitMode.page,
          pageField: _pageField,
          searchActive: _showSearch,
          bookmarked: _isBookmarked,
          pageModeSingle: _pageMode == 'single',
          themeMode: _themeMode,
          autoScrollActive: _autoScrollActive,
          autoScrollSpeed: _autoScrollSpeed,
          autoScrollSpeedMin: _autoScrollMinPx,
          autoScrollSpeedMax: _autoScrollMaxPx,
          searchTooltip: l10n.findInBookLabel,
          firstTooltip: l10n.pdfFirstPage,
          previousTooltip: l10n.pdfPreviousPage,
          nextTooltip: l10n.pdfNextPage,
          lastTooltip: l10n.pdfLastPage,
          zoomOutTooltip: l10n.pdfZoomOut,
          zoomInTooltip: l10n.pdfZoomIn,
          fitWidthTooltip: l10n.pdfFitWidth,
          fitPageTooltip: l10n.pdfFitPage,
          themeTooltip: l10n.pdfThemeTooltip,
          pageModeTooltip: _pageMode == 'single'
              ? l10n.pdfPageModeScroll
              : l10n.pdfPageModeSingle,
          autoScrollTooltip: _autoScrollActive
              ? l10n.pdfAutoScrollStop
              : l10n.pdfAutoScrollStart,
          autoScrollSpeedTooltip: l10n.pdfAutoScrollSpeedTooltip(
            _autoScrollSpeedLabel(l10n),
          ),
          outlineTooltip: l10n.pdfOutlineTitle,
          bookmarksTooltip: l10n.pdfBookmarksTitle,
          bookmarkTooltip: _isBookmarked
              ? l10n.pdfRemoveBookmarkTooltip
              : l10n.pdfAddBookmarkTooltip,
          shareTooltip: l10n.pdfCiteShare,
          hideTooltip: l10n.pdfHideControls,
          fullscreenActive: _fullscreen,
          fullscreenTooltip: _fullscreen
              ? l10n.pdfExitFullscreen
              : l10n.pdfEnterFullscreen,
          onFirst: () => _goToPage(1),
          onPrevious: () => _goToPage(_navPageNumber - 1),
          onNext: () => _goToPage(_navPageNumber + 1),
          onLast: () => _goToPage(_navPageCount),
          onSubmitPage: _submitPageField,
          onZoomIn: _zoomIn,
          onZoomOut: _zoomOut,
          onFitWidth: _fitWidth,
          onFitPage: _fitPage,
          onResetZoom: _resetZoom,
          onToggleSearch: _toggleSearch,
          onCycleTheme: _cycleTheme,
          onTogglePageMode: _togglePageMode,
          onToggleAutoScroll: _toggleAutoScroll,
          onAutoScrollSpeedChanged: _setAutoScrollSpeed,
          onOutline: _openOutlineSheet,
          onBookmarks: _openBookmarksSheet,
          onToggleBookmark: widget.bookId == null ? null : _toggleBookmark,
          onShare: _shareCite,
          onHide: _hideChrome,
          onToggleFullscreen: () => unawaited(_toggleFullscreen()),
        ),
        if (_showSearch) ...[
          const SizedBox(height: AppSpace.xxs),
          _PdfSearchBar(
            theme: theme,
            enabled: _ready,
            controller: _searchField,
            focusNode: _searchFocus,
            hintText: l10n.findInBookHint,
            statusLabel: _searchStatusLabel(l10n),
            searchTooltip: l10n.search,
            previousTooltip: l10n.previousMatch,
            nextTooltip: l10n.nextMatch,
            canCycleMatches: _canCycleMatches,
            onChanged: _onSearchChanged,
            onSubmitted: () => _onSearchChanged(),
            onPreviousMatch: () => _searcher?.goToPrevMatch(),
            onNextMatch: () => _searcher?.goToNextMatch(),
            onClose: _toggleSearch,
          ),
        ],
      ],
    );
  }

  Widget _hiddenChromeChip(AppLocalizations l10n, PdfReaderTheme theme) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: theme.toolbarBg,
        elevation: 2,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: _showChrome,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.visibility_rounded,
                  size: 18,
                  color: theme.toolbarFg,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.pdfShowControls,
                  style: TextStyle(
                    color: theme.toolbarFg,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (_ready) ...[
                  const SizedBox(width: 10),
                  Text(
                    l10n.pdfPageOf(_pageNumber, _pageCount),
                    style: TextStyle(
                      color: theme.toolbarMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaderShell(
    AppLocalizations l10n,
    PdfReaderTheme theme,
    bool dense,
  ) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _chromeVisible
              ? _chromePanel(l10n, theme, dense)
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.xs),
                  child: _hiddenChromeChip(l10n, theme),
                ),
        ),
        Expanded(child: _viewerPane(theme)),
      ],
    );

    return Focus(
      focusNode: _keysFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        padding: _fullscreen ? EdgeInsets.zero : widget.padding,
        child: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = _theme;
    final dense = useMobileShell(context);

    // Real UI lives in the root overlay while fullscreen so the PDF
    // controller is not remounted.
    if (_fullscreen) {
      return ColoredBox(
        color: theme.canvas.withValues(alpha: 0.35),
        child: Center(
          child: Icon(
            Icons.fullscreen_rounded,
            size: 28,
            color: theme.toolbarMuted,
          ),
        ),
      );
    }

    return _buildReaderShell(l10n, theme, dense);
  }
}

class _PdfSearchBar extends StatelessWidget {
  const _PdfSearchBar({
    required this.theme,
    required this.enabled,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.statusLabel,
    required this.searchTooltip,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.canCycleMatches,
    required this.onChanged,
    required this.onSubmitted,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onClose,
  });

  final PdfReaderTheme theme;
  final bool enabled;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String statusLabel;
  final String searchTooltip;
  final String previousTooltip;
  final String nextTooltip;
  final bool canCycleMatches;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onPreviousMatch;
  final VoidCallback onNextMatch;
  final VoidCallback onClose;

  static const _compactBreakpoint = 560.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;
        final field = TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          textInputAction: TextInputAction.search,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: theme.toolbarFg),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: theme.toolbarMuted),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.toolbarMuted,
              size: 20,
            ),
            suffixIcon: IconButton(
              tooltip: searchTooltip,
              onPressed: enabled ? onSubmitted : null,
              icon: Icon(Icons.check_rounded, size: 20, color: theme.toolbarFg),
            ),
            filled: true,
            fillColor: theme.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: BorderSide(color: theme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: BorderSide(color: theme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
        );

        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                statusLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: theme.toolbarMuted),
              ),
            ),
            _ToolbarIcon(
              theme: theme,
              tooltip: previousTooltip,
              icon: Icons.keyboard_arrow_up_rounded,
              onPressed: enabled && canCycleMatches ? onPreviousMatch : null,
            ),
            _ToolbarIcon(
              theme: theme,
              tooltip: nextTooltip,
              icon: Icons.keyboard_arrow_down_rounded,
              onPressed: enabled && canCycleMatches ? onNextMatch : null,
            ),
            _ToolbarIcon(
              theme: theme,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Icons.close_rounded,
              onPressed: onClose,
            ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            color: theme.toolbarBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: theme.border),
          ),
          padding: const EdgeInsets.all(AppSpace.xs),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    field,
                    const SizedBox(height: AppSpace.xxs),
                    controls,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: field),
                    const SizedBox(width: AppSpace.sm),
                    SizedBox(width: 240, child: controls),
                  ],
                ),
        );
      },
    );
  }
}

class _PdfToolbar extends StatelessWidget {
  const _PdfToolbar({
    required this.theme,
    required this.dense,
    required this.enabled,
    required this.pageNumber,
    required this.pageCount,
    required this.zoom,
    required this.fitWidthActive,
    required this.fitPageActive,
    required this.pageField,
    required this.searchActive,
    required this.bookmarked,
    required this.pageModeSingle,
    required this.themeMode,
    required this.autoScrollActive,
    required this.autoScrollSpeed,
    required this.autoScrollSpeedMin,
    required this.autoScrollSpeedMax,
    required this.searchTooltip,
    required this.firstTooltip,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.lastTooltip,
    required this.zoomOutTooltip,
    required this.zoomInTooltip,
    required this.fitWidthTooltip,
    required this.fitPageTooltip,
    required this.themeTooltip,
    required this.pageModeTooltip,
    required this.autoScrollTooltip,
    required this.autoScrollSpeedTooltip,
    required this.outlineTooltip,
    required this.bookmarksTooltip,
    required this.bookmarkTooltip,
    required this.shareTooltip,
    required this.hideTooltip,
    required this.fullscreenActive,
    required this.fullscreenTooltip,
    required this.onFirst,
    required this.onPrevious,
    required this.onNext,
    required this.onLast,
    required this.onSubmitPage,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitWidth,
    required this.onFitPage,
    required this.onResetZoom,
    required this.onToggleSearch,
    required this.onCycleTheme,
    required this.onTogglePageMode,
    required this.onToggleAutoScroll,
    required this.onAutoScrollSpeedChanged,
    required this.onOutline,
    required this.onBookmarks,
    required this.onToggleBookmark,
    required this.onShare,
    required this.onHide,
    required this.onToggleFullscreen,
  });

  final PdfReaderTheme theme;
  final bool dense;
  final bool enabled;
  final int pageNumber;
  final int pageCount;
  final double zoom;
  final bool fitWidthActive;
  final bool fitPageActive;
  final TextEditingController pageField;
  final bool searchActive;
  final bool bookmarked;
  final bool pageModeSingle;
  final String themeMode;
  final bool autoScrollActive;
  final double autoScrollSpeed;
  final double autoScrollSpeedMin;
  final double autoScrollSpeedMax;
  final String searchTooltip;
  final String firstTooltip;
  final String previousTooltip;
  final String nextTooltip;
  final String lastTooltip;
  final String zoomOutTooltip;
  final String zoomInTooltip;
  final String fitWidthTooltip;
  final String fitPageTooltip;
  final String themeTooltip;
  final String pageModeTooltip;
  final String autoScrollTooltip;
  final String autoScrollSpeedTooltip;
  final String outlineTooltip;
  final String bookmarksTooltip;
  final String bookmarkTooltip;
  final String shareTooltip;
  final String hideTooltip;
  final bool fullscreenActive;
  final String fullscreenTooltip;
  final VoidCallback onFirst;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onLast;
  final VoidCallback onSubmitPage;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitWidth;
  final VoidCallback onFitPage;
  final VoidCallback onResetZoom;
  final VoidCallback onToggleSearch;
  final VoidCallback onCycleTheme;
  final VoidCallback onTogglePageMode;
  final VoidCallback onToggleAutoScroll;
  final ValueChanged<double> onAutoScrollSpeedChanged;
  final VoidCallback onOutline;
  final VoidCallback onBookmarks;
  final VoidCallback? onToggleBookmark;
  final VoidCallback onShare;
  final VoidCallback onHide;
  final VoidCallback onToggleFullscreen;

  static const _compactBreakpoint = 720.0;

  IconData get _themeIcon => switch (themeMode) {
    'dark' => Icons.dark_mode_rounded,
    'sepia' => Icons.tonality_rounded,
    _ => Icons.light_mode_rounded,
  };

  static const _controlH = 36.0;

  @override
  Widget build(BuildContext context) {
    final zoomPercent = (zoom * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint || dense;
        final canPrev = enabled && pageNumber > 1;
        final canNext = enabled && pageNumber < pageCount;

        Widget zone(List<Widget> children) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        );

        final pageNav = zone([
          _ToolbarIcon(
            theme: theme,
            tooltip: firstTooltip,
            icon: Icons.first_page_rounded,
            onPressed: canPrev ? onFirst : null,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: previousTooltip,
            icon: Icons.chevron_left_rounded,
            onPressed: canPrev ? onPrevious : null,
          ),
          _PageField(
            theme: theme,
            controller: pageField,
            enabled: enabled,
            pageCount: pageCount,
            onSubmit: onSubmitPage,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: nextTooltip,
            icon: Icons.chevron_right_rounded,
            onPressed: canNext ? onNext : null,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: lastTooltip,
            icon: Icons.last_page_rounded,
            onPressed: canNext ? onLast : null,
          ),
        ]);

        final viewControls = zone([
          _ToolbarIcon(
            theme: theme,
            tooltip: zoomOutTooltip,
            icon: Icons.zoom_out_rounded,
            onPressed: enabled ? onZoomOut : null,
          ),
          _ZoomBadge(
            theme: theme,
            label: '$zoomPercent%',
            enabled: enabled,
            onPressed: onResetZoom,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: zoomInTooltip,
            icon: Icons.zoom_in_rounded,
            onPressed: enabled ? onZoomIn : null,
          ),
          const SizedBox(width: 4),
          _ToolbarIcon(
            theme: theme,
            tooltip: fitWidthTooltip,
            icon: Icons.width_wide_rounded,
            selected: fitWidthActive,
            onPressed: enabled ? onFitWidth : null,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: fitPageTooltip,
            icon: Icons.fit_screen_rounded,
            selected: fitPageActive,
            onPressed: enabled ? onFitPage : null,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: pageModeTooltip,
            icon: pageModeSingle
                ? Icons.view_day_rounded
                : Icons.view_agenda_rounded,
            selected: pageModeSingle,
            onPressed: enabled ? onTogglePageMode : null,
          ),
        ]);

        final studyControls = zone([
          _ToolbarIcon(
            theme: theme,
            tooltip: searchTooltip,
            icon: searchActive
                ? Icons.search_off_rounded
                : Icons.search_rounded,
            selected: searchActive,
            onPressed: enabled ? onToggleSearch : null,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: outlineTooltip,
            icon: Icons.list_alt_rounded,
            onPressed: enabled ? onOutline : null,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: bookmarksTooltip,
            icon: Icons.bookmarks_outlined,
            onPressed: enabled ? onBookmarks : null,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: bookmarkTooltip,
            icon: bookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            selected: bookmarked,
            onPressed: enabled ? onToggleBookmark : null,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: shareTooltip,
            icon: Icons.ios_share_rounded,
            onPressed: enabled ? onShare : null,
          ),
        ]);

        final readingControls = zone([
          _ToolbarIcon(
            theme: theme,
            tooltip: themeTooltip,
            icon: _themeIcon,
            onPressed: onCycleTheme,
          ),
          _AutoScrollControl(
            theme: theme,
            active: autoScrollActive,
            speed: autoScrollSpeed,
            speedMin: autoScrollSpeedMin,
            speedMax: autoScrollSpeedMax,
            enabled: enabled,
            playTooltip: autoScrollTooltip,
            speedTooltip: autoScrollSpeedTooltip,
            onToggle: onToggleAutoScroll,
            onSpeedChanged: onAutoScrollSpeedChanged,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: fullscreenTooltip,
            icon: fullscreenActive
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
            selected: fullscreenActive,
            onPressed: onToggleFullscreen,
          ),
          _ToolbarIcon(
            theme: theme,
            tooltip: hideTooltip,
            icon: Icons.visibility_off_rounded,
            onPressed: onHide,
          ),
        ]);

        Widget divider() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            height: 20,
            child: VerticalDivider(
              width: 1,
              thickness: 1,
              color: theme.border.withValues(alpha: 0.9),
            ),
          ),
        );

        final toolsRow = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            viewControls,
            divider(),
            studyControls,
            divider(),
            readingControls,
          ],
        );

        return Container(
          height: compact ? null : 48,
          decoration: BoxDecoration(
            color: theme.toolbarBg,
            // Square corners so toolbar + viewer read as one panel.
            borderRadius: BorderRadius.zero,
            border: Border(
              top: BorderSide(color: theme.border),
              left: BorderSide(color: theme.border),
              right: BorderSide(color: theme.border),
              bottom: BorderSide(color: theme.border.withValues(alpha: 0.55)),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 10,
            vertical: compact ? 6 : 0,
          ),
          alignment: Alignment.center,
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _controlH,
                      child: Center(child: pageNav),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: _controlH,
                      child: Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: toolsRow,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: pageNav,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: toolsRow,
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.theme,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.selected = false,
  });

  final PdfReaderTheme theme;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final active = onPressed != null;
    final color = !active
        ? theme.toolbarMuted.withValues(alpha: 0.45)
        : selected
        ? AppColors.primary
        : theme.toolbarFg;
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        iconSize: 20,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          backgroundColor: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
        ),
        icon: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _PageField extends StatelessWidget {
  const _PageField({
    required this.theme,
    required this.controller,
    required this.enabled,
    required this.pageCount,
    required this.onSubmit,
  });

  final PdfReaderTheme theme;
  final TextEditingController controller;
  final bool enabled;
  final int pageCount;
  final VoidCallback onSubmit;

  /// Wide enough for the longest page index (e.g. 1860).
  double get _inputWidth {
    final digits = pageCount.toString().length.clamp(1, 5);
    return 12.0 + digits * 8.5;
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.0,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    // One quiet chip for "N / total" — no separate fill on the digits alone.
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _inputWidth,
            child: Center(
              child: TextField(
                controller: controller,
                enabled: enabled,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: base.copyWith(
                  color: enabled
                      ? AppColors.primaryDeep
                      : theme.toolbarMuted,
                ),
                cursorColor: AppColors.primary,
                cursorHeight: 14,
                // App theme fills inputs grey — turn that off here.
                decoration: const InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => onSubmit(),
                onEditingComplete: onSubmit,
              ),
            ),
          ),
          Text(
            ' / $pageCount',
            style: base.copyWith(color: theme.toolbarMuted),
          ),
        ],
      ),
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({
    required this.theme,
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.selected = false,
  });

  final PdfReaderTheme theme;
  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fg = !enabled
        ? theme.toolbarMuted
        : selected
        ? AppColors.primary
        : AppColors.primaryDeep;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          constraints: const BoxConstraints(minWidth: 48),
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : theme.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              height: 1.0,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}

/// Play/pause + speed slider as one reading-control unit.
class _AutoScrollControl extends StatelessWidget {
  const _AutoScrollControl({
    required this.theme,
    required this.active,
    required this.speed,
    required this.speedMin,
    required this.speedMax,
    required this.enabled,
    required this.playTooltip,
    required this.speedTooltip,
    required this.onToggle,
    required this.onSpeedChanged,
  });

  final PdfReaderTheme theme;
  final bool active;
  final double speed;
  final double speedMin;
  final double speedMax;
  final bool enabled;
  final String playTooltip;
  final String speedTooltip;
  final VoidCallback onToggle;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    final play = _ToolbarIcon(
      theme: theme,
      tooltip: playTooltip,
      icon: active ? Icons.pause_rounded : Icons.play_arrow_rounded,
      selected: active,
      onPressed: enabled ? onToggle : null,
    );

    if (!active) return play;

    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.only(left: 2, right: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          play,
          Tooltip(
            message: speedTooltip,
            child: SizedBox(
              width: 96,
              height: 32,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: theme.border,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.12),
                  trackShape: const RoundedRectSliderTrackShape(),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 12,
                  ),
                ),
                child: Slider(
                  value: speed.clamp(speedMin, speedMax),
                  min: speedMin,
                  max: speedMax,
                  onChanged: enabled ? onSpeedChanged : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
