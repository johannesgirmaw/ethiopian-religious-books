import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../common/platform/platform_shell.dart';
import '../../../desktop/widgets/shell/desktop_auth_layout.dart';
import '../../layout/app_layout_scope.dart';
import '../../../widgets/primitives/auth_screen_layout.dart';
import 'web_auth_layout.dart';

/// Picks mobile or wide-web auth chrome.
class AdaptiveAuthLayout extends StatelessWidget {
  const AdaptiveAuthLayout({
    super.key,
    required this.headline,
    required this.subtitle,
    required this.formChild,
    this.footer,
  });

  final String headline;
  final String subtitle;
  final Widget formChild;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb && useWebShell(context)) {
      return WebAuthLayout(
        headline: headline,
        subtitle: subtitle,
        formChild: formChild,
        footer: footer,
      );
    }

    if (useDesktopShell(context)) {
      return DesktopAuthLayout(
        headline: headline,
        subtitle: subtitle,
        formChild: formChild,
        footer: footer,
      );
    }

    return AuthScreenLayout(
      headline: headline,
      subtitle: subtitle,
      formChild: formChild,
      footer: footer,
    );
  }
}
