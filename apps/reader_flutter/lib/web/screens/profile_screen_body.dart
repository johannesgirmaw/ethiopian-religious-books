import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../design/app_tokens.dart';
import '../design/web_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user_profile.dart';
import '../../providers/api_client.dart';
import '../../providers/session_notifier.dart';
import '../layout/app_layout_scope.dart';
import '../widgets/common/web_page_header.dart';
import '../widgets/common/web_section.dart';

class ProfileScreenBody extends ConsumerWidget {
  const ProfileScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
    final user = session?.user;
    final padding = WebTokens.pagePadding(AppLayoutScope.tierOf(context));

    return ListView(
      padding: padding,
      children: [
        WebPageHeader(
          title: l10n.profileTitle,
          subtitle: user?.email ?? l10n.signInSubtitle,
        ),
        const SizedBox(height: 24),
        if (user != null) ...[
          WebPanel(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.referencePrimary.withValues(
                    alpha: 0.12,
                  ),
                  child: Text(
                    _initials(user),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.referencePrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName?.trim().isNotEmpty == true
                            ? user.displayName!.trim()
                            : l10n.readerAccount,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user.isSuperuser ? l10n.adminRoleBadge : user.role,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.referencePrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          WebSection(
            title: l10n.profileAccountDetails.toUpperCase(),
            child: WebPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _DetailRow(label: l10n.emailLabel, value: user.email),
                  const Divider(height: 1),
                  _DetailRow(
                    label: l10n.displayNameLabel,
                    value: user.displayName?.trim().isNotEmpty == true
                        ? user.displayName!.trim()
                        : l10n.profileValueNotSet,
                  ),
                  const Divider(height: 1),
                  _DetailRow(
                    label: l10n.profileRoleLabel,
                    value: user.isSuperuser ? l10n.adminRoleBadge : user.role,
                  ),
                  if (user.preferredUiLanguage?.trim().isNotEmpty == true) ...[
                    const Divider(height: 1),
                    _DetailRow(
                      label: l10n.profilePreferredLanguageLabel,
                      value: user.preferredUiLanguage!.trim(),
                    ),
                  ],
                  const Divider(height: 1),
                  _DetailRow(
                    label: l10n.profileUserIdLabel,
                    value: user.id,
                    monospace: true,
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: user.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.profileUserIdCopied)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          WebSection(
            title: l10n.aboutTitle.toUpperCase(),
            child: WebPanel(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _LinkRow(
                    title: l10n.paymentMyPurchases,
                    subtitle: l10n.paymentPurchasesSubtitle,
                    onTap: () => context.go('/purchases'),
                  ),
                  const Divider(height: 1),
                  _LinkRow(
                    title: l10n.drawerAbout,
                    subtitle: l10n.aboutAppSectionTitle,
                    onTap: () => context.push('/about'),
                  ),
                  if (user.canManageBooks != true) ...[
                    const Divider(height: 1),
                    _LinkRow(
                      title: l10n.authorApplyEntryTitle,
                      subtitle: l10n.authorApplyEntrySubtitle,
                      onTap: () => context.push('/become-author'),
                    ),
                  ],
                  if (user.isSuperuser) ...[
                    const Divider(height: 1),
                    _LinkRow(
                      title: l10n.adminPanel,
                      subtitle: l10n.adminPanelSubtitle,
                      onTap: () => context.push('/admin/books'),
                    ),
                    const Divider(height: 1),
                    _LinkRow(
                      title: l10n.adminManageOrders,
                      subtitle: l10n.adminOrdersSubtitle,
                      onTap: () => context.push('/admin/payments'),
                    ),
                    const Divider(height: 1),
                    _LinkRow(
                      title: l10n.adminAuthorAppsTitle,
                      subtitle: l10n.adminAuthorAppsSubtitle,
                      onTap: () => context.push('/admin/author-applications'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          WebSection(
            title: l10n.profileSecuritySection.toUpperCase(),
            child: WebPanel(
              padding: EdgeInsets.zero,
              child: _LinkRow(
                title: l10n.changePasswordTitle,
                subtitle: l10n.changePasswordLinkSubtitle,
                onTap: () => context.push('/change-password'),
              ),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () => _signOut(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.signOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.errorText,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ] else
          WebPanel(
            child: Column(
              children: [
                Text(
                  l10n.noProfileCached,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(l10n.signInSubtitle, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l10n.signIn),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _initials(UserProfile user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name
          .split(RegExp(r'\s+'))
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.length >= 2)
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return parts[0][0].toUpperCase();
    }
    return user.email.isNotEmpty ? user.email[0].toUpperCase() : '?';
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
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
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.monospace = false,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool monospace;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: monospace ? 12 : 14,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 18),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
