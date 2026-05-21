import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../providers/api_client.dart';
import '../providers/session_notifier.dart';
import '../widgets/shell_page_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
    final user = session?.user;
    final theme = Theme.of(context);
    return ShellPageScaffold(
      title: l10n.profileTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ProfileHeroCard(user: user, l10n: l10n),
          const SizedBox(height: 24),
          Text(
            l10n.profileAccountDetails,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (user != null)
            _ProfileDetailsCard(user: user, l10n: l10n)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.lg),
                child: Text(
                  l10n.noProfileCached,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          if (user != null) ...[
            FilledButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
              label: Text(l10n.profileOpenSettings),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: user == null
                ? null
                : () async {
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
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.user,
    required this.l10n,
  });

  final UserProfile? user;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(user);
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : l10n.readerAccount;
    final email = user?.email ?? l10n.noEmail;
    final roleLabel = user == null
        ? ''
        : user!.isSuperuser
            ? l10n.adminRoleBadge
            : user!.role.toUpperCase();

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.referencePrimary.withValues(alpha: 0.8),
                  AppColors.referencePrimary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    initials,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (roleLabel.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            roleLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
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
        ],
      ),
    );
  }

  String _initials(UserProfile? user) {
    if (user?.displayName?.trim().isNotEmpty == true) {
      return user!.displayName!.trim()[0].toUpperCase();
    }
    if (user?.email.isNotEmpty == true) {
      return user!.email[0].toUpperCase();
    }
    return 'U';
  }
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({
    required this.user,
    required this.l10n,
  });

  final UserProfile user;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final notSet = l10n.profileValueNotSet;

    final rows = <_ProfileInfoRow>[
      _ProfileInfoRow(
        icon: Icons.badge_outlined,
        label: l10n.profileUserIdLabel,
        value: user.id,
      ),
      _ProfileInfoRow(
        icon: Icons.mail_outline_rounded,
        label: l10n.emailLabel,
        value: user.email,
      ),
      _ProfileInfoRow(
        icon: Icons.person_outline_rounded,
        label: l10n.displayNameLabel,
        value: user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : notSet,
        muted: user.displayName?.trim().isEmpty != false,
      ),
      _ProfileInfoRow(
        icon: Icons.shield_outlined,
        label: l10n.profileRoleLabel,
        value: user.isSuperuser ? l10n.adminRoleBadge : user.role,
      ),
      _ProfileInfoRow(
        icon: Icons.admin_panel_settings_outlined,
        label: l10n.profileSuperuserLabel,
        value: user.isSuperuser ? l10n.profileYes : l10n.profileNo,
      ),
      _ProfileInfoRow(
        icon: Icons.language_outlined,
        label: l10n.profilePreferredLanguageLabel,
        value: user.preferredUiLanguage?.trim().isNotEmpty == true
            ? user.preferredUiLanguage!.trim()
            : notSet,
        muted: user.preferredUiLanguage?.trim().isEmpty != false,
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 56),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.muted = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: AppColors.referencePrimary),
      title: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        value,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: muted ? AppColors.textSecondary : AppColors.textPrimary,
          fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
