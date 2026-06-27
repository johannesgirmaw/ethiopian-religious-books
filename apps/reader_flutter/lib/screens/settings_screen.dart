import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_decorations.dart';
import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../providers/catalog_providers.dart';
import '../providers/download_jobs_provider.dart';
import '../storage/book_content_cache_storage.dart';
import '../utils/format_catalog_cache_age.dart';
import '../widgets/language_preference_card.dart';
import '../widgets/primitives/shell_primitives.dart';
import '../widgets/shell_page_scaffold.dart';
import '../widgets/skeleton_loader.dart';
import '../common/platform/platform_shell.dart';
import '../desktop/screens/settings_screen_body.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/settings_screen_body.dart';
import '../web/widgets/shell/web_page_scaffold.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalog = ref.watch(catalogProvider);
    final cachedAt = ref.watch(catalogCachedAtProvider).valueOrNull;
    final downloadJobs = ref.watch(downloadJobsProvider);
    final offlineCount = ref.watch(offlineBookCountProvider);

    if (useWebShell(context)) {
      return const WebPageScaffold(body: SettingsScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopSettingsScreenBody());
    }

    return ShellPageScaffold(
      title: l10n.settingsTitle,
      showBackButton: true,
      onBack: () => context.go('/profile'),
      body: ListView(
        padding: AppLayout.page,
        children: [
          // AppGreetingCard(
          //   greetingLine: greetingForL10n(l10n),
          //   title: l10n.settingsTitle,
          //   subtitle: l10n.homeQuickSettingsSubtitle,
          // ),
          const SizedBox(height: AppLayout.sectionGap),
          AppSectionAccent(label: l10n.dashboard.toUpperCase()),
          const SizedBox(height: AppLayout.blockGap),
          downloadJobs.when(
            data: (jobs) {
              final pending =
                  jobs.where((e) => e.state == 'in_progress').length;
              final failed = jobs.where((e) => e.state == 'failed').length;
              return Row(
                children: [
                  _SettingsMetricCard(
                    icon: Icons.downloading_rounded,
                    value: '$pending',
                    label: l10n.inProgressDownloads,
                  ),
                  const SizedBox(width: 12),
                  _SettingsMetricCard(
                    icon: Icons.error_outline_rounded,
                    value: '$failed',
                    label: l10n.failedDownloads,
                    accent: AppColors.referenceSecondary,
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 96,
              child: SkeletonCardGroup(count: 2),
            ),
            error: (_, __) => Row(
              children: [
                _SettingsMetricCard(
                  icon: Icons.downloading_rounded,
                  value: '—',
                  label: l10n.inProgressDownloads,
                ),
                const SizedBox(width: 12),
                _SettingsMetricCard(
                  icon: Icons.error_outline_rounded,
                  value: '—',
                  label: l10n.failedDownloads,
                  accent: AppColors.referenceSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.itemGap),
          _SettingsActionRow(
            icon: Icons.download_outlined,
            title: l10n.homeQuickDownloads,
            subtitle: offlineCount.when(
              data: (count) => l10n.offlineBooksSaved(count),
              loading: () => l10n.checkingCache,
              error: (_, __) => l10n.cacheUnavailable,
            ),
            onTap: () => context.go('/downloads'),
          ),
          const SizedBox(height: 10),
          catalog.when(
            data: (page) {
              final languages = page.items
                  .map((b) => (b.primaryLanguage ?? '').trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .length;
              return Row(
                children: [
                  _SettingsMetricCard(
                    icon: Icons.auto_stories_rounded,
                    value: '${page.items.length}',
                    label: l10n.availableBooks,
                  ),
                  const SizedBox(width: 12),
                  _SettingsMetricCard(
                    icon: Icons.language_rounded,
                    value: '$languages',
                    label: l10n.languagesMetric,
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 96,
              child: SkeletonCardGroup(count: 2),
            ),
            error: (_, __) => Row(
              children: [
                _SettingsMetricCard(
                  icon: Icons.auto_stories_rounded,
                  value: '—',
                  label: l10n.availableBooks,
                ),
                const SizedBox(width: 10),
                _SettingsMetricCard(
                  icon: Icons.language_rounded,
                  value: '—',
                  label: l10n.languagesMetric,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.sectionGap),
          AppSectionAccent(label: l10n.languagePreferenceTitle.toUpperCase()),
          const SizedBox(height: AppLayout.itemGap),
          const LanguagePreferenceCard(),
          const SizedBox(height: AppLayout.sectionGap),
          AppSectionAccent(label: l10n.settingsCacheSection.toUpperCase()),
          const SizedBox(height: AppLayout.itemGap),
          if (cachedAt != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppLayout.itemGap),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.successSurface,
                borderRadius: BorderRadius.circular(AppRadius.cardV2),
                border: Border.all(color: AppColors.successBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.successText.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.cloud_done_outlined,
                      size: 20,
                      color: AppColors.successText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.catalogSynced(formatCatalogCacheAge(l10n, cachedAt)),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successText,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _SettingsActionRow(
            icon: Icons.offline_bolt_rounded,
            title: l10n.offlineChapterCache,
            subtitle: offlineCount.when(
              data: (count) => l10n.offlineBooksSaved(count),
              loading: () => l10n.checkingCache,
              error: (_, __) => l10n.cacheUnavailable,
            ),
            trailing: TextButton(
              onPressed: () => _confirmClearCache(context, ref, l10n),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.referenceSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(l10n.clear),
            ),
          ),
        ],
      ),
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

class _SettingsMetricCard extends StatelessWidget {
  const _SettingsMetricCard({
    required this.icon,
    required this.value,
    required this.label,
    this.accent = AppColors.referencePrimary,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: AppDecorations.listRow(),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppDecorations.listRow(),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.referencePrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: AppColors.referencePrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
