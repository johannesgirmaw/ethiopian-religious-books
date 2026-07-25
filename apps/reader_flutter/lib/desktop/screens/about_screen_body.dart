import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/primitives/shared_widgets.dart';
import '../design/desktop_tokens.dart';
import '../layout/desktop_layout_scope.dart';
import '../widgets/common/desktop_page_header.dart';
import '../widgets/common/desktop_section.dart';

class DesktopAboutScreenBody extends StatelessWidget {
  const DesktopAboutScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final padding =
        DesktopTokens.pagePadding(DesktopLayoutScope.tierOf(context));
    final tier = DesktopLayoutScope.tierOf(context);

    final sections = [
      _AboutPanel(
        title: l10n.aboutAppSectionTitle,
        content: l10n.aboutAppSectionBody,
        icon: Icons.info_outline_rounded,
      ),
      _AboutPanel(
        title: l10n.aboutVersionSectionTitle,
        content: l10n.aboutVersionValue,
        icon: Icons.language_rounded,
      ),
      _AboutPanel(
        title: l10n.aboutDevelopersSectionTitle,
        content: l10n.aboutDevelopersBody,
        icon: Icons.code_rounded,
      ),
    ];

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopPageHeader(
            title: l10n.aboutTitle,
            subtitle: l10n.aboutAppSectionBody,
          ),
          const SizedBox(height: 24),
          DesktopPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const AppBrandWordmark(fontSize: 20, stacked: true),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    l10n.splashTagline,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          DesktopSection(
            title: l10n.aboutTitle.toUpperCase(),
            child: tier == DesktopLayoutTier.expanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < sections.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i < sections.length - 1 ? 12 : 0,
                            ),
                            child: sections[i],
                          ),
                        ),
                    ],
                  )
                : Column(
                    children: [
                      for (var i = 0; i < sections.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        sections[i],
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AboutPanel extends StatelessWidget {
  const _AboutPanel({
    required this.title,
    required this.content,
    required this.icon,
  });

  final String title;
  final String content;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DesktopPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.referencePrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.referencePrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.55,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
