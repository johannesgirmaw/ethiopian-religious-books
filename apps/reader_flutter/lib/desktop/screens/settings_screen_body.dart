import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/catalog_providers.dart';
import '../../providers/download_jobs_provider.dart';
import '../../storage/book_content_cache_storage.dart';
import '../../utils/format_catalog_cache_age.dart';
import '../../widgets/language_preference_card.dart';
import '../../widgets/skeleton_loader.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/common/desktop_page_header.dart';
import '../widgets/common/desktop_scroll_body.dart';
import '../widgets/common/desktop_section.dart';

class DesktopSettingsScreenBody extends ConsumerWidget {
  const DesktopSettingsScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(catalogProvider);
    final cachedAt = ref.watch(catalogCachedAtProvider).valueOrNull;
    final downloadJobs = ref.watch(downloadJobsProvider);
    final offlineCount = ref.watch(offlineBookCountProvider);
    final padding =
        DesktopTokens.pagePadding(DesktopLayoutScope.tierOf(context));

    return DesktopScrollBody(
      padding: padding,
      children: [
        DesktopPageHeader(
          title: l10n.settingsTitle,
          subtitle: l10n.homeQuickSettingsSubtitle,
        ),
        const SizedBox(height: 24),
        DesktopSection(
          title: l10n.dashboard.toUpperCase(),
          child: downloadJobs.when(
            data: (jobs) {
              final pending =
                  jobs.where((e) => e.state == 'in_progress').length;
              final failed = jobs.where((e) => e.state == 'failed').length;
              return Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      label: l10n.inProgressDownloads,
                      value: '$pending',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      label: l10n.failedDownloads,
                      value: '$failed',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: catalog.when(
                      data: (page) => _StatTile(
                        label: l10n.availableBooks,
                        value: '${page.items.length}',
                      ),
                      loading: () => const _StatTile(label: '…', value: '—'),
                      error: (_, __) =>
                          _StatTile(label: l10n.availableBooks, value: '—'),
                    ),
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 80,
              child: SkeletonCardGroup(count: 3),
            ),
            error: (_, __) => Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: l10n.inProgressDownloads,
                    value: '—',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: l10n.failedDownloads,
                    value: '—',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: catalog.when(
                    data: (page) => _StatTile(
                      label: l10n.availableBooks,
                      value: '${page.items.length}',
                    ),
                    loading: () => const _StatTile(label: '…', value: '—'),
                    error: (_, __) =>
                        _StatTile(label: l10n.availableBooks, value: '—'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        DesktopSection(
          title: l10n.languagePreferenceTitle.toUpperCase(),
          child: const LanguagePreferenceCard(),
        ),
        const SizedBox(height: 20),
        DesktopSection(
          title: l10n.settingsCacheSection.toUpperCase(),
          child: DesktopPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cachedAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      l10n.catalogSynced(formatCatalogCacheAge(l10n, cachedAt)),
                      style: const TextStyle(
                        color: AppColors.successText,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                _SettingsRow(
                  title: l10n.offlineChapterCache,
                  subtitle: offlineCount.when(
                    data: (count) => l10n.offlineBooksSaved(count),
                    loading: () => l10n.checkingCache,
                    error: (_, __) => l10n.cacheUnavailable,
                  ),
                  trailing: TextButton(
                    onPressed: () => _confirmClearCache(context, ref, l10n),
                    child: Text(l10n.clear),
                  ),
                ),
                const Divider(height: 20),
                _SettingsRow(
                  title: l10n.homeQuickDownloads,
                  subtitle: offlineCount.when(
                    data: (count) => l10n.offlineBooksSaved(count),
                    loading: () => l10n.checkingCache,
                    error: (_, __) => l10n.cacheUnavailable,
                  ),
                  trailing: TextButton(
                    onPressed: () => context.go('/downloads'),
                    child: Text(l10n.openLibrary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearCache(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
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
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DesktopPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
