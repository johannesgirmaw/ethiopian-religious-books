import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';

import '../design/app_tokens.dart';

/// In-app PDF reader with navigation and zoom controls (ported from gizecare).
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
  var _ready = false;
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
    _pageField.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PdfDocumentReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = oldWidget.filePath ?? oldWidget.uri;
    if (oldKey != _sourceKey) {
      setState(() {
        _ready = false;
        _pageNumber = 1;
        _pageCount = 1;
        _zoom = 1;
      });
      _pageField.text = '1';
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
          ),
          const SizedBox(height: AppSpace.xs),
          Expanded(
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
        ],
      ),
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
  });

  final bool enabled;
  final int pageNumber;
  final int pageCount;
  final double zoom;
  final TextEditingController pageField;
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
