import 'package:intl/intl.dart';

class AppDateUtils {
  const AppDateUtils._();

  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy', _locale).format(date.toLocal());
  }

  static String formatDateTime(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a', _locale).format(date.toLocal());
  }

  static String currentMonthLabel() =>
      DateFormat('MMMM yyyy', _locale).format(DateTime.now());

  static String monthLabel(DateTime date) =>
      DateFormat('MMMM yyyy', _locale).format(date.toLocal());

  static String timeAgo(DateTime? date) {
    if (date == null) return '-';
    final difference = DateTime.now().difference(date.toLocal());
    final hindi = _locale.startsWith('hi');
    if (difference.inMinutes < 1) return hindi ? 'अभी' : 'Just now';
    if (difference.inMinutes < 60) {
      return hindi
          ? '${difference.inMinutes} मिनट पहले'
          : '${difference.inMinutes}m ago';
    }
    if (difference.inHours < 24) {
      return hindi
          ? '${difference.inHours} घंटे पहले'
          : '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return hindi
          ? '${difference.inDays} दिन पहले'
          : '${difference.inDays}d ago';
    }
    return formatDate(date);
  }

  static String get _locale {
    final locale = Intl.getCurrentLocale();
    return locale.isEmpty ? 'en_IN' : locale;
  }
}
