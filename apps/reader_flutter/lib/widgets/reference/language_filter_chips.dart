import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';

class LanguageFilterOption {
  const LanguageFilterOption({required this.key, required this.label});

  final String key;
  final String label;
}

/// Premium horizontal language filter pills.
class LanguageFilterChips extends StatelessWidget {
  const LanguageFilterChips({
    super.key,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
    this.allLabel,
    this.padding,
  });

  final List<LanguageFilterOption> options;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;
  final String? allLabel;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final all = allLabel ?? l10n.filterAll;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding ?? AppLayout.pageHorizontalOnly,
        children: [
          _LanguagePill(
            label: all,
            selected: selectedKey == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 10),
          ...options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _LanguagePill(
                label: option.label,
                selected: selectedKey == option.key,
                onTap: () => onSelected(option.key),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.short,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.referencePrimary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.referencePrimary : AppColors.line,
          ),
          boxShadow: selected ? AppShadows.listRow : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
