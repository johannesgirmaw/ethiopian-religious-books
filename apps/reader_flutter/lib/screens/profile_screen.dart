import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/screens/profile_screen_body.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../mobile/screens/mobile_profile_screen.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/profile_screen_body.dart';
import '../web/widgets/shell/web_page_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useWebShell(context)) {
      return const WebPageScaffold(body: ProfileScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopProfileScreenBody());
    }

    return const MobileProfileScreen();
  }
}
