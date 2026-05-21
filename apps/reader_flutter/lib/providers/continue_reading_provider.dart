import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/reader_prefs_storage.dart';

final lastOpenedBookProvider = FutureProvider<LastOpenedBook?>((ref) async {
  return ReaderPrefsStorage.readLastOpenedBook();
});
