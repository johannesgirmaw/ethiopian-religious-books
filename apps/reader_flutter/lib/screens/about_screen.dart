import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../design/reference_assets.dart';
import '../l10n/app_localizations.dart';
import '../router/app_navigation.dart';
import '../common/platform/platform_shell.dart';
import '../desktop/screens/about_screen_body.dart';
import '../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/about_screen_body.dart';
import '../web/widgets/shell/web_overlay_scaffold.dart';
import '../widgets/about_section_card.dart';
import '../widgets/primitives/shared_widgets.dart';

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

    return AppSubPageScaffold(
      title: l10n.aboutTitle,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Image.asset(
                ReferenceAssets.appLogo,
                width: 100,
                height: 88,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            AboutSectionCard(
              title: l10n.aboutAppSectionTitle,
              content: l10n.aboutAppSectionBody,
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 12),
            AboutSectionCard(
              title: l10n.aboutVersionSectionTitle,
              content: l10n.aboutVersionValue,
              icon: Icons.phone_android_rounded,
            ),
            const SizedBox(height: 12),
            AboutSectionCard(
              title: l10n.aboutDevelopersSectionTitle,
              content: l10n.aboutDevelopersBody,
              icon: Icons.code_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
