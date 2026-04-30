/// Turn DRF-style JSON error bodies into a single user-visible string.
String? messageFromDioResponse(dynamic data) {
  if (data is! Map) return null;
  final m = Map<String, dynamic>.from(data);

  String? stringify(dynamic v) {
    if (v == null) return null;
    if (v is List) {
      return v
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .join(' ');
    }
    return v.toString().trim();
  }

  const orderedKeys = [
    'non_field_errors',
    'email',
    'password',
    'username',
    'display_name',
  ];
  for (final key in orderedKeys) {
    if (m.containsKey(key)) {
      final s = stringify(m[key]);
      if (s != null && s.isNotEmpty) return s;
    }
  }
  if (m['detail'] != null) {
    final s = stringify(m['detail']);
    if (s != null && s.isNotEmpty) return s;
  }
  final err = m['error'];
  if (err is Map) {
    final em = Map<String, dynamic>.from(err);
    final s = stringify(em['message']) ?? stringify(em['code']);
    if (s != null && s.isNotEmpty) return s;
  }
  for (final e in m.entries) {
    if (orderedKeys.contains(e.key) || e.key == 'detail') continue;
    final s = stringify(e.value);
    if (s != null && s.isNotEmpty) return s;
  }
  return null;
}
