// Grade-level dropdown for the "Create New Class" dialog in the promotion wizard.
// Converts integer grade levels to human-readable SD/SMP/SMA labels.
// Receives the available grade list from the parent to stay stateless.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A form dropdown that lists available grade levels (e.g. "Kelas 7 SMP").
///
/// Like a `<grade-select>` Vue component — stateless, fires [onChanged].
/// [availableGradeLevels] is a list of numeric strings (e.g. ["7","8","9"]).
/// [primaryColor] sets the leading icon colour.
class PromotionGradeLevelDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final LanguageProvider languageProvider;
  final List<String> availableGradeLevels;
  final Color primaryColor;

  const PromotionGradeLevelDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    required this.languageProvider,
    required this.availableGradeLevels,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: languageProvider.getTranslatedText({
            'en': 'Grade Level',
            'id': 'Tingkat Kelas',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate600, fontSize: 13),
          prefixIcon: Icon(
            Icons.grade_rounded,
            color: primaryColor,
            size: 18,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: availableGradeLevels.map((gradeStr) {
          final grade = int.tryParse(gradeStr) ?? 0;
          String gradeText;
          if (grade <= 6) {
            gradeText = 'Kelas $grade SD';
          } else if (grade <= 9) {
            gradeText = 'Kelas $grade SMP';
          } else {
            gradeText = 'Kelas $grade SMA';
          }
          return DropdownMenuItem<String>(
            value: gradeStr,
            child: Text(gradeText),
          );
        }).toList(),
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }
}
