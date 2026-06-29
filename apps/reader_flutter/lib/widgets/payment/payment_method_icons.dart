import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/payment_models.dart';

/// Material icon for a payment method.
IconData paymentMethodIcon(PaymentMethodKind method) {
  switch (method) {
    case PaymentMethodKind.stripe:
      return Icons.credit_card_rounded;
    case PaymentMethodKind.paypal:
      return Icons.account_balance_wallet_outlined;
    case PaymentMethodKind.telebirr:
      return Icons.phone_iphone_rounded;
    case PaymentMethodKind.bankTransfer:
      return Icons.account_balance_outlined;
  }
}

/// Localized label for a payment method.
String paymentMethodLabel(PaymentMethodKind method, AppLocalizations l10n) {
  switch (method) {
    case PaymentMethodKind.stripe:
      return l10n.paymentMethodStripe;
    case PaymentMethodKind.paypal:
      return l10n.paymentMethodPaypal;
    case PaymentMethodKind.telebirr:
      return l10n.paymentMethodTelebirr;
    case PaymentMethodKind.bankTransfer:
      return l10n.paymentMethodBank;
  }
}

/// Localized label for a transaction status (used by status tracking lists).
String paymentStatusLabel(PaymentStatus status, AppLocalizations l10n) {
  switch (status) {
    case PaymentStatus.pending:
      return l10n.paymentStatusPending;
    case PaymentStatus.onReview:
      return l10n.paymentStatusOnReview;
    case PaymentStatus.approved:
      return l10n.paymentStatusApproved;
    case PaymentStatus.completed:
      return l10n.paymentStatusCompleted;
    case PaymentStatus.cancelled:
      return l10n.paymentStatusCancelled;
    case PaymentStatus.rejected:
      return l10n.paymentStatusRejected;
    case PaymentStatus.unknown:
      return l10n.paymentStatusPending;
  }
}
