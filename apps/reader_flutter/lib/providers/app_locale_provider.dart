import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_locale_storage.dart';

/// Set from [main] after reading storage, before [runApp].
Locale? appLocaleBootOverride;

final appLocaleProvider = StateProvider<Locale>(
  (ref) => appLocaleBootOverride ?? const Locale('en'),
);

extension AppLocaleWrite on WidgetRef {
  Future<void> setAppLocale(Locale locale) async {
    final normalized =
        locale.languageCode.toLowerCase() == 'am' ? const Locale('am') : const Locale('en');
    read(appLocaleProvider.notifier).state = normalized;
    await AppLocaleStorage.writeLanguageCode(normalized.languageCode);
  }
}
