import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/platform/platform_shell.dart';
import '../../desktop/screens/admin_books_screen_body.dart';
import '../../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../../mobile/screens/mobile_admin_books_screen.dart';
import '../../web/layout/app_layout_scope.dart';
import '../../web/screens/admin_books_screen_body.dart';
import '../../web/widgets/shell/web_page_scaffold.dart';

/// Single admin hub: search, filter, and manage every book from one list.
class AdminBooksScreen extends ConsumerWidget {
  const AdminBooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useWebShell(context)) {
      return const WebPageScaffold(body: AdminBooksScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopAdminBooksScreenBody());
    }

    return const MobileAdminBooksScreen();
  }
}
