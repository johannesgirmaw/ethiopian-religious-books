import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/study_models.dart';
import '../providers/download_jobs_provider.dart';
import '../providers/api_client.dart';
import '../providers/catalog_providers.dart';
import '../providers/study_providers.dart';
import '../providers/session_notifier.dart';
import '../storage/book_content_cache_storage.dart';
import '../utils/format_catalog_cache_age.dart';
import '../widgets/app_section_card.dart';
import '../widgets/language_preference_card.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
    final catalog = ref.watch(catalogProvider);
    final cachedAt = ref.watch(catalogCachedAtProvider).valueOrNull;
    final downloadJobs = ref.watch(downloadJobsProvider);
    final reminderPref = ref.watch(reminderPreferenceProvider);
    final plans = ref.watch(dailyPlansProvider);
    final user = session?.user;
    final theme = Theme.of(context);

    final initials = (user?.displayName?.isNotEmpty == true
            ? user!.displayName!.trim()[0]
            : user?.email.substring(0, 1).toUpperCase() ?? 'U')
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const LanguagePreferenceCard(),
          const SizedBox(height: 16),
          AppSectionCard(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDeep],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName?.isNotEmpty == true
                            ? user!.displayName!
                            : l10n.readerAccount,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? l10n.noEmail,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user?.role != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceStrong,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user!.isSuperuser
                                ? l10n.adminRoleBadge
                                : user.role.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (cachedAt != null)
            AppSectionCard(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                children: [
                  const Icon(Icons.cloud_done_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.catalogSynced(
                        formatCatalogCacheAge(l10n, cachedAt),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (cachedAt != null) const SizedBox(height: 16),
          Text(
            l10n.dashboard,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          downloadJobs.when(
            data: (jobs) {
              final pending =
                  jobs.where((e) => e.state == 'in_progress').length;
              final failed = jobs.where((e) => e.state == 'failed').length;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _DashboardMetricCard(
                        label: l10n.inProgressDownloads,
                        value: '$pending',
                        icon: Icons.downloading_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DashboardMetricCard(
                        label: l10n.failedDownloads,
                        value: '$failed',
                        icon: Icons.error_outline_rounded,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          catalog.when(
            data: (page) {
              final languages = page.items
                  .map((b) => (b.primaryLanguage ?? '').trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .length;
              return Row(
                children: [
                  Expanded(
                    child: _DashboardMetricCard(
                      label: l10n.availableBooks,
                      value: '${page.items.length}',
                      icon: Icons.auto_stories_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DashboardMetricCard(
                      label: l10n.languagesMetric,
                      value: '$languages',
                      icon: Icons.language_rounded,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Row(
              children: [
                Expanded(
                  child: _DashboardMetricCard(
                    label: l10n.availableBooks,
                    value: '--',
                    icon: Icons.auto_stories_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DashboardMetricCard(
                    label: l10n.languagesMetric,
                    value: '--',
                    icon: Icons.language_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.offline_bolt_rounded),
              title: Text(l10n.offlineChapterCache),
              subtitle: ref.watch(offlineBookCountProvider).when(
                    data: (count) => Text(l10n.offlineBooksSaved(count)),
                    loading: () => Text(l10n.checkingCache),
                    error: (_, __) => Text(l10n.cacheUnavailable),
                  ),
              trailing: TextButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l10n.clearOfflineCacheTitle),
                      content: Text(l10n.clearOfflineCacheBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: Text(l10n.clear),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await BookContentCacheStorage.clearAll();
                  ref.invalidate(offlineBookCountProvider);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.offlineCacheCleared)),
                  );
                },
                child: Text(l10n.clear),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.studyAndReminders,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: reminderPref.when(
              data: (pref) => SwitchListTile(
                value: pref.enabled,
                title: Text(l10n.dailyReadingReminders),
                subtitle: Text(
                  l10n.reminderTimeUtc(
                    pref.hourUtc.toString().padLeft(2, '0'),
                    pref.minuteUtc.toString().padLeft(2, '0'),
                    pref.weekdaysOnly ? l10n.weekdaysOnlySuffix : '',
                  ),
                ),
                onChanged: (value) async {
                  try {
                    final dio = ref.read(apiDioProvider);
                    await dio.put<void>(
                      'study/reminder-preference',
                      data: {'enabled': value},
                    );
                    ref.invalidate(reminderPreferenceProvider);
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.reminderUpdateFailed)),
                    );
                  }
                },
              ),
              loading: () => ListTile(
                leading: const CircularProgressIndicator(),
                title: Text(l10n.loadingReminderSettings),
              ),
              error: (e, _) => ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: Text(l10n.reminderSettingsUnavailable),
                subtitle: Text('$e'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          plans.when(
            data: (items) => Card(
              child: ListTile(
                leading: const Icon(Icons.event_note_rounded),
                title: Text(l10n.dailyReadingPlans),
                subtitle: Text(
                  items.isEmpty
                      ? l10n.noReadingPlansYet
                      : '${l10n.readingPlansConfigured(items.length)}'
                          '${_firstPlanItem(items) != null ? l10n.tapOpenTodaysReading : ''}',
                ),
                onTap: () {
                  final planItem = _firstPlanItem(items);
                  if (planItem == null) return;
                  final chapter = planItem.chapterKey.trim();
                  final page = planItem.pageStart;
                  final query = <String, String>{
                    if (chapter.isNotEmpty) 'chapter': chapter,
                    if (page != null && page > 0) 'page': '$page',
                  };
                  final uri = Uri(path: '/reader/${planItem.bookId}', queryParameters: query);
                  context.push(uri.toString());
                },
                trailing: IconButton(
                  tooltip: l10n.createPlanTooltip,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () async {
                    try {
                      final dio = ref.read(apiDioProvider);
                      final firstBook = catalog.valueOrNull?.items.isNotEmpty == true
                          ? catalog.valueOrNull!.items.first
                          : null;
                      await dio.post<void>(
                        'study/plans',
                        data: {
                          'title': 'My daily plan',
                          'items': firstBook == null
                              ? const []
                              : [
                                  {
                                    'day_index': 1,
                                    'book': firstBook.id,
                                    'chapter_key': '',
                                    'page_start': 1,
                                    'page_end': 1,
                                    'note': 'Start reading',
                                  },
                                ],
                        },
                      );
                      ref.invalidate(dailyPlansProvider);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.dailyPlanCreateFailed)),
                      );
                    }
                  },
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.accountInfo,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (user != null) ...[
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: Text(l10n.emailLabel),
                    subtitle: Text(user.email),
                  ),
                  const Divider(height: 1, indent: 56),
                  if (user.displayName != null && user.displayName!.isNotEmpty)
                    ListTile(
                      leading: const Icon(Icons.person_outline_rounded),
                      title: Text(l10n.displayNameLabel),
                      subtitle: Text(user.displayName!),
                    ),
                ],
              ),
            ),
            if (user.isSuperuser) ...[
              const SizedBox(height: 10),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: Text(l10n.adminPanel),
                  subtitle: Text(l10n.adminPanelSubtitle),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/admin'),
                ),
              ),
            ],
          ] else
            Text(l10n.noProfileCached),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () async {
              final s = ref.read(sessionNotifierProvider).valueOrNull;
              if (s == null) return;
              try {
                final dio = ref.read(apiDioProvider);
                await dio.post<void>(
                  'auth/logout',
                  data: {'refresh_token': s.refreshToken},
                );
              } catch (_) {}
              await ref.read(sessionNotifierProvider.notifier).clear();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.signOut),
          ),
        ],
      ),
    );
  }
}

DailyReadingPlanItem? _firstPlanItem(List<DailyReadingPlan> plans) {
  for (final plan in plans) {
    if (!plan.isActive || plan.items.isEmpty) continue;
    final sorted = [...plan.items]..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));
    return sorted.first;
  }
  return null;
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
