import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/screens/home_screen_body.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../mobile/screens/mobile_home_screen.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/home_screen_body.dart';
import '../web/widgets/shell/web_page_scaffold.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useWebShell(context)) {
      return const WebPageScaffold(body: HomeScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopHomeScreenBody());
    }

    return const MobileHomeScreen();
  }
}
