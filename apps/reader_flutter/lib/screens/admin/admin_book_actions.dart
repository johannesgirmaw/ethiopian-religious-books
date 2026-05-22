import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/admin_providers.dart';
import '../../providers/api_client.dart';
import '../../utils/api_error_message.dart';

/// Confirms and publishes the latest draft for [bookId].
Future<bool> adminPublishBook({
  required BuildContext context,
  required WidgetRef ref,
  required String bookId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final d = AppLocalizations.of(ctx)!;
      return AlertDialog(
        title: Text(d.publishLatestDraftTitle),
        content: Text(
          d.publishLatestDraftBody,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(d.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(d.publish),
          ),
        ],
      );
    },
  );
  if (ok != true || !context.mounted) return false;

  try {
    final dio = ref.read(apiDioProvider);
    await dio.post<Map<String, dynamic>>('admin/books/$bookId/publish');
    ref.invalidate(adminBooksProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.publishedLatestRevision)),
      );
    }
    return true;
  } on DioException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          messageFromDioResponse(e.response?.data) ??
              publishErrorMessage(e) ??
              e.message ??
              l10n.publishFailed,
        ),
      ),
    );
    return false;
  }
}

/// Unpublishes [bookId] without extra confirmation (reversible via publish).
Future<bool> adminUnpublishBook({
  required BuildContext context,
  required WidgetRef ref,
  required String bookId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final dio = ref.read(apiDioProvider);
    await dio.post<void>('admin/books/$bookId/unpublish');
    ref.invalidate(adminBooksProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unpublish)),
      );
    }
    return true;
  } on DioException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          messageFromDioResponse(e.response?.data) ??
              e.message ??
              l10n.unpublishFailed,
        ),
      ),
    );
    return false;
  }
}
