// Dialog widget for creating a new target class from within the promotion
// wizard.
//
// Extracted from ClassPromotionWizard._showCreateClassDialog.
// Renders a modal Dialog with a gradient header, a text field, grade-level
// dropdown, and homeroom-teacher dropdown — like a `<v-dialog>` form in Vue.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_grade_level_dropdown.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/promotion_homeroom_teacher_dropdown.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Dialog that creates a new class (target) while inside the promotion wizard.
///
/// [availableGradeLevels] — list of valid grade levels based on school jenjang.
/// [teachers] — list of teacher maps for the homeroom-teacher picker.
/// [selectedTargetYearId] — the currently chosen target academic year ID;
///   passed to the API call so the new class lands in the right year.
/// [onClassCreated] — called after a successful `POST /api/classes` so the
///   parent can refresh its target-class list.
class PromotionCreateClassDialog extends StatefulWidget {
  const PromotionCreateClassDialog({
    super.key,
    required this.availableGradeLevels,
    required this.teachers,
    required this.selectedTargetYearId,
    required this.primaryColor,
    required this.cardGradient,
    required this.languageProvider,
    required this.onClassCreated,
  });

  final List<String> availableGradeLevels;
  final List<dynamic> teachers;
  final String? selectedTargetYearId;
  final Color primaryColor;
  final LinearGradient cardGradient;
  final LanguageProvider languageProvider;
  final VoidCallback onClassCreated;

  @override
  State<PromotionCreateClassDialog> createState() =>
      _PromotionCreateClassDialogState();
}

class _PromotionCreateClassDialogState
    extends State<PromotionCreateClassDialog> {
  final _nameController = TextEditingController();
  String? _selectedGradeLevel;
  String? _selectedHomeroomTeacherId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(gradient: widget.cardGradient),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.languageProvider.getTranslatedText({
                            'en': 'Create New Class',
                            'id': 'Buat Kelas Baru',
                          }),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.languageProvider.getTranslatedText({
                            'en': 'Add a new target class',
                            'id': 'Tambah kelas tujuan baru',
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Form body
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: widget.languageProvider.getTranslatedText({
                      'en': 'Class Name',
                      'id': 'Nama Kelas',
                    }),
                    icon: Icons.school_rounded,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PromotionGradeLevelDropdown(
                    value: _selectedGradeLevel,
                    onChanged: (val) {
                      setState(() {
                        _selectedGradeLevel = val;
                      });
                    },
                    languageProvider: widget.languageProvider,
                    availableGradeLevels: widget.availableGradeLevels,
                    primaryColor: widget.primaryColor,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PromotionHomeroomTeacherDropdown(
                    value: _selectedHomeroomTeacherId,
                    onChanged: (val) {
                      setState(() {
                        _selectedHomeroomTeacherId = val;
                      });
                    },
                    languageProvider: widget.languageProvider,
                    teachers: widget.teachers,
                    primaryColor: widget.primaryColor,
                  ),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        widget.languageProvider.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(
                          color: ColorUtils.slate700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 2,
                        shadowColor: widget.primaryColor.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        widget.languageProvider.getTranslatedText({
                          'en': 'Create',
                          'id': 'Buat',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameController.text.isEmpty || _selectedGradeLevel == null) {
      SnackBarUtils.showWarning(context, 'Please fill required fields');
      return;
    }

    try {
      final data = {
        'name': _nameController.text.trim(),
        'grade_level': int.parse(_selectedGradeLevel!),
        'homeroom_teacher_id': _selectedHomeroomTeacherId,
        'academic_year_id': widget.selectedTargetYearId,
      };
      await getIt<ApiClassService>().addClass(data);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      AppNavigator.pop(context);
      widget.onClassCreated();
      // ignore: use_build_context_synchronously
      SnackBarUtils.showSuccess(context, 'Class Created');
    } catch (e) {
      AppLogger.error('classroom', e);
      if (mounted) {
        SnackBarUtils.showError(
          // ignore: use_build_context_synchronously
          context,
          '${AppLocalizations.failedToSave.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: ColorUtils.slate800, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate600, fontSize: 13),
          prefixIcon: Icon(icon, color: widget.primaryColor, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
