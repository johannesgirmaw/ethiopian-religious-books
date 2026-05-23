import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';

/// Premium horizontal language filter pills.
class LanguageFilterChips extends StatelessWidget {
  const LanguageFilterChips({
    super.key,
    required this.languages,
    required this.selectedLanguage,
    required this.onSelected,
    this.allLabel,
  });

  final List<String> languages;
  final String? selectedLanguage;
  final ValueChanged<String?> onSelected;
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final all = allLabel ?? l10n.filterAll;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _LanguagePill(
            label: all,
            selected: selectedLanguage == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...languages.map(
            (lang) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _LanguagePill(
                label: lang,
                selected: selectedLanguage == lang,
                onTap: () => onSelected(lang),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.referencePrimary
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.referencePrimary : AppColors.line,
            width: 1,
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
