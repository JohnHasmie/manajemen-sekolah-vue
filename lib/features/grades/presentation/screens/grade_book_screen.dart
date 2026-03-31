// Grade book table screen for teachers.
// Like `pages/teacher/GradeBookTable.vue` in a Vue app.
//
// This is the actual grade table with inline editing (Step 2).
// It supports grading students by assignment type (tugas, ulangan, UTS, UAS),
// Excel export, filtering by grade type, and an onboarding tour.
// In Laravel terms, this is GradeController@index + @store + @export.
//
// Extracted from teacher_grade_input_screen.dart.
// Contains:
// - [GradeBookPage] -- the grade table with inline editing
import 'package:manajemensekolah/core/constants/grade_constants.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/grade_book_controller.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_input_form.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_input_form_new.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_assessment_detail_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_column_options_sheet.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_confirm_delete_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_edit_table_widget.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_filter_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_table_widget.dart';

/// The grade book table page (Step 2) -- displays and edits student grades
/// in a spreadsheet-like view.
///
/// This is like a Vue `<GradeBookTable>` component with complex inline editing.
/// Think of it as a mini spreadsheet: rows are students, columns are assessment
/// types (UH, Tugas, UTS, UAS, PTS, PAS). Supports inline grade editing,
/// column management, filtering by grade type, and Excel export.
///
/// Props (like Vue props):
/// - [teacher] -- the logged-in teacher
/// - [subject] -- the selected subject
/// - [classData] -- the selected class
/// - [onBack] -- callback to navigate back (like Vue `$emit('back')`)
class GradeBookPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final Map<String, dynamic> classData;
  final VoidCallback? onBack;

  const GradeBookPage({
    super.key,
    required this.teacher,
    required this.subject,
    required this.classData,
    this.onBack,
  });

  @override
  GradeBookPageState createState() => GradeBookPageState();
}

/// State for [GradeBookPage] -- holds the grade data and editing state.
///
/// Key state variables (like Vue `data()`):
/// - [_studentList] / [_filteredStudentList] -- student list (all and filtered)
/// - [_gradeList] -- raw grade records from the API
/// - [_assessmentHeaders] -- column headers organized by grade type
/// - [_isEditMode] -- whether inline editing is active
/// - [_gradeTypeFilter] -- which grade types are visible (like Vue checkbox filters)
class GradeBookPageState extends ConsumerState<GradeBookPage> {
  List<Student> _studentList = [];
  List<Student> _filteredStudentList = [];
  List<Map<String, dynamic>> _gradeList = [];
  final List<String> _allGradeTypeList = GradeConstants.allTypes;
  List<String> _filteredGradeTypeList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Filter state — all types visible by default
  final Map<String, bool> _gradeTypeFilter = GradeConstants.defaultFilter;

  // Map to store unique assessments for each grade type
  // Key: type (e.g., 'harian'), Value: List of assessment headers
  // Each header: { 'id': String?, 'date': String, 'title': String?, 'is_temp': bool }
  Map<String, List<Map<String, dynamic>>> _assessmentHeaders = {};

  // Scroll controller for horizontal scroll synchronization
  final ScrollController _horizontalScrollController = ScrollController();

  // Edit Mode State
  bool _isEditMode = false;
  String? _editGradeType;
  // Map to store controllers: key = "studentId_field" (e.g. "123_score", "123_description")
  final Map<String, TextEditingController> _editControllers = {};
  final Map<String, FocusNode> _editFocusNodes = {};

  bool get _canEdit {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    return role == 'guru' || role == 'teacher';
  }

  bool get _isReadOnly {
    final academicYearProvider = ref.read(academicYearRiverpod);
    return academicYearProvider.isReadOnly;
  }

  // Tour properties
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _addGradeKey = GlobalKey();

  /// Like Vue's `mounted()` -- loads grade data and sets up search listener.
  @override
  void initState() {
    super.initState();
    _loadData();
    _updateFilteredGradeTypes();
    _searchController.addListener(_filterStudents);
  }

