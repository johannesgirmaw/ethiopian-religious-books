import 'package:flutter/material.dart';

import '../design/app_tokens.dart';
import 'reference/reference_menu_button.dart';

/// Tab page scaffold with a standard toolbar and drawer menu.
class ShellPageScaffold extends StatelessWidget {
  const ShellPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

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
            height: ReferenceMenuLayout.toolbarHeight + topInset,
            padding: EdgeInsets.only(top: topInset),
            color: AppColors.referencePageBg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const ReferenceMenuButton(),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
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
          Expanded(child: body),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
