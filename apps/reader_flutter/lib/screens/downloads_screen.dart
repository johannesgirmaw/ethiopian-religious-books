import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/platform/platform_shell.dart';
import '../desktop/screens/downloads_screen_body.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../mobile/screens/mobile_downloads_screen.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/downloads_screen_body.dart';
import '../web/widgets/shell/web_page_scaffold.dart';

/// Offline downloads hub — saved books and active download jobs (not the full catalog).
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useWebShell(context)) {
      return const WebPageScaffold(body: DownloadsScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopDownloadsScreenBody());
    }

    return const MobileDownloadsScreen();
  }
}
