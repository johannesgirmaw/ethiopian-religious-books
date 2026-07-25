import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/app_locale_provider.dart';
import '../../../widgets/primitives/shared_widgets.dart';
import '../../design/desktop_tokens.dart';
import '../common/desktop_section.dart';

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
      backgroundColor: DesktopTokens.canvasBg,
      body: Row(
        children: [
          const Expanded(
            flex: 5,
            child: DesktopAuthBrandPanel(),
          ),
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
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppGradients.greetingMesh,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogoTile(size: 64),
                const SizedBox(height: 24),
                const AppBrandWordmark(
                  fontSize: 32,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.splashTagline,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 15,
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

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
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
              const SizedBox(height: 24),
              Text(
                headline,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              DesktopPanel(
                padding: const EdgeInsets.all(28),
                child: formChild,
              ),
              if (footer != null) ...[
                const SizedBox(height: 16),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
