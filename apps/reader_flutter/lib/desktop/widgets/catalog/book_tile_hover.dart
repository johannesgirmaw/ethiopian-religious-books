import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';

/// Hover and keyboard focus wrapper for catalog book tiles on desktop.
class DesktopBookTileHover extends StatefulWidget {
  const DesktopBookTileHover({
    super.key,
    required this.route,
    required this.child,
    this.onActivate,
  });

  final String route;
  final Widget child;

  /// When set, tap and keyboard activation use this instead of [route].
  final VoidCallback? onActivate;

  @override
  State<DesktopBookTileHover> createState() => _DesktopBookTileHoverState();
}

class _DesktopBookTileHoverState extends State<DesktopBookTileHover> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() {
    final custom = widget.onActivate;
    if (custom != null) {
      custom();
      return;
    }
    context.push(widget.route);
  }

  @override
  Widget build(BuildContext context) {
    final elevated = _hovered || _focused;

    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _activate,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppMotion.short,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: elevated ? AppShadows.elevated : null,
              border: _focused
                  ? Border.all(
                      color: AppColors.referencePrimary.withValues(alpha: 0.5),
                      width: 2,
                    )
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
