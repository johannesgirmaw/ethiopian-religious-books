import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/platform/platform_shell.dart';
import '../l10n/app_localizations.dart';
import '../widgets/payment/purchases_view.dart';
import '../widgets/shell_page_scaffold.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_page_scaffold.dart';

/// "My purchases" (status tracking) — a primary destination shown inside the
/// app shell (bottom nav on mobile, sidebar on web/desktop). Branches
/// web → desktop → mobile and hosts the shared [PurchasesView].
class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (useWebShell(context)) {
      return const WebPageScaffold(body: PurchasesView());
    }
    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: PurchasesView());
    }
    return ShellPageScaffold(
      title: l10n.paymentMyPurchases,
      body: const PurchasesView(),
    );
  }
}
