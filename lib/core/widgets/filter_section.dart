// Schedule filter section with semester and academic year selectors.
//
// Like a Vue component `<ScheduleFilterBar>` placed at the top of a schedule
// management page. Similar to Laravel Nova's filter panel where you pick
// semester and academic year before viewing data.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:provider/provider.dart';

/// A filter bar widget for selecting semester and academic year.
///
/// Like a Vue `<FilterSection>` component with props:
/// - [selectedSemester] / [selectedAcademicYear] - current filter values (like `v-model`)
/// - [semesterList] - available semesters from API (like `:options`)
/// - [onSemesterChanged] / [onAcademicYearChanged] - callbacks (like `@change`)
///
/// Renders two filter cards side by side, each opening a bottom sheet or dialog
/// for selection (similar to dropdown filters in Laravel Nova).
class FilterSection extends StatelessWidget {
  final String selectedSemester;
  final String selectedAcademicYear;
  final List<dynamic> semesterList;
  final Function(String) onSemesterChanged;
  final Function(String) onAcademicYearChanged;

  const FilterSection({
    super.key,
    required this.selectedSemester,
    required this.selectedAcademicYear,
    required this.semesterList,
    required this.onSemesterChanged,
    required this.onAcademicYearChanged,
  });

  /// Resolves a semester ID to its display name from the semester list.
  /// Like a Laravel accessor `getSemesterNameAttribute()` on a model.
  String _getSemesterName(String semesterId, List<dynamic> semesterList) {
  try {
    final semester = semesterList.firstWhere(
      (sem) => sem['id'].toString() == semesterId.toString(),
      orElse: () => {'nama': 'Ganjil'}, // Fallback if not found
    );
    return semester['nama'] ?? 'Ganjil';
  } catch (e) {
    return 'Ganjil';
  }
}

  /// Opens a dialog for the user to type/select an academic year.
  /// Like a Vue method that shows a `$bvModal.show('academic-year-picker')`.
  Future<void> _showAcademicYearDialog(BuildContext context) async {
    final TextEditingController controller = TextEditingController(
      text: selectedAcademicYear,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return AlertDialog(
            title: Text(
              languageProvider.getTranslatedText({
                'en': 'Select Academic Year',
                'id': 'Pilih Tahun Ajaran',
              }),
            ),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: languageProvider.getTranslatedText({
                  'en': 'Example: 2024/2025',
                  'id': 'Contoh: 2024/2025',
                }),
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.cancel.tr),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Select',
                    'id': 'Pilih',
                  }),
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (result != null && result.isNotEmpty && result != selectedAcademicYear) {
      onAcademicYearChanged(result);
    }
  }

  /// Opens a bottom sheet to select a semester.
  /// Like showing a `<v-bottom-sheet>` with a list of semester options.
  void _showSemesterFilter(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: semesterList.map((semester) {
              return ListTile(
                title: Text(semester['nama'] ?? 'Unknown'),
                onTap: () => Navigator.pop(context, semester['id']),
                selected: selectedSemester == semester['id'],
              );
            }).toList(),
          ),
        );
      },
    );
    if (selected != null && selected != selectedSemester) {
      onSemesterChanged(selected);
    }
  }

  /// Builds a single tappable filter card showing label and current value.
  /// Like a `<FilterChip>` Vue component with a dropdown arrow.
  Widget _buildFilterCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50, // Changed to light grey background
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300), // Changed to grey border
        ),
        child: Row(
          children: [
            Icon(icon, color: ColorUtils.primaryColor, size: 20), // Changed to primary color
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label: $value',
                style: TextStyle(
                  color: Colors.black, // Changed to black
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey.shade600), // Changed to grey
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, // Changed to white background
            border: Border.all(
              color: Colors.grey.shade300, // Added grey border
              width: 1,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                AppLocalizations.manageTeachingSchedule.tr,
                style: TextStyle(
                  color: Colors.black, // Changed to black
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '${_getSemesterName(selectedSemester, semesterList)} • $selectedAcademicYear',
                style: TextStyle(
                  color: Colors.grey.shade700, // Changed to dark grey
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterCard(
                      context,
                      languageProvider.getTranslatedText({
                        'en': 'Semester',
                        'id': 'Semester',
                      }),
                      _getSemesterName(selectedSemester, semesterList),
                      Icons.school,
                      () => _showSemesterFilter(context),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _buildFilterCard(
                      context,
                      languageProvider.getTranslatedText({
                        'en': 'Academic Year',
                        'id': 'Tahun Ajaran',
                      }),
                      selectedAcademicYear,
                      Icons.calendar_today,
                      () => _showAcademicYearDialog(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}