/// Utility to format attraction entry fees with their native currency.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats an entry fee with the specified currency code.
  ///
  /// Examples:
  /// - (0, 'USD') -> 'Free'
  /// - (29, 'EUR') -> '€29'
  /// - (25, 'USD') -> '$25'
  /// - (25, 'INR') -> '₹25'
  /// - (1500, 'JPY') -> '¥1,500'
  /// - (30, 'AED') -> 'AED 30'
  /// - (20, 'GBP') -> '£20'
  static String format(num? fee, {String? currency}) {
    if (fee == null) return 'Not available';
    if (fee == 0) return 'Free';

    final code = currency?.toUpperCase().trim() ?? 'USD';
    final symbol = symbolFor(code);

    final isWhole = fee == fee.roundToDouble();
    final formattedNumber = isWhole
        ? _formatWithCommas(fee.toInt())
        : fee.toStringAsFixed(2);

    final endsWithDollar = symbol.endsWith(r'$');
    if (symbol.length == 1 || endsWithDollar) {
      return '$symbol$formattedNumber';
    }
    return '$symbol $formattedNumber';
  }

  /// Returns the symbol or standard code representation for a currency code.
  static String symbolFor(String code) {
    switch (code.toUpperCase().trim()) {
      case 'EUR':
        return '€';
      case 'USD':
        return '\$';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'INR':
        return '₹';
      case 'AUD':
        return 'A\$';
      case 'CAD':
        return 'C\$';
      case 'BRL':
        return 'R\$';
      case 'EGP':
        return 'EGP';
      case 'AED':
        return 'AED';
      case 'SGD':
        return 'S\$';
      default:
        return code.toUpperCase();
    }
  }

  static String _formatWithCommas(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) {
        buffer.write(',');
      }
    }
    return buffer.toString().split('').reversed.join();
  }
}
