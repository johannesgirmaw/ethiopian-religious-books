import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../design/web_tokens.dart';

class WebNavItem {
  const WebNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Top navigation bar for wide web layouts.
class WebTopNavBar extends StatelessWidget {
  const WebTopNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.appTitle,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<WebNavItem> items;
  final String appTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.referencePageBg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: WebTokens.navHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: AppGradients.gold,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: AppShadows.listRow,
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primaryDeep,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      appTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _WebNavTab(
                        item: items[i],
                        selected: selectedIndex == i,
                        onTap: () => onSelected(i),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WebNavTab extends StatelessWidget {
  const _WebNavTab({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final WebNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppMotion.short,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.referencePrimary.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: selected
                ? Border.all(
                    color: AppColors.referencePrimary.withValues(alpha: 0.25),
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? item.selectedIcon : item.icon,
                size: 18,
                color: selected
                    ? AppColors.referencePrimary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.referencePrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
