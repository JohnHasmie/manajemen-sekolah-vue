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
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/grade_book_controller.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_input_form.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

import 'package:manajemensekolah/features/grades/presentation/widgets/grade_assessment_detail_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_column_options_sheet.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_confirm_delete_dialog.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_edit_table_widget.dart';

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
  bool _isCardView = true; // Default to mobile-friendly card view
  final Set<String> _expandedStudents = {}; // Track expanded student cards
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
  final GlobalKey _addGradeKey = GlobalKey();

  /// Like Vue's `mounted()` -- loads grade data and sets up search listener.
  @override
  void initState() {
    super.initState();
    _loadViewPref();
    _loadData();
    _updateFilteredGradeTypes();
    _searchController.addListener(_filterStudents);
  }

  Future<void> _loadViewPref() async {
    try {
      final c = await LocalCacheService.load('buku_nilai_view_preference');
      if (c is Map && mounted) setState(() => _isCardView = c['is_card_view'] ?? true);
    } catch (_) {}
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
      _loadData(useCache: false);
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
    if (reload) _loadData(showLoading: false, useCache: false);
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
        totalScore += double.tryParse((existingGrade['score'] ?? existingGrade['nilai'] ?? 0).toString()) ?? 0.0;
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
    _loadData(useCache: false);
  }

  Future<void> _addNewAssessment(String type) async {
    // Screen owns the date-picker dialog (UI concern); controller owns the
    // data manipulation. Like Vue: component handles the modal, composable
    // updates the reactive list.
    final DateTime? picked = await showModernDatePicker(
      context: context,
      initialDate: DateTime.now(),
      title: 'Pilih Tanggal Penilaian',
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GradeInputDialog(
        teacher: widget.teacher,
        subject: widget.subject,
        studentList: _filteredStudentList,
        primaryColor: _getPrimaryColor(),
        languageProvider: languageProvider,
        onSaved: () => _loadData(useCache: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
          _GradeBookHeader(
            primaryColor: _getPrimaryColor(),
            title: languageProvider.getTranslatedText({'en': 'Grade Book', 'id': 'Buku Nilai'}),
            subtitle: '${widget.subject['name'] ?? widget.subject['nama'] ?? ''} - ${widget.classData['name'] ?? widget.classData['nama'] ?? ''}',
            isCardView: _isCardView,
            onBack: () { if (widget.onBack != null) { widget.onBack!(); } else { AppNavigator.pop(context); } },
            onExport: () => _exportGrades(languageProvider),
            onToggleView: () { setState(() => _isCardView = !_isCardView); LocalCacheService.save('buku_nilai_view_preference', {'is_card_view': _isCardView}); },
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
                              'score',
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
                        await _loadData(useCache: false);
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
                      // Search bar
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        color: ColorUtils.slate50,
                        child: Column(children: [
                          Container(
                            height: 40,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: ColorUtils.slate200)),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: ColorUtils.slate900, fontSize: 13),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: languageProvider.getTranslatedText({'en': 'Search students...', 'id': 'Cari siswa...'}),
                                hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
                                prefixIcon: Icon(Icons.search, color: ColorUtils.slate400, size: 18),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                                isCollapsed: true,
                              ),
                              onSubmitted: (_) => FocusScope.of(context).unfocus(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Filter chips + student count
                          Row(children: [
                            Text('${_filteredStudentList.length} siswa', style: TextStyle(fontSize: 11, color: ColorUtils.slate500, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 8),
                            Expanded(child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(children: _allGradeTypeList.map((type) {
                                final isActive = _gradeTypeFilter[type] ?? true;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: GestureDetector(
                                    onTap: () => setState(() {
                                      _gradeTypeFilter[type] = !isActive;
                                      _updateFilteredGradeTypes();
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isActive ? _getPrimaryColor().withValues(alpha: 0.1) : Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: isActive ? _getPrimaryColor().withValues(alpha: 0.3) : ColorUtils.slate200),
                                      ),
                                      child: Text(
                                        _getGradeTypeLabel(type, languageProvider),
                                        style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? _getPrimaryColor() : ColorUtils.slate400),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList()),
                            )),
                          ]),
                        ]),
                      ),
                      // Content with pull-to-refresh
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => _loadData(useCache: false),
                          color: _getPrimaryColor(),
                          child: _filteredStudentList.isEmpty
                              ? ListView(children: [
                                  const SizedBox(height: 100),
                                  EmptyState(
                                    title: languageProvider.getTranslatedText({'en': 'No students found', 'id': 'Tidak ada siswa'}),
                                    subtitle: _searchController.text.isEmpty
                                        ? languageProvider.getTranslatedText({'en': 'No students in this class', 'id': 'Tidak ada siswa di kelas ini'})
                                        : languageProvider.getTranslatedText({'en': 'No search results found', 'id': 'Tidak ditemukan hasil pencarian'}),
                                    icon: Icons.people_outline,
                                  ),
                                ])
                              : _isCardView
                                  ? _buildStudentCardList(languageProvider)
                                  : ListView(padding: EdgeInsets.zero, children: [
                                      GradeTableWidget(
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
                                          onInlineSave: (student, type, header, value) async {
                                            final error = await ref.read(gradeBookControllerProvider).saveInlineGrade(
                                              student, type, header, 'score', value, _gradeList, widget.teacher, widget.subject,
                                            );
                                            if (error == null) { _loadData(showLoading: false, useCache: false); }
                                            return error;
                                          },
                                        ),
                                    ]),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
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

  // ── Student card list (mobile-friendly grade view) ──

  Widget _buildStudentCardList(LanguageProvider lp) {
    final p = _getPrimaryColor();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
      itemCount: _filteredStudentList.length,
      itemBuilder: (context, index) {
        final student = _filteredStudentList[index];
        final isExpanded = _expandedStudents.contains(student.id);

        // Gather all grades for this student
        final studentGrades = _gradeList.where((g) {
          final gStudentId = (g['siswa_id'] ?? g['student_id'] ?? g['student_class_id'])?.toString();
          return gStudentId == student.id || gStudentId == student.studentClassId;
        }).toList();

        // Calculate average
        final scores = studentGrades.map((g) => g['score']).whereType<num>().toList();
        final avg = scores.isNotEmpty ? scores.reduce((a, b) => a + b) / scores.length : null;

        // Group by type for expanded view
        final byType = <String, List<Map<String, dynamic>>>{};
        for (final g in studentGrades) {
          final type = (g['jenis'] ?? g['type'] ?? '').toString();
          byType.putIfAbsent(type, () => []).add(g);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isExpanded ? p.withValues(alpha: 0.2) : ColorUtils.slate100),
          ),
          child: Column(children: [
            // Student header — always visible
            InkWell(
              onTap: () => setState(() {
                if (isExpanded) { _expandedStudents.remove(student.id); }
                else { _expandedStudents.add(student.id); }
              }),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(children: [
                  // Index
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: ColorUtils.slate100, borderRadius: BorderRadius.circular(7)),
                    child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ColorUtils.slate600))),
                  ),
                  const SizedBox(width: 10),
                  // Name
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(student.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate800), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (student.studentNumber.isNotEmpty)
                      Text(student.studentNumber, style: TextStyle(fontSize: 10, color: ColorUtils.slate400)),
                  ])),
                  // Average score
                  if (avg != null) ...[
                    Text(avg.toStringAsFixed(1), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _scoreColor(avg.toDouble()))),
                    const SizedBox(width: 6),
                  ],
                  Icon(isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: ColorUtils.slate400),
                ]),
              ),
            ),

            // Grade chips (collapsed preview)
            if (!isExpanded && studentGrades.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(52, 0, 14, 10),
                child: SizedBox(
                  height: 26,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: studentGrades.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (_, i) {
                      final g = studentGrades[i];
                      final score = g['score'];
                      final type = _shortTypeLabel((g['jenis'] ?? g['type'] ?? '').toString());
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: score != null ? _scoreColor((score as num).toDouble()).withValues(alpha: 0.08) : ColorUtils.slate50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: score != null ? _scoreColor(score.toDouble()).withValues(alpha: 0.2) : ColorUtils.slate200),
                        ),
                        child: Text(
                          score != null ? '$type ${_formatScore(score)}' : '$type -',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: score != null ? _scoreColor(score.toDouble()) : ColorUtils.slate400),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Expanded: full breakdown by type
            if (isExpanded) ...[
              Divider(height: 1, color: ColorUtils.slate100),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ...byType.entries.map((entry) {
                    final typeLabel = _getGradeTypeLabel(entry.key, lp);
                    final grades = entry.value;
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Text(typeLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p, letterSpacing: 0.3)),
                      ),
                      ...grades.map((g) {
                        final score = g['score'];
                        final title = g['title']?.toString() ?? '';
                        final date = g['tanggal']?.toString().split('T').first ?? '';
                        final dateFormatted = date.length >= 10 ? '${date.substring(8, 10)}/${date.substring(5, 7)}' : date;

                        return InkWell(
                          onTap: () {
                            // Find matching assessment header
                            final assessmentId = g['assessment_id']?.toString();
                            final type = (g['jenis'] ?? g['type'] ?? '').toString();
                            final headers = _assessmentHeaders[type] ?? [];
                            final header = headers.firstWhere(
                              (h) => h['id']?.toString() == assessmentId,
                              orElse: () => {'id': assessmentId, 'date': date, 'title': title},
                            );
                            _openInputForm(student, type, lp, header: header);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(children: [
                              const SizedBox(width: 8),
                              Expanded(child: Row(children: [
                                Text(title.isNotEmpty ? title : typeLabel, style: TextStyle(fontSize: 12, color: ColorUtils.slate700)),
                                if (dateFormatted.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text('($dateFormatted)', style: TextStyle(fontSize: 10, color: ColorUtils.slate400)),
                                ],
                              ])),
                              Text(
                                score != null ? _formatScore(score) : '-',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: score != null ? _scoreColor((score as num).toDouble()) : ColorUtils.slate400),
                              ),
                              if (_canEdit && !_isReadOnly) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.edit_outlined, size: 12, color: ColorUtils.slate300),
                              ],
                            ]),
                          ),
                        );
                      }),
                    ]);
                  }),
                  if (studentGrades.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(lp.getTranslatedText({'en': 'No grades yet', 'id': 'Belum ada nilai'}), style: TextStyle(fontSize: 12, color: ColorUtils.slate400)),
                    ),
                ]),
              ),
            ],
          ]),
        );
      },
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return ColorUtils.success600;
    if (score >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  String _shortTypeLabel(String type) {
    const labels = {'uh': 'UH', 'tugas': 'Tgs', 'uts': 'UTS', 'uas': 'UAS', 'pts': 'PTS', 'pas': 'PAS'};
    return labels[type] ?? type.toUpperCase();
  }

  String _formatScore(dynamic score) {
    if (score == null) return '-';
    final d = (score is num) ? score.toDouble() : double.tryParse(score.toString()) ?? 0;
    return d == d.truncateToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
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
  final bool isCardView;
  final VoidCallback onBack;
  final VoidCallback onExport;
  final VoidCallback onToggleView;

  const _GradeBookHeader({
    required this.primaryColor,
    required this.title,
    required this.subtitle,
    required this.isCardView,
    required this.onBack,
    required this.onExport,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [primaryColor, primaryColor.withValues(alpha: 0.85)]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // Drag handle
        Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
        // Title row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.menu_book_outlined, color: Colors.white, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
            // View toggle
            GestureDetector(onTap: onToggleView, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Icon(isCardView ? Icons.table_chart_rounded : Icons.view_agenda_rounded, color: Colors.white, size: 16))),
            const SizedBox(width: 6),
            // Export
            GestureDetector(onTap: onExport, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.download_rounded, color: Colors.white, size: 16))),
            const SizedBox(width: 6),
            // Close
            GestureDetector(onTap: onBack, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.close, color: Colors.white, size: 18))),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Grade Input Dialog — DraggableScrollableSheet for adding new grades
