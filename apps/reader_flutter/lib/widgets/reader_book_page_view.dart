import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Programmatic navigation for [ReaderBookPageView].
class ReaderPageController {
  _ReaderBookPageViewState? _state;

  void _attach(_ReaderBookPageViewState state) => _state = state;

  void _detach(_ReaderBookPageViewState state) {
    if (_state == state) _state = null;
  }

  void goToPage(int index) => _state?.goToPage(index);

  bool get isAttached => _state != null;
}

/// One page at a time with overlay side arrow navigation.
class ReaderBookPageView extends StatefulWidget {
  const ReaderBookPageView({
    super.key,
    this.controller,
    required this.pageCount,
    required this.initialPage,
    required this.pageBuilder,
    required this.onPageChanged,
    this.onTap,
    this.showArrows = false,
    this.onInteraction,
    this.backgroundColor = const Color(0xFFFFFCF8),
  });

  final ReaderPageController? controller;
  final int pageCount;
  final int initialPage;
  final IndexedWidgetBuilder pageBuilder;
  final ValueChanged<int> onPageChanged;
  final VoidCallback? onTap;
  final bool showArrows;
  final VoidCallback? onInteraction;
  final Color backgroundColor;

  @override
  State<ReaderBookPageView> createState() => _ReaderBookPageViewState();
}

class _ReaderBookPageViewState extends State<ReaderBookPageView> {
  late int _index;
  Offset? _pointerDown;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
    _index = widget.initialPage.clamp(0, math.max(0, widget.pageCount - 1));
  }

  @override
  void didUpdateWidget(ReaderBookPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pageCount == 0) return;
    final safe = widget.initialPage.clamp(0, widget.pageCount - 1);
    if (safe != _index) {
      setState(() => _index = safe);
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    super.dispose();
  }

  bool get _canGoBack => _index > 0;
  bool get _canGoForward => _index < widget.pageCount - 1;

  void _goBack() {
    if (!_canGoBack) return;
    setState(() => _index -= 1);
    widget.onPageChanged(_index);
    widget.onInteraction?.call();
  }

  void _goForward() {
    if (!_canGoForward) return;
    setState(() => _index += 1);
    widget.onPageChanged(_index);
    widget.onInteraction?.call();
  }

  void goToPage(int index) {
    if (index < 0 || index >= widget.pageCount) return;
    if (index == _index) return;
    setState(() => _index = index);
    widget.onPageChanged(_index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pageCount <= 0) {
      return ColoredBox(color: widget.backgroundColor);
    }

    return ColoredBox(
      color: widget.backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (event) => _pointerDown = event.position,
            onPointerUp: (event) {
              final start = _pointerDown;
              _pointerDown = null;
              if (start == null || widget.onTap == null) return;
              if ((event.position - start).distance > 18) return;
              widget.onTap!();
            },
            onPointerCancel: (_) => _pointerDown = null,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // Top-align pages so short content starts at the top, not centered.
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: widget.pageBuilder(context, _index),
              ),
            ),
          ),
          if (_canGoBack)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _PageArrowButton(
                  icon: Icons.chevron_left_rounded,
                  onPressed: _goBack,
                  visible: widget.showArrows,
                ),
              ),
            ),
          if (_canGoForward)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: _PageArrowButton(
                  icon: Icons.chevron_right_rounded,
                  onPressed: _goForward,
                  visible: widget.showArrows,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PageArrowButton extends StatelessWidget {
  const _PageArrowButton({
    required this.icon,
    required this.onPressed,
    required this.visible,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: IgnorePointer(
        ignoring: !visible,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(24),
              child: Ink(
                width: 40,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EE).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
