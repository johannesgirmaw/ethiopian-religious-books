import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';

/// Hover and keyboard focus wrapper for catalog book tiles on web.
class WebBookTileHover extends StatefulWidget {
  const WebBookTileHover({
    super.key,
    required this.route,
    required this.child,
  });

  final String route;
  final Widget child;

  @override
  State<WebBookTileHover> createState() => _WebBookTileHoverState();
}

class _WebBookTileHoverState extends State<WebBookTileHover> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() => context.push(widget.route);

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
          child: AnimatedScale(
            scale: elevated ? 1.02 : 1.0,
            duration: AppMotion.short,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: AppMotion.short,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.cardV2),
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
      ),
    );
  }
}
