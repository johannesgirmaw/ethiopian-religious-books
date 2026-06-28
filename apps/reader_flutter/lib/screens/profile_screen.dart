import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_decorations.dart';
import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../providers/api_client.dart';
import '../providers/session_notifier.dart';
import '../widgets/primitives/shell_primitives.dart';
import '../widgets/shell_page_scaffold.dart';
import '../common/platform/platform_shell.dart';
import '../desktop/screens/profile_screen_body.dart';
import '../desktop/widgets/shell/desktop_page_scaffold.dart';
import '../web/layout/app_layout_scope.dart';
import '../web/screens/profile_screen_body.dart';
import '../web/widgets/shell/web_page_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
    final user = session?.user;

    if (useWebShell(context)) {
      return const WebPageScaffold(body: ProfileScreenBody());
    }

    if (useDesktopShell(context)) {
      return const DesktopPageScaffold(body: DesktopProfileScreenBody());
    }

    return ShellPageScaffold(
      title: l10n.profileTitle,
      showBackButton: true,
      onBack: () => context.go('/home'),
      body: ListView(
        padding: AppLayout.page,
        children: [
          // _ProfileHero(user: user, l10n: l10n),
          const SizedBox(height: AppLayout.sectionGap),
          AppSectionAccent(label: l10n.profileAccountDetails.toUpperCase()),
          const SizedBox(height: AppLayout.blockGap),
          if (user != null) ...[
            _ProfileFieldCard(
              icon: Icons.mail_outline_rounded,
              label: l10n.emailLabel,
              value: user.email,
            ),
            const SizedBox(height: AppLayout.itemGap),
            _ProfileFieldCard(
              icon: Icons.person_outline_rounded,
              label: l10n.displayNameLabel,
              value: user.displayName?.trim().isNotEmpty == true
                  ? user.displayName!.trim()
                  : l10n.profileValueNotSet,
              muted: user.displayName?.trim().isEmpty != false,
            ),
            const SizedBox(height: AppLayout.itemGap),
            _ProfileFieldCard(
              icon: Icons.shield_outlined,
              label: l10n.profileRoleLabel,
              value: user.isSuperuser ? l10n.adminRoleBadge : user.role,
              accent: user.isSuperuser
                  ? AppColors.referencePrimary
                  : AppColors.referencePrimary,
            ),
            if (user.preferredUiLanguage?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppLayout.itemGap),
              _ProfileFieldCard(
                icon: Icons.language_rounded,
                label: l10n.profilePreferredLanguageLabel,
                value: user.preferredUiLanguage!.trim(),
              ),
            ],
            const SizedBox(height: AppLayout.itemGap),
            _ProfileFieldCard(
              icon: Icons.badge_outlined,
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
          ] else
            _SignedOutCard(l10n: l10n),
          const SizedBox(height: AppLayout.sectionGap),
          AppSectionAccent(label: l10n.aboutTitle.toUpperCase()),
          const SizedBox(height: AppLayout.blockGap),
          _ProfileLinkRow(
            icon: Icons.tune_rounded,
            title: l10n.navSettings,
            subtitle: l10n.profileSettingsSubtitle,
            onTap: () => context.go('/settings'),
          ),
          if (user != null) ...[
            const SizedBox(height: AppLayout.itemGap),
            _ProfileLinkRow(
              icon: Icons.receipt_long_outlined,
              title: l10n.paymentMyPurchases,
              subtitle: l10n.paymentPurchasesSubtitle,
              onTap: () => context.go('/purchases'),
            ),
          ],
          const SizedBox(height: AppLayout.itemGap),
          _ProfileLinkRow(
            icon: Icons.info_outline_rounded,
            title: l10n.drawerAbout,
            subtitle: l10n.aboutAppSectionTitle,
            onTap: () => context.push('/about'),
          ),
          if (user?.isSuperuser == true) ...[
            const SizedBox(height: AppLayout.itemGap),
            _ProfileLinkRow(
              icon: Icons.admin_panel_settings_outlined,
              title: l10n.adminPanel,
              subtitle: l10n.adminPanelSubtitle,
              onTap: () => context.push('/admin'),
            ),
            const SizedBox(height: AppLayout.itemGap),
            _ProfileLinkRow(
              icon: Icons.receipt_long_outlined,
              title: l10n.adminManageOrders,
              subtitle: l10n.adminOrdersSubtitle,
              onTap: () => context.push('/admin/payments'),
            ),
          ],
          if (user != null) ...[
            const SizedBox(height: AppLayout.sectionGap),
            AppSectionAccent(label: l10n.profileSecuritySection.toUpperCase()),
            const SizedBox(height: AppLayout.blockGap),
            _ProfileLinkRow(
              icon: Icons.lock_outline_rounded,
              title: l10n.changePasswordTitle,
              subtitle: l10n.changePasswordLinkSubtitle,
              onTap: () => context.push('/change-password'),
            ),
          ],
          if (user != null) ...[
            const SizedBox(height: AppLayout.sectionGap),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _signOut(context, ref),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: Text(l10n.signOut),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorText,
                  backgroundColor: AppColors.surfaceCard,
                  side: BorderSide(
                    color: AppColors.errorBorder.withValues(alpha: 0.7),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.cardV2),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user, required this.l10n});

  final UserProfile? user;
  final AppLocalizations l10n;

  String _initials(UserProfile? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
      final list = parts.toList();
      if (list.length >= 2) {
        return '${list.first[0]}${list[1][0]}'.toUpperCase();
      }
      return list.first[0].toUpperCase();
    }
    final email = user?.email.trim();
    if (email != null && email.isNotEmpty) {
      return email[0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : l10n.readerAccount;
    final email = user?.email ?? l10n.noEmail;
    final isAdmin = user?.isSuperuser == true;

    return AppGreetingCard(
      greetingLine: greetingForL10n(l10n),
      title: displayName,
      subtitle: email,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AppStatusChip(
                label: isAdmin ? l10n.adminRoleBadge : user!.role,
                kind: isAdmin ? AppStatusKind.accent : AppStatusKind.active,
              ),
            ),
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              _initials(user),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileFieldCard extends StatelessWidget {
  const _ProfileFieldCard({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = AppColors.referencePrimary,
    this.muted = false,
    this.monospace = false,
    this.onCopy,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool muted;
  final bool monospace;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCopy,
        borderRadius: BorderRadius.circular(AppRadius.cardV2),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppDecorations.listRow(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: monospace ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        color: muted
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                        height: 1.35,
                        fontFamily: monospace ? 'monospace' : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (onCopy != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  onPressed: onCopy,
                  tooltip: MaterialLocalizations.of(context).copyButtonLabel,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileLinkRow extends StatelessWidget {
  const _ProfileLinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
                child: Icon(icon, size: 22, color: AppColors.referencePrimary),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

class _SignedOutCard extends StatelessWidget {
  const _SignedOutCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.referencePrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              size: 28,
              color: AppColors.referencePrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.noProfileCached,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.signInSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login_rounded, size: 20),
              label: Text(l10n.signIn),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.referencePrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.cardV2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
