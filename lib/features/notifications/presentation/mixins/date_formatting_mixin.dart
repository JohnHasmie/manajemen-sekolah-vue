import 'package:intl/intl.dart';

/// Mixin for date formatting and time-ago display.
mixin DateFormattingMixin {
  String formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes} menit yang lalu';
      }
      if (diff.inHours < 24) {
        return '${diff.inHours} jam yang lalu';
      }
      if (diff.inDays < 7) {
        return '${diff.inDays} hari yang lalu';
      }
      return DateFormat('dd MMM yyyy, HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
