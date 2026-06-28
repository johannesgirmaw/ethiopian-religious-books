import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../design/reference_assets.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_locale_provider.dart';
import '../../design/web_tokens.dart';
import '../../layout/app_layout_scope.dart';
import '../common/web_section.dart';

/// Wide-web auth layout: brand panel + form column.
class WebAuthLayout extends ConsumerWidget {
  const WebAuthLayout({
    super.key,
    required this.headline,
    required this.subtitle,
    required this.formChild,
    this.footer,
  });

  final String headline;
  final String subtitle;
  final Widget formChild;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = AppLayoutScope.tierOf(context);
    final isExpanded = tier == AppLayoutTier.expanded;

    return Scaffold(
      backgroundColor: WebTokens.canvasBg,
      body: AppLayoutScopeBuilder(
        child: SafeArea(
          child: isExpanded
              ? Row(
                  children: [
                    const Expanded(
                      flex: 5,
                      child: WebAuthBrandPanel(),
                    ),
                    Expanded(
                      flex: 4,
                      child: WebAuthFormPane(
                        headline: headline,
                        subtitle: subtitle,
                        formChild: formChild,
                        footer: footer,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: WebAuthFormPane(
                        headline: headline,
                        subtitle: subtitle,
                        formChild: formChild,
                        footer: footer,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class WebAuthBrandPanel extends StatelessWidget {
  const WebAuthBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppGradients.greetingMesh,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppGradients.gold,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppShadows.goldGlow,
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    ReferenceAssets.appLogo,
                    fit: BoxFit.contain,
                    color: AppColors.primaryDeep,
                    colorBlendMode: BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  l10n.appTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.splashTagline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WebAuthFormPane extends ConsumerWidget {
  const WebAuthFormPane({
    super.key,
    required this.headline,
    required this.subtitle,
    required this.formChild,
    this.footer,
  });

  final String headline;
  final String subtitle;
  final Widget formChild;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(appLocaleProvider).languageCode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.line),
              ),
              child: SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: 'en',
                    label: Text('EN', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment(
                    value: 'am',
                    label: Text('አማ', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {code},
                onSelectionChanged: (s) async =>
                    ref.setAppLocale(Locale(s.first)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            headline,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          WebPanel(
            padding: const EdgeInsets.all(28),
            child: formChild,
          ),
          if (footer != null) ...[
            const SizedBox(height: 20),
            footer!,
          ],
        ],
      ),
    );
  }
}
