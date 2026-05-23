import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/app_locale_provider.dart';
import 'primitives/shell_primitives.dart';

/// Compact app language control — EN / አማርኛ.
class LanguagePreferenceCard extends ConsumerWidget {
  const LanguagePreferenceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final current = ref.watch(appLocaleProvider).languageCode;

    return AppPanel(
      child: Row(
        children: [
          Icon(
            Icons.language_rounded,
            size: 22,
            color: AppColors.referencePrimary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.languagePreferenceTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              ButtonSegment(
                value: 'en',
                label: Text(
                  l10n.languageEnglish,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              ButtonSegment(
                value: 'am',
                label: Text(
                  l10n.languageAmharic,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
            selected: {current},
            onSelectionChanged: (selection) async {
              final code = selection.first;
              final locale =
                  code == 'am' ? const Locale('am') : const Locale('en');
              await ref.setAppLocale(locale);
            },
          ),
        ],
      ),
    );
  }
}
