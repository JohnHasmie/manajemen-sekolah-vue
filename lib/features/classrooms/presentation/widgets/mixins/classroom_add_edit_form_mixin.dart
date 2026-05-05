import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';
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

  /// Builds the scrollable, sectioned form body.
  Widget buildFormBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        4,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminFormSection(
            label: languageProvider.getTranslatedText({
              'en': 'BASIC DATA',
              'id': 'DATA POKOK',
            }) as String,
            children: [
              ClassroomDialogTextField(
                controller: nameController,
                label: languageProvider.getTranslatedText({
                  'en': 'Class Name',
                  'id': 'Nama Kelas',
                }),
                icon: Icons.school,
              ),
              ClassroomGradeLevelDropdown(
                value: selectedGradeLevel,
                onChanged: (value) =>
                    setState(() => updateSelectedGradeLevel(value)),
                availableGradeLevels: availableGradeLevels,
                languageProvider: languageProvider,
              ),
            ],
          ),
          AdminFormSection(
            label: languageProvider.getTranslatedText({
              'en': 'HOMEROOM',
              'id': 'WALI KELAS',
            }) as String,
            bottomGap: 4,
            children: [
              ClassroomHomeroomTeacherDropdown(
                value: selectedHomeroomTeacherId,
                onChanged: (value) =>
                    setState(() => updateSelectedHomeroomTeacherId(value)),
                teachers: teachers,
                languageProvider: languageProvider,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
