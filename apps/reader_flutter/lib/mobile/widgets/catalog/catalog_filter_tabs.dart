import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/catalog_providers.dart';
import 'genre_chip_row.dart' show genreOptionLabel;

/// Underlined filter tabs for the catalog grid: "All Results" + one tab per
/// genre present (dynamic). A null value means "All".
class CatalogFilterTabs extends StatelessWidget {
  const CatalogFilterTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<GenreOption> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.pageHorizontal,
        ),
        itemCount: options.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 18),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Tab(
              label: l10n.catalogAllResults,
              active: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final g = options[i - 1];
          return _Tab(
            label: genreOptionLabel(context, g),
            active: selected == g.slug,
            onTap: () => onSelected(g.slug),
          );
        },
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: AppMotion.short,
            height: 3,
            width: active ? 22 : 0,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ],
      ),
    );
  }
}
