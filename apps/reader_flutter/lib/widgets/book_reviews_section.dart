import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/engagement_providers.dart';
import '../providers/session_notifier.dart';
import '../utils/form_draft_controller.dart';
import '../utils/form_draft_keys.dart';

/// Reviews block for the book detail page: average summary, the list of
/// reviews, and a "write a review" action. Shared across platforms.
class BookReviewsSection extends ConsumerWidget {
  const BookReviewsSection({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(bookReviewsProvider(bookId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.reviewsSection,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => _openReviewSheet(context, ref, l10n),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: Text(l10n.writeReviewTitle),
            ),
          ],
        ),
        const SizedBox(height: 8),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            '$e',
            style: const TextStyle(color: AppColors.textTertiary),
          ),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  borderRadius: BorderRadius.circular(AppRadius.cardV2),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  l10n.reviewsEmpty,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final r in reviews) _ReviewTile(review: r),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openReviewSheet(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => _ReviewComposerSheet(
        bookId: bookId,
        draftKey: FormDraftKeys.scope(
          userId: ref.read(sessionNotifierProvider).valueOrNull?.user?.id,
          formKey: FormDraftKeys.bookReview(bookId),
        ),
        l10n: l10n,
      ),
    );
  }
}

class _ReviewComposerSheet extends ConsumerStatefulWidget {
  const _ReviewComposerSheet({
    required this.bookId,
    required this.draftKey,
    required this.l10n,
  });

  final String bookId;
  final String draftKey;
  final AppLocalizations l10n;

  @override
  ConsumerState<_ReviewComposerSheet> createState() =>
      _ReviewComposerSheetState();
}

class _ReviewComposerSheetState extends ConsumerState<_ReviewComposerSheet> {
  var _rating = 5;
  late final TextEditingController _bodyCtrl;
  late final FormDraftController _draft;

  @override
  void initState() {
    super.initState();
    _bodyCtrl = TextEditingController();
    _draft = FormDraftController(
      draftKey: widget.draftKey,
      capture: () => {'rating': _rating, 'body': _bodyCtrl.text},
      restore: (data) {
        _rating = (data['rating'] as num?)?.toInt().clamp(1, 5) ?? 5;
        _bodyCtrl.text = data['body'] as String? ?? '';
      },
      isEmpty: (data) {
        final body = (data['body'] as String? ?? '').trim();
        final rating = (data['rating'] as num?)?.toInt() ?? 5;
        return body.isEmpty && rating == 5;
      },
    );
    _bodyCtrl.addListener(_draft.onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final restored = await _draft.restoreIfPresent();
      if (!mounted || !restored) return;
      setState(() {});
      showFormDraftRestoredSnackBar(context);
    });
  }

  @override
  void dispose() {
    unawaited(_draft.persistNow());
    _bodyCtrl.removeListener(_draft.onChanged);
    _bodyCtrl.dispose();
    _draft.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    try {
      await submitReview(
        ref,
        widget.bookId,
        rating: _rating,
        body: _bodyCtrl.text.trim(),
      );
      await _draft.clear();
    } catch (_) {/* ignore submit failure */}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.writeReviewTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.yourRatingLabel,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () {
                    setState(() => _rating = i);
                    _draft.onChanged();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      i <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 34,
                      color: AppColors.accent,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bodyCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: l10n.reviewBodyHint,
              filled: true,
              fillColor: AppColors.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(l10n.submitReviewAction),
          ),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final BookReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.userName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 1; i <= 5; i++)
                    Icon(
                      i <= review.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 14,
                      color: AppColors.accent,
                    ),
                ],
              ),
            ],
          ),
          if (review.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.body,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
