import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/platform/platform_shell.dart';
import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/payment/admin_purchases_view.dart';
import '../../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../../web/layout/app_layout_scope.dart';
import '../../web/widgets/shell/web_page_scaffold.dart';

/// Admin "Orders & payments" hub: review manual payments, approve (→ complete +
/// ledger) or reject. Branches web → desktop → mobile.
class AdminPurchasesScreen extends ConsumerWidget {
  const AdminPurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (useWebShell(context)) {
      return const WebPageScaffold(body: AdminPurchasesView());
    }
    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: AdminPurchasesView());
    }

    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.adminPaymentsTitle),
      ),
      body: const SafeArea(child: AdminPurchasesView()),
    );
  }
}