  /// Like Vue's `beforeUnmount()` -- disposes all controllers and focus nodes.
  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _searchController.dispose();
    for (var controller in _editControllers.values) {
      controller.dispose();
    }
    for (var node in _editFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  /// Filters student list by search query. Like a Vue `computed` that filters
  /// an array, or `watch` on a search input that filters `this.students`.
  void _filterStudents() {
    setState(() {
      _filteredStudentList = ref
          .read(gradeBookControllerProvider)
          .filterStudents(_studentList, _searchController.text);
    });
  }

  /// Applies a [LoadDataResult] from the controller into local state fields.
  /// Must be called inside setState.
  void _applyLoadResult(LoadDataResult result) {
    _studentList = result.studentList;
    _filteredStudentList = result.filteredStudentList;
    _gradeList = result.gradeList;
    _assessmentHeaders = result.assessmentHeaders;
    _isLoading = result.isLoading;
  }

  /// Loads student list and grade data from API with caching.
  /// Like `async mounted()` in Vue calling `axios.get('/api/grades')`.
  /// Uses cache-first strategy; falls back to API on cache miss.
  /// Loads grade data via the controller (cache-first) and applies results
  /// via setState. Shows a snackbar on error.
  Future<void> _loadData({
    bool showLoading = true,
    bool useCache = true,
  }) async {
    if (!mounted) return;

    if (showLoading && _studentList.isEmpty) {
      setState(() => _isLoading = true);
    }

    final ctrl = ref.read(gradeBookControllerProvider);
    final result = await ctrl.loadData(
      teacher: widget.teacher,
      subject: widget.subject,
      classData: widget.classData,
      allGradeTypeList: _allGradeTypeList,
      showLoading: showLoading,
      useCache: useCache,
    );

    if (!mounted) return;

    if (result.error != null) {
      if (_studentList.isEmpty) setState(() => _isLoading = false);
      _showErrorSnackBar(result.error!);
      return;
    }

    setState(() => _applyLoadResult(result));
    _filterStudents();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAndShowTour();
    });
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ref.read(gradeBookControllerProvider).showErrorSnackBar(context, message);
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ref.read(gradeBookControllerProvider).showSuccessSnackBar(context, message);
    }
  }

  void _updateFilteredGradeTypes() {
    setState(() {
      _filteredGradeTypeList = ref
          .read(gradeBookControllerProvider)
          .computeFilteredGradeTypes(_allGradeTypeList, _gradeTypeFilter);
    });
  }

  void _showFilterDialog(LanguageProvider languageProvider) {
    showGradeFilterSheet(
      context: context,
      allGradeTypes: _allGradeTypeList,
      gradeTypeFilter: _gradeTypeFilter,
      primaryColor: _getPrimaryColor(),
      getLabel: (type) => _getGradeTypeLabel(type, languageProvider),
      onFilterChanged: (updated) {
        setState(() {
          for (final entry in updated.entries) {
            _gradeTypeFilter[entry.key] = entry.value;
          }
          _updateFilteredGradeTypes();
        });
      },
    );
  }

  Map<String, dynamic>? _getGradeForStudentAndHeader(
    Student student,
    String type,
    Map<String, dynamic> header,
  ) {
    return ref
        .read(gradeBookControllerProvider)
        .getGradeForStudentAndHeader(student, type, header, _gradeList);
  }

  void _openInputForm(
    Student student,
    String gradeType,
    LanguageProvider languageProvider, {
    Map<String, dynamic>? header,
  }) {
    final existingGrade = header != null
        ? _getGradeForStudentAndHeader(student, gradeType, header)
        : null;

    AppNavigator.push(
      context,
      GradeInputForm(
        teacher: widget.teacher,
        subject: widget.subject,
        student: student,
        gradeType: gradeType,
        existingGrade: existingGrade,
        assessmentId: header?['id'], // Pass assessment ID
        initialDate: header != null ? DateTime.parse(header['date']) : null,
        initialTitle: header?['title'],
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _showColumnOptions(
    String type,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    final String date = header['date'];
    final String? title = header['title'];
    final String displayTitle = title != null && title.isNotEmpty
        ? '$title (${_formatDateDisplay(date)})'
        : _formatDateDisplay(date);

    showGradeColumnOptionsSheet(
      context: context,
      gradeTypeLabel: _getGradeTypeLabel(type, languageProvider),
      displayTitle: displayTitle,
      primaryColor: _getPrimaryColor(),
      canEdit: _canEdit,
      isReadOnly: _isReadOnly,
      onViewDetails: () => _showAssessmentDetail(type, header, languageProvider),
      onEditAssessment: () => _enterEditMode(type, header),
      onDeleteAssessment: () =>
          _confirmDeleteAssessment(type, header, languageProvider),
      labelViewDetails: languageProvider.getTranslatedText({
        'en': 'View Details',
        'id': 'Lihat Detail',
      }),
      labelEditAssessment: languageProvider.getTranslatedText({
        'en': 'Edit Assessment',
        'id': 'Edit Penilaian',
      }),
      labelDeleteAssessment: languageProvider.getTranslatedText({
        'en': 'Delete Assessment',
        'id': 'Hapus Penilaian',
      }),
      labelDeleteSubtitle: languageProvider.getTranslatedText({
        'en': 'Delete all grades for this assessment',
        'id': 'Hapus semua nilai penilaian ini',
      }),
    );
  }

  Map<String, dynamic>? _editHeader;

  /// Enters inline edit mode for a specific grade column.
  /// Delegates all setup to the controller; screen just applies the result via
  /// setState. Like calling a Vue composable and spreading its return value
  /// into the component's reactive state.
  void _enterEditMode(String type, Map<String, dynamic> header) {
    // Dispose old nodes/controllers before replacing them.
    for (var c in _editControllers.values) {
      c.dispose();
    }
    for (var n in _editFocusNodes.values) {
      n.dispose();
    }
    _editControllers.clear();
    _editFocusNodes.clear();

    final result = ref.read(gradeBookControllerProvider).enterEditMode(
      type,
      header,
      _filteredStudentList,
      _gradeList,
      onFocusLost: _saveInlineGrade,
    );

    setState(() {
      _isEditMode = result.isEditMode;
      _editGradeType = result.editGradeType;
      _editHeader = result.editHeader;
      _editControllers.addAll(result.editControllers);
      _editFocusNodes.addAll(result.editFocusNodes);
    });
  }

  /// Saves a single grade value to the API (inline edit).
  /// Delegates to the controller; reloads data on success unless [reload] is
  /// false (used when finishing a batch-save so we only reload once at the end).
  Future<void> _saveInlineGrade(
    Student student,
    String type,
    Map<String, dynamic> header,
    String field,
    String value, {
    bool reload = true,
  }) async {
    final error = await ref.read(gradeBookControllerProvider).saveInlineGrade(
          student,
          type,
          header,
          field,
          value,
          _gradeList,
          widget.teacher,
          widget.subject,
        );
    if (error != null) {
      _showErrorSnackBar(error);
      return;
    }
    if (reload) _loadData(showLoading: false);
  }

  String _formatDateDisplay(String dateStr) =>
      ref.read(gradeBookControllerProvider).formatDateDisplay(dateStr);

  void _showAssessmentDetail(
    String type,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    final String date = header['date'];
    final String? title = header['title'];

    // Pre-compute stats — like a Vue computed property before opening a modal.
    final int totalSiswa = _studentList.length;
    int gradedCount = 0;
    double totalScore = 0;
    for (var student in _studentList) {
      final existingGrade = _getGradeForStudentAndHeader(student, type, header);
      if (existingGrade != null && existingGrade.isNotEmpty) {
        gradedCount++;
        totalScore += double.tryParse(existingGrade['nilai'].toString()) ?? 0.0;
      }
    }
    final double average = gradedCount > 0 ? totalScore / gradedCount : 0;

    showGradeAssessmentDetailDialog(
      context: context,
      primaryColor: _getPrimaryColor(),
      labelTitle: languageProvider.getTranslatedText({
        'en': 'Assessment Details',
        'id': 'Detail Penilaian',
      }),
      labelType: languageProvider.getTranslatedText({'en': 'Type', 'id': 'Jenis'}),
      labelDate: languageProvider.getTranslatedText({'en': 'Date', 'id': 'Tanggal'}),
      labelAssessmentTitle: languageProvider.getTranslatedText({
        'en': 'Title',
        'id': 'Judul',
      }),
      labelTotalStudents: languageProvider.getTranslatedText({
        'en': 'Total Students',
        'id': 'Total Siswa',
      }),
      labelGraded: languageProvider.getTranslatedText({
        'en': 'Graded',
        'id': 'Sudah Dinilai',
      }),
      labelAverage: languageProvider.getTranslatedText({
        'en': 'Average Score',
        'id': 'Rata-rata Nilai',
      }),
      gradeTypeLabel: _getGradeTypeLabel(type, languageProvider),
      formattedDate: _formatDateDisplay(date),
      assessmentTitle: (title != null && title.isNotEmpty) ? title : null,
      totalStudents: totalSiswa,
      gradedCount: gradedCount,
      averageScore: average.toStringAsFixed(2),
    );
  }

  void _confirmDeleteAssessment(
    String type,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    final String date = header['date'];
    final String? title = header['title'];
    final String typeLabel = _getGradeTypeLabel(type, languageProvider);
    final String dateLabel = _formatDateDisplay(date);
    final String titleSuffix = title != null ? ' ($title)' : '';

    showGradeConfirmDeleteDialog(
      context: context,
      labelHeader: languageProvider.getTranslatedText({
        'en': 'Delete Assessment?',
        'id': 'Hapus Penilaian?',
      }),
      confirmMessage: languageProvider.getTranslatedText({
        'en':
            'Are you sure you want to delete all grades for $typeLabel on $dateLabel$titleSuffix? This action cannot be undone.',
        'id':
            'Apakah Anda yakin ingin menghapus semua nilai $typeLabel pada tanggal $dateLabel$titleSuffix? Tindakan ini tidak dapat dibatalkan.',
      }),
      labelCancel: languageProvider.getTranslatedText({
        'en': 'Cancel',
        'id': 'Batal',
      }),
      labelDelete: languageProvider.getTranslatedText({
        'en': 'Delete',
        'id': 'Hapus',
      }),
      onConfirm: () => _deleteAssessment(type, header),
    );
  }

  Future<void> _deleteAssessment(
    String type,
    Map<String, dynamic> header,
  ) async {
    setState(() => _isLoading = true);
    final error = await ref
        .read(gradeBookControllerProvider)
        .deleteAssessment(type, header, widget.subject);
    if (error != null) {
      setState(() => _isLoading = false);
      _showErrorSnackBar(error);
      return;
    }
    _showSuccessSnackBar('Assessment deleted successfully');
    _loadData();
  }

  Future<void> _addNewAssessment(String type) async {
    // Screen owns the date-picker dialog (UI concern); controller owns the
    // data manipulation. Like Vue: component handles the modal, composable
    // updates the reactive list.
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    final updated = ref
        .read(gradeBookControllerProvider)
        .addNewAssessment(type, _assessmentHeaders, picked);

    if (updated != null) {
      setState(() => _assessmentHeaders = updated);
    }
  }

  Future<void> _exportGrades(LanguageProvider languageProvider) async {
    setState(() => _isLoading = true);
    final error = await ref.read(gradeBookControllerProvider).exportGrades(
          widget.teacher,
          widget.subject,
          widget.classData,
        );
    setState(() => _isLoading = false);
    if (error != null) {
      _showErrorSnackBar(error);
      return;
    }
    _showSuccessSnackBar(
      languageProvider.getTranslatedText({
        'en': 'Export successful',
        'id': 'Ekspor berhasil',
      }),
    );
  }

  void _openNewInputForm(LanguageProvider languageProvider) {
    AppNavigator.push(
      context,
      GradeInputFormNew(
        teacher: widget.teacher,
        subject: widget.subject,
        studentList: _studentList,
      ),
    ).then((_) {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final activeFilterCount = _gradeTypeFilter.values.where((v) => v).length;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Pattern #7 Gradient Header — extracted to _GradeBookHeader
          _GradeBookHeader(
            primaryColor: _getPrimaryColor(),
            title: languageProvider.getTranslatedText({
              'en': 'Grade Book',
              'id': 'Buku Nilai',
            }),
            subtitle:
                '${widget.subject['name'] ?? widget.subject['nama'] ?? ''}'
                ' - '
                '${widget.classData['name'] ?? widget.classData['nama'] ?? ''}',
            filterKey: _filterKey,
            activeFilterCount: activeFilterCount,
            totalGradeTypes: _allGradeTypeList.length,
            onBack: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                AppNavigator.pop(context);
              }
            },
            onExport: () => _exportGrades(languageProvider),
            onFilter: () => _showFilterDialog(languageProvider),
            onRefresh: _loadData,
          ),

          // Body
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                  )
                : _isEditMode && _editGradeType != null && _editHeader != null
                ? GradeEditTableWidget(
                    editGradeType: _editGradeType!,
                    editHeader: _editHeader!,
                    filteredStudentList: _filteredStudentList,
                    editControllers: _editControllers,
                    editFocusNodes: _editFocusNodes,
                    isReadOnly: _isReadOnly,
                    primaryColor: _getPrimaryColor(),
                    languageProvider: languageProvider,
                    onSaveGrade: (student, field, value) => _saveInlineGrade(
                      student,
                      _editGradeType!,
                      _editHeader!,
                      field,
                      value,
                    ),
                    onFinish: () async {
                      setState(() => _isLoading = true);
                      try {
                        for (var student in _filteredStudentList) {
                          final scoreKey = '${student.id}_score';
                          final deskripsiKey = '${student.id}_deskripsi';
                          if (_editControllers.containsKey(scoreKey)) {
                            await _saveInlineGrade(
                              student,
                              _editGradeType!,
                              _editHeader!,
                              'nilai',
                              _editControllers[scoreKey]!.text,
                              reload: false,
                            );
                          }
                          if (_editControllers.containsKey(deskripsiKey)) {
                            await _saveInlineGrade(
                              student,
                              _editGradeType!,
                              _editHeader!,
                              'deskripsi',
                              _editControllers[deskripsiKey]!.text,
                              reload: false,
                            );
                          }
                        }
                        await _loadData();
                        setState(() {
                          _isEditMode = false;
                          _editGradeType = null;
                          _editHeader = null;
                          _isLoading = false;
                        });
                      } catch (e) {
                        AppLogger.error('grades', e);
                        setState(() => _isLoading = false);
                        _showErrorSnackBar(e.toString());
                      }
                    },
                  )
                : Column(
                    children: [
                      // Info bar (Pattern from spec)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(color: ColorUtils.slate200),
                          boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                              ),
                              child: Icon(
                                Icons.book_outlined,
                                color: _getPrimaryColor(),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.subject['name'] ??
                                        widget.subject['nama'] ??
                                        '-',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: ColorUtils.slate900,
                                    ),
                                  ),
                                  Text(
                                    '${languageProvider.getTranslatedText({'en': 'Types', 'id': 'Jenis'})}: ${_filteredGradeTypeList.map((j) => _getGradeTypeLabel(j, languageProvider)).join(', ')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ColorUtils.slate600,
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

                      // Search Bar
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(color: ColorUtils.slate200),
                          boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: ColorUtils.slate900),
                          decoration: InputDecoration(
                            hintText: languageProvider.getTranslatedText({
                              'en': 'Search students...',
                              'id': 'Cari siswa...',
                            }),
                            hintStyle: TextStyle(color: ColorUtils.slate400),
                            prefixIcon: Icon(
                              Icons.search,
                              color: ColorUtils.slate400,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),

                      if (_filteredStudentList.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Row(
                            children: [
                              Text(
                                '${_filteredStudentList.length} ${languageProvider.getTranslatedText({'en': 'students found', 'id': 'siswa ditemukan'})}',
                                style: TextStyle(
                                  color: ColorUtils.slate500,
                                  fontSize: 12,
                                ),
                              ),
                              Spacer(),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Tap cells to edit',
                                  'id': 'Klik sel untuk mengedit',
                                }),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorUtils.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),

                      // Tabel Nilai
                      Expanded(
                        child: _filteredStudentList.isEmpty
                            ? EmptyState(
                                title: languageProvider.getTranslatedText({
                                  'en': 'No students found',
                                  'id': 'Tidak ada siswa',
                                }),
                                subtitle: _searchController.text.isEmpty
                                    ? languageProvider.getTranslatedText({
                                        'en': 'No students in this class',
                                        'id': 'Tidak ada siswa di kelas ini',
                                      })
                                    : languageProvider.getTranslatedText({
                                        'en': 'No search results found',
                                        'id': 'Tidak ditemukan hasil pencarian',
                                      }),
                                icon: Icons.people_outline,
                              )
                            : Container(
                                margin: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                                  border: Border.all(
                                    color: ColorUtils.slate200,
                                  ),
                                  boxShadow: ColorUtils.corporateShadow(
                                    elevation: 1.0,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: GradeTableWidget(
                                    filteredStudentList: _filteredStudentList,
                                    filteredGradeTypeList: _filteredGradeTypeList,
                                    assessmentHeaders: _assessmentHeaders,
                                    gradeList: _gradeList,
                                    horizontalScrollController: _horizontalScrollController,
                                    canEdit: _canEdit,
                                    isReadOnly: _isReadOnly,
                                    primaryColor: _getPrimaryColor(),
                                    languageProvider: languageProvider,
                                    onColumnTap: (type, header) => _showColumnOptions(type, header, languageProvider),
                                    onCellTap: (student, type, header) => _openInputForm(student, type, languageProvider, header: header),
                                    onAddAssessment: _addNewAssessment,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: (_isEditMode || !_canEdit || _isReadOnly)
          ? null
          : FloatingActionButton(
              key: _addGradeKey,
              onPressed: () => _openNewInputForm(languageProvider),
              backgroundColor: _getPrimaryColor(),
              foregroundColor: Colors.white,
              child: Icon(Icons.add),
            ),
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'input_grade_screen',
        'guru',
      );

      // Only use cache (pre-fetched by dashboard), no API call
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('grades', e);
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'input_grade_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('input_grade_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'input_grade_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('input_grade_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];

    targets.add(
      TargetFocus(
        identify: "FilterGrades",
        keyTarget: _filterKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Filter Jenis Nilai",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Gunakan tombol ini untuk menyaring kolom penilaian berdasarkan jenis (misal: hanya tampilkan UTS & UAS saja).",
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    if (_canEdit && !_isReadOnly) {
      targets.add(
        TargetFocus(
          identify: "AddGrade",
          keyTarget: _addGradeKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Tambah Penilaian",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Ketuk tombol ini untuk membuat kolom penilaian baru secara massal untuk seluruh siswa di kelas ini.",
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    return targets;
  }

  // ---------------------------------------------------------------------------
  // Color / label helpers — thin delegates to the controller so call-sites in
  // this file stay unchanged. Like Vue `methods` that forward to a composable.
  // ---------------------------------------------------------------------------

  Color _getPrimaryColor() =>
      ref.read(gradeBookControllerProvider).getPrimaryColor(widget.teacher);

  String _getGradeTypeLabel(String type, LanguageProvider languageProvider) =>
      ref
          .read(gradeBookControllerProvider)
          .getGradeTypeLabel(type, languageProvider);
}

/// Gradient header bar for [GradeBookPage].
/// Extracted from the build method to reduce its size and allow independent
/// rebuilds. Like a Vue `<GradeBookHeader>` presentational component.
class _GradeBookHeader extends StatelessWidget {
  final Color primaryColor;
  final String title;
  final String subtitle;
  final GlobalKey filterKey;
  final int activeFilterCount;
  final int totalGradeTypes;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onFilter;
  final VoidCallback onRefresh;

  const _GradeBookHeader({
    required this.primaryColor,
    required this.title,
    required this.subtitle,
    required this.filterKey,
    required this.activeFilterCount,
    required this.totalGradeTypes,
    required this.onBack,
    required this.onExport,
    required this.onFilter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
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
          // Export button
          GestureDetector(
            onTap: onExport,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(Icons.download, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Filter button with badge
          Stack(
            key: filterKey,
            children: [
              GestureDetector(
                onTap: onFilter,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: const Icon(
                    Icons.filter_list_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              if (activeFilterCount < totalGradeTypes)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: ColorUtils.error600,
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '${totalGradeTypes - activeFilterCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          // Refresh button
          GestureDetector(
            onTap: onRefresh,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
