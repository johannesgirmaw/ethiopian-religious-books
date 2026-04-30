import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'providers/app_locale_provider.dart';
import 'storage/app_locale_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.ensureInitialized();
  final code = await AppLocaleStorage.readLanguageCode();
  appLocaleBootOverride =
      code == 'am' ? const Locale('am') : const Locale('en');
  runApp(const ProviderScope(child: EthiopianReaderApp()));
}
