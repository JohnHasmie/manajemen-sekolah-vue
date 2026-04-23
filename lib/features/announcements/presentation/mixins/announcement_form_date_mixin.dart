import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_form_sheet.dart';

/// Mixin for announcement form date picker logic.
mixin AnnouncementFormDateMixin on State<AnnouncementFormSheet> {
  /// Opens date picker and calls callback with selected date.
  Future<void> selectDate(
    BuildContext context,
    bool isStartDate,
    Function(DateTime) onDateSelected,
  ) async {
    final DateTime? picked = await showModernDatePicker(
      context: context,
      initialDate: DateTime.now(),
      title: isStartDate ? 'Pilih Tanggal Mulai' : 'Pilih Tanggal Selesai',
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }
}
