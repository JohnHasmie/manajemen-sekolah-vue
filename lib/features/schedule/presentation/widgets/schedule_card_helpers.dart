/// Helper utilities for schedule card functionality.
library;

/// Formats a raw time string like "07.30.00" or "07:30:00" → "07:30".
String formatTimeStr(String? time) {
  if (time == null || time.isEmpty) return '--:--';
  final cleanedTime = time.replaceAll('.', ':');
  final timeParts = cleanedTime.split(':');
  if (timeParts.length >= 2) {
    final hour = timeParts[0].padLeft(2, '0');
    final minute = timeParts[1].padLeft(2, '0');
    return '$hour:$minute';
  }
  return time.length >= 5 ? time.substring(0, 5) : time;
}

/// Day name translations for Indonesian and English.
const kDayNames = <String, Map<String, String>>{
  'Senin': {'en': 'Monday', 'id': 'Senin'},
  'Selasa': {'en': 'Tuesday', 'id': 'Selasa'},
  'Rabu': {'en': 'Wednesday', 'id': 'Rabu'},
  'Kamis': {'en': 'Thursday', 'id': 'Kamis'},
  'Jumat': {'en': 'Friday', 'id': 'Jumat'},
  'Sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
  'Minggu': {'en': 'Sunday', 'id': 'Minggu'},
};
