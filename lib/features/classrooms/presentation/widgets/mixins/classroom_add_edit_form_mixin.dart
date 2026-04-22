import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_form_fields.dart';

/// Mixin for building the form body section of
/// [ClassroomAddEditSheet].
///
/// Provides [buildFormBody] to render scrollable form
/// with text field and dropdowns.
mixin ClassroomAddEditFormMixin {
  /// Provides access to setState callback.
  void setState(VoidCallback fn);

  /// Provides access to name controller.
  TextEditingController get nameController;

  /// Provides access to selected grade level value.
  String? get selectedGradeLevel;

  /// Callback for grade level changes.
  void updateSelectedGradeLevel(String? value);

  /// Provides access to selected homeroom teacher ID.
  String? get selectedHomeroomTeacherId;

  /// Callback for homeroom teacher changes.
  void updateSelectedHomeroomTeacherId(String? value);

  /// Provides access to available grade levels.
  List<String> get availableGradeLevels;

  /// Provides access to teachers list.
  List<dynamic> get teachers;

  /// Provides access to language provider for translations.
  dynamic get languageProvider;

  /// Builds the scrollable form body with all form fields.
  ///
  /// Returns an Expanded widget containing a SingleChildScrollView
  /// with the form field widgets (name, grade level, teacher).
  Widget buildFormBody() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClassroomDialogTextField(
              controller: nameController,
              label: languageProvider.getTranslatedText({
                'en': 'Class Name',
                'id': 'Nama Kelas',
              }),
              icon: Icons.school,
            ),
            const SizedBox(height: AppSpacing.md),
            ClassroomGradeLevelDropdown(
              value: selectedGradeLevel,
              onChanged: (value) =>
                  setState(() => updateSelectedGradeLevel(value)),
              availableGradeLevels: availableGradeLevels,
              languageProvider: languageProvider,
            ),
            const SizedBox(height: AppSpacing.md),
            ClassroomHomeroomTeacherDropdown(
              value: selectedHomeroomTeacherId,
              onChanged: (value) =>
                  setState(() => updateSelectedHomeroomTeacherId(value)),
              teachers: teachers,
              languageProvider: languageProvider,
            ),
          ],
        ),
      ),
    );
  }
}
