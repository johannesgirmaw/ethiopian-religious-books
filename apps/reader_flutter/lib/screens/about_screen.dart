import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/screens/about_screen_body.dart';
import '../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../mobile/screens/mobile_about_screen.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/about_screen_body.dart';
import '../web/widgets/shell/web_overlay_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (useWebShell(context)) {
      return WebOverlayScaffold(
        title: l10n.aboutTitle,
        currentLocation: GoRouterState.of(context).matchedLocation,
        appTitle: l10n.appTitle,
        body: const AboutScreenBody(),
      );
    }

    if (useDesktopShell(context)) {
      return DesktopOverlayScaffold(
        title: l10n.aboutTitle,
        currentLocation: GoRouterState.of(context).matchedLocation,
        appTitle: l10n.appTitle,
        body: const DesktopAboutScreenBody(),
      );
    }

    return const MobileAboutScreen();
  }
}
