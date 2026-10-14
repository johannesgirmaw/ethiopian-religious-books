import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/catalog_providers.dart';
import '../../../providers/continue_reading_provider.dart';
import '../../../router/app_navigation.dart';
import '../../design/web_tokens.dart';

/// Full-width continue reading strip for the web library.
class WebContinueReadingStrip extends ConsumerWidget {
  const WebContinueReadingStrip({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final catalog = ref.watch(catalogProvider).valueOrNull;
    final book = catalog?.items.where((b) => b.id == bookId).firstOrNull;
    final title = book?.title ?? l10n.resumeReading;
    final meta = ref.watch(catalogBookMetaProvider(bookId)).valueOrNull;
    final progress = (meta?.progress ?? 0).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final lastOpened = ref.watch(lastOpenedBookProvider).valueOrNull;
    final isPdf = book?.isPdf ?? lastOpened?.isPdf ?? false;
    final path = readingPathForBook(bookId, isPdf: isPdf);

    return DecoratedBox(
      decoration: WebTokens.panelDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.referencePrimary.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.referencePrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.resumeReading,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => context.push(path),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.referencePrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          // Theme uses Size.fromHeight(50) (infinite min
                          // width). A Row cannot layout that as a non-flex
                          // child — shrink to the label instead.
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(l10n.readNow),
                      ),
                    ],
                  ],
                ),
                if (percent > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.12,
                            ),
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.readingProgressPercent(percent),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (compact) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: () => context.push(path),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.referencePrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(l10n.readNow),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
