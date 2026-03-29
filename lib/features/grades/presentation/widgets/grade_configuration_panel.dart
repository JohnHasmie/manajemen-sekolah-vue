// Configuration panel for selecting grade type, date, and optional title.
// Like a "step 1" form panel — the teacher must confirm these before entering grades.
// In Laravel terms, this is the header fields of GradeController@store (type, date, title).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Shows subject info, a grade-type dropdown, a date picker row, and an optional
/// title field. The parent owns all state; this widget calls back via
/// [onGradeTypeChanged], [onSelectDate], and [onConfirm].
class GradeConfigurationPanel extends StatelessWidget {
  final Map<String, dynamic> subject;
  final Color primaryColor;
  final List<String> gradeTypeList;
  final String? selectedGradeType;
  final DateTime selectedDate;
  final TextEditingController titleController;
  final bool isReadOnly;
  final LanguageProvider languageProvider;

  /// Called when the dropdown value changes.
  final void Function(String? value) onGradeTypeChanged;

  /// Called when the user taps the date button; parent shows a date picker.
  final VoidCallback onSelectDate;

  /// Called when the teacher taps "Set" to confirm the configuration.
  final VoidCallback onConfirm;

  /// Returns a human-readable label for [type] in the current language.
  final String Function(String type) getGradeTypeLabel;

  const GradeConfigurationPanel({
    super.key,
    required this.subject,
    required this.primaryColor,
    required this.gradeTypeList,
    required this.selectedGradeType,
    required this.selectedDate,
    required this.titleController,
    required this.isReadOnly,
    required this.languageProvider,
    required this.onGradeTypeChanged,
    required this.onSelectDate,
    required this.onConfirm,
    required this.getGradeTypeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: ColorUtils.slate200, width: 1),
          ),
        ),
        child: Column(
          children: [
            // Subject info card
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject['nama'] ?? subject['name'] ?? '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        if (subject['code'] != null || subject['kode'] != null)
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'Code', 'id': 'Kode'})}: ${subject['code'] ?? subject['kode']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Grade type dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: selectedGradeType,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.assignment_outlined,
                    color: primaryColor,
                  ),
                  hintText: languageProvider.getTranslatedText({
                    'en': 'Select grade type',
                    'id': 'Pilih jenis nilai',
                  }),
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(color: ColorUtils.slate900),
                items: gradeTypeList.map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(getGradeTypeLabel(type)),
                  );
                }).toList(),
                onChanged: onGradeTypeChanged,
                validator: (value) {
                  if (value == null) {
                    return languageProvider.getTranslatedText({
                      'en': 'Please select grade type',
                      'id': 'Pilih jenis nilai terlebih dahulu',
                    });
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Date picker row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Date:',
                      'id': 'Tanggal:',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: ColorUtils.slate600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onSelectDate,
                    child: Text(
                      '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: TextStyle(
                        fontSize: 15,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Optional assessment title field
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: TextFormField(
                controller: titleController,
                style: TextStyle(color: ColorUtils.slate900),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.title, color: primaryColor),
                  hintText: languageProvider.getTranslatedText({
                    'en': 'Assessment Title (Optional)',
                    'id': 'Judul Penilaian (Opsional)',
                  }),
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                  helperText: languageProvider.getTranslatedText({
                    'en': 'E.g., Quiz 1, Chapter 5 Test',
                    'id': 'Contoh: Kuis 1, Ulangan Bab 5',
                  }),
                  helperStyle: TextStyle(
                    color: ColorUtils.slate400,
                    fontSize: 11,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Confirm / Set button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (selectedGradeType != null && !isReadOnly)
                    ? onConfirm
                    : null,
                icon: Icon(Icons.check),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Set',
                    'id': 'Tetapkan',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: ColorUtils.slate200,
                  disabledForegroundColor: ColorUtils.slate500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
