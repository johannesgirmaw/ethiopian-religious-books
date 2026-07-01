import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/number_system_storage.dart';
import '../utils/geez_numerals.dart';

/// Set from [main] after reading storage, before [runApp].
bool numberSystemGeezBootOverride = false;

/// True = render numbers (chapter/verse) in Ge'ez; false = Western/Arabic.
final useGeezNumeralsProvider =
    StateProvider<bool>((ref) => numberSystemGeezBootOverride);

/// Formats [value] according to the current numeral-system preference.
String formatNumberFor(WidgetRef ref, int value) =>
    formatNumber(value, geez: ref.watch(useGeezNumeralsProvider));

extension NumberSystemWrite on WidgetRef {
  Future<void> setUseGeezNumerals(bool geez) async {
    read(useGeezNumeralsProvider.notifier).state = geez;
    await NumberSystemStorage.writeGeez(geez);
  }
}
