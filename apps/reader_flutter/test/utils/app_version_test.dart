import 'package:flutter_test/flutter_test.dart';

import 'package:ethiopian_reader/utils/app_release.dart';
import 'package:ethiopian_reader/utils/app_version.dart';

void main() {
  test('compares dotted versions and the build number', () {
    expect(
      AppVersion.parse('1.0.1+2').isNewerThan(AppVersion.parse('1.0.0+9')),
      isTrue,
    );
    expect(
      AppVersion.parse('1.0.1+3').isNewerThan(AppVersion.parse('1.0.1+2')),
      isTrue,
    );
    expect(
      AppVersion.parse('1.0.1+2').isNewerThan(AppVersion.parse('1.0.1+2')),
      isFalse,
    );
    expect(
      AppVersion.parse('2.0.0+1').isNewerThan(AppVersion.parse('1.9.9+99')),
      isTrue,
    );
    expect(AppVersion('1.0').versionName, '1.0.0');
    expect(
      AppVersion.fromPackage(version: '1.0.1+2', buildNumber: '').build,
      2,
    );
    expect(
      AppVersion.fromPackage(version: '1.0.1', buildNumber: '2').build,
      2,
    );
  });

  test('accepts only a newer trusted installer for this platform', () {
    const json = {
      'version': '1.0.2',
      'build': 3,
      'android': 'https://felegemetsahft.com/downloads/felege-metsahft.apk',
      'windows':
          'http://felegemetsahft.com/downloads/felege-metsahft-setup.exe',
      'macos': 'https://example.com/downloads/felege-metsahft-macos.dmg',
    };
    final local = AppVersion.parse('1.0.1+2');

    final android = newerReleaseFromJson(json, 'android', local);
    expect(android?.version, '1.0.2');
    expect(android?.url, json['android']);

    expect(newerReleaseFromJson(json, 'windows', local), isNull);
    expect(newerReleaseFromJson(json, 'macos', local), isNull);
    expect(newerReleaseFromJson(json, 'linux', local), isNull);
    expect(
      newerReleaseFromJson(json, 'android', AppVersion.parse('1.0.2+3')),
      isNull,
    );
    expect(newerReleaseFromJson('nope', 'android', local), isNull);
  });
}
