import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../common/platform/platform_shell.dart';
import '../web/layout/app_layout_scope.dart';
import '../desktop/widgets/shell/desktop_auth_shell.dart';
import '../web/widgets/shell/web_auth_shell.dart';

/// Keeps the brand panel fixed while login/register form panes swap.
class AuthRouteShell extends StatelessWidget {
  const AuthRouteShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && useWebShell(context)) {
      return WebAuthShell(child: child);
    }
    if (useDesktopShell(context)) {
      return DesktopAuthShell(child: child);
    }
    return child;
  }
}
