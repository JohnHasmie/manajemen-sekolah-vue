import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';
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
      // Sheet sizes naturally to its content (capped at 88 % so users
      // can still see the dimmed list behind). The form body inside
      // buildFormContent() handles its own scrolling when needed.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  buildHeader(languageProvider),
                  Flexible(
                    child: buildFormContent(languageProvider, _buildFormBody),
                  ),
                  buildFooter(saveTeacher),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormBody(LanguageProvider languageProvider) {
    String t(Map<String, String> m) => languageProvider.getTranslatedText(m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFormSection(
          label: t(const {'en': 'BASIC DATA', 'id': 'DATA POKOK'}),
          children: [
            buildNameField(languageProvider),
            buildEmailField(languageProvider),
            buildNipField(),
          ],
        ),
        AdminFormSection(
          label: t(const {'en': 'PERSONAL DATA', 'id': 'DATA PRIBADI'}),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminFormFieldLabel(
                  text: t(const {'en': 'Gender', 'id': 'Jenis kelamin'}),
                ),
                AdminFormChoiceChips<String>(
                  value: selectedGender,
                  onChanged: (v) => setState(() => selectedGender = v),
                  choices: [
                    AdminFormChoice(
                      value: 'L',
                      label: t(const {'en': 'Male', 'id': 'Laki-laki'}),
                      icon: Icons.male_rounded,
                    ),
                    AdminFormChoice(
                      value: 'P',
                      label: t(const {'en': 'Female', 'id': 'Perempuan'}),
                      icon: Icons.female_rounded,
                    ),
                  ],
                ),
              ],
            ),
            buildEmploymentStatusDropdown(languageProvider),
          ],
        ),
        AdminFormSection(
          label: t(const {'en': 'ASSIGNMENT', 'id': 'PENUGASAN'}),
          bottomGap: 4,
          children: [
            buildSubjectsSection(languageProvider),
            buildHomeroomClassDropdown(languageProvider),
            if (widget.teacher != null) buildChangeUserSwitch(languageProvider),
          ],
        ),
      ],
    );
  }
}
