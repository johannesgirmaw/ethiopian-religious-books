import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../providers/api_client.dart';
import '../providers/session_notifier.dart';
import '../widgets/primitives/shared_widgets.dart';
import '../widgets/primitives/shell_primitives.dart';
import '../widgets/shell_page_scaffold.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
    final user = session?.user;

    return ShellPageScaffold(
      title: l10n.profileTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ProfileHero(user: user, l10n: l10n),
          const SizedBox(height: 20),
          AppSectionHeader(title: l10n.profileAccountDetails),
          const SizedBox(height: 8),
          if (user != null)
            AppPanel(
              child: Column(
                children: [
                  AppDetailRow(
                    icon: Icons.badge_outlined,
                    label: l10n.profileUserIdLabel,
                    value: user.id,
                  ),
                  Divider(height: 1, color: AppColors.line),
                  AppDetailRow(
                    icon: Icons.mail_outline_rounded,
                    label: l10n.emailLabel,
                    value: user.email,
                  ),
                  Divider(height: 1, color: AppColors.line),
                  AppDetailRow(
                    icon: Icons.person_outline_rounded,
                    label: l10n.displayNameLabel,
                    value: user.displayName?.trim().isNotEmpty == true
                        ? user.displayName!.trim()
                        : l10n.profileValueNotSet,
                    muted: user.displayName?.trim().isEmpty != false,
                  ),
                  Divider(height: 1, color: AppColors.line),
                  AppDetailRow(
                    icon: Icons.shield_outlined,
                    label: l10n.profileRoleLabel,
                    value: user.isSuperuser ? l10n.adminRoleBadge : user.role,
                  ),
                ],
              ),
            )
          else
            AppPanel(
              child: Text(
                l10n.noProfileCached,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          const SizedBox(height: 24),
          if (user != null)
            FilledButton.icon(
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
              label: Text(l10n.profileOpenSettings),
            ),
          if (user != null) const SizedBox(height: 12),
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
                    await ref
                        .read(sessionNotifierProvider.notifier)
                        .clear();
                    if (context.mounted) context.go('/login');
                  },
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.signOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(
                color: Theme.of(context).colorScheme.error.withValues(
                      alpha: 0.5,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.user, required this.l10n});

  final UserProfile? user;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : l10n.readerAccount;
    final email = user?.email ?? l10n.noEmail;
    return AppGreetingCard(
      greetingLine: greetingForL10n(l10n),
      title: displayName,
      subtitle: email,
      showMenu: false,
      trailing: user != null
          ? AppStatusChip(
              label: user!.isSuperuser ? l10n.adminRoleBadge : user!.role,
              kind: AppStatusKind.neutral,
            )
          : null,
    );
  }

}
