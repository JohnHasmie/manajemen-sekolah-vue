/// date_utils.dart - Date parsing and formatting helpers with correct timezone handling.
/// Like a Laravel Helper function file (e.g., Carbon date helpers in `helpers.php`).
/// Solves the common timezone pitfall where `DateTime.parse("2024-01-15")` creates a
/// UTC date that shifts back one day when displayed in local time (e.g., WIB = UTC+7).
library;

import 'package:intl/intl.dart';

/// Provides static date utility methods for safe parsing and formatting.
/// Like a Laravel Helper function class. Wraps Dart's `DateTime.parse` and
/// the `intl` package's `DateFormat` with timezone-aware logic.
///
/// Key design decision: Dates without time components (e.g., "2024-01-15")
/// are parsed as **local time** instead of UTC to prevent the off-by-one-day bug
/// common in mobile apps. This is similar to how Carbon in Laravel handles
/// `Carbon::parse('2024-01-15')` in the app's configured timezone.
/// Maps English day names (from the backend) to Indonesian.
///
/// The backend `days` table stores English names (Monday, Tuesday, …).
/// Use this at the UI layer wherever day names are displayed to users.
const Map<String, String> _enToIdDayNames = {
  'Monday': 'Senin',
  'Tuesday': 'Selasa',
  'Wednesday': 'Rabu',
  'Thursday': 'Kamis',
  'Friday': 'Jumat',
  'Saturday': 'Sabtu',
  'Sunday': 'Minggu',
};

const Map<String, String> _idToEnDayNames = {
  'Senin': 'Monday',
  'Selasa': 'Tuesday',
  'Rabu': 'Wednesday',
  'Kamis': 'Thursday',
  'Jumat': 'Friday',
  'Sabtu': 'Saturday',
  'Minggu': 'Sunday',
};

/// Translate an English day name to Indonesian.
/// Returns the original string if no mapping is found.
String dayNameToIndonesian(String englishName) =>
    _enToIdDayNames[englishName] ?? englishName;

/// Translate an Indonesian day name to English.
/// Returns the original string if no mapping is found.
String dayNameToEnglish(String indonesianName) =>
    _idToEnDayNames[indonesianName] ?? indonesianName;

class AppDateUtils {
  /// Parse date string (YYYY-MM-DD) as local date, not UTC
  /// This prevents timezone issues that shift the date back by 1 day
  static DateTime parseLocalDate(String dateString) {
    try {
      // Parse with YYYY-MM-DD format
      final parts = dateString.split('-');
      if (parts.length == 3) {
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final day = int.parse(parts[2]);

        // Create DateTime as local time, not UTC
        return DateTime(year, month, day);
      }

      // Fallback: parse normally but convert to local
      return DateTime.parse(dateString).toLocal();
    } catch (e) {
      // If parsing fails, return today's date
      return DateTime.now();
    }
  }

  /// Format DateTime to YYYY-MM-DD string for sending to backend
  static String formatDateForApi(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Format DateTime to a more readable format: dd/MM/yyyy
  static String formatDateReadable(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Format DateTime to Indonesian format: dd MMMM yyyy
  static String formatDateIndonesian(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'id_ID').format(date);
  }

  /// Format DateTime to full format: EEEE, dd MMMM yyyy
  static String formatDateFull(DateTime date) {
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  }

  /// Safely parse date string from API response
  /// Handles various date formats and timezones
  static DateTime? parseApiDate(dynamic dateValue) {
    if (dateValue == null) return null;

    try {
      if (dateValue is DateTime) {
        return dateValue;
      }

      final String dateString = dateValue.toString();

      // If format is YYYY-MM-DD (without time), parse as local date
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateString)) {
        return parseLocalDate(dateString);
      }

      // If ISO timestamp (with T and timezone), parse normally
      if (dateString.contains('T')) {
        return DateTime.parse(dateString).toLocal();
      }

      // Default fallback
      return parseLocalDate(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Format date from string to the desired format
  /// With correct timezone handling
  static String formatDateString(
    String? dateString, {
    String format = 'dd/MM/yyyy',
  }) {
    if (dateString == null || dateString.isEmpty) return '-';

    try {
      final date = parseApiDate(dateString);
      if (date == null) return dateString;

      return DateFormat(format, 'id_ID').format(date);
    } catch (e) {
      return dateString;
    }
  }
}
