import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/platform_security.dart';
import 'protected_content_guards_stub.dart'
    if (dart.library.html) 'protected_content_guards_web.dart';

/// Enables native screenshot/capture protection while a reader route is open.
class ContentProtectionLifecycle extends StatefulWidget {
  const ContentProtectionLifecycle({super.key, required this.child});

  final Widget child;

  @override
  State<ContentProtectionLifecycle> createState() =>
      _ContentProtectionLifecycleState();
}

class _ContentProtectionLifecycleState extends State<ContentProtectionLifecycle> {
  @override
  void initState() {
    super.initState();
    PlatformSecurity.setSecureMode(true);
    enableWebContentGuards(true);
  }

  @override
  void dispose() {
    enableWebContentGuards(false);
    PlatformSecurity.setSecureMode(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Blocks text selection and copy shortcuts for book body content.
///
/// Place toolbars, search fields, and navigation chrome **outside** this widget
/// so users can still type queries and use page controls.
class CopyProtectedContent extends StatelessWidget {
  const CopyProtectedContent({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            const _BlockCopyIntent(),
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
            const _BlockCopyIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            const _BlockSelectAllIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            const _BlockSelectAllIntent(),
        const SingleActivator(LogicalKeyboardKey.insert, shift: true):
            const _BlockCopyIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _BlockCopyIntent: _ConsumeAction(),
          _BlockSelectAllIntent: _ConsumeAction(),
          CopySelectionTextIntent: _ConsumeAction(),
          SelectAllTextIntent: _ConsumeAction(),
        },
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          child: SelectionContainer.disabled(
            child: GestureDetector(
              onSecondaryTap: () {},
              behavior: HitTestBehavior.deferToChild,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience wrapper when the whole screen is reader content (no chrome).
class ProtectedContentScope extends StatelessWidget {
  const ProtectedContentScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ContentProtectionLifecycle(
      child: CopyProtectedContent(child: child),
    );
  }
}

class _BlockCopyIntent extends Intent {
  const _BlockCopyIntent();
}

class _BlockSelectAllIntent extends Intent {
  const _BlockSelectAllIntent();
}

class _ConsumeAction extends Action<Intent> {
  @override
  Object? invoke(Intent intent) => null;
}
