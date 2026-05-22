import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Programmatic navigation for [ReaderBookPageCurlView].
class ReaderPageCurlController {
  _ReaderBookPageCurlViewState? _state;

  void _attach(_ReaderBookPageCurlViewState state) => _state = state;

  void _detach(_ReaderBookPageCurlViewState state) {
    if (_state == state) _state = null;
  }

  void goToPage(int index) => _state?.goToPage(index);

  bool get isAttached => _state != null;
}

/// Book page reader with edge/corner drag curl (no horizontal PageView).
class ReaderBookPageCurlView extends StatefulWidget {
  const ReaderBookPageCurlView({
    super.key,
    this.controller,
    required this.pageCount,
    required this.initialPage,
    required this.pageBuilder,
    required this.onPageChanged,
    this.backgroundColor = const Color(0xFFFFFCF8),
  });

  final ReaderPageCurlController? controller;
  final int pageCount;
  final int initialPage;
  final IndexedWidgetBuilder pageBuilder;
  final ValueChanged<int> onPageChanged;
  final Color backgroundColor;

  @override
  State<ReaderBookPageCurlView> createState() => _ReaderBookPageCurlViewState();
}

class _ReaderBookPageCurlViewState extends State<ReaderBookPageCurlView>
    with SingleTickerProviderStateMixin {
  /// Right/bottom touch band where curl drag is recognized.
  static const double _edgeWidthFraction = 0.38;
  static const double _cornerHeightFraction = 0.45;

  late int _index;
  double _turnAmount = 0;
  bool _dragging = false;
  bool _turnForward = true;
  Offset? _dragAnchor;
  late AnimationController _settleController;
  Animation<double>? _settleAnim;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _index = widget.initialPage.clamp(0, math.max(0, widget.pageCount - 1));
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addListener(_onSettleTick);
    _settleController.addStatusListener(_onSettleStatus);
  }

  @override
  void didUpdateWidget(ReaderBookPageCurlView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageCount == 0) return;
    final safe = widget.initialPage.clamp(0, widget.pageCount - 1);
    if (safe != _index && !_dragging && !_settleController.isAnimating) {
      setState(() => _index = safe);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _settleController.dispose();
    super.dispose();
  }

  void _onSettleTick() {
    if (_settleAnim != null) {
      setState(() => _turnAmount = _settleAnim!.value);
    }
  }

  void _onSettleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_turnAmount >= 0.98) {
      final next = (_turnForward ? _index + 1 : _index - 1)
          .clamp(0, widget.pageCount - 1);
      if (next != _index) {
        setState(() => _index = next);
        widget.onPageChanged(_index);
      }
    }
    setState(() {
      _turnAmount = 0;
      _dragging = false;
      _dragAnchor = null;
    });
  }

  int get _underIndex {
    if (_turnForward) {
      return (_index + 1).clamp(0, widget.pageCount - 1);
    }
    return (_index - 1).clamp(0, widget.pageCount - 1);
  }

  bool get _canTurnForward => _index < widget.pageCount - 1;
  bool get _canTurnBackward => _index > 0;

  bool _isInForwardZone(double x, double y, double w, double h) =>
      x >= w * (1 - _edgeWidthFraction) &&
      y >= h * (1 - _cornerHeightFraction);

  bool _isInBackwardZone(double x, double y, double w, double h) =>
      x <= w * _edgeWidthFraction && y >= h * (1 - _cornerHeightFraction);

  void _beginDrag(DragStartDetails details, BoxConstraints constraints) {
    if (widget.pageCount <= 1) return;
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    final pos = details.localPosition;
    if (_isInForwardZone(pos.dx, pos.dy, w, h) && _canTurnForward) {
      _turnForward = true;
    } else if (_isInBackwardZone(pos.dx, pos.dy, w, h) && _canTurnBackward) {
      _turnForward = false;
    } else {
      return;
    }
    _settleController.stop();
    setState(() {
      _dragging = true;
      _turnAmount = 0;
      _dragAnchor = pos;
    });
  }

  void _updateDrag(DragUpdateDetails details, BoxConstraints constraints) {
    if (!_dragging || _dragAnchor == null) return;
    final w = constraints.maxWidth;
    final pos = details.localPosition;
    final travel = w * 0.65;
    double amount;
    if (_turnForward) {
      // Drag up-left from bottom-right corner to lift the page.
      final dx = (_dragAnchor!.dx - pos.dx).clamp(0.0, travel);
      final dy = (_dragAnchor!.dy - pos.dy).clamp(0.0, travel * 0.6);
      amount = (dx * 0.75 + dy * 0.55) / travel;
    } else {
      final dx = (pos.dx - _dragAnchor!.dx).clamp(0.0, travel);
      final dy = (_dragAnchor!.dy - pos.dy).clamp(0.0, travel * 0.6);
      amount = (dx * 0.75 + dy * 0.55) / travel;
    }
    setState(() => _turnAmount = amount.clamp(0.0, 1.0));
  }

  void _endDrag() {
    if (!_dragging) return;
    final complete = _turnAmount > 0.35;
    final target = complete ? 1.0 : 0.0;
    _settleController.stop();
    _settleController.reset();
    _settleAnim = Tween<double>(begin: _turnAmount, end: target).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutCubic),
    );
    _settleController.forward();
  }

  void goToPage(int index) {
    if (index < 0 || index >= widget.pageCount) return;
    if (index == _index) return;
    setState(() {
      _index = index;
      _turnAmount = 0;
      _dragging = false;
      _dragAnchor = null;
    });
    widget.onPageChanged(_index);
  }

  /// Diagonal fold line: top hinge moves slightly faster than bottom (book corner).
  _FoldGeometry _foldGeometry(Size size, double t, bool forward) {
    final w = size.width;
    final h = size.height;
    if (forward) {
      return _FoldGeometry(
        topX: w * (1 - t * 0.96),
        bottomX: w * (1 - t * 0.82),
        height: h,
        forward: true,
      );
    }
    return _FoldGeometry(
      topX: w * (t * 0.96),
      bottomX: w * (t * 0.82),
      height: h,
      forward: false,
    );
  }

  Matrix4 _flapTransform(_FoldGeometry fold, double t) {
    final pivotX = (fold.topX + fold.bottomX) / 2;
    final angle = t * math.pi / 2 * (fold.forward ? -1 : 1);
    return Matrix4.identity()
      ..setEntry(3, 2, 0.004)
      ..translateByDouble(pivotX, 0, 0, 1)
      ..rotateY(angle)
      ..translateByDouble(-pivotX, 0, 0, 1);
  }

  Widget _buildFlap({
    required BuildContext context,
    required Size size,
    required int pageIndex,
    required _FoldGeometry fold,
    required double t,
  }) {
    return CustomPaint(
      foregroundPainter: _FlapEdgeShadowPainter(fold: fold, progress: t),
      child: ClipPath(
        clipper: _FlapTrapezoidClipper(fold: fold),
        child: Transform(
          transform: _flapTransform(fold, t),
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.pageBuilder(context, pageIndex),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: fold.forward
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    end: fold.forward
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    colors: [
                      Colors.brown.withValues(alpha: 0.18 + t * 0.12),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.35],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageStack(BuildContext context, Size size) {
    final t = _turnAmount.clamp(0.0, 1.0);
    final turning = t > 0.004;
    final under = turning ? _underIndex : _index;

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: widget.pageBuilder(context, under),
        ),
        if (turning) ...[
          CustomPaint(
            size: size,
            painter: _UnderPageRevealShadow(
              fold: _foldGeometry(size, t, _turnForward),
              progress: t,
            ),
          ),
          Positioned.fill(
            child: _buildFlap(
              context: context,
              size: size,
              pageIndex: _index,
              fold: _foldGeometry(size, t, _turnForward),
              t: t,
            ),
          ),
        ] else
          Positioned.fill(
            child: widget.pageBuilder(context, _index),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pageCount <= 0) {
      return ColoredBox(color: widget.backgroundColor);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final edgeWidth = size.width * _edgeWidthFraction;
        final cornerHeight = size.height * _cornerHeightFraction;

        return ColoredBox(
          color: widget.backgroundColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildPageStack(context, size),
              if (_canTurnBackward)
                Positioned(
                  left: 0,
                  bottom: 0,
                  width: edgeWidth,
                  height: cornerHeight,
                  child: _PageTurnDragZone(
                    onStart: (d) => _beginDrag(d, constraints),
                    onUpdate: (d) => _updateDrag(d, constraints),
                    onEnd: _endDrag,
                    hintAlignment: Alignment.bottomLeft,
                  ),
                ),
              if (_canTurnForward)
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: edgeWidth,
                  height: cornerHeight,
                  child: _PageTurnDragZone(
                    onStart: (d) => _beginDrag(d, constraints),
                    onUpdate: (d) => _updateDrag(d, constraints),
                    onEnd: _endDrag,
                    hintAlignment: Alignment.bottomRight,
                    showCurlHint: !_dragging && _turnAmount < 0.01,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FoldGeometry {
  const _FoldGeometry({
    required this.topX,
    required this.bottomX,
    required this.height,
    required this.forward,
  });

  final double topX;
  final double bottomX;
  final double height;
  final bool forward;
}

class _PageTurnDragZone extends StatelessWidget {
  const _PageTurnDragZone({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.hintAlignment,
    this.showCurlHint = false,
  });

  final void Function(DragStartDetails) onStart;
  final void Function(DragUpdateDetails) onUpdate;
  final VoidCallback onEnd;
  final Alignment hintAlignment;
  final bool showCurlHint;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: onStart,
      onPanUpdate: onUpdate,
      onPanEnd: (_) => onEnd(),
      onPanCancel: onEnd,
      child: showCurlHint
          ? Align(
              alignment: hintAlignment,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.auto_stories_outlined,
                  size: 30,
                  color: Colors.black.withValues(alpha: 0.22),
                ),
              ),
            )
          : const SizedBox.expand(),
    );
  }
}

class _FlapTrapezoidClipper extends CustomClipper<Path> {
  _FlapTrapezoidClipper({required this.fold});

  final _FoldGeometry fold;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (fold.forward) {
      path
        ..moveTo(fold.topX, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, fold.height)
        ..lineTo(fold.bottomX, fold.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(fold.topX, 0)
        ..lineTo(fold.bottomX, fold.height)
        ..lineTo(0, fold.height)
        ..close();
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _FlapTrapezoidClipper oldClipper) =>
      oldClipper.fold.topX != fold.topX ||
      oldClipper.fold.bottomX != fold.bottomX;
}

class _FlapEdgeShadowPainter extends CustomPainter {
  _FlapEdgeShadowPainter({required this.fold, required this.progress});

  final _FoldGeometry fold;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.02) return;
    final path = Path();
    if (fold.forward) {
      path
        ..moveTo(fold.topX, 0)
        ..lineTo(fold.topX + 6, 0)
        ..lineTo(fold.bottomX + 8, fold.height)
        ..lineTo(fold.bottomX, fold.height)
        ..close();
    } else {
      path
        ..moveTo(fold.topX, 0)
        ..lineTo(fold.topX - 6, 0)
        ..lineTo(fold.bottomX - 8, fold.height)
        ..lineTo(fold.bottomX, fold.height)
        ..close();
    }
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.5), 10, false);
  }

  @override
  bool shouldRepaint(covariant _FlapEdgeShadowPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fold.topX != fold.topX;
}

class _UnderPageRevealShadow extends CustomPainter {
  _UnderPageRevealShadow({required this.fold, required this.progress});

  final _FoldGeometry fold;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < 0.03) return;
    final w = size.width;
    final h = size.height;
    final shade = Path();
    if (fold.forward) {
      shade
        ..moveTo(fold.topX, 0)
        ..lineTo(w, 0)
        ..lineTo(w, h)
        ..lineTo(fold.bottomX, h)
        ..close();
    } else {
      shade
        ..moveTo(0, 0)
        ..lineTo(fold.topX, 0)
        ..lineTo(fold.bottomX, h)
        ..lineTo(0, h)
        ..close();
    }
    canvas.drawPath(
      shade,
      Paint()
        ..shader = LinearGradient(
          begin: fold.forward ? Alignment.centerLeft : Alignment.centerRight,
          end: fold.forward ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Colors.black.withValues(alpha: 0.08),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
  }

  @override
  bool shouldRepaint(covariant _UnderPageRevealShadow oldDelegate) =>
      oldDelegate.progress != progress;
}
