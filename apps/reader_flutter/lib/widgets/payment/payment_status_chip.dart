import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/payment_models.dart';
import 'payment_method_icons.dart';

/// Pill showing a transaction status, colour-coded by outcome:
/// green = completed, red = rejected/cancelled, amber = awaiting (pending/review).
class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({super.key, required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (bg, border, fg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: border),
      ),
      child: Text(
        paymentStatusLabel(status, l10n),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  (Color, Color, Color) _colors(PaymentStatus status) {
    if (status.isSuccessful) {
      return (
        AppColors.successSurface,
        AppColors.successBorder,
        AppColors.successText,
      );
    }
    if (status == PaymentStatus.rejected || status == PaymentStatus.cancelled) {
      return (AppColors.errorSurface, AppColors.errorBorder, AppColors.errorText);
    }
    // pending / on_review / approved / unknown → awaiting
    return (
      AppColors.accent.withValues(alpha: 0.12),
      AppColors.accent.withValues(alpha: 0.45),
      const Color(0xFFB76E00),
    );
  }
}
