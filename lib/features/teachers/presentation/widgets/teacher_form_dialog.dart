import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_form_builders_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_form_init_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_form_layout_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_form_logic_mixin.dart';
import 'package:manajemensekolah/features/teachers/presentation/mixins/teacher_form_ui_mixin.dart';

/// Standalone dialog for adding or editing a teacher.
/// Extracted from `admin_teacher_management_screen.dart`.
class TeacherFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? teacher;
  final List<dynamic> subjects;
  final List<dynamic> classes;
  final VoidCallback onSaved;

  const TeacherFormDialog({
    super.key,
    this.teacher,
    required this.subjects,
    required this.classes,
    required this.onSaved,
  });

  @override
  ConsumerState<TeacherFormDialog> createState() => _TeacherFormDialogState();
}

class _TeacherFormDialogState extends ConsumerState<TeacherFormDialog>
    with
        TeacherFormInitMixin,
        TeacherFormUiMixin,
        TeacherFormLogicMixin,
        TeacherFormBuildersMixin,
        TeacherFormLayoutMixin {
  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              buildHeader(languageProvider),
              buildFormContent(languageProvider, _buildFormBody),
              buildFooter(saveTeacher),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormBody(LanguageProvider languageProvider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildNameField(languageProvider),
        const SizedBox(height: AppSpacing.md),
        if (widget.teacher != null) buildChangeUserSwitch(languageProvider),
        buildEmailField(languageProvider),
        const SizedBox(height: AppSpacing.md),
        buildNipField(),
        const SizedBox(height: AppSpacing.md),
        buildGenderDropdown(languageProvider),
        const SizedBox(height: AppSpacing.lg),
        buildSubjectsSection(languageProvider),
        const SizedBox(height: AppSpacing.md),
        buildHomeroomClassDropdown(languageProvider),
        const SizedBox(height: AppSpacing.md),
        buildEmploymentStatusDropdown(languageProvider),
      ],
    );
  }
}
