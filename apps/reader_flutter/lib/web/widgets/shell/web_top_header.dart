import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_locale_provider.dart';
import '../../../providers/session_notifier.dart';
import '../../../utils/sidebar_identity.dart';
import '../../design/web_tokens.dart';

/// Persistent chrome above authenticated web pages: title/back, language,
/// and the signed-in user.
class WebTopHeader extends ConsumerWidget {
  const WebTopHeader({
    super.key,
    this.breadcrumb,
    this.breadcrumbParent,
    this.onBreadcrumbParent,
    this.actions,
    this.onBack,
  });

  final String? breadcrumb;
  final String? breadcrumbParent;
  final VoidCallback? onBreadcrumbParent;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(sessionNotifierProvider).valueOrNull?.user;
    final name = user == null ? l10n.readerAccount : sidebarUserName(user);
    final localeCode = ref.watch(appLocaleProvider).languageCode;
    final hasTitle = breadcrumb != null && breadcrumb!.isNotEmpty;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WebTokens.surfaceBg,
        border: Border(bottom: BorderSide(color: WebTokens.borderColor)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: WebTokens.navHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (onBack != null) ...[
                        _SquareBackButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: onBack!,
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (hasTitle &&
                          breadcrumbParent != null &&
                          breadcrumbParent!.isNotEmpty)
                        Flexible(
                          child: _BreadcrumbTrail(
                            parent: breadcrumbParent!,
                            current: breadcrumb!,
                            onParent: onBreadcrumbParent,
                          ),
                        )
                      else if (hasTitle)
                        Flexible(
                          child: Text(
                            breadcrumb!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      if (actions != null && actions!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ...actions!,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _LanguagePill(
                  code: localeCode,
                  l10n: l10n,
                  onSelected: (code) => ref.setAppLocale(Locale(code)),
                ),
                const SizedBox(width: 10),
                _UserChip(
                  greeting: l10n.headerGreeting(name),
                  initial: sidebarInitial(name),
                  profileLabel: l10n.navProfile,
                  onProfile: () => context.go('/profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SquareBackButton extends StatelessWidget {
  const _SquareBackButton({required this.tooltip, required this.onPressed});

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbTrail extends StatelessWidget {
  const _BreadcrumbTrail({
    required this.parent,
    required this.current,
    this.onParent,
  });

  final String parent;
  final String current;
  final VoidCallback? onParent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MouseRegion(
          cursor: onParent == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onParent,
            child: Text(
              parent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ),
        const Text(
          '  /  ',
          style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
        ),
        Flexible(
          child: Text(
            current,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.code,
    required this.l10n,
    required this.onSelected,
  });

  final String code;
  final AppLocalizations l10n;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = code == 'am'
        ? l10n.languageAmharicShort
        : l10n.languageEnglishShort;
    return PopupMenuButton<String>(
      tooltip: l10n.languagePreferenceTitle,
      initialValue: code,
      onSelected: onSelected,
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'en', child: Text(l10n.languageEnglish)),
        PopupMenuItem(value: 'am', child: Text(l10n.languageAmharic)),
      ],
      child: _HeaderPill(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({
    required this.greeting,
    required this.initial,
    required this.profileLabel,
    required this.onProfile,
  });

  final String greeting;
  final String initial;
  final String profileLabel;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: profileLabel,
      offset: const Offset(0, 44),
      onSelected: (_) => onProfile(),
      itemBuilder: (context) => [
        PopupMenuItem(value: 'profile', child: Text(profileLabel)),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: AppGradients.hero,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              greeting,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: WebTokens.surfaceBg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: WebTokens.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        child: child,
      ),
    );
  }
}
