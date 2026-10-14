/// Numeric app version (`major.minor.patch`) plus the Android-style build number.
class AppVersion implements Comparable<AppVersion> {
  AppVersion(String version, [this.build = 0]) : parts = _parts(version);

  /// Parses a pubspec value such as `1.0.1+2`.
  factory AppVersion.parse(String spec) {
    final bits = spec.trim().split('+');
    final build = bits.length > 1 ? int.tryParse(bits[1]) ?? 0 : 0;
    return AppVersion(bits.first, build);
  }

  /// Combines [PackageInfo.version] and [PackageInfo.buildNumber].
  ///
  /// An empty build number keeps the `+build` suffix from [version].
  factory AppVersion.fromPackage({
    required String version,
    required String buildNumber,
  }) {
    final parsed = AppVersion.parse(version);
    final build = int.tryParse(buildNumber);
    if (build == null) return parsed;
    return AppVersion(parsed.versionName, build);
  }

  final List<int> parts;
  final int build;

  String get versionName => parts.join('.');

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    for (var i = 0; i < 3; i++) {
      final delta = parts[i].compareTo(other.parts[i]);
      if (delta != 0) return delta;
    }
    return build.compareTo(other.build);
  }

  static List<int> _parts(String version) {
    final name = version.split('+').first.trim();
    final nums = name
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums.take(3).toList();
  }
}
