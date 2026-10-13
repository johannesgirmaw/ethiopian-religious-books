import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment_models.dart';
import 'api_client.dart';

/// Payment methods the platform currently accepts (from platform settings).
final paymentMethodsProvider =
    FutureProvider.autoDispose<PaymentMethodsResult>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('payments/methods');
  return PaymentMethodsResult.fromJson(res.data ?? const {});
});

/// Active banks for the manual bank-transfer flow.
final banksProvider = FutureProvider.autoDispose<List<BankAccount>>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('payments/banks');
  final items = res.data?['items'] as List<dynamic>? ?? const [];
  return items
      .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Set of book ids the current user has completed a purchase for (entitlements).
/// Used by the reader/buy gate so a paid book opens directly.
final entitledBookIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('payments/entitlements');
  final ids = res.data?['book_ids'] as List<dynamic>? ?? const [];
  return ids.map((e) => e.toString()).toSet();
});

/// Whether the current user has completed a purchase for [bookId]. Reads the
/// latest entitlements; returns false on any error (fail closed).
Future<bool> userOwnsBook(WidgetRef ref, String bookId) async {
  try {
    final ids = await ref.read(entitledBookIdsProvider.future);
    return ids.contains(bookId);
  } catch (_) {
    return false;
  }
}

/// The current user's payment transactions (status tracking).
final myTransactionsProvider =
    FutureProvider.autoDispose<List<PaymentTransaction>>((ref) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('payments/transactions');
  final items = res.data?['items'] as List<dynamic>? ?? const [];
  return items
      .map((e) => PaymentTransaction.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Book ids with a submitted payment still waiting on admin (or approved but
/// not yet completed). Used to disable "Purchase" on the book detail page.
final pendingPurchaseBookIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final txns = await ref.watch(myTransactionsProvider.future);
  return {
    for (final t in txns)
      if (t.status.isAwaitingReview && t.bookId.isNotEmpty) t.bookId,
  };
});

/// Book ids whose checkout was started and not submitted. Opening the book
/// resumes that form instead of starting another purchase.
final resumeCheckoutBookIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final txns = await ref.watch(myTransactionsProvider.future);
  return {
    for (final t in txns)
      if (t.status.resumesCheckout && t.bookId.isNotEmpty) t.bookId,
  };
});

/// The buyer's purchase that blocks a new checkout for [bookId], if any.
///
/// Completed wins over in-review, which wins over a half-finished checkout.
PaymentTransaction? activePurchaseForBook(
  Iterable<PaymentTransaction> transactions,
  String bookId,
) {
  PaymentTransaction? best;
  var bestRank = 99;
  for (final txn in transactions) {
    if (txn.bookId != bookId || !txn.status.blocksNewPurchase) continue;
    final rank = switch (txn.status) {
      PaymentStatus.completed => 0,
      PaymentStatus.approved => 1,
      PaymentStatus.onReview => 2,
      PaymentStatus.pending => 3,
      _ => 99,
    };
    if (rank < bestRank) {
      best = txn;
      bestRank = rank;
    }
  }
  return best;
}

/// Thrown when creating a purchase is refused because one already exists.
class PurchaseConflict implements Exception {
  PurchaseConflict({required this.code, required this.transaction});

  final String code;
  final PaymentTransaction transaction;
}

/// A single transaction by id (polled for status updates).
final transactionProvider = FutureProvider.autoDispose
    .family<PaymentTransaction, String>((ref, id) async {
  final dio = ref.watch(apiDioProvider);
  final res = await dio.get<Map<String, dynamic>>('payments/transactions/$id');
  return PaymentTransaction.fromJson(res.data ?? const {});
});

/// Raw bytes of a transaction's uploaded receipt, fetched through the
/// authenticated client (the receipt endpoint is private). Returns null when
/// there is no receipt. Works on every platform incl. web (no <img> auth/CORS
/// issues, since the API client carries the bearer token).
final receiptBytesProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((ref, txnId) async {
  final dio = ref.watch(apiDioProvider);
  try {
    final res = await dio.get<List<int>>(
      'payments/transactions/$txnId/receipt-file',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = res.data;
    if (data == null || data.isEmpty) return null;
    return Uint8List.fromList(data);
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return null;
    rethrow;
  }
});

/// Repository for payment mutations. Obtained via [paymentRepositoryProvider].
class PaymentRepository {
  PaymentRepository(this._dio);

  final Dio _dio;

  /// Create a transaction for [bookId] with [method]. For the manual flow the
  /// result carries the bank list; online methods may carry a checkout URL.
  Future<CreateTransactionResult> createTransaction({
    required String bookId,
    required PaymentMethodKind method,
    String? bankId,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        'payments/transactions',
        data: {
          'book': bookId,
          'payment_method': method.apiValue,
          if (bankId != null) 'bank': bankId,
        },
      );
      return CreateTransactionResult.fromJson(res.data ?? const {});
    } on DioException catch (e) {
      final code = paymentErrorCode(e);
      final data = e.response?.data;
      if ((code == 'ALREADY_OWNED' || code == 'PURCHASE_IN_PROGRESS') &&
          data is Map &&
          data['transaction'] is Map) {
        throw PurchaseConflict(
          code: code,
          transaction: PaymentTransaction.fromJson(
            Map<String, dynamic>.from(data['transaction'] as Map),
          ),
        );
      }
      rethrow;
    }
  }

  /// Save bank and reference on a checkout that has not been submitted.
  Future<PaymentTransaction> updatePending({
    required String transactionId,
    String? bankId,
    String? transactionReference,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      'payments/transactions/$transactionId',
      data: {
        if (bankId != null) 'bank': bankId,
        if (transactionReference != null)
          'transaction_reference': transactionReference,
      },
    );
    return PaymentTransaction.fromJson(res.data ?? const {});
  }

  /// Withdraw a pending checkout or a payment still waiting for approval.
  Future<PaymentTransaction> cancelTransaction(String transactionId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      'payments/transactions/$transactionId/cancel',
    );
    return PaymentTransaction.fromJson(res.data ?? const {});
  }

  /// Upload a receipt + reference for a manual transaction (-> ON_REVIEW).
  Future<PaymentTransaction> submitReceipt({
    required String transactionId,
    required List<int> bytes,
    required String filename,
    required String transactionReference,
    String? bankId,
  }) async {
    final form = FormData.fromMap({
      'transaction_reference': transactionReference,
      if (bankId != null) 'bank': bankId,
      'receipt': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      'payments/transactions/$transactionId/receipt',
      data: form,
    );
    return PaymentTransaction.fromJson(res.data ?? const {});
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(apiDioProvider));
});

/// Extracts a human-readable message from a payment API error response,
/// falling back to [fallback]. Recognises the `{"error":{"code","message"}}`
/// shape the backend returns.
String paymentErrorMessage(Object error, String fallback) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final msg = (data['error'] as Map)['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg;
    }
  }
  return fallback;
}

/// The error `code` from a payment API error, or "" when absent.
String paymentErrorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final code = (data['error'] as Map)['code'];
      if (code is String) return code;
    }
  }
  return '';
}
