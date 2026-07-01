import 'package:flutter_test/flutter_test.dart';
import 'package:ethiopian_reader/utils/geez_numerals.dart';

void main() {
  group('toGeezNumeral', () {
    const cases = <int, String>{
      1: '፩',
      2: '፪',
      9: '፱',
      10: '፲',
      11: '፲፩',
      20: '፳',
      30: '፴',
      79: '፸፱',
      99: '፺፱',
      100: '፻',
      101: '፻፩',
      110: '፻፲',
      123: '፻፳፫',
      150: '፻፶',
      200: '፪፻',
      1000: '፲፻',
      1979: '፲፱፻፸፱',
      10000: '፼',
      20000: '፪፼',
    };

    cases.forEach((number, geez) {
      test('$number → $geez', () => expect(toGeezNumeral(number), geez));
    });

    test('0 and negatives fall back to Western digits', () {
      expect(toGeezNumeral(0), '0');
      expect(toGeezNumeral(-5), '-5');
    });
  });

  group('parseGeezNumeral round-trips', () {
    for (final n in [1, 9, 10, 11, 99, 100, 123, 200, 1000, 1979, 10000, 20000]) {
      test('$n', () => expect(parseGeezNumeral(toGeezNumeral(n)), n));
    }

    test('non-Ge\'ez input returns null', () {
      expect(parseGeezNumeral('123'), isNull);
      expect(parseGeezNumeral('abc'), isNull);
      expect(parseGeezNumeral(''), isNull);
    });
  });

  group('formatNumber', () {
    test('geez vs arabic', () {
      expect(formatNumber(16, geez: true), '፲፮');
      expect(formatNumber(16, geez: false), '16');
    });
  });
}
