import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/admin_book.dart';
import '../providers/admin_providers.dart';
import 'primitives/shell_primitives.dart';
import 'stored_rich_text_view.dart';

/// Shared review-round history list (submitted / approved / changes-requested /
/// withdrawn), used by the review screen on every platform. Renders each
/// reviewer comment as rich text via [StoredRichTextView].
class BookReviewHistoryView extends ConsumerWidget {
  const BookReviewHistoryView({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notesAsync = ref.watch(reviewNotesProvider(bookId));
    return notesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(l10n.reviewHistoryEmpty)),
      data: (notes) {
        if (notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.xl),
              child: Text(
                l10n.reviewHistoryEmpty,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpace.md),
          itemCount: notes.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpace.sm),
          itemBuilder: (context, i) => _ReviewNoteCard(note: notes[i]),
        );
      },
    );
  }
}

class _ReviewNoteCard extends StatelessWidget {
  const _ReviewNoteCard({required this.note});

  final BookReviewNote note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final (label, kind) = _decisionChip(l10n, note.decision);
    final meta = [
      if (note.reviewerEmail != null && note.reviewerEmail!.isNotEmpty)
        note.reviewerEmail!,
      if (note.createdAt != null) _formatDate(note.createdAt!),
    ].join(' · ');
    final showComment =
        note.isChangesRequested && note.comment.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppStatusChip(label: label, kind: kind),
              const SizedBox(width: AppSpace.sm),
              if (meta.isNotEmpty)
                Expanded(
                  child: Text(
                    meta,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          if (showComment) ...[
            const SizedBox(height: AppSpace.sm),
            StoredRichTextView(raw: note.comment),
          ],
        ],
      ),
    );
  }
}

(String, AppStatusKind) _decisionChip(AppLocalizations l10n, String decision) {
  switch (decision) {
    case 'approved':
      return (l10n.reviewDecisionApproved, AppStatusKind.active);
    case 'changes_requested':
      return (l10n.reviewDecisionChangesRequested, AppStatusKind.pending);
    case 'withdrawn':
      return (l10n.reviewDecisionWithdrawn, AppStatusKind.neutral);
    case 'submitted':
    default:
      return (l10n.reviewDecisionSubmitted, AppStatusKind.accent);
  }
}

String _formatDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
