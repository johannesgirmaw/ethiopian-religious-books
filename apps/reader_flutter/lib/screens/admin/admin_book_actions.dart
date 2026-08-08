import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
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

/// Shared confirm dialog for the simple review transitions.
Future<bool> _confirmReviewAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final d = AppLocalizations.of(ctx)!;
      return AlertDialog(
        title: Text(title),
        content: Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(d.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return ok == true;
}

/// POSTs a review transition, refreshes the admin caches, and reports the result.
Future<bool> _postReviewAction({
  required BuildContext context,
  required WidgetRef ref,
  required String bookId,
  required String path,
  required String successMessage,
  required String fallbackError,
  Object? data,
}) async {
  try {
    final dio = ref.read(apiDioProvider);
    await dio.post<Map<String, dynamic>>(path, data: data);
    ref.invalidate(adminBooksProvider);
    ref.invalidate(reviewNotesProvider(bookId));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    }
    return true;
  } on DioException catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          messageFromDioResponse(e.response?.data) ?? e.message ?? fallbackError,
        ),
      ),
    );
    return false;
  }
}

/// Author sends a draft for editorial review (draft -> in_review).
Future<bool> adminSubmitBookForReview({
  required BuildContext context,
  required WidgetRef ref,
  required String bookId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await _confirmReviewAction(
    context,
    title: l10n.sendForReview,
    body: l10n.sendForReviewBody,
    confirmLabel: l10n.sendForReview,
  );
  if (!ok || !context.mounted) return false;
  return _postReviewAction(
    context: context,
    ref: ref,
    bookId: bookId,
    path: 'admin/books/$bookId/submit-review',
    successMessage: l10n.submitReviewSuccess,
    fallbackError: l10n.reviewActionFailed,
  );
}

/// Author withdraws a pending submission (in_review -> draft).
Future<bool> adminWithdrawBookReview({
  required BuildContext context,
  required WidgetRef ref,
  required String bookId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  return _postReviewAction(
    context: context,
    ref: ref,
    bookId: bookId,
    path: 'admin/books/$bookId/withdraw-review',
    successMessage: l10n.withdrawReviewSuccess,
    fallbackError: l10n.reviewActionFailed,
  );
}

/// Reviewer approves a book under review (in_review -> reviewed).
Future<bool> adminApproveBookReview({
  required BuildContext context,
  required WidgetRef ref,
  required String bookId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await _confirmReviewAction(
    context,
    title: l10n.approveReview,
    body: l10n.approveReviewBody,
    confirmLabel: l10n.approveReview,
  );
  if (!ok || !context.mounted) return false;
  return _postReviewAction(
    context: context,
    ref: ref,
    bookId: bookId,
    path: 'admin/books/$bookId/review/approve',
    successMessage: l10n.approveReviewSuccess,
    fallbackError: l10n.reviewActionFailed,
  );
}

/// Reviewer requests changes (in_review -> draft) with a mandatory rich-text
/// comment. The dialog's submit button stays disabled until a comment is typed.
Future<bool> adminRequestChangesForBook({
  required BuildContext context,
  required WidgetRef ref,
  required String bookId,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final delta = await showDialog<String>(
    context: context,
    builder: (ctx) => const _ReviewCommentDialog(),
  );
  if (delta == null || !context.mounted) return false;
  return _postReviewAction(
    context: context,
    ref: ref,
    bookId: bookId,
    path: 'admin/books/$bookId/review/reject',
    data: {'comment': delta},
    successMessage: l10n.requestChangesSuccess,
    fallbackError: l10n.reviewActionFailed,
  );
}

/// Rich-text (Quill) comment composer for a reviewer's change request. Pops the
/// route with the Quill delta JSON string, or null when cancelled.
class _ReviewCommentDialog extends StatefulWidget {
  const _ReviewCommentDialog();

  @override
  State<_ReviewCommentDialog> createState() => _ReviewCommentDialogState();
}

class _ReviewCommentDialogState extends State<_ReviewCommentDialog> {
  final QuillController _controller = QuillController.basic();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final has = _controller.document.toPlainText().trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.requestChanges),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reviewCommentLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ColoredBox(
              color: theme.colorScheme.surfaceContainerHigh,
              child: QuillSimpleToolbar(
                controller: _controller,
                config: const QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,
                  embedButtons: [],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: QuillEditor.basic(
                controller: _controller,
                config: QuillEditorConfig(
                  placeholder: l10n.reviewCommentLabel,
                  padding: const EdgeInsets.all(12),
                  embedBuilders: const [],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _hasText
              ? () => Navigator.pop(
                    context,
                    jsonEncode(_controller.document.toDelta().toJson()),
                  )
              : null,
          child: Text(l10n.requestChanges),
        ),
      ],
    );
  }
}

/// Permanently deletes a draft book after a destructive confirmation.
///
/// Only offered for books still in the draft stage — the server re-checks that
/// (`catalog/deletion.py`) and answers 409 for anything published, in review, or
/// already sold, which surfaces here as a snackbar.
Future<bool> adminDeleteBook({
  required BuildContext context,
  required WidgetRef ref,
  required String bookId,
  required String bookTitle,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final d = AppLocalizations.of(ctx)!;
      return AlertDialog(
        title: Text(d.deleteBookTitle),
        content: Text(
          d.deleteBookBody(bookTitle),
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(d.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorText,
              foregroundColor: Colors.white,
            ),
            child: Text(d.deleteBookConfirm),
          ),
        ],
      );
    },
  );
  if (ok != true || !context.mounted) return false;

  try {
    final dio = ref.read(apiDioProvider);
    await dio.delete<void>('admin/books/$bookId');
    ref.invalidate(adminBooksProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteBookSuccess)),
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
              l10n.deleteBookFailed,
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
