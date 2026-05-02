import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart';

Document? documentFromStoredSummary(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;
  try {
    final parsed = jsonDecode(text);
    List<dynamic>? ops;
    if (parsed is List) {
      ops = parsed;
    } else if (parsed is Map) {
      final rawOps = Map<String, dynamic>.from(parsed)['ops'];
      if (rawOps is List) {
        ops = rawOps;
      }
    }
    if (ops != null && ops.isNotEmpty) {
      final opMaps = ops
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (opMaps.isNotEmpty) {
        return Document.fromJson(opMaps);
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
