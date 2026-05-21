import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';

/// Horizontal language filter chips (All + one chip per language).
class LanguageFilterChips extends StatelessWidget {
  const LanguageFilterChips({
    super.key,
    required this.languages,
    required this.selectedLanguage,
    required this.onSelected,
    this.allLabel,
  });

  /// Display labels including [generalCategory] for books without a language.
  final List<String> languages;
  final String? selectedLanguage;
  final ValueChanged<String?> onSelected;
  final String? allLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final all = allLabel ?? l10n.filterAll;

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _LanguageChip(
            label: all,
            selected: selectedLanguage == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          ...languages.map(
            (lang) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _LanguageChip(
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

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.referencePrimary.withValues(alpha: 0.45),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? AppColors.referencePrimary : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }
}
