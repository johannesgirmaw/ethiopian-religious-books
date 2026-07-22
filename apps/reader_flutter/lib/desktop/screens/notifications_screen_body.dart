import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/engagement_providers.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/common/desktop_page_header.dart';
import '../widgets/common/desktop_section.dart';

class DesktopNotificationsScreenBody extends ConsumerWidget {
  const DesktopNotificationsScreenBody({super.key});

  IconData _icon(String kind) => switch (kind) {
        'new_book' => Icons.auto_stories_rounded,
        'reminder' => Icons.alarm_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final padding =
        DesktopTokens.pagePadding(DesktopLayoutScope.tierOf(context));
    final async = ref.watch(notificationsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Padding(
        padding: padding,
        child: DesktopEmptyState(
          icon: Icons.notifications_off_outlined,
          title: l10n.notificationsTitle,
          message: '$e',
        ),
      ),
      data: (result) {
        if (result.items.isEmpty) {
          return Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DesktopPageHeader(title: l10n.notificationsTitle),
                const SizedBox(height: 20),
                DesktopEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: l10n.notificationsEmptyTitle,
                  message: l10n.notificationsEmptyMessage,
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: padding,
          children: [
            DesktopPageHeader(
              title: l10n.notificationsTitle,
              actions: [
                TextButton(
                  onPressed: () => markAllNotificationsRead(ref),
                  child: Text(l10n.notificationsMarkAllRead),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...result.items.map((n) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      if (!n.isRead) markNotificationRead(ref, n.id);
                      if (n.bookId != null) {
                        context.push('/book/${n.bookId}');
                      }
                    },
                    child: DesktopPanel(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(
                              _icon(n.kind),
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: n.isRead
                                        ? FontWeight.w600
                                        : FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (n.body.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    n.body,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!n.isRead)
                            Container(
                              margin: const EdgeInsets.only(left: 8, top: 4),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
