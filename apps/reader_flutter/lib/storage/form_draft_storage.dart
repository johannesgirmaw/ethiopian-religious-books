import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persisted envelope for a single in-progress form draft.
class FormDraftEnvelope {
  FormDraftEnvelope({
    required this.key,
    required this.savedAtEpochMs,
    required this.data,
    this.version = FormDraftStorage.currentVersion,
  });

  final int version;
  final String key;
  final int savedAtEpochMs;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
        'version': version,
        'key': key,
        'saved_at': savedAtEpochMs,
        'data': data,
      };

  factory FormDraftEnvelope.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return FormDraftEnvelope(
      version: (json['version'] as num?)?.toInt() ??
          FormDraftStorage.currentVersion,
      key: json['key'] as String? ?? '',
      savedAtEpochMs: (json['saved_at'] as num?)?.toInt() ?? 0,
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
    );
  }
}

/// Local persistence for unsaved form state. Drafts survive navigation,
/// app restarts, and platform switches until the form is submitted or
/// explicitly discarded.
class FormDraftStorage {
  FormDraftStorage._();

  static const currentVersion = 1;
  static const _indexKey = 'form_draft_index_v1';
  static const _payloadPrefix = 'form_draft_payload_v1_';

  static String _payloadKey(String scopedKey) =>
      '$_payloadPrefix${Uri.encodeComponent(scopedKey)}';

  static Future<FormDraftEnvelope?> read(String scopedKey) async {
    if (scopedKey.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_payloadKey(scopedKey));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return FormDraftEnvelope.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> exists(String scopedKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_payloadKey(scopedKey));
  }

  static Future<void> write({
    required String scopedKey,
    required Map<String, dynamic> data,
  }) async {
    if (scopedKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final envelope = FormDraftEnvelope(
      key: scopedKey,
      savedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      data: data,
    );
    await prefs.setString(
      _payloadKey(scopedKey),
      jsonEncode(envelope.toJson()),
    );
    await _upsertIndex(prefs, scopedKey, envelope.savedAtEpochMs);
  }

  static Future<void> delete(String scopedKey) async {
    if (scopedKey.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_payloadKey(scopedKey));
    await _removeFromIndex(prefs, scopedKey);
  }

  static Future<List<FormDraftEnvelope>> listAll() async {
    final prefs = await SharedPreferences.getInstance();
    final index = _readIndex(prefs);
    final out = <FormDraftEnvelope>[];
    for (final key in index.keys) {
      final envelope = await read(key);
      if (envelope != null) out.add(envelope);
    }
    out.sort((a, b) => b.savedAtEpochMs.compareTo(a.savedAtEpochMs));
    return out;
  }

  static Future<void> _upsertIndex(
    SharedPreferences prefs,
    String scopedKey,
    int savedAtEpochMs,
  ) async {
    final index = _readIndex(prefs);
    index[scopedKey] = savedAtEpochMs;
    await prefs.setString(_indexKey, jsonEncode(index));
  }

  static Future<void> _removeFromIndex(
    SharedPreferences prefs,
    String scopedKey,
  ) async {
    final index = _readIndex(prefs);
    index.remove(scopedKey);
    await prefs.setString(_indexKey, jsonEncode(index));
  }

  static Map<String, int> _readIndex(SharedPreferences prefs) {
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), (value as num).toInt()),
      );
    } catch (_) {
      return {};
    }
  }
}
