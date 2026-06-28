import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/engagement_providers.dart';
import '../router/app_navigation.dart';
import '../widgets/app_state_view.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String kind) => switch (kind) {
        'new_book' => Icons.auto_stories_rounded,
        'reminder' => Icons.alarm_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => popOverlayRoute(context),
        ),
        title: Text(l10n.notificationsTitle),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => markAllNotificationsRead(ref),
            child: Text(l10n.notificationsMarkAllRead),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppStateView(
          title: l10n.notificationsTitle,
          message: '$e',
          icon: Icons.notifications_off_outlined,
        ),
        data: (result) {
          if (result.items.isEmpty) {
            return AppStateView(
              title: l10n.notificationsEmptyTitle,
              message: l10n.notificationsEmptyMessage,
              icon: Icons.notifications_none_rounded,
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.all(AppLayout.pageHorizontal),
                itemCount: result.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = result.items[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.cardV2),
                      onTap: () {
                        if (!n.isRead) markNotificationRead(ref, n.id);
                        if (n.bookId != null) context.push('/book/${n.bookId}');
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: n.isRead
                              ? AppColors.surfaceCard
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(AppRadius.cardV2),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(_icon(n.kind),
                                  size: 19, color: AppColors.primary),
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
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
