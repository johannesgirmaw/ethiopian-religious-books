import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../storage/form_draft_storage.dart';

typedef FormDraftCapture = Map<String, dynamic> Function();
typedef FormDraftRestore = void Function(Map<String, dynamic> data);
typedef FormDraftIsEmpty = bool Function(Map<String, dynamic> data);

/// Debounced local draft persistence for any form. Call [onChanged] from field
/// listeners, [persistNow] before cancel/dismiss, [clear] after a successful
/// submit, and [restoreIfPresent] during [initState].
class FormDraftController {
  FormDraftController({
    required String draftKey,
    required FormDraftCapture capture,
    required FormDraftRestore restore,
    FormDraftIsEmpty? isEmpty,
    this.debounce = const Duration(milliseconds: 1200),
  })  : scopedKey = draftKey,
        _capture = capture,
        _restore = restore,
        _isEmpty = isEmpty ?? _defaultIsEmpty;

  final String scopedKey;
  final Duration debounce;
  final FormDraftCapture _capture;
  final FormDraftRestore _restore;
  final FormDraftIsEmpty _isEmpty;

  Timer? _debounceTimer;
  bool _disposed = false;

  /// Loads a saved draft when present. Returns true when data was restored.
  Future<bool> restoreIfPresent() async {
    final envelope = await FormDraftStorage.read(scopedKey);
    if (envelope == null) return false;
    _restore(envelope.data);
    return true;
  }

  /// Schedules a debounced persist after the user edits a field.
  void onChanged() {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(persistNow());
    });
  }

  /// Writes the current form snapshot immediately.
  Future<void> persistNow() async {
    if (_disposed) return;
    final data = _capture();
    if (_isEmpty(data)) {
      await FormDraftStorage.delete(scopedKey);
      return;
    }
    await FormDraftStorage.write(scopedKey: scopedKey, data: data);
  }

  /// Removes the saved draft after a successful submit.
  Future<void> clear() => FormDraftStorage.delete(scopedKey);

  Future<bool> hasDraft() => FormDraftStorage.exists(scopedKey);

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
  }

  static bool _defaultIsEmpty(Map<String, dynamic> data) {
    for (final value in data.values) {
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      if (value is List && value.isEmpty) continue;
      if (value is Map && value.isEmpty) continue;
      if (value is bool && !value) continue;
      if (value is num && value == 0) continue;
      return false;
    }
    return true;
  }
}

void showFormDraftRestoredSnackBar(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.formDraftRestored)),
  );
}

void showFormDraftSavedSnackBar(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(l10n.formDraftSaved)),
  );
}

/// Returns true when the user chose to leave and discard the local draft.
Future<bool> confirmDiscardFormDraft(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final d = AppLocalizations.of(ctx)!;
      return AlertDialog(
        title: Text(d.formDraftDiscardTitle),
        content: Text(d.formDraftDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(d.stay),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(d.formDraftDiscardAction),
          ),
        ],
      );
    },
  );
  return result == true;
}
