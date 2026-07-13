import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/platform/platform_shell.dart';
import '../design/app_tokens.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../l10n/app_localizations.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/widgets/shell/web_page_scaffold.dart';
import '../widgets/author/author_apply_view.dart';

/// Route adapter for `/author/apply` — a reader's "Become an author" form.
/// Branches web → desktop → mobile, wrapping the shared [AuthorApplyView].
class AuthorApplyScreen extends ConsumerWidget {
  const AuthorApplyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    if (useWebShell(context)) {
      return const WebPageScaffold(body: AuthorApplyView(showHeader: true));
    }
    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: AuthorApplyView(showHeader: true));
    }

    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: Text(l10n.authorApplyTitle),
      ),
      body: const SafeArea(child: AuthorApplyView()),
    );
  }
}
