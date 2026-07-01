/// Ethiopic (Ge'ez) numeral conversion.
///
/// Ge'ez numerals are not a positional decimal system: numbers are written in
/// two-digit groups whose place is marked by ፻ (100) and ፼ (10 000). This
/// implements the standard algorithm used across Ethiopic numeral libraries.
///
/// Symbols: units ፩–፱ (U+1369–U+1371), tens ፲–፺ (U+1372–U+137A),
/// hundred ፻ (U+137B), ten-thousand ፼ (U+137C). There is no zero.
library;

const _units = ['', '፩', '፪', '፫', '፬', '፭', '፮', '፯', '፰', '፱'];
const _tens = ['', '፲', '፳', '፴', '፵', '፶', '፷', '፸', '፹', '፺'];

/// Separator that marks the 100^p group (p counted from the right, 0-based):
/// p=1 → ፻, p=2 → ፼, p=3 → ፻፼, p=4 → ፼፼, …
String _separator(int p) {
  if (p == 0) return '';
  final buffer = StringBuffer();
  if (p.isOdd) buffer.write('፻');
  buffer.write('፼' * (p ~/ 2));
  return buffer.toString();
}

/// Converts a non-negative integer to Ge'ez numerals.
///
/// 0 (and negatives) have no Ge'ez form, so the Western digits are returned
/// verbatim — callers pass verse/chapter numbers which are always ≥ 1.
String toGeezNumeral(int value) {
  if (value <= 0) return value.toString();

  // Pad to an even number of decimal digits, then split into 2-digit pairs.
  var digits = value.toString();
  if (digits.length.isOdd) digits = '0$digits';
  final pairCount = digits.length ~/ 2;

  final out = StringBuffer();
  for (var i = 0; i < pairCount; i++) {
    final pos = pairCount - 1 - i; // 100^pos group
    final tens = int.parse(digits[i * 2]);
    final unit = int.parse(digits[i * 2 + 1]);
    final coeff = tens * 10 + unit;
    if (coeff == 0) continue; // empty group contributes nothing (no separator)

    // The coefficient "1" in front of a separator is implicit (100 = ፻, not ፩፻).
    if (!(coeff == 1 && pos > 0)) {
      out.write(_tens[tens]);
      out.write(_units[unit]);
    }
    out.write(_separator(pos));
  }
  return out.toString();
}

/// Formats [value] in the chosen system. [geez] false → Western/Arabic digits.
String formatNumber(int value, {required bool geez}) =>
    geez ? toGeezNumeral(value) : value.toString();

const _unitLookup = {
  '፩': 1, '፪': 2, '፫': 3, '፬': 4, '፭': 5, '፮': 6, '፯': 7, '፰': 8, '፱': 9,
};
const _tensLookup = {
  '፲': 10, '፳': 20, '፴': 30, '፵': 40, '፶': 50, '፷': 60, '፸': 70, '፹': 80, '፺': 90,
};
const _hundred = '፻';
const _tenThousand = '፼';

bool _isGeezDigit(String ch) =>
    _unitLookup.containsKey(ch) ||
    _tensLookup.containsKey(ch) ||
    ch == _hundred ||
    ch == _tenThousand;

/// Parses a Ge'ez numeral string back to an integer, or null if it isn't one.
/// Inverse of [toGeezNumeral] for well-formed input.
int? parseGeezNumeral(String input) {
  final s = input.trim();
  if (s.isEmpty || !s.split('').every(_isGeezDigit)) return null;

  var total = 0; // accumulated value
  var group = 0; // current <100 coefficient being built
  for (final ch in s.split('')) {
    if (_tensLookup.containsKey(ch)) {
      group += _tensLookup[ch]!;
    } else if (_unitLookup.containsKey(ch)) {
      group += _unitLookup[ch]!;
    } else if (ch == _hundred) {
      total += (group == 0 ? 1 : group) * 100;
      group = 0;
    } else if (ch == _tenThousand) {
      total = (total + (group == 0 ? 1 : group)) * 10000;
      group = 0;
    }
  }
  return total + group;
}
