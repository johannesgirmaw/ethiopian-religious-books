import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import 'protected_content_scope.dart';

/// In-app PDF reader with navigation, zoom, and text search (ported from gizecare).
///
/// Provide either [filePath] (native cache file) or [uri] (presigned / blob URL on web).
class PdfDocumentReader extends StatefulWidget {
  const PdfDocumentReader({
    super.key,
    this.filePath,
    this.uri,
    this.padding = EdgeInsets.zero,
    this.loadingLabel = 'Loading PDF…',
    this.errorTitle = 'Could not open PDF',
  }) : assert(
          (filePath != null) ^ (uri != null),
          'Provide exactly one of filePath or uri',
        );

  final String? filePath;
  final Uri? uri;
  final EdgeInsets padding;
  final String loadingLabel;
  final String errorTitle;

  @override
  State<PdfDocumentReader> createState() => _PdfDocumentReaderState();
}

class _PdfDocumentReaderState extends State<PdfDocumentReader> {
  late final PdfViewerController _controller;
  final TextEditingController _pageField = TextEditingController();
  final TextEditingController _searchField = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  PdfTextSearcher? _searcher;
  VoidCallback? _removeSearchListener;
  var _ready = false;
  var _showSearch = false;
  int _pageNumber = 1;
  int _pageCount = 1;
  double _zoom = 1;

