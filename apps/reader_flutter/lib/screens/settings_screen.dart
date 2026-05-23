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
import '../storage/book_content_cache_storage.dart';
import '../utils/format_catalog_cache_age.dart';
import '../widgets/language_preference_card.dart';
import '../widgets/primitives/shell_primitives.dart';
import '../widgets/shell_page_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(catalogProvider);
    final cachedAt = ref.watch(catalogCachedAtProvider).valueOrNull;
    final downloadJobs = ref.watch(downloadJobsProvider);
    final reminderPref = ref.watch(reminderPreferenceProvider);
    final plans = ref.watch(dailyPlansProvider);
    final theme = Theme.of(context);

    return ShellPageScaffold(
      title: l10n.settingsTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          AppSectionHeader(title: l10n.dashboard),
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
                      child: AppStatTile(
                        label: l10n.inProgressDownloads,
                        value: '$pending',
                        icon: Icons.downloading_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppStatTile(
                        label: l10n.failedDownloads,
                        value: '$failed',
                        icon: Icons.error_outline_rounded,
                        accent: AppColors.referenceSecondary,
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
                    child: AppStatTile(
                      label: l10n.availableBooks,
                      value: '${page.items.length}',
                      icon: Icons.auto_stories_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppStatTile(
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
                  child: AppStatTile(
                    label: l10n.availableBooks,
                    value: '--',
                    icon: Icons.auto_stories_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppStatTile(
                    label: l10n.languagesMetric,
                    value: '--',
                    icon: Icons.language_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppSectionHeader(title: l10n.studyAndReminders),
          const SizedBox(height: 10),
          AppPanel(
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
                leading: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
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
            data: (items) => AppPanel(
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
                  final uri = Uri(
                    path: '/reader/${planItem.bookId}',
                    queryParameters: query,
                  );
                  context.push(uri.toString());
                },
                trailing: IconButton(
                  tooltip: l10n.createPlanTooltip,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onPressed: () async {
                    try {
                      final dio = ref.read(apiDioProvider);
                      final firstBook =
                          catalog.valueOrNull?.items.isNotEmpty == true
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
          const SizedBox(height: 24),
          const LanguagePreferenceCard(),
          const SizedBox(height: 24),
          AppSectionHeader(title: l10n.settingsCacheSection),
          const SizedBox(height: 10),
          if (cachedAt != null)
            AppPanel(
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.cloud_done_outlined, size: 22),
                title: Text(
                  l10n.catalogSynced(formatCatalogCacheAge(l10n, cachedAt)),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          if (cachedAt != null) const SizedBox(height: 10),
          AppPanel(
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

