import '../config/app_config.dart';

/// Rewrites a catalog [cover_url] so image requests use the same API host as
/// [AppConfig.apiBaseUrl]. The server may return `127.0.0.1` while the desktop
/// app talks to a LAN IP — without this, [Image.network] fails silently.
String? resolveCoverUrl(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;

  final api = Uri.parse(AppConfig.apiBaseUrl);
  final origin = Uri(
    scheme: api.scheme,
    host: api.host,
    port: api.hasPort ? api.port : null,
  );

  final parsed = Uri.tryParse(trimmed);
  if (parsed == null) return trimmed;

  late Uri target;
  if (parsed.hasScheme && parsed.host.isNotEmpty) {
    target = parsed;
  } else {
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    target = Uri.parse('http://placeholder$path');
  }

  return origin
      .replace(
        path: target.path,
        query: target.query,
        fragment: target.fragment,
      )
      .toString();
}
