import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

Document? documentFromStoredSummary(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;
  try {
    final parsed = jsonDecode(text);
    if (parsed is List) {
      final ops = parsed
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (ops.isNotEmpty) {
        return Document.fromJson(ops);
      }
    }
  } catch (_) {}
  return null;
}

String plainTextFromStoredSummary(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final doc = documentFromStoredSummary(raw);
  if (doc != null) {
    return doc.toPlainText().replaceAll('\uFFFC', '').trim();
  }
  return raw.replaceAll('\uFFFC', '').trim();
}
