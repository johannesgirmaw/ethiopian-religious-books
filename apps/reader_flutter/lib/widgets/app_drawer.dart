import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_tokens.dart';
import '../design/reference_assets.dart';
import '../l10n/app_localizations.dart';
import '../providers/continue_reading_provider.dart';
import '../providers/session_notifier.dart';

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
    final lastOpened = ref.watch(lastOpenedBookProvider).valueOrNull;
    final isSuperuser = user?.isSuperuser == true;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(ReferenceAssets.drawerHero),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.referencePrimary.withValues(alpha: 0.4),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 16,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      // color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        ReferenceAssets.appLogo,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 3,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                      if (user?.email != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          user!.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          _DrawerNavTile(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
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
          // if (lastOpened != null && lastOpened.bookId.isNotEmpty)
          //   _DrawerNavTile(
          //     icon: Icons.menu_book_outlined,
          //     selectedIcon: Icons.menu_book_rounded,
          //     label: l10n.drawerContinueReading,
          //     subtitle: lastOpened.title,
          //     selected: false,
          //     onTap: () {
          //       Navigator.of(context).pop();
          //       context.push('/reader/${lastOpened.bookId}');
          //     },
          //   ),
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
            const Divider(),
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
        color: selected ? AppColors.referencePrimary : Colors.black26,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
    );
  }
}
