import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_date_pickers.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_dialog.dart';

/// Mixin providing date and deadline picker functionality
mixin ActivityDatePickerMixin on ConsumerState<AddActivityDialog> {
  final List<String> days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  /// Shows a date picker modal for activity date selection
  void showActivityDatePicker({
    required BuildContext context,
    required DateTime initialDate,
    required Function(DateTime) onDateSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityDatePicker(
        initialDate: initialDate,
        title: 'Pilih Tanggal Kegiatan',
        onDateSelected: onDateSelected,
      ),
    );
  }

  /// Shows a date-time picker modal for deadline selection
  void showDeadlinePicker({
    required BuildContext context,
    required DateTime initialDateTime,
    required Function(DateTime) onDateTimeSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActivityDateTimePicker(
        initialDateTime: initialDateTime,
        title: 'Pilih Batas Waktu',
        onDateTimeSelected: onDateTimeSelected,
      ),
    );
  }

  /// Gets the day name from a date's weekday
  String getDayName(DateTime date) {
    return days[date.weekday - 1];
  }
}
