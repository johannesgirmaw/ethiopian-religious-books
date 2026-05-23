import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_locale_provider.dart';
import 'shared_widgets.dart';
import 'shell_primitives.dart';

/// Shared auth layout: inset greeting card + white form panel.
class AuthScreenLayout extends StatelessWidget {
  const AuthScreenLayout({
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.referencePageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerRight,
                    child: _LangToggle(),
                  ),
                  const SizedBox(height: 12),
                  AppGreetingCard(
                    greetingLine: greetingForL10n(l10n),
                    title: headline,
                    subtitle: subtitle,
                    showMenu: false,
                  ),
                  const SizedBox(height: 20),
                  const Center(child: AppLogoTile(size: 72)),
                  const SizedBox(height: 24),
                  AppPanel(
                    padding: const EdgeInsets.all(24),
                    child: formChild,
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 20),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LangToggle extends ConsumerWidget {
  const _LangToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(appLocaleProvider).languageCode;
    return Container(
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
        onSelectionChanged: (s) async => ref.setAppLocale(Locale(s.first)),
      ),
    );
  }
}
