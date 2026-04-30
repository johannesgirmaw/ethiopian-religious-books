import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_locale_provider.dart';

class LanguagePreferenceCard extends ConsumerStatefulWidget {
  const LanguagePreferenceCard({super.key});

  @override
  ConsumerState<LanguagePreferenceCard> createState() =>
      _LanguagePreferenceCardState();
}

class _LanguagePreferenceCardState extends ConsumerState<LanguagePreferenceCard> {
  late String _draftCode;

  @override
  void initState() {
    super.initState();
    _draftCode = ref.read(appLocaleProvider).languageCode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              title: Text(l10n.languagePreferenceTitle),
              subtitle: Text(l10n.languagePreferenceSubtitle),
            ),
            RadioListTile<String>(
              title: Text(l10n.languageEnglish),
              value: 'en',
              groupValue: _draftCode,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _draftCode = v);
              },
            ),
            RadioListTile<String>(
              title: Text(l10n.languageAmharic),
              value: 'am',
              groupValue: _draftCode,
              onChanged: (v) {
                if (v == null) return;
                setState(() => _draftCode = v);
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: FilledButton(
                  onPressed: () async {
                    final locale =
                        _draftCode == 'am' ? const Locale('am') : const Locale('en');
                    await ref.setAppLocale(locale);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.languageSaved)),
                    );
                  },
                  child: Text(l10n.saveLanguage),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
