// New grade input form for multiple students.
// Like a Vue modal component for bulk-entering grades for a class.
//
// This form is shown when a teacher creates a new assessment and
// enters grades for all students at once.
// In Laravel terms, this is GradeController@store for batch grade creation.
//
// Extracted from teacher_grade_input_screen.dart.
// Contains:
// - [GradeInputFormNew] -- bulk grade input form for multiple students
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_add_header.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_configuration_panel.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_input_table.dart';

// New Grade Input Form for Multiple Students
class GradeInputFormNew extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final List<Student> studentList;

  const GradeInputFormNew({
    super.key,
    required this.teacher,
    required this.subject,
    required this.studentList,
  });

  @override
  GradeInputFormNewState createState() => GradeInputFormNewState();
}

class GradeInputFormNewState extends ConsumerState<GradeInputFormNew> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();

  bool get _isReadOnly {
    return ref.read(academicYearRiverpod).isReadOnly;
  }

  // State variables
  String? _selectedGradeType;
  final List<String> _gradeTypeList = [
    'uh',
    'tugas',
    'uts',
    'uas',
    'pts',
    'pas',
  ];

  // Map to store grades per student
  final Map<String, Map<String, dynamic>> _gradeStudentMap = {};

  // Text controllers for input table
  final Map<String, TextEditingController> _tableControllers = {};
  final Map<String, FocusNode> _tableFocusNodes = {};

  // State for tracking whether grade type and date have been set
  bool _isConfigurationSet = false;
  bool _isSaving = false;
  String? _confirmedGradeType;
  DateTime? _confirmedDate;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize map with default values for each student
    for (var student in widget.studentList) {
      _gradeStudentMap[student.id] = {'score': '', 'description': ''};
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var controller in _tableControllers.values) {
      controller.dispose();
    }
    for (var node in _tableFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitGrade() async {
    final languageProvider = ref.read(languageRiverpod);

    if (_formKey.currentState!.validate()) {
      if (_selectedGradeType == null) {
        SnackBarUtils.showWarning(
          context,
          languageProvider.getTranslatedText({
            'en': 'Please select grade type first',
            'id': 'Pilih jenis nilai terlebih dahulu',
          }),
        );
        return;
      }

      // Check if at least one student has a grade value
      bool hasData = false;
      for (var student in widget.studentList) {
        final gradeData = _gradeStudentMap[student.id];
        if (gradeData?['score']?.isNotEmpty == true) {
          hasData = true;
          break;
        }
      }

      if (!hasData) {
        SnackBarUtils.showWarning(
          context,
          languageProvider.getTranslatedText({
            'en': 'Enter grade for at least one student',
            'id': 'Masukkan nilai untuk setidaknya satu siswa',
          }),
        );
        return;
      }

      setState(() => _isSaving = true);

      try {
        int successCount = 0;

        for (var student in widget.studentList) {
          final gradeData = _gradeStudentMap[student.id];
          final gradeValue = gradeData?['score']?.toString().trim();

          // Skip if no grade value was entered
          if (gradeValue == null || gradeValue.isEmpty) {
            continue;
          }

          // Fix: Send Student Class ID if available, fallback to student ID (for compatibility)
          final studentIdToSend = student.studentClassId ?? student.id;

          // ... (inside _submitGrade)
          final data = {
            'student_id': student.id, // For legacy/history
            'student_class_id':
                studentIdToSend, // New field required by backend
            'teacher_id': widget.teacher['id'],
            'subject_id': widget.subject['id'],
            'type': _selectedGradeType,
            'score': int.parse(gradeData!['score']),
            'notes': gradeData['description'] ?? '',
            'date':
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
            'title': _titleController.text.isNotEmpty
                ? _titleController.text
                : null,
          };

          // Tambah nilai baru
          await ApiService().post('/grades', data);
          successCount++;
        }

        if (!mounted) return;
        SnackBarUtils.showSuccess(
          context,
          languageProvider.getTranslatedText({
            'en': '$successCount grades successfully saved',
            'id': '$successCount nilai berhasil disimpan',
          }),
        );

        AppNavigator.pop(context);
      } catch (e) {
        AppLogger.error('grades', e);
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else {
      // Validation failed - show error message
      SnackBarUtils.showError(
        context,
        languageProvider.getTranslatedText({
          'en':
              'Please check your input. Grades must be integers between 0-100.',
          'id':
              'Periksa input Anda. Nilai harus berupa angka bulat antara 0-100.',
        }),
      );
    }
  }

  String _getGradeTypeLabel(String type, LanguageProvider languageProvider) {
    switch (type) {
      case 'uh':
        return languageProvider.getTranslatedText({
          'en': 'Daily/Quiz',
          'id': 'UH/Ulangan',
        });
      case 'tugas':
        return languageProvider.getTranslatedText({
          'en': 'Assignment',
          'id': 'Tugas',
        });
      case 'uts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm',
          'id': 'UTS',
        });
      case 'uas':
        return languageProvider.getTranslatedText({'en': 'Final', 'id': 'UAS'});
      case 'pts':
        return languageProvider.getTranslatedText({
          'en': 'Midterm Exam',
          'id': 'PTS',
        });
      case 'pas':
        return languageProvider.getTranslatedText({
          'en': 'Final Exam',
          'id': 'PAS',
        });
      default:
        return type.toUpperCase();
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  /// Ensures controllers and focus nodes exist for [student.id] before the
  /// table widget reads them. Called just before building the table.
  void _ensureTableControllers() {
    for (final student in widget.studentList) {
      final gradeKey = '${student.id}_nilai';
      final deskripsiKey = '${student.id}_deskripsi';
      if (!_tableControllers.containsKey(gradeKey)) {
        _tableControllers[gradeKey] = TextEditingController();
        _tableFocusNodes[gradeKey] = FocusNode();
      }
      if (!_tableControllers.containsKey(deskripsiKey)) {
        _tableControllers[deskripsiKey] = TextEditingController();
        _tableFocusNodes[deskripsiKey] = FocusNode();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final studentsWithGradeCount = widget.studentList.where((student) {
      final gradeData = _gradeStudentMap[student.id];
      return gradeData?['score']?.isNotEmpty == true;
    }).length;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Pattern #7 Gradient Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _getPrimaryColor(),
                  _getPrimaryColor().withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'New Grade Input',
                          'id': 'Input Nilai Baru',
                        }),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.subject['nama'] ?? widget.subject['name'] ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Conditional header based on state
                  if (!_isConfigurationSet)
                    GradeConfigurationPanel(
                      subject: widget.subject,
                      primaryColor: _getPrimaryColor(),
                      gradeTypeList: _gradeTypeList,
                      selectedGradeType: _selectedGradeType,
                      selectedDate: _selectedDate,
                      titleController: _titleController,
                      isReadOnly: _isReadOnly,
                      languageProvider: languageProvider,
                      onGradeTypeChanged: (value) =>
                          setState(() => _selectedGradeType = value),
                      onSelectDate: () => _selectDate(context),
                      onConfirm: () => setState(() {
                        _isConfigurationSet = true;
                        _confirmedGradeType = _selectedGradeType;
                        _confirmedDate = _selectedDate;
                      }),
                      getGradeTypeLabel: (type) =>
                          _getGradeTypeLabel(type, languageProvider),
                    )
                  else
                    GradeAddHeader(
                      gradeTypeLabel: _getGradeTypeLabel(
                        _confirmedGradeType ?? '',
                        languageProvider,
                      ),
                      confirmedDate: _confirmedDate!,
                      languageProvider: languageProvider,
                      onEditConfiguration: () =>
                          setState(() => _isConfigurationSet = false),
                    ),

                  // Student List Section - only show after configuration is set
                  if (_isConfigurationSet) ...[
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Student List',
                              'id': 'Daftar Siswa',
                            }),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: ColorUtils.slate700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: studentsWithGradeCount > 0
                                  ? ColorUtils.success600.withValues(
                                      alpha: 0.08,
                                    )
                                  : ColorUtils.slate100,
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              border: Border.all(
                                color: studentsWithGradeCount > 0
                                    ? ColorUtils.success600.withValues(
                                        alpha: 0.3,
                                      )
                                    : ColorUtils.slate200,
                              ),
                            ),
                            child: Text(
                              '$studentsWithGradeCount/${widget.studentList.length} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                              style: TextStyle(
                                color: studentsWithGradeCount > 0
                                    ? ColorUtils.success600
                                    : ColorUtils.slate500,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Edit grade and description for each student',
                          'id': 'Edit nilai dan deskripsi untuk setiap siswa',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate400,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Expanded(
                      child: Builder(
                        builder: (_) {
                          // Ensure controllers exist before handing them to the
                          // stateless table widget (same logic that was inside
                          // the old _buildInputTable method).
                          _ensureTableControllers();
                          return GradeInputTable(
                            studentList: widget.studentList,
                            tableControllers: _tableControllers,
                            tableFocusNodes: _tableFocusNodes,
                            languageProvider: languageProvider,
                            onGradeChanged: (studentId, value) =>
                                setState(() => _gradeStudentMap[studentId]
                                    ?['score'] = value),
                            onDescriptionChanged: (studentId, value) {
                              _gradeStudentMap[studentId]?['description'] = value;
                            },
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    const Expanded(
                      child: EmptyState(
                        title: 'Select grade type and date',
                        subtitle:
                            'Please select grade type and date first then click Set',
                        icon: Icons.assignment,
                      ),
                    ),
                  ],

                  // Finish button - only show after configuration is set
                  if (_isConfigurationSet) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: ColorUtils.slate200),
                        ),
                      ),
                      child: SafeArea(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _submitGrade,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              disabledBackgroundColor: _getPrimaryColor()
                                  .withValues(alpha: 0.6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                              ),
                            ),
                            child: _isSaving
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Finish',
                                      'id': 'Selesai',
                                    }),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
