import 'app_version.dart';

/// A newer installer published at `https://felegemetsahft.com/downloads/`.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.build,
    required this.url,
  });

  final String version;
  final int build;
  final String url;
}

const appReleasesUrl = 'https://felegemetsahft.com/downloads/releases.json';

/// Picks [platformKey] from a releases manifest when it is newer than [local].
///
/// Returns null for a current install, a missing file, or a URL that is not
/// hosted on the public download site.
AppRelease? newerReleaseFromJson(
  Object? data,
  String platformKey,
  AppVersion local,
) {
  if (data is! Map) return null;
  final version = data['version'];
  final url = data[platformKey];
  if (version is! String || version.trim().isEmpty) return null;
  if (url is! String || !_isTrustedDownload(url)) return null;
  final buildValue = data['build'];
  final build = buildValue is int
      ? buildValue
      : int.tryParse('$buildValue') ?? 0;
  final remote = AppVersion(version, build);
  if (!remote.isNewerThan(local)) return null;
  return AppRelease(version: remote.versionName, build: build, url: url);
}

bool _isTrustedDownload(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.hasAuthority == false) return false;
  if (uri.scheme != 'https' || uri.host != 'felegemetsahft.com') return false;
  if (uri.userInfo.isNotEmpty) return false;
  return uri.path.startsWith('/downloads/');
}
