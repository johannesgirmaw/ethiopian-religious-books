import 'package:flutter/material.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/catalog_providers.dart';

/// Resolves the locale-appropriate label for a genre option.
String genreOptionLabel(BuildContext context, GenreOption g) {
  final isAm = Localizations.localeOf(context).languageCode == 'am';
  if (isAm && (g.labelAm?.isNotEmpty ?? false)) return g.labelAm!;
  return g.label.isNotEmpty ? g.label : g.slug;
}

/// Horizontal genre/category chips driven by the dynamic genres lookup.
/// A null selection means "All".
class GenreChipRow extends StatelessWidget {
  const GenreChipRow({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppLayout.pageHorizontal,
    ),
  });

  final List<GenreOption> options;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _Chip(
              label: l10n.homeAllGenre,
              active: selected == null,
              onTap: () => onSelected(null),
            );
          }
          final g = options[i - 1];
          return _Chip(
            label: genreOptionLabel(context, g),
            active: selected == g.slug,
            onTap: () => onSelected(g.slug),
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
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
      child: AnimatedContainer(
        duration: AppMotion.short,
        curve: Curves.easeOutCubic,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.line,
          ),
          // boxShadow: active ? AppShadows.floatingBtn : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
            color: active ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
