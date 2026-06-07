import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

const kNotJustNow = {'en': 'Just now', 'id': 'Baru saja'};
const kNotMinutesAgo = {
  'en': '{n} minutes ago',
  'id': '{n} menit yang lalu',
};
const kNotHoursAgo = {'en': '{n} hours ago', 'id': '{n} jam yang lalu'};
const kNotDaysAgo = {'en': '{n} days ago', 'id': '{n} hari yang lalu'};

/// Mixin for date formatting and time-ago display.
mixin DateFormattingMixin {
  String formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return kNotJustNow.tr;
      if (diff.inMinutes < 60) {
        return kNotMinutesAgo.tr.replaceAll('{n}', '${diff.inMinutes}');
      }
      if (diff.inHours < 24) {
        return kNotHoursAgo.tr.replaceAll('{n}', '${diff.inHours}');
      }
      if (diff.inDays < 7) {
        return kNotDaysAgo.tr.replaceAll('{n}', '${diff.inDays}');
      }
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
