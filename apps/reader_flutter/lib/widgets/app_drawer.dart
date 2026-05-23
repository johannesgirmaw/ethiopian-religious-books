import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/reference_assets.dart';
import '../l10n/app_localizations.dart';
import '../providers/session_notifier.dart';
import 'primitives/shared_widgets.dart';
import 'primitives/shell_primitives.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _navigate(BuildContext context, String path) {
    Navigator.of(context).pop();
    context.go(path);
  }

  void _pushAndClose(BuildContext context, String path) {
    Navigator.of(context).pop();
    context.push(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final location = GoRouterState.of(context).matchedLocation;
    final session = ref.watch(sessionNotifierProvider).valueOrNull;
    final user = session?.user;
    final isSuperuser = user?.isSuperuser == true;

    return Drawer(
      backgroundColor: AppColors.referencePageBg,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppGreetingCard(
              greetingLine: greetingForL10n(l10n),
              title: l10n.appTitle,
              subtitle: user?.email ?? l10n.splashTagline,
              showMenu: false,
              trailing: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  ReferenceAssets.appLogo,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _DrawerNavTile(
            icon: Icons.explore_outlined,
            selectedIcon: Icons.explore_rounded,
            label: l10n.drawerHome,
            selected: location.startsWith('/home'),
            onTap: () => _navigate(context, '/home'),
          ),
          _DrawerNavTile(
            icon: Icons.library_books_outlined,
            selectedIcon: Icons.library_books_rounded,
            label: l10n.drawerBrowse,
            selected: location.startsWith('/library'),
            onTap: () => _navigate(context, '/library'),
          ),
          _DrawerNavTile(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: l10n.drawerProfile,
            selected: location.startsWith('/profile'),
            onTap: () => _navigate(context, '/profile'),
          ),
          _DrawerNavTile(
            icon: Icons.settings_outlined,
            selectedIcon: Icons.settings_rounded,
            label: l10n.drawerSettings,
            selected: location.startsWith('/settings'),
            onTap: () => _navigate(context, '/settings'),
          ),
          _DrawerNavTile(
            icon: Icons.info_outline_rounded,
            selectedIcon: Icons.info_rounded,
            label: l10n.drawerAbout,
            selected: false,
            onTap: () => _pushAndClose(context, '/about'),
          ),
          if (isSuperuser) ...[
            Divider(height: 24, color: AppColors.line, indent: 16, endIndent: 16),
            _DrawerNavTile(
              icon: Icons.admin_panel_settings_outlined,
              selectedIcon: Icons.admin_panel_settings_rounded,
              label: l10n.adminPanel,
              subtitle: l10n.adminPanelSubtitle,
              selected: location.startsWith('/admin'),
              onTap: () => _pushAndClose(context, '/admin'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  const _DrawerNavTile({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        selected ? selectedIcon : icon,
        color: selected ? AppColors.referencePrimary : AppColors.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      selected: selected,
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}
