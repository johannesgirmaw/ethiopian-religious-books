import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../utils/open_support_link.dart';
import 'telegram_icon.dart';

/// Brand-tinted banner inviting readers to the public Telegram support group.
class TelegramSupportBanner extends StatelessWidget {
  const TelegramSupportBanner({super.key, this.compact = false});

  /// Tighter padding for toolbars / home strips.
  final bool compact;

  static const _telegramBlue = Color(0xFF229ED9);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => openTelegramSupport(),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Ink(
          decoration: BoxDecoration(
            color: _telegramBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: _telegramBlue.withValues(alpha: 0.28)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpace.md : AppSpace.lg,
            vertical: compact ? AppSpace.sm : AppSpace.md,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 36 : 42,
                height: compact ? 36 : 42,
                decoration: BoxDecoration(
                  color: _telegramBlue.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const TelegramIcon(size: 22),
              ),
              SizedBox(width: compact ? AppSpace.sm : AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.telegramSupportTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.telegramSupportBody(AppConfig.telegramSupportHandle),
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                l10n.telegramSupportJoin,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _telegramBlue,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: _telegramBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating action control that opens the Telegram support group.
class TelegramSupportFab extends StatelessWidget {
  const TelegramSupportFab({super.key, this.bottomInset = 0});

  /// Extra bottom offset (e.g. mobile nav bar clearance).
  final double bottomInset;

  static const _telegramBlue = Color(0xFF229ED9);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Positioned(
      right: 16,
      bottom: 16 + bottomInset,
      child: FloatingActionButton.extended(
        heroTag: 'telegram_support_fab',
        onPressed: () => openTelegramSupport(),
        backgroundColor: _telegramBlue,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const TelegramIcon(size: 20, color: Colors.white, filled: false),
        label: Text(
          l10n.telegramSupportFab,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
