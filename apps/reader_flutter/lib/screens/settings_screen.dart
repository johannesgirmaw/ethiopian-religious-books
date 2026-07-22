import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/screens/settings_screen_body.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../mobile/screens/mobile_settings_screen.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/settings_screen_body.dart';
import '../web/widgets/shell/web_page_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useWebShell(context)) {
      return const WebPageScaffold(body: SettingsScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopSettingsScreenBody());
    }

    return const MobileSettingsScreen();
  }
}