// ═══════════════════════════════════════════════════════════════════════════════

class _GradeInputDialog extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final List<Student> studentList;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onSaved;

  const _GradeInputDialog({
    required this.teacher, required this.subject, required this.studentList,
    required this.primaryColor, required this.languageProvider, required this.onSaved,
  });

  @override
  State<_GradeInputDialog> createState() => _GradeInputDialogState();
}

class _GradeInputDialogState extends State<_GradeInputDialog> {
  String _selectedType = 'uh';
  DateTime _selectedDate = DateTime.now();
  final _titleController = TextEditingController();
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, FocusNode> _scoreFocusNodes = {};
  bool _isSaving = false;

  final _types = ['uh', 'tugas', 'uts', 'uas', 'pts', 'pas'];
  final _typeLabels = {'uh': 'UH', 'tugas': 'Tugas', 'uts': 'UTS', 'uas': 'UAS', 'pts': 'PTS', 'pas': 'PAS'};

  @override
  void initState() {
    super.initState();
    for (final s in widget.studentList) {
      _scoreControllers[s.id] = TextEditingController();
      _scoreFocusNodes[s.id] = FocusNode();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _scoreControllers.values) { c.dispose(); }
    for (final f in _scoreFocusNodes.values) { f.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    final entries = _scoreControllers.entries.where((e) => e.value.text.trim().isNotEmpty).toList();
    if (entries.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      int saved = 0;
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      for (final entry in entries) {
        final student = widget.studentList.firstWhere((s) => s.id == entry.key);
        final score = int.tryParse(entry.value.text.trim());
        if (score == null) continue;

        await dioClient.post('/grades', data: {
          'student_id': student.id,
          'student_class_id': student.studentClassId ?? student.id,
          'teacher_id': widget.teacher['id'],
          'subject_id': widget.subject['id'],
          'type': _selectedType,
          'score': score,
          'date': dateStr,
          'title': _titleController.text.isNotEmpty ? _titleController.text : null,
        });
        saved++;
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$saved nilai berhasil disimpan'), backgroundColor: ColorUtils.success600));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e)), backgroundColor: ColorUtils.error600));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _focusStudent(int index) {
    if (index >= 0 && index < widget.studentList.length) {
      _scoreFocusNodes[widget.studentList[index].id]?.requestFocus();
    }
  }

  String _fmtDate(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.primaryColor;
    final subjectName = widget.subject['name'] ?? widget.subject['nama'] ?? '-';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          // ── Header ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p, p.withValues(alpha: 0.85)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 14),
                child: Row(children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.add_chart_rounded, color: Colors.white, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Input Nilai Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(subjectName, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                  ])),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.close, color: Colors.white, size: 18)),
                  ),
                ]),
              ),
            ]),
          ),

          // ── Sticky config: type + date + title ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Type chips
              SizedBox(height: 32, child: ListView(scrollDirection: Axis.horizontal, children: _types.map((t) {
                final selected = t == _selectedType;
                return Padding(padding: const EdgeInsets.only(right: 6), child: GestureDetector(
                  onTap: () => setState(() => _selectedType = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? p.withValues(alpha: 0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? p.withValues(alpha: 0.3) : ColorUtils.slate200),
                    ),
                    child: Text(_typeLabels[t] ?? t.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? p : ColorUtils.slate500)),
                  ),
                ));
              }).toList())),
              const SizedBox(height: 8),
              // Date + Title row
              Row(children: [
                GestureDetector(
                  onTap: () async {
                    final d = await showModernDatePicker(context: context, initialDate: _selectedDate, title: 'Pilih Tanggal Penilaian');
                    if (d != null) setState(() => _selectedDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: ColorUtils.slate50, borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.calendar_today_rounded, size: 13, color: p),
                      const SizedBox(width: 6),
                      Text(_fmtDate(_selectedDate), style: TextStyle(fontSize: 11, color: ColorUtils.slate700, fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Judul (opsional)',
                    hintStyle: TextStyle(fontSize: 11, color: ColorUtils.slate400),
                    filled: true, fillColor: ColorUtils.slate50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                )),
              ]),
            ]),
          ),
          Divider(height: 1, color: ColorUtils.slate100),

          // ── Student list (scrollable, keyboard-aware) ──
          Expanded(child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : MediaQuery.of(context).padding.bottom + 60),
            itemCount: widget.studentList.length,
            itemBuilder: (ctx, i) {
              final student = widget.studentList[i];
              final ctrl = _scoreControllers[student.id]!;
              final focusNode = _scoreFocusNodes[student.id]!;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : ColorUtils.slate50,
                  border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
                ),
                child: Row(children: [
                  SizedBox(width: 24, child: Text('${i + 1}', style: TextStyle(fontSize: 10, color: ColorUtils.slate400, fontWeight: FontWeight.w600))),
                  Expanded(child: Text(student.name, style: TextStyle(fontSize: 13, color: ColorUtils.slate800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: ctrl,
                      focusNode: focusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: i < widget.studentList.length - 1 ? TextInputAction.next : TextInputAction.done,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p),
                      decoration: InputDecoration(
                        hintText: '-',
                        hintStyle: TextStyle(color: ColorUtils.slate300, fontWeight: FontWeight.w400),
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ColorUtils.slate200)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: ColorUtils.slate200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: p, width: 1.5)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _focusStudent(i + 1),
                    ),
                  ),
                ]),
              );
            },
          )),

          // ── Bottom bar ──
          if (bottomInset == 0)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: ColorUtils.slate100))),
                child: SizedBox(
                  width: double.infinity, height: 46,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, elevation: 0, disabledBackgroundColor: ColorUtils.slate300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Simpan Nilai', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
