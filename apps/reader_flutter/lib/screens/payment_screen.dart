import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/catalog_providers.dart';
import '../router/app_navigation.dart';
import '../widgets/app_state_view.dart';
import '../widgets/payment/payment_flow_view.dart';
import '../widgets/skeleton_loader.dart';
import '../desktop/widgets/shell/desktop_overlay_scaffold.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_overlay_scaffold.dart';

/// Route adapter for the checkout flow. Branches web → desktop → mobile and
/// hosts the shared [PaymentFlowView] in the platform's overlay scaffold.
class PaymentScreen extends ConsumerWidget {
  const PaymentScreen({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final asyncBook = ref.watch(bookDetailProvider(bookId));

    Widget body() => asyncBook.when(
          data: (book) => PaymentFlowView(
            book: book,
            onClose: () => popOverlayRoute(context),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonCardGroup(count: 3),
          ),
          error: (e, _) => AppStateView(
            title: l10n.unableToLoadBook,
            message: l10n.bookLoadErrorMessage,
            icon: Icons.menu_book_outlined,
            actionLabel: l10n.goBack,
            onAction: () => popOverlayRoute(context),
          ),
        );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) popOverlayRoute(context);
      },
      child: AppLayoutScopeBuilder(
        child: Builder(
          builder: (context) {
            if (useWebShell(context)) {
              return WebOverlayScaffold(
                title: l10n.paymentTitle,
                currentLocation: GoRouterState.of(context).matchedLocation,
                appTitle: l10n.appTitle,
                onBack: () => popOverlayRoute(context),
                body: body(),
              );
            }
            if (useDesktopShell(context)) {
              return DesktopOverlayScaffold(
                title: l10n.paymentTitle,
                currentLocation: GoRouterState.of(context).matchedLocation,
                appTitle: l10n.appTitle,
                onBack: () => popOverlayRoute(context),
                body: body(),
              );
            }
            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => popOverlayRoute(context),
                ),
                title: Text(l10n.paymentTitle),
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Divider(height: 1, color: AppColors.line),
                ),
              ),
              body: SafeArea(child: body()),
            );
          },
        ),
      ),
    );
  }
}
