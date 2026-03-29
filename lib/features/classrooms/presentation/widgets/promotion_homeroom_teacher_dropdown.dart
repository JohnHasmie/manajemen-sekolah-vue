// Homeroom-teacher dropdown for the "Create New Class" dialog in the promotion wizard.
// De-duplicates teacher records by ID and formats display as "Name (NIP: xxx)".
// Receives the full teacher list from the parent to stay stateless.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A form dropdown listing all available homeroom teachers.
///
/// Like a `<teacher-select>` Vue component — stateless, fires [onChanged].
/// [teachers] is the raw list of teacher maps from the API.
/// [primaryColor] sets the leading icon colour.
class PromotionHomeroomTeacherDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final LanguageProvider languageProvider;
  final List<dynamic> teachers;
  final Color primaryColor;

  const PromotionHomeroomTeacherDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    required this.languageProvider,
    required this.teachers,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    // De-duplicate teachers by ID (same as removing duplicate keys in a Vue computed).
    final uniqueTeachers = <String, Map<String, dynamic>>{};
    for (var teacher in teachers) {
      if (teacher['id'] != null) {
        uniqueTeachers[teacher['id'].toString()] = teacher;
      }
    }

    // Guard: if the current value is no longer in the list, reset to null.
    String? validValue = value;
    if (validValue != null && !uniqueTeachers.containsKey(validValue)) {
      validValue = null;
    }

    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: validValue,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Homeroom Teacher',
            'id': 'Wali Kelas',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate600, fontSize: 13),
          prefixIcon: Icon(
            Icons.person_rounded,
            color: primaryColor,
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        items: [
          DropdownMenuItem<String>(
            value: null,
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'No Homeroom Teacher',
                'id': 'Tidak ada wali kelas',
              }),
              style: TextStyle(color: ColorUtils.slate500),
            ),
          ),
          ...uniqueTeachers.values.map((teacher) {
            final teacherName = teacher['name'] ?? 'Unknown';
            final teacherNip = teacher['nip']?.toString() ?? '';
            final displayText = teacherNip.isNotEmpty
                ? '$teacherName (NIP: $teacherNip)'
                : teacherName;
            return DropdownMenuItem<String>(
              value: teacher['id'].toString(),
              child: Text(displayText, overflow: TextOverflow.ellipsis),
            );
          }),
        ],
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }
}
