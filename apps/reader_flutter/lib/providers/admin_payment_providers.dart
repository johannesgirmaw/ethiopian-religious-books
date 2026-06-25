import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment_models.dart';
import 'api_client.dart';

/// Admin payment dashboard totals.
final adminPaymentDashboardProvider =
    FutureProvider.autoDispose<AdminPaymentDashboard>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('admin/payments/dashboard');
  return AdminPaymentDashboard.fromJson(res.data ?? const {});
});

/// All payment transactions for admin review, optionally filtered by status
/// (`''` = all). The argument is the status `apiValue` (e.g. `on_review`).
final adminTransactionsProvider = FutureProvider.autoDispose
    .family<List<PaymentTransaction>, String>((ref, statusFilter) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>(
    'admin/payments/transactions',
    queryParameters: {
      if (statusFilter.isNotEmpty) 'status': statusFilter,
    },
  );
  final items = res.data?['items'] as List<dynamic>? ?? const [];
  return items
      .map((e) => PaymentTransaction.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Admin review actions for manual payments.
class AdminPaymentRepository {
  AdminPaymentRepository(this._dio);

  final Dio _dio;

  /// Approve a transaction → marks it COMPLETED and writes the revenue ledger.
  Future<PaymentTransaction> approve(String id) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'admin/payments/transactions/$id/approve',
    );
    return PaymentTransaction.fromJson(res.data ?? const {});
  }

  /// Reject a transaction with an optional reason.
  Future<PaymentTransaction> reject(String id, {String note = ''}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'admin/payments/transactions/$id/reject',
      data: {'note': note},
    );
    return PaymentTransaction.fromJson(res.data ?? const {});
  }
}

final adminPaymentRepositoryProvider = Provider<AdminPaymentRepository>((ref) {
  return AdminPaymentRepository(ref.watch(apiDioProvider));
});

/// Invalidate every admin payment view after a mutation.
void refreshAdminPayments(Ref ref) {
  ref.invalidate(adminPaymentDashboardProvider);
  ref.invalidate(adminTransactionsProvider);
}

void refreshAdminPaymentsW(WidgetRef ref) {
  ref.invalidate(adminPaymentDashboardProvider);
  ref.invalidate(adminTransactionsProvider);
}
