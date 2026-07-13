import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/platform/platform_shell.dart';
import '../../design/app_tokens.dart';
import '../../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../../l10n/app_localizations.dart';
import '../../web/layout/app_layout_scope.dart';
import '../../web/widgets/shell/web_page_scaffold.dart';
import '../../widgets/author/admin_author_applications_view.dart';

/// Admin "Author applications" review hub (platform-admin only — gated by the
/// router redirect). Branches web → desktop → mobile.
class AdminAuthorApplicationsScreen extends ConsumerWidget {
  const AdminAuthorApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (useWebShell(context)) {
      return const WebPageScaffold(
        body: AdminAuthorApplicationsView(showHeader: true),
      );
    }
    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(
        body: AdminAuthorApplicationsView(showHeader: true),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(l10n.adminAuthorAppsTitle),
      ),
      body: const SafeArea(child: AdminAuthorApplicationsView()),
    );
  }
}
