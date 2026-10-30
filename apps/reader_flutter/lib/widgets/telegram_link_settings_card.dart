import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/session_notifier.dart';
import 'telegram_icon.dart';

/// Settings row: link Telegram when missing, or show a Linked badge when set.
class TelegramLinkSettingsCard extends ConsumerWidget {
  const TelegramLinkSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;
    final linked = user?.telegramLinked == true;
    final username = (user?.telegramUsername ?? '').trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF229ED9).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const TelegramIcon(size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                linked ? l10n.telegramLinkedLabel : l10n.telegramNotLinkedLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                linked
                    ? (username.isNotEmpty
                        ? '@$username · ${l10n.telegramLinkedNavSubtitle}'
                        : l10n.telegramLinkedNavSubtitle)
                    : l10n.telegramLinkNavSubtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (linked)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.successSurface,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.successBorder),
            ),
            child: Text(
              l10n.telegramLinkedBadge,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.successText,
              ),
            ),
          )
        else
          TextButton(
            onPressed: () => context.push('/profile/link-telegram'),
            child: Text(l10n.telegramLinkCta),
          ),
      ],
    );
  }
}