  Object get _sourceKey => widget.filePath ?? widget.uri!;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _removeSearchListener?.call();
    _searcher?.dispose();
    _pageField.dispose();
    _searchField.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PdfDocumentReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = oldWidget.filePath ?? oldWidget.uri;
    if (oldKey != _sourceKey) {
      _teardownSearch();
      setState(() {
        _ready = false;
        _showSearch = false;
        _pageNumber = 1;
        _pageCount = 1;
        _zoom = 1;
      });
      _pageField.text = '1';
      _searchField.clear();
    }
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
    setState(() {
      _ready = true;
      _pageNumber = page;
      _pageCount = count;
      _zoom = zoom;
    });
    if (_pageField.text != '$page') {
      _pageField.text = '$page';
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
      return;
    }
    searcher.startTextSearch(
      query,
      caseInsensitive: true,
      goToFirstMatch: true,
    );
  }

  void _toggleSearch() {
    if (_showSearch) {
      _searcher?.resetTextSearch();
      _searchField.clear();
      _searchFocus.unfocus();
      setState(() => _showSearch = false);
      return;
    }
    setState(() => _showSearch = true);
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
      return searcher.isSearching ? l10n.pdfSearching : l10n.noMatchesYet;
    }

    final current = searcher.currentIndex;
    if (current != null) {
      return l10n.matchPosition(current + 1, total);
    }
    return l10n.matchCount(total);
  }

  bool get _canCycleMatches {
    final searcher = _searcher;
    if (searcher == null) return false;
    return searcher.matches.length >= 2;
  }

  Future<void> _goToPage(int page) async {
    if (!_controller.isReady) return;
    final target = page.clamp(1, _controller.pageCount);
    await _controller.goToPage(pageNumber: target);
  }

  Future<void> _submitPageField() async {
    final parsed = int.tryParse(_pageField.text.trim());
    if (parsed == null) {
      _pageField.text = '$_pageNumber';
      return;
    }
    await _goToPage(parsed);
  }

  static const _minZoom = 0.25;
  static const _maxZoom = 8.0;
  static const _zoomStep = 0.25;

  Future<void> _setZoomPercent(double zoom) async {
    if (!_controller.isReady) return;
    final clamped = zoom.clamp(_minZoom, _maxZoom);
    await _controller.setZoom(_controller.centerPosition, clamped);
  }

  Future<void> _zoomIn() async {
    if (!_controller.isReady) return;
    final current = _controller.currentZoom;
    final stepped = ((current / _zoomStep).round() * _zoomStep) + _zoomStep;
    await _setZoomPercent(stepped);
  }

  Future<void> _zoomOut() async {
    if (!_controller.isReady) return;
    final current = _controller.currentZoom;
    final stepped = ((current / _zoomStep).round() * _zoomStep) - _zoomStep;
    await _setZoomPercent(stepped);
  }

  Future<void> _fitWidth() async {
    if (!_controller.isReady) return;
    final page = _controller.pageNumber ?? 1;
    final fits = _controller.calcFitZoomMatrices();
    if (fits.isNotEmpty) {
      await _controller.goTo(fits.first.matrix);
      return;
    }
    final zoom = _controller.alternativeFitScale ?? _controller.coverScale;
    await _setZoomPercent(zoom);
    await _controller.goToPage(pageNumber: page);
  }

  Future<void> _fitPage() async {
    if (!_controller.isReady) return;
    final page = _controller.pageNumber ?? 1;
    await _controller.goTo(
      _controller.calcMatrixForPage(
        pageNumber: page,
        anchor: PdfPageAnchor.all,
      ),
    );
  }

  Future<void> _resetZoom() async {
    await _setZoomPercent(1.0);
  }

  Widget _buildViewer() {
    final searcher = _searcher;
    final params = PdfViewerParams(
      backgroundColor: AppColors.surfaceStrong,
      panEnabled: true,
      scaleEnabled: true,
      minScale: 0.25,
      maxScale: 8,
      useAlternativeFitScaleAsMinScale: false,
      scrollByMouseWheel: 0.25,
      enableKeyboardNavigation: true,
      margin: 16,
      matchTextColor: AppColors.accent.withValues(alpha: 0.45),
      activeMatchTextColor: AppColors.primary.withValues(alpha: 0.55),
      textSelectionParams: const PdfTextSelectionParams(enabled: false),
      pagePaintCallbacks: searcher == null
          ? null
          : [searcher.pageTextMatchPaintCallback],
      calculateInitialZoom: (document, controller, fitZoom, coverZoom) => 1.0,
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: AppSpace.sm),
              Text(
                widget.loadingLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        );
      },
      errorBannerBuilder: (context, error, stackTrace, documentRef) {
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
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
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
        _pageField.text = '$_pageNumber';
      },
      onPageChanged: (pageNumber) {
        if (!mounted || pageNumber == null) return;
        setState(() => _pageNumber = pageNumber);
        if (_pageField.text != '$pageNumber') {
          _pageField.text = '$pageNumber';
        }
      },
      viewerOverlayBuilder: (context, size, handleLinkTap) => [
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

    if (widget.filePath != null) {
      return PdfViewer.file(
        widget.filePath!,
        key: ValueKey(widget.filePath),
        controller: _controller,
        params: params,
      );
    }
    return PdfViewer.uri(
      widget.uri!,
      key: ValueKey(widget.uri.toString()),
      controller: _controller,
      params: params,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PdfToolbar(
            enabled: _ready,
            pageNumber: _pageNumber,
            pageCount: _pageCount,
            zoom: _zoom,
            pageField: _pageField,
            searchActive: _showSearch,
            searchTooltip: l10n.findInBookLabel,
            onFirst: () => _goToPage(1),
            onPrevious: () => _goToPage(_pageNumber - 1),
            onNext: () => _goToPage(_pageNumber + 1),
            onLast: () => _goToPage(_pageCount),
            onSubmitPage: _submitPageField,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onFitWidth: _fitWidth,
            onFitPage: _fitPage,
            onResetZoom: _resetZoom,
            onToggleSearch: _toggleSearch,
          ),
          if (_showSearch) ...[
            const SizedBox(height: AppSpace.xxs),
            _PdfSearchBar(
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
          const SizedBox(height: AppSpace.xs),
          Expanded(
            child: CopyProtectedContent(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surfaceStrong,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: _buildViewer(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfSearchBar extends StatelessWidget {
  const _PdfSearchBar({
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
            suffixIcon: IconButton(
              tooltip: searchTooltip,
              onPressed: enabled ? onSubmitted : null,
              icon: const Icon(Icons.check_rounded, size: 20),
            ),
            filled: true,
            fillColor: AppColors.surfaceCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpace.sm,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.7),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            _ToolbarIcon(
              tooltip: previousTooltip,
              icon: Icons.keyboard_arrow_up_rounded,
              onPressed: enabled && canCycleMatches ? onPreviousMatch : null,
            ),
            _ToolbarIcon(
              tooltip: nextTooltip,
              icon: Icons.keyboard_arrow_down_rounded,
              onPressed: enabled && canCycleMatches ? onNextMatch : null,
            ),
            _ToolbarIcon(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: Icons.close_rounded,
              onPressed: onClose,
            ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
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
                    SizedBox(width: 220, child: controls),
                  ],
                ),
        );
      },
    );
  }
}

class _PdfToolbar extends StatelessWidget {
  const _PdfToolbar({
    required this.enabled,
    required this.pageNumber,
    required this.pageCount,
    required this.zoom,
    required this.pageField,
    required this.searchActive,
    required this.searchTooltip,
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
  });

  final bool enabled;
  final int pageNumber;
  final int pageCount;
  final double zoom;
  final TextEditingController pageField;
  final bool searchActive;
  final String searchTooltip;
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

  static const _compactBreakpoint = 560.0;

  @override
  Widget build(BuildContext context) {
    final zoomPercent = (zoom * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;
        final canPrev = enabled && pageNumber > 1;
        final canNext = enabled && pageNumber < pageCount;

        final pageNav = _ToolbarGroup(
          children: [
            _ToolbarIcon(
              tooltip: 'First page',
              icon: Icons.first_page_rounded,
              onPressed: canPrev ? onFirst : null,
            ),
            _ToolbarIcon(
              tooltip: 'Previous page',
              icon: Icons.chevron_left_rounded,
              onPressed: canPrev ? onPrevious : null,
            ),
            _PageField(
              controller: pageField,
              enabled: enabled,
              pageCount: pageCount,
              onSubmit: onSubmitPage,
            ),
            _ToolbarIcon(
              tooltip: 'Next page',
              icon: Icons.chevron_right_rounded,
              onPressed: canNext ? onNext : null,
            ),
            _ToolbarIcon(
              tooltip: 'Last page',
              icon: Icons.last_page_rounded,
              onPressed: canNext ? onLast : null,
            ),
          ],
        );

        final zoomControls = _ToolbarGroup(
          children: [
            _ToolbarIcon(
              tooltip: 'Zoom out',
              icon: Icons.zoom_out_rounded,
              onPressed: enabled ? onZoomOut : null,
            ),
            _ZoomBadge(
              label: '$zoomPercent%',
              enabled: enabled,
              onPressed: onResetZoom,
            ),
            _ToolbarIcon(
              tooltip: 'Zoom in',
              icon: Icons.zoom_in_rounded,
              onPressed: enabled ? onZoomIn : null,
            ),
          ],
        );

        final fitControls = _ToolbarGroup(
          children: [
            _ToolbarIcon(
              tooltip: 'Fit width',
              icon: Icons.fit_screen_outlined,
              onPressed: enabled ? onFitWidth : null,
            ),
            _ToolbarIcon(
              tooltip: 'Fit page',
              icon: Icons.fullscreen_rounded,
              onPressed: enabled ? onFitPage : null,
            ),
          ],
        );

        final searchControl = _ToolbarGroup(
          children: [
            _ToolbarIcon(
              tooltip: searchTooltip,
              icon: searchActive ? Icons.search_off_rounded : Icons.search_rounded,
              onPressed: enabled ? onToggleSearch : null,
            ),
          ],
        );

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpace.xs : AppSpace.sm,
            vertical: AppSpace.xs,
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: pageNav),
                    const SizedBox(height: AppSpace.xxs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        zoomControls,
                        const SizedBox(width: AppSpace.xs),
                        fitControls,
                        const SizedBox(width: AppSpace.xs),
                        searchControl,
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: pageNav,
                      ),
                    ),
                    zoomControls,
                    const SizedBox(width: AppSpace.xs),
                    fitControls,
                    const SizedBox(width: AppSpace.xs),
                    searchControl,
                  ],
                ),
        );
      },
    );
  }
}

class _ToolbarGroup extends StatelessWidget {
  const _ToolbarGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final active = onPressed != null;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      iconSize: 22,
      icon: Icon(
        icon,
        color: active ? AppColors.textPrimary : AppColors.textTertiary,
      ),
    );
  }
}

class _PageField extends StatelessWidget {
  const _PageField({
    required this.controller,
    required this.enabled,
    required this.pageCount,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final int pageCount;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 48,
          height: 34,
          child: TextField(
            controller: controller,
            enabled: enabled,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceCard,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xs),
                borderSide: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.7),
                ),
              ),
            ),
            onSubmitted: (_) => onSubmit(),
            onEditingComplete: onSubmit,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '/ $pageCount',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  const _ZoomBadge({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.xs),
          child: Container(
            constraints: const BoxConstraints(minWidth: 52, minHeight: 34),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: enabled
                        ? AppColors.primaryDeep
                        : AppColors.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
