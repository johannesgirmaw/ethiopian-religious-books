import 'package:flutter/material.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/primitives/shared_widgets.dart';
import '../design/web_tokens.dart';
import '../layout/app_layout_scope.dart';
import '../widgets/common/web_page_header.dart';
import '../widgets/common/web_section.dart';

class AboutScreenBody extends StatelessWidget {
  const AboutScreenBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final padding = WebTokens.pagePadding(AppLayoutScope.tierOf(context));
    final tier = AppLayoutScope.tierOf(context);

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
          WebPageHeader(
            title: l10n.aboutTitle,
            subtitle: l10n.aboutAppSectionBody,
          ),
          const SizedBox(height: 28),
          WebPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogoTile(size: 72),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppBrandWordmark(fontSize: 18),
                      const SizedBox(height: 8),
                      Text(
                        l10n.splashTagline,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          WebSection(
            title: l10n.aboutTitle.toUpperCase(),
            child: tier == AppLayoutTier.expanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < sections.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: i < sections.length - 1 ? 16 : 0,
                            ),
                            child: sections[i],
                          ),
                        ),
                    ],
                  )
                : Column(
                    children: [
                      for (var i = 0; i < sections.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
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
    return WebPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.referencePrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.referencePrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
