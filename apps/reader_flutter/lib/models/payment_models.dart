// Payment domain models. Pure Dart (no Flutter imports) — UI mapping for icons
// and labels lives in the widget layer.

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

/// Supported payment methods. [apiValue] mirrors the backend `PaymentMethod`.
enum PaymentMethodKind {
  stripe('stripe'),
  paypal('paypal'),
  telebirr('telebirr'),
  bankTransfer('bank_transfer');

  const PaymentMethodKind(this.apiValue);

  final String apiValue;

  bool get isManual => this == PaymentMethodKind.bankTransfer;
  bool get isOnline => !isManual;

  static PaymentMethodKind? fromApi(String? value) {
    for (final m in PaymentMethodKind.values) {
      if (m.apiValue == value) return m;
    }
    return null;
  }
}

/// Lifecycle of a [PaymentTransaction], mirrors backend `TransactionStatus`.
enum PaymentStatus {
  pending('pending'),
  onReview('on_review'),
  approved('approved'),
  completed('completed'),
  cancelled('cancelled'),
  rejected('rejected'),
  unknown('');

  const PaymentStatus(this.apiValue);

  final String apiValue;

  bool get isTerminal =>
      this == completed || this == cancelled || this == rejected;
  bool get isSuccessful => this == completed;
  bool get isAwaitingReview => this == onReview || this == approved;

  static PaymentStatus fromApi(String? value) {
    for (final s in PaymentStatus.values) {
      if (s.apiValue == value) return s;
    }
    return PaymentStatus.unknown;
  }
}

class PaymentMethodsResult {
  const PaymentMethodsResult({
    required this.methods,
    required this.manualEnabled,
  });

  final List<PaymentMethodKind> methods;
  final bool manualEnabled;

  factory PaymentMethodsResult.fromJson(Map<String, dynamic> j) {
    final raw = j['methods'] as List<dynamic>? ?? const [];
    return PaymentMethodsResult(
      methods: raw
          .map((e) => PaymentMethodKind.fromApi(e as String?))
          .whereType<PaymentMethodKind>()
          .toList(),
      manualEnabled: j['manual_payment_enabled'] as bool? ?? false,
    );
  }
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.name,
    this.code = '',
    this.accountName = '',
    this.accountNumber = '',
    this.logoUrl = '',
  });

  final String id;
  final String name;
  final String code;
  final String accountName;
  final String accountNumber;
  final String logoUrl;

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        code: j['code'] as String? ?? '',
        accountName: j['account_name'] as String? ?? '',
        accountNumber: j['account_number'] as String? ?? '',
        logoUrl: j['logo_url'] as String? ?? '',
      );
}

class PaymentTransaction {
  const PaymentTransaction({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    this.userEmail = '',
    required this.currency,
    required this.amount,
    required this.commissionAmount,
    required this.authorAmount,
    required this.method,
    required this.status,
    required this.transactionReference,
    required this.receiptUrl,
    this.bank,
    this.createdAt,
  });

  final String id;
  final String bookId;
  final String bookTitle;
  final String userEmail;
  final String currency;
  final double amount;
  final double commissionAmount;
  final double authorAmount;
  final PaymentMethodKind? method;
  final PaymentStatus status;
  final String transactionReference;
  final String receiptUrl;
  final BankAccount? bank;
  final DateTime? createdAt;

  factory PaymentTransaction.fromJson(Map<String, dynamic> j) {
    final bankDetail = j['bank_detail'];
    return PaymentTransaction(
      id: j['id'] as String,
      bookId: j['book'] as String? ?? '',
      bookTitle: j['book_title'] as String? ?? '',
      userEmail: j['user_email'] as String? ?? '',
      currency: j['currency'] as String? ?? 'USD',
      amount: _toDouble(j['amount']),
      commissionAmount: _toDouble(j['commission_amount']),
      authorAmount: _toDouble(j['author_amount']),
      method: PaymentMethodKind.fromApi(j['payment_method'] as String?),
      status: PaymentStatus.fromApi(j['status'] as String?),
      transactionReference: j['transaction_reference'] as String? ?? '',
      receiptUrl: j['receipt_url'] as String? ?? '',
      bank: bankDetail is Map<String, dynamic>
          ? BankAccount.fromJson(bankDetail)
          : null,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? ''),
    );
  }
}

/// Admin payment dashboard totals (GET /v1/admin/payments/dashboard).
class AdminPaymentDashboard {
  const AdminPaymentDashboard({
    required this.totalSales,
    required this.grossRevenue,
    required this.platformRevenue,
    required this.authorRevenue,
    required this.pendingReviews,
    required this.completedTransactions,
  });

  final int totalSales;
  final String grossRevenue;
  final String platformRevenue;
  final String authorRevenue;
  final int pendingReviews;
  final int completedTransactions;

  factory AdminPaymentDashboard.fromJson(Map<String, dynamic> j) =>
      AdminPaymentDashboard(
        totalSales: (j['total_sales'] as num?)?.toInt() ?? 0,
        grossRevenue: '${j['gross_revenue'] ?? 0}',
        platformRevenue: '${j['platform_revenue'] ?? 0}',
        authorRevenue: '${j['author_revenue'] ?? 0}',
        pendingReviews: (j['pending_reviews'] as num?)?.toInt() ?? 0,
        completedTransactions:
            (j['completed_transactions'] as num?)?.toInt() ?? 0,
      );
}

/// Result of initiating a purchase. For the manual flow [banks] is populated;
/// for online flows [checkoutUrl] may be set.
class CreateTransactionResult {
  const CreateTransactionResult({
    required this.transaction,
    required this.banks,
    this.checkoutUrl,
  });

  final PaymentTransaction transaction;
  final List<BankAccount> banks;
  final String? checkoutUrl;

  factory CreateTransactionResult.fromJson(Map<String, dynamic> j) {
    final rawBanks = j['banks'] as List<dynamic>? ?? const [];
    final checkout = j['checkout'] as Map<String, dynamic>?;
    return CreateTransactionResult(
      transaction: PaymentTransaction.fromJson(
        j['transaction'] as Map<String, dynamic>,
      ),
      banks: rawBanks
          .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
          .toList(),
      checkoutUrl: (checkout?['checkout_url'] as String?)?.trim().isNotEmpty == true
          ? checkout!['checkout_url'] as String
          : null,
    );
  }
}
