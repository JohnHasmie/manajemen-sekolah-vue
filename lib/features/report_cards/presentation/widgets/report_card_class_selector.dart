// Class selector dropdown for the teacher report card screen.
// Replaces _buildClassSelector() from teacher_report_card_screen.dart.
// Like a Vue <ClassSelector> component that emits 'class-changed' upward.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Displays a styled dropdown that lets the teacher pick a homeroom class.
///
/// All state is passed in as constructor params (like Vue props). The widget
/// fires [onClassChanged] upward instead of calling setState directly — just
/// like Vue `$emit('class-changed', newClass)`.
class ReportCardClassSelector extends StatelessWidget {
  /// The key forwarded to the outer container (used by the tour overlay).
  final GlobalKey selectorKey;

  /// All classes available for selection.
  final List<dynamic> classes;

  /// Currently selected class, or null when nothing is chosen yet.
  final Map<String, dynamic>? selectedClass;

  /// Language helper — injected from parent so locale changes propagate.
  final LanguageProvider languageProvider;

  /// Fired when the user picks a different class from the dropdown.
  /// Parent is responsible for updating state and reloading students.
  final ValueChanged<Map<String, dynamic>> onClassChanged;

  const ReportCardClassSelector({
    super.key,
    required this.selectorKey,
    required this.classes,
    required this.selectedClass,
    required this.languageProvider,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: selectorKey,
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: ColorUtils.corporateShadow(),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Icon(
              Icons.class_outlined,
              color: ColorUtils.slate600,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select Class',
                    'id': 'Pilih Kelas',
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (classes.isNotEmpty)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      value: selectedClass,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: ColorUtils.slate400,
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate800,
                      ),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          // Fire upward — parent calls setState + reload.
                          // Like Vue: this.$emit('class-changed', newValue)
                          onClassChanged(newValue);
                        }
                      },
                      items: classes.map((cls) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: cls,
                          child: Text(cls['name'] ?? 'Unknown Class'),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'No classes available',
                      'id': 'Tidak ada kelas',
                    }),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate800,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
