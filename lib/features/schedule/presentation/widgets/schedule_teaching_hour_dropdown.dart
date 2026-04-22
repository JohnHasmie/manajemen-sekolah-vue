import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/form_field_section.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class ScheduleTeachingHourDropdown extends StatelessWidget {
  final List<dynamic> teachingHours;
  final List<dynamic> occupiedSlots;
  final String selectedValue;
  final Function(String) onChanged;
  final LanguageProvider languageProvider;
  final Color primaryColor;
  final bool isLoading;

  const ScheduleTeachingHourDropdown({
    super.key,
    required this.teachingHours,
    required this.occupiedSlots,
    required this.selectedValue,
    required this.onChanged,
    required this.languageProvider,
    required this.primaryColor,
    this.isLoading = false,
  });

  String _formatTime(String? timeString) {
    if (timeString == null || timeString.isEmpty) return '07:00';
    try {
      if (timeString.contains(':')) {
        final parts = timeString.split(':');
        if (parts.length >= 2) {
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
        }
      }
      return timeString;
    } catch (e) {
      return '07:00';
    }
  }

  List<DropdownMenuItem<String>> _buildItems() {
    final seenIds = <String>{};
    return teachingHours
        .where((jam) {
          final id = jam['id']?.toString() ?? '';
          if (id.isEmpty || seenIds.contains(id)) {
            return false;
          }
          seenIds.add(id);
          return true;
        })
        .map<DropdownMenuItem<String>>((jam) {
          final jamId = jam['id'].toString();
          final isOccupied = occupiedSlots.any((occupied) {
            final occId =
                occupied['lesson_hour_days_id']?.toString() ??
                occupied['lesson_hour_id']?.toString() ??
                (occupied['lesson_hour'] != null
                    ? occupied['lesson_hour']['id']?.toString()
                    : null);
            return occId == jamId;
          });

          final jamMulai = _formatTime(
            jam['start_time']?.toString() ?? jam['jam_mulai']?.toString(),
          );
          final jamSelesai = _formatTime(
            jam['end_time']?.toString() ?? jam['jam_selesai']?.toString(),
          );
          final label = isOccupied
              ? '$jamMulai - $jamSelesai (Terisi)'
              : '$jamMulai - $jamSelesai';

          return DropdownMenuItem<String>(
            value: jamId,
            enabled: !isOccupied,
            child: Opacity(
              opacity: !isOccupied ? 1.0 : 0.5,
              child: Text(label),
            ),
          );
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return FormDropdownField<String>(
      label: languageProvider.getTranslatedText({
        'en': 'Teaching Hour',
        'id': 'Jam Pelajaran',
      }),
      isRequired: true,
      value: selectedValue.isEmpty ? null : selectedValue,
      items: _buildItems(),
      onChanged: (value) {
        if (!isLoading) onChanged(value ?? '');
      },
      hintText: languageProvider.getTranslatedText({
        'en': 'Select Teaching Hour',
        'id': 'Pilih Jam Pelajaran',
      }),
      isLoading: isLoading,
      errorText: selectedValue.isEmpty
          ? languageProvider.getTranslatedText({
              'en': 'Please select a teaching hour',
              'id': 'Harap pilih jam pelajaran',
            })
          : null,
    );
  }
}
