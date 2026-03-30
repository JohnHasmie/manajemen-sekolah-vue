// Bottom sheet widget for adding or editing a classroom record.
//
// Like Vue's `<ClassroomFormModal>` component — owns all local form state
// (text controllers, dropdowns, loading flag) and calls back via [onSaved].
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/classroom_form_fields.dart';

/// Bottom sheet for creating or editing a class (kelas).
///
/// Receives initial data via [classData] (null = add mode).
/// Calls [onSaved] when the API call completes successfully so the
/// parent screen can refresh its list — like a Vue `$emit('saved')`.
class ClassroomAddEditSheet extends ConsumerStatefulWidget {
  const ClassroomAddEditSheet({
    super.key,
    this.classData,
    required this.teachers,
    required this.availableGradeLevels,
    required this.onSaved,
  });

  /// Existing class data when editing; null when adding a new class.
  final Map<String, dynamic>? classData;

  /// Flat list of teacher maps (id, name) — passed in from the parent screen.
  final List<dynamic> teachers;

  /// Grade levels available for the current school type (e.g. ['1','2',...,'6']).
  final List<String> availableGradeLevels;

  /// Called after a successful save so the parent can reload its list.
  final VoidCallback onSaved;

  @override
  ClassroomAddEditSheetState createState() => ClassroomAddEditSheetState();
}

/// Mutable state for [ClassroomAddEditSheet].
///
/// Like Vue `data()` for the form modal:
/// - [_nameController] - text field controller (class name)
/// - [_selectedGradeLevel] / [_selectedHomeroomTeacherId] - dropdown values
/// - [_isSaving] - loading spinner flag while API call is in-flight
class ClassroomAddEditSheetState extends ConsumerState<ClassroomAddEditSheet> {
  late final TextEditingController _nameController;
  String? _selectedGradeLevel;
  String? _selectedHomeroomTeacherId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.classData;

    // Pre-populate fields when editing — like assigning v-model initial values.
    _nameController = TextEditingController(
      text: data?['name'] ?? data?['nama'] ?? '',
    );

    _selectedGradeLevel = data?['grade_level']?.toString();

    if (data != null) {
      // Prefer flat key; fall back to nested homeroom_teacher object.
      _selectedHomeroomTeacherId =
          data['homeroom_teacher_id']?.toString() ??
          data['wali_kelas_id']?.toString();

      if (_selectedHomeroomTeacherId == null) {
        if (data['homeroom_teacher'] is List &&
            (data['homeroom_teacher'] as List).isNotEmpty) {
          _selectedHomeroomTeacherId =
              data['homeroom_teacher'][0]['id']?.toString();
        } else if (data['homeroom_teacher'] is Map) {
          _selectedHomeroomTeacherId =
              data['homeroom_teacher']['id']?.toString();
        } else if (data['wali_kelas'] is Map) {
          _selectedHomeroomTeacherId = data['wali_kelas']['id']?.toString();
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Like a Vue method `submitForm()` — validates, calls API, then emits.
  Future<void> _submit() async {
    final languageProvider = ref.read(languageRiverpod);
    final name = _nameController.text.trim();

    if (name.isEmpty || _selectedGradeLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Class name and grade level must be filled',
              'id': 'Nama kelas dan grade level harus diisi',
            }),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString();
      final isEdit = widget.classData != null;
      final service = getIt<ApiClassService>();

      if (isEdit) {
        await service.updateClass(widget.classData!['id'].toString(), {
          'name': _nameController.text,
          'grade_level': _selectedGradeLevel,
          'homeroom_teacher_id': _selectedHomeroomTeacherId,
          'academic_year_id': selectedYearId,
        });
      } else {
        await service.addClass({
          'name': _nameController.text,
          'grade_level': _selectedGradeLevel,
          'homeroom_teacher_id': _selectedHomeroomTeacherId,
          'academic_year_id': selectedYearId,
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText(
              isEdit
                  ? {'en': 'Class successfully updated', 'id': 'Kelas berhasil diperbarui'}
                  : {'en': 'Class successfully added', 'id': 'Kelas berhasil ditambahkan'},
            ),
          ),
          backgroundColor: Colors.green,
        ),
      );

      AppNavigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.failedToSave.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final isEdit = widget.classData != null;

    return Padding(
      // Slide up above the soft keyboard — like CSS `padding-bottom: env(keyboard-inset-height)`.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              // ── Gradient header ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ColorUtils.corporateBlue600,
                      ColorUtils.corporateBlue600.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_rounded : Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit
                                ? languageProvider.getTranslatedText({
                                    'en': 'Edit Class',
                                    'id': 'Edit Kelas',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Add Class',
                                    'id': 'Tambah Kelas',
                                  }),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEdit
                                ? languageProvider.getTranslatedText({
                                    'en': 'Update class information',
                                    'id': 'Perbarui informasi kelas',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Fill in class information',
                                    'id': 'Isi informasi kelas',
                                  }),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => AppNavigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable form body ─────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClassroomDialogTextField(
                        controller: _nameController,
                        label: languageProvider.getTranslatedText({
                          'en': 'Class Name',
                          'id': 'Nama Kelas',
                        }),
                        icon: Icons.school,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ClassroomGradeLevelDropdown(
                        value: _selectedGradeLevel,
                        onChanged: (value) =>
                            setState(() => _selectedGradeLevel = value),
                        availableGradeLevels: widget.availableGradeLevels,
                        languageProvider: languageProvider,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ClassroomHomeroomTeacherDropdown(
                        value: _selectedHomeroomTeacherId,
                        onChanged: (value) =>
                            setState(() => _selectedHomeroomTeacherId = value),
                        teachers: widget.teachers,
                        languageProvider: languageProvider,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Footer action buttons ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.slate900.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => AppNavigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: ColorUtils.slate300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.cancel.tr,
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
                        onPressed: _isSaving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.corporateBlue600,
                          disabledBackgroundColor:
                              ColorUtils.corporateBlue600.withValues(alpha: 0.6),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shadowColor: ColorUtils.corporateBlue600
                              .withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEdit
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Update',
                                        'id': 'Perbarui',
                                      })
                                    : AppLocalizations.save.tr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
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
      ),
    );
  }
}
