/// Formats an amount with a currency symbol/code, e.g. `$100.00`, `Br 50.00`.
String formatMoney(double amount, String currency) {
  final symbol = _symbols[currency.toUpperCase()];
  final value = amount.toStringAsFixed(2);
  if (symbol != null) {
    // Symbols that read naturally as a prefix without a space.
    if (symbol == r'$' || symbol == '€' || symbol == '£') {
      return '$symbol$value';
    }
    return '$symbol $value';
  }
  return '${currency.toUpperCase()} $value';
}

const Map<String, String> _symbols = {
  'USD': r'$',
  'EUR': '€',
  'GBP': '£',
  'ETB': 'Br',
};
