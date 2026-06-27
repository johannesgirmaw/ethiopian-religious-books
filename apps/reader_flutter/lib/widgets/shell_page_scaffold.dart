import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';

/// Tab page scaffold with a standard toolbar.
class ShellPageScaffold extends StatelessWidget {
  const ShellPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = false,
    this.onBack,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.referencePageBg,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            padding: EdgeInsets.only(top: topInset),
            child: SizedBox(
              height: kToolbarHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (showBackButton)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      color: AppColors.textPrimary,
                      onPressed: onBack ?? () => context.go('/home'),
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                    )
                  else
                    const SizedBox(width: AppLayout.pageHorizontal),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 19,
                        letterSpacing: -0.2,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
