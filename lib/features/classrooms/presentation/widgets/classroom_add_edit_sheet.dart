import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/mixins/classroom_add_edit_footer_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/mixins/classroom_add_edit_form_mixin.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/mixins/classroom_add_edit_header_mixin.dart';

/// Bottom sheet for creating or editing a class (kelas).
///
/// Receives initial data via [classData] (null = add mode).
/// Calls [onSaved] when the API call completes successfully.
class ClassroomAddEditSheet extends ConsumerStatefulWidget {
  const ClassroomAddEditSheet({
    super.key,
    this.classData,
    required this.teachers,
    required this.availableGradeLevels,
    required this.onSaved,
  });

  /// Existing class data when editing; null when adding.
  final Map<String, dynamic>? classData;

  /// Flat list of teacher maps (id, name).
  final List<dynamic> teachers;

  /// Grade levels available (e.g. ['1','2',...,'6']).
  final List<String> availableGradeLevels;

  /// Called after successful save for parent to reload.
  final VoidCallback onSaved;

  @override
  ClassroomAddEditSheetState createState() => ClassroomAddEditSheetState();
}

/// Mutable state for [ClassroomAddEditSheet].
///
/// Manages form state (name, grade level, teacher, saving)
/// and delegates UI building to mixins.
class ClassroomAddEditSheetState extends ConsumerState<ClassroomAddEditSheet>
    with
        ClassroomAddEditHeaderMixin,
        ClassroomAddEditFormMixin,
        ClassroomAddEditFooterMixin {
  late TextEditingController _nameController;
  String? _selectedGradeLevel;
  String? _selectedHomeroomTeacherId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final data = widget.classData;
    final model = data == null ? null : Classroom.fromJson(data);

    _nameController = TextEditingController(text: model?.name ?? '');
    _selectedGradeLevel = model?.gradeLevel;
    _selectedHomeroomTeacherId = model?.homeroomTeacherId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Validates form and submits data to API.
  @override
  Future<void> submit() async {
    final languageProvider = ref.read(languageRiverpod);
    final name = _nameController.text.trim();

    if (name.isEmpty || _selectedGradeLevel == null) {
      SnackBarUtils.showWarning(
        context,
        languageProvider.getTranslatedText({
          'en': 'Class name and grade level must be filled',
          'id': 'Nama kelas dan grade level harus diisi',
        }),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();
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

      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText(
          isEdit
              ? {
                  'en': 'Class successfully updated',
                  'id': 'Kelas berhasil diperbarui',
                }
              : {
                  'en': 'Class successfully added',
                  'id': 'Kelas berhasil ditambahkan',
                },
        ),
      );

      AppNavigator.pop(context);
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal menyimpan: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                  buildHeaderSection(),
                  Flexible(child: buildFormBody()),
                  buildFooterSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Mixin requirements for HeaderMixin ──────────────────

  @override
  Map<String, dynamic>? get classData => widget.classData;

  // ── Mixin requirements for FormMixin ───────────────────

  @override
  TextEditingController get nameController => _nameController;

  @override
  String? get selectedGradeLevel => _selectedGradeLevel;

  @override
  void updateSelectedGradeLevel(String? value) {
    _selectedGradeLevel = value;
  }

  @override
  String? get selectedHomeroomTeacherId => _selectedHomeroomTeacherId;

  @override
  void updateSelectedHomeroomTeacherId(String? value) {
    _selectedHomeroomTeacherId = value;
  }

  @override
  List<String> get availableGradeLevels => widget.availableGradeLevels;

  @override
  List<dynamic> get teachers => widget.teachers;

  // ── Shared mixin requirements ──────────────────────────

  @override
  bool get isSaving => _isSaving;

  @override
  dynamic get languageProvider => ref.watch(languageRiverpod);
}
