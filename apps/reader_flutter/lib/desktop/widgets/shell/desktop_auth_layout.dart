import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_locale_provider.dart';
import '../../../widgets/primitives/shared_widgets.dart';
import 'desktop_auth_book_stack.dart';

/// Native desktop auth layout: brand panel + form column.
class DesktopAuthLayout extends ConsumerWidget {
  const DesktopAuthLayout({
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          const Expanded(flex: 5, child: DesktopAuthBrandPanel()),
          Expanded(
            flex: 4,
            child: DesktopAuthFormPane(
              headline: headline,
              subtitle: subtitle,
              formChild: formChild,
              footer: footer,
            ),
          ),
        ],
      ),
    );
  }
}

class DesktopAuthBrandPanel extends StatelessWidget {
  const DesktopAuthBrandPanel({super.key});

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
              top: -72,
              left: -48,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.10),
                ),
              ),
            ),
            Positioned(
              bottom: -36,
              right: -16,
              child: Container(
                width: 200,
                height: 200,
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
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppBrandWordmark(
                        fontSize: 38,
                        color: AppColors.primary,
                        stacked: true,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.splashTagline,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),
                      const DesktopAuthBookStack(),
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

class DesktopAuthFormPane extends ConsumerWidget {
  const DesktopAuthFormPane({
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
    final l10n = AppLocalizations.of(context);

    return ColoredBox(
      color: AppColors.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const AppBrandWordmark(
                      fontSize: 18,
                      stacked: true,
                      color: AppColors.primary,
                    ),
                    const Spacer(),
                    SegmentedButton<String>(
                      style: SegmentedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      segments: [
                        ButtonSegment(
                          value: 'en',
                          label: Text(
                            l10n.languageEnglishShort,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        ButtonSegment(
                          value: 'am',
                          label: Text(
                            l10n.languageAmharicShort,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                      selected: {code},
                      onSelectionChanged: (s) async =>
                          ref.setAppLocale(Locale(s.first)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  headline,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
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
                if (footer != null) ...[const SizedBox(height: 16), footer!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
