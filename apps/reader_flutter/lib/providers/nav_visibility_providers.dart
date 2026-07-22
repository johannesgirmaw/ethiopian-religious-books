import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'session_notifier.dart';

/// Data-driven visibility for optional navigation entries.
///
/// Both checks fail closed (false = entry hidden): a signed-out session, an
/// offline device, or a failed request must never surface a menu entry that
/// leads to an empty screen. They are kept alive (no autoDispose) so every
/// shell/overlay rebuild reuses one answer instead of re-querying.

/// True when the Bible catalogue has at least one published book that actually
/// carries chapters — a book shell with no verses yet is not "data".
final hasBibleContentProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(sessionNotifierProvider).valueOrNull == null) return false;
  final dio = ref.watch(apiDioProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('bible/books');
    final items = res.data?['items'] as List<dynamic>? ?? const [];
    return items.any((e) {
      final count = (e as Map)['chapter_count'];
      return count is num && count > 0;
    });
  } catch (_) {
    return false;
  }
});

/// True when the signed-in user has at least one payment transaction, i.e. the
/// purchases screen has something to show.
final hasPurchasesProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(sessionNotifierProvider).valueOrNull == null) return false;
  final dio = ref.watch(apiDioProvider);
  try {
    final res = await dio.get<Map<String, dynamic>>('payments/transactions');
    final items = res.data?['items'] as List<dynamic>? ?? const [];
    return items.isNotEmpty;
  } catch (_) {
    return false;
  }
});
