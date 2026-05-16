import 'package:intl/intl.dart';

class CurrencyFormatter {
  const CurrencyFormatter._();

  static String inr(num value) {
    final locale = Intl.getCurrentLocale();
    return NumberFormat.currency(
      locale: locale.isEmpty ? 'en_IN' : locale,
      symbol: '\u20B9',
      decimalDigits: 0,
    ).format(value);
  }
}
