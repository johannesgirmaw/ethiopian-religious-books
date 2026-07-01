import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/number_system_provider.dart';
import 'primitives/shell_primitives.dart';

/// Numeral system control — Arabic (123) vs Ge'ez (፩፪፫). Applies to chapter and
/// verse numbering in the Bible reader.
class NumberSystemPreferenceCard extends ConsumerWidget {
  const NumberSystemPreferenceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final geez = ref.watch(useGeezNumeralsProvider);

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
                  Icons.numbers_rounded,
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
                      l10n.numberSystemTitle,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.numberSystemSubtitle,
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
            child: AppSegmentedControl<bool>(
              options: const [
                AppSegmentedOption(value: false, label: '123'),
                AppSegmentedOption(value: true, label: '፩፪፫'),
              ],
              value: geez,
              onChanged: (value) => ref.setUseGeezNumerals(value),
            ),
          ),
        ],
      ),
    );
  }
}
