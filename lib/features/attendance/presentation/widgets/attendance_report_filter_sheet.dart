// Extracted filter bottom sheet for admin attendance report.
//
// Like a reusable Vue component that receives props (initial filter values,
// dropdown data) and emits events (onApply callback with selected filters).
// Decoupled from the parent screen's state -- communicates via callbacks only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Holds the selected filter values returned by the filter sheet.
/// Like a DTO that carries filter state from the sheet back to the parent.
class AttendanceFilterResult {
  final String? selectedDate;
  final List<String> selectedSubjectIds;
  final List<String> selectedClassIds;
  final List<String> selectedDayIds;
  final List<String> selectedLessonHourIds;

  const AttendanceFilterResult({
    this.selectedDate,
    this.selectedSubjectIds = const [],
    this.selectedClassIds = const [],
    this.selectedDayIds = const [],
    this.selectedLessonHourIds = const [],
  });
}

/// Shows the attendance report filter bottom sheet.
///
/// [context] - BuildContext to show the modal
/// [ref] - WidgetRef for reading Riverpod providers (language)
/// [primaryColor] - Theme color for chips and header gradient
/// [initialDate] - Currently selected date filter ('today', 'week', 'month')
/// [initialSubjectIds] - Currently selected subject IDs
/// [initialClassIds] - Currently selected class IDs
/// [initialDayIds] - Currently selected day IDs (1-7)
/// [initialLessonHourIds] - Currently selected lesson hour IDs
/// [subjectList] - Available subjects (list of maps with 'id' and 'name')
/// [classList] - Available classes (list of maps with 'id' and 'name')
/// [lessonHours] - Available lesson hours (list of maps with 'id' and 'name')
/// [onApply] - Callback invoked with the selected filter values
void showAttendanceReportFilterSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Color primaryColor,
  required String? initialDate,
  required List<String> initialSubjectIds,
  required List<String> initialClassIds,
  required List<String> initialDayIds,
  required List<String> initialLessonHourIds,
  required List<dynamic> subjectList,
  required List<dynamic> classList,
  required List<dynamic> lessonHours,
  required void Function(AttendanceFilterResult result) onApply,
}) {
  final languageProvider = ref.read(languageRiverpod);

  // Temporary copies so changes don't affect parent until "Apply" is pressed.
  // Like v-model on a local data() copy in Vue, committed on save.
  String? tempSelectedDate = initialDate;
  final List<String> tempSelectedSubjects = List.from(initialSubjectIds);
  final List<String> tempSelectedClasses = List.from(initialClassIds);
  final List<String> tempSelectedDays = List.from(initialDayIds);
  final List<String> tempSelectedLessonHours = List.from(initialLessonHourIds);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header with gradient
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor,
                    primaryColor.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Filter',
                          'id': 'Filter',
                        }),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        tempSelectedDate = null;
                        tempSelectedSubjects.clear();
                        tempSelectedClasses.clear();
                        tempSelectedDays.clear();
                        tempSelectedLessonHours.clear();
                      });
                    },
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Reset',
                        'id': 'Reset',
                      }),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Filter Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Filter
                    _buildSectionHeader(
                      icon: Icons.date_range,
                      label: languageProvider.getTranslatedText({
                        'en': 'Date Range',
                        'id': 'Rentang Tanggal',
                      }),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['today', 'week', 'month'].map((period) {
                        final isSelected = tempSelectedDate == period;
                        final label = period == 'today'
                            ? languageProvider.getTranslatedText({
                                'en': 'Today',
                                'id': 'Hari Ini',
                              })
                            : period == 'week'
                            ? languageProvider.getTranslatedText({
                                'en': 'This Week',
                                'id': 'Minggu Ini',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'This Month',
                                'id': 'Bulan Ini',
                              });
                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              tempSelectedDate = selected ? period : null;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: primaryColor.withValues(alpha: 0.2),
                          checkmarkColor: primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected ? primaryColor : ColorUtils.slate600,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: AppSpacing.xxl),

                    // Subject Filter
                    _buildSectionHeader(
                      icon: Icons.book_outlined,
                      label: languageProvider.getTranslatedText({
                        'en': 'Subject',
                        'id': 'Mata Pelajaran',
                      }),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subjectList.map<Widget>((subject) {
                        final subjectId = subject['id'].toString();
                        final subjectName = subject['name'] ?? 'Subject';
                        final isSelected = tempSelectedSubjects.contains(
                          subjectId,
                        );
                        return FilterChip(
                          label: Text(subjectName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                tempSelectedSubjects.add(subjectId);
                              } else {
                                tempSelectedSubjects.remove(subjectId);
                              }
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: primaryColor.withValues(alpha: 0.2),
                          checkmarkColor: primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? primaryColor
                                : ColorUtils.slate600,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: AppSpacing.xxl),

                    // Day Filter
                    _buildSectionHeader(
                      icon: Icons.calendar_today_outlined,
                      label: languageProvider.getTranslatedText({
                        'en': 'Day',
                        'id': 'Hari',
                      }),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            {'en': 'Monday', 'id': 'Senin', 'val': '1'},
                            {'en': 'Tuesday', 'id': 'Selasa', 'val': '2'},
                            {'en': 'Wednesday', 'id': 'Rabu', 'val': '3'},
                            {'en': 'Thursday', 'id': 'Kamis', 'val': '4'},
                            {'en': 'Friday', 'id': 'Jumat', 'val': '5'},
                            {'en': 'Saturday', 'id': 'Sabtu', 'val': '6'},
                            {'en': 'Sunday', 'id': 'Minggu', 'val': '7'},
                          ].map<Widget>((d) {
                            final val = d['val']!;
                            final label = languageProvider.getTranslatedText({
                              'en': d['en']!,
                              'id': d['id']!,
                            });
                            final isSelected = tempSelectedDays.contains(val);
                            return FilterChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (selected) {
                                setModalState(() {
                                  if (selected) {
                                    tempSelectedDays.add(val);
                                  } else {
                                    tempSelectedDays.remove(val);
                                  }
                                });
                              },
                              backgroundColor: Colors.white,
                              selectedColor: primaryColor.withValues(
                                alpha: 0.2,
                              ),
                              checkmarkColor: primaryColor,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? primaryColor
                                    : ColorUtils.slate600,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                    ),
                    SizedBox(height: AppSpacing.xxl),

                    // Lesson Hour Filter
                    _buildSectionHeader(
                      icon: Icons.access_time_outlined,
                      label: languageProvider.getTranslatedText({
                        'en': 'Lesson Hour',
                        'id': 'Jam Pelajaran',
                      }),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: lessonHours.map<Widget>((lh) {
                        final lhId = lh['id'].toString();
                        final lhName = lh['name'] ?? 'Jam';
                        final isSelected = tempSelectedLessonHours.contains(
                          lhId,
                        );
                        return FilterChip(
                          label: Text(lhName),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                tempSelectedLessonHours.add(lhId);
                              } else {
                                tempSelectedLessonHours.remove(lhId);
                              }
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: primaryColor.withValues(alpha: 0.2),
                          checkmarkColor: primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? primaryColor
                                : ColorUtils.slate600,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: AppSpacing.xxl),

                    // Class Filter
                    _buildSectionHeader(
                      icon: Icons.class_outlined,
                      label: languageProvider.getTranslatedText({
                        'en': 'Class',
                        'id': 'Kelas',
                      }),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: classList.map<Widget>((classItem) {
                        final classId = classItem['id'].toString();
                        final className = classItem['name'] ?? 'Class';
                        final isSelected = tempSelectedClasses.contains(
                          classId,
                        );
                        return FilterChip(
                          label: Text(className),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                tempSelectedClasses.add(classId);
                              } else {
                                tempSelectedClasses.remove(classId);
                              }
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: primaryColor.withValues(alpha: 0.2),
                          checkmarkColor: primaryColor,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? primaryColor
                                : ColorUtils.slate600,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Apply / Cancel Buttons
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: ColorUtils.slate200)),
                boxShadow: [
                  BoxShadow(
                    color: ColorUtils.slate900.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(color: ColorUtils.slate700),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        AppNavigator.pop(context);
                        onApply(AttendanceFilterResult(
                          selectedDate: tempSelectedDate,
                          selectedSubjectIds: List.from(tempSelectedSubjects),
                          selectedClassIds: List.from(tempSelectedClasses),
                          selectedDayIds: List.from(tempSelectedDays),
                          selectedLessonHourIds: List.from(tempSelectedLessonHours),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Apply',
                          'id': 'Terapkan',
                        }),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Helper to build a consistent section header row (icon + label).
Widget _buildSectionHeader({required IconData icon, required String label}) {
  return Row(
    children: [
      Icon(icon, size: 16, color: ColorUtils.slate700),
      SizedBox(width: AppSpacing.sm),
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: ColorUtils.slate900,
        ),
      ),
    ],
  );
}
