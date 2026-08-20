import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'providers/app_locale_provider.dart';
import 'providers/number_system_provider.dart';
import 'storage/app_locale_storage.dart';
import 'storage/number_system_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await pdfrxFlutterInitialize(dismissPdfiumWasmWarnings: true);
  await AppConfig.ensureInitialized();
  final code = await AppLocaleStorage.readLanguageCode();
  appLocaleBootOverride =
      code == 'am' ? const Locale('am') : const Locale('en');
  numberSystemGeezBootOverride = await NumberSystemStorage.readGeez();
  runApp(const ProviderScope(child: EthiopianReaderApp()));
}
