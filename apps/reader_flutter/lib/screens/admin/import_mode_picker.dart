import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/admin_providers.dart';

/// Localized display name for a detection [mode] key.
String importModeLabel(AppLocalizations l10n, String mode) {
  switch (mode) {
    case 'auto':
      return l10n.importModeAuto;
    case 'heading':
      return l10n.importModeHeading;
    case 'patterns':
      return l10n.importModePatterns;
    case 'format':
      return l10n.importModeFormat;
    case 'pagebreak':
      return l10n.importModePagebreak;
    case 'marker':
      return l10n.importModeMarker;
    case 'size':
      return l10n.importModeSize;
    default:
      return mode;
  }
}

/// A radio list of detection strategies with per-mode chapter/page counts.
///
/// Built on Flutter's canonical [RadioGroup] + [RadioListTile] (robust across
/// platforms and the non-deprecated API in Flutter 3.32+), with a strong
/// whole-row selected affordance (filled background + border) and a stable
/// [Key] (`import-mode-<mode>`) per row so selection is easy to drive from
/// tests. Stateless — the parent owns [selectedMode] and updates it in
/// [onSelect].
class ImportModePicker extends StatelessWidget {
  const ImportModePicker({
    super.key,
    required this.modes,
    required this.selectedMode,
    required this.onSelect,
    this.recommendedMode = 'auto',
  });

  final List<ImportModeSummary> modes;
  final String selectedMode;
  final ValueChanged<String> onSelect;
  final String recommendedMode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RadioGroup<String>(
      groupValue: selectedMode,
      onChanged: (value) {
        if (value != null) onSelect(value);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final m in modes)
            Padding(
              key: Key('import-mode-${m.mode}'),
              padding: const EdgeInsets.only(bottom: 8),
              child: RadioListTile<String>(
                value: m.mode,
                selected: m.mode == selectedMode,
                controlAffinity: ListTileControlAffinity.leading,
                visualDensity: VisualDensity.compact,
                tileColor: Colors.transparent,
                selectedTileColor: scheme.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: m.mode == selectedMode
                        ? scheme.primary
                        : scheme.outlineVariant,
                    width: m.mode == selectedMode ? 2 : 1,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        importModeLabel(l10n, m.mode),
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: m.mode == selectedMode
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    if (m.mode == recommendedMode) ...[
                      const SizedBox(width: 8),
                      _Badge(text: l10n.importRecommendedBadge, scheme: scheme),
                    ],
                  ],
                ),
                subtitle: Text(l10n.importDetectedCounts(m.chapters, m.pages)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.scheme});
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}

/// Shows a sample of detected chapter [titles] (capped at [maxShown]) or the
/// "no chapters" placeholder — never blank. No inner scrollable, so it can't
/// collapse to zero height inside the dialog's own scroll view.
class DetectedChaptersList extends StatelessWidget {
  const DetectedChaptersList({
    super.key,
    required this.titles,
    this.maxShown = 8,
  });

  final List<String> titles;
  final int maxShown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    if (titles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(l10n.importNoChapters, style: textTheme.bodySmall),
      );
    }

    final shown = titles.take(maxShown).toList();
    final remaining = titles.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${i + 1}. ${shown[i]}', style: textTheme.bodySmall),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.importMoreTitles(remaining),
              style: textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
