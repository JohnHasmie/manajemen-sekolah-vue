import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/class_detail_dialog.dart';

/// Mixin for building the content section of
/// ClassDetailDialog.
///
/// Provides [buildContentSection] to render detail items
/// and the "View Students" action button.
mixin ClassDetailContentMixin {
  /// Provides access to BuildContext for navigation.
  BuildContext get context;

  /// Provides access to class data Map.
  Map<String, dynamic> get classData;

  /// Provides access to language provider for translations.
  LanguageProvider get languageProvider;

  /// Provides access to primary accent color.
  Color get primaryColor;

  /// Builds the content section with detail items and
  /// action buttons.
  ///
  /// Returns a Padding container with ClassDetailItem
  /// widgets and a full-width ElevatedButton for viewing
  /// students.
  Widget buildContentSection(String teacherName, int studentCount) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStudentCountItem(studentCount),
          _buildTeacherNameItem(teacherName),
          const SizedBox(height: AppSpacing.xl),
          _buildViewStudentsButton(),
        ],
      ),
    );
  }

  /// Builds the total students detail item.
  Widget _buildStudentCountItem(int studentCount) {
    final countText = languageProvider.getTranslatedText({
      'en': 'students',
      'id': 'siswa',
    });
    return ClassDetailItem(
      icon: Icons.people,
      label: languageProvider.getTranslatedText({
        'en': 'Total Students',
        'id': 'Jumlah Siswa',
      }),
      value: '$studentCount $countText',
    );
  }

  /// Builds the homeroom teacher detail item.
  Widget _buildTeacherNameItem(String teacherName) {
    return ClassDetailItem(
      icon: Icons.person,
      label: languageProvider.getTranslatedText({
        'en': 'Homeroom Teacher',
        'id': 'Wali Kelas',
      }),
      value: teacherName,
    );
  }

  /// Builds the full-width "View Students" button.
  ///
  /// Closes the dialog and navigates to the student
  /// management screen for this class.
  Widget _buildViewStudentsButton() {
    final viewStudentsText = languageProvider.getTranslatedText({
      'en': 'View Students',
      'id': 'Lihat Daftar Siswa',
    });
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          AppNavigator.pop(context);
          AppNavigator.push(
            context,
            StudentManagementScreen(initialClassId: classData['id'].toString()),
          );
        },
        icon: const Icon(Icons.list, color: Colors.white),
        label: Text(
          viewStudentsText,
          style: const TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
