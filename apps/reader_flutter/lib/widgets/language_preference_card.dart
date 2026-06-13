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
    final current = ref.watch(appLocaleProvider).languageCode;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.referencePrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  size: 22,
                  color: AppColors.referencePrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.languagePreferenceTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.languagePreferenceSubtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: AppSegmentedControl<String>(
              options: [
                AppSegmentedOption(
                  value: 'en',
                  label: l10n.languageEnglish,
                ),
                AppSegmentedOption(
                  value: 'am',
                  label: l10n.languageAmharic,
                ),
              ],
              value: current,
              onChanged: (code) async {
                final locale =
                    code == 'am' ? const Locale('am') : const Locale('en');
                await ref.setAppLocale(locale);
              },
            ),
          ),
        ],
      ),
    );
  }
}
