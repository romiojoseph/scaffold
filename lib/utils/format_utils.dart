import 'dart:io';
import 'package:intl/intl.dart';

class FormatUtils {
  FormatUtils._();

  // Country/Locale-based number formatting

  /// Formats numbers according to detected country/system locale with thousand separators.
  /// Example (US): 1234567 -> "1,234,567"
  /// Example (DE/FR): 1234567 -> "1.234.567" or "1 234 567"
  static String formatNumber(num number, {String? locale}) {
    final systemLocale = locale ?? Platform.localeName;
    try {
      final formatter = NumberFormat.decimalPattern(systemLocale);
      return formatter.format(number);
    } catch (_) {
      return NumberFormat.decimalPattern('en_US').format(number);
    }
  }

  /// Formats decimal numbers with fixed fraction digits according to country locale.
  static String formatDecimal(
    num number, {
    int decimalPlaces = 2,
    String? locale,
  }) {
    final systemLocale = locale ?? Platform.localeName;
    try {
      final formatter = NumberFormat.currency(
        locale: systemLocale,
        symbol: '',
        decimalDigits: decimalPlaces,
      );
      return formatter.format(number).trim();
    } catch (_) {
      return number.toStringAsFixed(decimalPlaces);
    }
  }

  /// Compact number format (e.g. 1.2M, 4.5K)
  static String formatCompactNumber(num number, {String? locale}) {
    final systemLocale = locale ?? Platform.localeName;
    try {
      return NumberFormat.compact(locale: systemLocale).format(number);
    } catch (_) {
      return number.toString();
    }
  }

  // Date formatting patterns

  /// Pattern 1: 07/08/2026 (DD/MM/YYYY)
  static String formatDateSlash(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  /// Pattern 2: 07-08-2026 (DD-MM-YYYY)
  static String formatDateDash(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd-MM-yyyy').format(dt);
  }

  /// Pattern 3: 07 Aug 2026
  static String formatDateShortMonth(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  /// Pattern 4: 07 Aug 2026 09:41 PM (Short month + 12-hour time)
  static String formatDateShortMonthTime12h(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd MMM yyyy hh:mm a').format(dt);
  }

  /// Pattern 5: 07 August 2026 (Full Month)
  static String formatDateFullMonth(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd MMMM yyyy').format(dt);
  }

  /// Pattern 6: Aug 07, 2026 (US standard)
  static String formatDateUs(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(dt);
  }

  /// Pattern 7: 2026-08-07 (ISO YYYY-MM-DD)
  static String formatDateIso(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  /// Pattern 8: Friday, 07 Aug 2026 (Full weekday name)
  static String formatDateFullWeekday(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('EEEE, dd MMM yyyy').format(dt);
  }

  /// Pattern 9: 07/08/26 (Short year)
  static String formatDateShortYear(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd/MM/yy').format(dt);
  }

  /// Pattern 10: 20260807 (Compact ISO integer string)
  static String formatDateCompact(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('yyyyMMdd').format(dt);
  }

  // Time & 12-Hour formats

  /// 12-Hour Time Format (e.g. 09:41 PM)
  static String formatTime12h(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('hh:mm a').format(dt);
  }

  /// 12-Hour Time with seconds (e.g. 09:41:25 PM)
  static String formatTime12hWithSeconds(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('hh:mm:ss a').format(dt);
  }

  /// Full Date & 12-Hour Time (e.g. 2026-08-07 09:41:25 PM)
  static String formatDateTimeIso12h(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('dd MMM yyyy, h:mm a').format(dt);
  }
}
