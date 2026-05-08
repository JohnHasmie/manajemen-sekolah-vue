// Dialog form for creating/editing a lesson plan (RPP).
// Extracted from teacher_lesson_plan_screen.dart to reduce file size.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/academic_year_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/form_field_section.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_form_data_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_form_dialog_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_form_fields_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_form_file_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_form_submit_mixin.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_form_ui_mixin.dart';

/// Dialog form for creating or editing an RPP (lesson plan).
///
/// Like a Vue `<RppFormModal>` component. When [lessonPlanData] is null,
/// it creates a new RPP; when provided, it edits the existing one.
/// Props: [teacherId], [onSaved] callback, optional [lessonPlanData] for
/// editing.
class LessonPlanFormDialog extends ConsumerStatefulWidget {
  final String teacherId;
  final VoidCallback onSaved;
  final Map<String, dynamic>? lessonPlanData;

  const LessonPlanFormDialog({
    super.key,
    required this.teacherId,
    required this.onSaved,
    this.lessonPlanData,
  });

  @override
  ConsumerState<LessonPlanFormDialog> createState() =>
      _LessonPlanFormDialogState();
}

class _LessonPlanFormDialogState extends ConsumerState<LessonPlanFormDialog>
    with
        LessonPlanFormDataMixin,
        LessonPlanFormFileMixin,
        LessonPlanFormSubmitMixin,
        LessonPlanFormUiMixin,
        LessonPlanFormDialogMixin,
        LessonPlanFormFieldsMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _academicYearController = TextEditingController();

  String? _selectedSubjectId;
  String? _selectedClassId;
  String? _selectedTerm = 'Ganjil';
  String? _selectedFileName;
  File? _selectedFile;
  bool _isUploading = false;

  /// Chip options for the tahun ajaran selector. Default window is
  /// [prev, current, next, next+1]. If the edited RPP has a year outside
  /// this window we prepend it so the value stays visible.
  late List<String> _academicYearOptions;
  late String _selectedAcademicYear;

  @override
  void initState() {
    super.initState();
    loadSubjectsByTeacher();

    _academicYearOptions = academicYearChipOptions();
    _selectedAcademicYear = currentAcademicYearString();

    if (widget.lessonPlanData != null) {
      final model = LessonPlan.fromJson(widget.lessonPlanData!);
      _titleController.text = model.title;
      final existingYear = (model.academicYear ?? '').trim();
      if (existingYear.isNotEmpty) {
        _selectedAcademicYear = existingYear;
        if (!_academicYearOptions.contains(existingYear)) {
          _academicYearOptions = [existingYear, ..._academicYearOptions];
        }
      }
      _selectedSubjectId =
          (widget.lessonPlanData!['subject_id'] ??
                  widget.lessonPlanData!['mata_pelajaran_id'])
              ?.toString();
      _selectedClassId =
          (widget.lessonPlanData!['class_id'] ??
                  widget.lessonPlanData!['kelas_id'])
              ?.toString();
      _selectedTerm = model.semester ?? 'Ganjil';
      // Prefer the persisted original filename. Fall back to the
      // storage path's basename for legacy rows that don't have a
      // file_name yet — the user still sees something readable
      // instead of the full storage path.
      final initialFileName =
          widget.lessonPlanData!['file_name']?.toString();
      final initialFilePath =
          widget.lessonPlanData!['file_path']?.toString();
      _selectedFileName = (initialFileName != null &&
              initialFileName.isNotEmpty)
          ? initialFileName
          : (initialFilePath != null && initialFilePath.isNotEmpty
              ? initialFilePath.split('/').last
              : null);

      if (_selectedSubjectId != null) {
        loadClassesBySubject(_selectedSubjectId!);
      }
    }

    // Mirror the selected chip into the text controller — the submit
    // mixin reads `academicYearController.text` to build the payload.
    _academicYearController.text = _selectedAcademicYear;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _academicYearController.dispose();
    super.dispose();
  }

  @override
  void setSelectedFile(String fileName, File file) {
    setState(() {
      _selectedFileName = fileName;
      _selectedFile = file;
    });
  }

  @override
  void showFilePickerDialogAction() => showFilePickerDialog();

  @override
  void viewCurrentFileAction() => viewCurrentFile();

  @override
  void submitFormAction(
    GlobalKey<FormState> formKey,
    String? selectedSubjectId,
    String? selectedClassId,
    String? selectedTerm,
    String? selectedFileName,
    dynamic selectedFile,
    TextEditingController titleController,
    TextEditingController academicYearController,
    Function(bool) setIsUploading,
  ) => submitForm(
    formKey,
    selectedSubjectId,
    selectedClassId,
    selectedTerm,
    selectedFileName,
    selectedFile,
    titleController,
    academicYearController,
    setIsUploading,
  );

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    final color = getPrimaryColor();
    final isEditMode = widget.lessonPlanData != null;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    // Shell mirrors the flat-flow sheet pattern used elsewhere (RPP
    // detail, AI result, recommendations). Padding(bottom: keyboardInset)
    // lifts the sheet above the keyboard; the outer container caps the
    // height and paints the rounded top; SafeArea(top: false) ensures
    // the footer clears the Samsung / iPhone home indicator so the
    // Simpan button is never hidden behind system nav.
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.92),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildHeader(lang, color, isEditMode),
                _buildFormContent(lang, color),
                buildFooterButtons(
                  lang,
                  color,
                  isEditMode,
                  _isUploading,
                  _formKey,
                  _selectedSubjectId,
                  _selectedClassId,
                  _selectedTerm,
                  _selectedFileName,
                  _selectedFile,
                  _titleController,
                  _academicYearController,
                  (bool val) => setState(() => _isUploading = val),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormContent(dynamic lang, Color color) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              FormTextField(
                label: lang.getTranslatedText({'en': 'Title', 'id': 'Judul'}),
                isRequired: true,
                controller: _titleController,
                hintText: lang.getTranslatedText({
                  'en': 'Enter RPP title',
                  'id': 'Masukkan judul RPP',
                }),
                prefixIcon: Icons.title_rounded,
                validator: (value) => (value?.isEmpty ?? true)
                    ? lang.getTranslatedText({
                        'en': 'Title is required',
                        'id': 'Judul wajib diisi',
                      })
                    : null,
              ),

              // Subject (chip select)
              FilterSectionHeader(
                title: lang.getTranslatedText({
                  'en': 'Subject',
                  'id': 'Mata Pelajaran',
                }),
                icon: Icons.book_outlined,
                primaryColor: color,
                padding: const EdgeInsets.only(top: 8, bottom: 12),
              ),
              if (subjectList.isEmpty)
                _buildLoadingChip(
                  lang.getTranslatedText({
                    'en': 'Loading subjects...',
                    'id': 'Memuat mata pelajaran...',
                  }),
                )
              else
                FilterChipGrid<String>(
                  options: subjectList.map((mp) {
                    final subj = Subject.fromJson(mp as Map<String, dynamic>);
                    return FilterOption(value: subj.id, label: subj.name);
                  }).toList(),
                  selectedValue: _selectedSubjectId,
                  onSelected: (value) {
                    setState(() {
                      _selectedSubjectId = value;
                      _selectedClassId = null;
                    });
                    if (value != null) {
                      loadClassesBySubject(value);
                    }
                  },
                  selectedColor: color,
                ),

              // Class (chip select, shown after subject selected)
              if (_selectedSubjectId != null) ...[
                FilterSectionHeader(
                  title: lang.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
                  icon: Icons.class_outlined,
                  primaryColor: color,
                  padding: const EdgeInsets.only(top: 16, bottom: 12),
                ),
                if (classList.isEmpty)
                  _buildLoadingChip(
                    lang.getTranslatedText({
                      'en': 'Loading classes...',
                      'id': 'Memuat kelas...',
                    }),
                  )
                else
                  FilterChipGrid<String>(
                    options: classList.map((classItem) {
                      final model = Classroom.fromJson(
                        classItem as Map<String, dynamic>,
                      );
                      return FilterOption(value: model.id, label: model.name);
                    }).toList(),
                    selectedValue: _selectedClassId,
                    onSelected: (value) {
                      setState(() {
                        _selectedClassId = value;
                      });
                    },
                    selectedColor: color,
                  ),
              ],

              // Semester (chip select)
              FilterSectionHeader(
                title: lang.getTranslatedText({
                  'en': 'Semester',
                  'id': 'Semester',
                }),
                icon: Icons.event_note_rounded,
                primaryColor: color,
                padding: const EdgeInsets.only(top: 16, bottom: 12),
              ),
              FilterChipGrid<String>(
                options: const [
                  FilterOption(
                    value: 'Ganjil',
                    label: 'Ganjil',
                    icon: Icons.looks_one_rounded,
                  ),
                  FilterOption(
                    value: 'Genap',
                    label: 'Genap',
                    icon: Icons.looks_two_rounded,
                  ),
                ],
                selectedValue: _selectedTerm,
                onSelected: (value) {
                  setState(() {
                    _selectedTerm = value ?? 'Ganjil';
                  });
                },
                selectedColor: color,
              ),

              // Academic Year (chip select — default = current tahun ajaran)
              FilterSectionHeader(
                title: lang.getTranslatedText({
                  'en': 'Academic Year',
                  'id': 'Tahun Ajaran',
                }),
                icon: Icons.calendar_today_rounded,
                primaryColor: color,
                padding: const EdgeInsets.only(top: 16, bottom: 12),
              ),
              FilterChipGrid<String>(
                options: _academicYearOptions
                    .map((y) => FilterOption(value: y, label: y))
                    .toList(),
                selectedValue: _selectedAcademicYear,
                onSelected: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedAcademicYear = value;
                    _academicYearController.text = value;
                  });
                },
                selectedColor: color,
              ),

              // File Attachment
              const SizedBox(height: AppSpacing.sm),
              buildFileSection(
                lang,
                color,
                _selectedFileName,
                widget.lessonPlanData != null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Loading indicator chip for async data.
  Widget _buildLoadingChip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ColorUtils.slate400,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: ColorUtils.slate400),
          ),
        ],
      ),
    );
  }
}
