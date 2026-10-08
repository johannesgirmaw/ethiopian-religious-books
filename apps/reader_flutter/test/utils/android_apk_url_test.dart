import 'package:ethiopian_reader/utils/android_apk_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native tests use the public landing APK url', () {
    expect(
      androidApkDownloadUrl(),
      'https://felegemetsahft.com/downloads/felege-metsahft.apk',
    );
    expect(androidApkFileName, 'felege-metsahft.apk');
  });
}
