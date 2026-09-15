import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_locale_provider.dart';
import '../../../widgets/primitives/shared_widgets.dart';
import '../../layout/app_layout_scope.dart';
import 'web_auth_book_stack.dart';

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
      backgroundColor: AppColors.background,
      body: AppLayoutScopeBuilder(
        child: SafeArea(
          child: isExpanded
              ? Row(
                  children: [
                    const Expanded(flex: 5, child: WebAuthBrandPanel()),
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
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              left: -60,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              right: -20,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryMid.withValues(alpha: 0.14),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(48),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppBrandWordmark(
                        fontSize: 40,
                        color: AppColors.primary,
                        stacked: true,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.splashTagline,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),
                      const WebAuthBookStack(),
                    ],
                  ),
                ),
              ),
            ),
          ],
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

    return ColoredBox(
      color: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const AppBrandWordmark(
                  fontSize: 20,
                  stacked: true,
                  color: AppColors.primary,
                ),
                const Spacer(),
                Container(
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
              ],
            ),
            const SizedBox(height: 36),
            Text(
              headline,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDeep.withValues(alpha: 0.08),
                    blurRadius: 80,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: formChild,
              ),
            ),
            if (footer != null) ...[const SizedBox(height: 20), footer!],
          ],
        ),
      ),
    );
  }
}
