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
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_input_form.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/grade_input_form_new.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

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
  final List<String> _allGradeTypeList = [
    'uh',
    'tugas',
    'uts',
    'uas',
    'pts',
    'pas',
  ];
  List<String> _filteredGradeTypeList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  final Map<String, bool> _gradeTypeFilter = {
    'uh': true,
    'tugas': true,
    'uts': true,
    'uas': true,
    'pts': true,
    'pas': true,
  };

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

  String _buildGradeCacheKey() {
    final academicYearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    final subjectId = widget.subject['id']?.toString() ?? 'unknown';
    final classId = widget.classData['id']?.toString() ?? 'unknown';
    return 'grade_book_${subjectId}_${classId}_$academicYearId';
  }

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
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudentList = List.from(_studentList);
      } else {
        _filteredStudentList = _studentList
            .where(
              (student) =>
                  student.name.toLowerCase().contains(query) ||
                  student.studentNumber.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  /// Process raw grade items and apply to state (used by both cache and fresh load)
  /// Processes raw API data into structured grade records per student.
  /// Like a Vue `computed` or `watch` that transforms API response into
  /// a table-friendly format. Maps student data with their grades.
  void _processAndApplyGradeData(
    List<dynamic> studentData,
    List<dynamic> rawGradeItems,
  ) {
    _studentList = studentData.map((s) => Student.fromJson(s)).toList();
    _filteredStudentList = List.from(_studentList);

    final currentStudentIds = _studentList.map((s) => s.id.toString()).toSet();
    final currentStudentClassIds = _studentList
        .map((s) => s.studentClassId?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    // Filter and map grades to internal legacy format
    _gradeList = rawGradeItems
        .where((item) {
          final studentId =
              (item['student_id'] ?? item['siswa_id'] ?? item['siswa']?['id'])
                  ?.toString();
          final studentClassId =
              (item['student_class_id'] ?? item['siswa_kelas_id'])?.toString();

          return currentStudentIds.contains(studentId) ||
              (studentClassId != null &&
                  currentStudentClassIds.contains(studentClassId));
        })
        .map<Map<String, dynamic>>((item) {
          return {
            'id': item['id'],
            'siswa_id':
                (item['student_id'] ?? item['siswa_id'] ?? item['siswa']?['id'])
                    ?.toString(),
            'student_class_id':
                (item['student_class_id'] ?? item['siswa_kelas_id'])
                    ?.toString(),
            'nilai': item['score'] ?? item['nilai'],
            'deskripsi': item['notes'] ?? item['deskripsi'],
            'tanggal':
                item['assessment']?['date'] ?? item['date'] ?? item['tanggal'],
            'jenis':
                (item['assessment']?['type'] ?? item['type'] ?? item['jenis'])
                    ?.toString()
                    .toLowerCase(),
            'title': item['assessment']?['title'] ?? item['title'] ?? '',
            'assessment_id': item['assessment_id'],
          };
        })
        .toList();

    // Process unique assessments for headers
    _assessmentHeaders = {};

    for (var gradeItem in _gradeList) {
      final type = gradeItem['jenis']?.toString().toLowerCase();
      if (type == null || !_allGradeTypeList.contains(type)) continue;

      final String? rawDate = gradeItem['tanggal'];
      if (rawDate != null) {
        final datePart = rawDate.split('T')[0];
        final assessmentId = gradeItem['assessment_id'];
        final title = (gradeItem['title'] ?? '').toString().trim();

        if (!_assessmentHeaders.containsKey(type)) {
          _assessmentHeaders[type] = [];
        }

        // Check if header already exists
        final existingIndex = _assessmentHeaders[type]!.indexWhere((h) {
          final headerId = h['id']?.toString();
          final currentAssessmentId = assessmentId?.toString();

          if (currentAssessmentId != null && headerId != null) {
            return headerId == currentAssessmentId;
          }
          if (currentAssessmentId != null || headerId != null) {
            return false;
          }
          final hTitle = (h['title'] ?? '').toString().trim();
          return h['date'] == datePart && hTitle == title;
        });

        if (existingIndex == -1) {
          _assessmentHeaders[type]!.add({
            'id': assessmentId,
            'date': datePart,
            'title': title,
            'is_temp': false,
          });
        }
      }
    }

    // Sort headers by date and title
    for (var key in _assessmentHeaders.keys) {
      _assessmentHeaders[key]!.sort((a, b) {
        final dateCompare = a['date'].compareTo(b['date']);
        if (dateCompare != 0) return dateCompare;
        return (a['title'] ?? '').compareTo(b['title'] ?? '');
      });
    }

    _isLoading = false;
  }

  /// Loads student list and grade data from API with caching.
  /// Like `async mounted()` in Vue calling `axios.get('/api/grades')`.
  /// Uses cache-first strategy; falls back to API on cache miss.
  Future<void> _loadData({
    bool showLoading = true,
    bool useCache = true,
  }) async {
    try {
      if (!mounted) return;

      // ─── Step 1: Try loading from cache → return early ───
      if (showLoading && useCache) {
        try {
          final cacheKey = _buildGradeCacheKey();
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 3),
          );
          if (cached != null && mounted) {
            final cachedData = Map<String, dynamic>.from(cached);
            final studentData = List<dynamic>.from(
              cachedData['studentData'] ?? [],
            );
            final gradeItems = List<dynamic>.from(
              cachedData['gradeItems'] ?? [],
            );
            if (studentData.isNotEmpty) {
              setState(() {
                _processAndApplyGradeData(studentData, gradeItems);
              });
              _filterStudents();
              // Trigger tour
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _checkAndShowTour();
              });
              AppLogger.info(
                'grades',
                'Grade book loaded from cache — skipping API',
              );
              return; // ✅ Cache hit — no API needed
            }
          }
        } catch (e) {
          AppLogger.error('grades', e);
        }
      }

      // Show skeleton only if no data yet
      if (_studentList.isEmpty && mounted) {
        if (showLoading) setState(() => _isLoading = true);
      }

      // ─── Step 2: No cache — fetch fresh from API ───
      // 1. Load students by class
      final studentData = await getIt<ApiStudentService>().getStudentByClass(
        widget.classData['id'],
      );

      // 2. Load existing grades
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id'];

      final subjectId = widget.subject['id'];
      final url =
          '/grades/teacher?subject_id=$subjectId&limit=500${academicYearId != null ? "&academic_year_id=$academicYearId" : ""}';

      AppLogger.debug('grades', 'DEBUG: Loading grades from $url');

      final response = await ApiService().get(url);

      // Handle paginated response (Map with 'data' key) or direct List
      List<dynamic> rawGradeItems = [];
      if (response is Map<String, dynamic> && response.containsKey('data')) {
        rawGradeItems = response['data'] as List<dynamic>;
      } else if (response is List) {
        rawGradeItems = response;
      }

      AppLogger.debug(
        'grades',
        'DEBUG: Received ${rawGradeItems.length} grade items',
      );

      if (!mounted) return;

      setState(() {
        _processAndApplyGradeData(studentData, rawGradeItems);
      });
      _filterStudents();

      // ─── Step 3: Save to cache ───
      final cacheKey = _buildGradeCacheKey();
      LocalCacheService.save(cacheKey, {
        'studentData': studentData,
        'gradeItems': rawGradeItems,
      });

      // Trigger tour
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    } catch (e) {
      AppLogger.error('grades', e);
      if (!mounted) return;
      if (_studentList.isEmpty) {
        setState(() => _isLoading = false);
      }
      _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showError(context, message);
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showSuccess(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': message,
          'id': message.replaceAll('successfully', 'berhasil'),
        }),
      );
    }
  }

  void _updateFilteredGradeTypes() {
    setState(() {
      _filteredGradeTypeList = _allGradeTypeList
          .where((type) => _gradeTypeFilter[type] == true)
          .toList();
    });
  }

  void _showFilterDialog(LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Gradient header
              Container(
                padding: EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getPrimaryColor(),
                      _getPrimaryColor().withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.filter_list_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: AppSpacing.md),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Filter Grade Types',
                            'id': 'Filter Jenis Nilai',
                          }),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setSheetState(() {
                          for (var key in _gradeTypeFilter.keys) {
                            _gradeTypeFilter[key] = true;
                          }
                        });
                        setState(_updateFilteredGradeTypes);
                      },
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: _allGradeTypeList.map((type) {
                      return CheckboxListTile(
                        title: Text(
                          _getGradeTypeLabel(type, languageProvider),
                          style: TextStyle(
                            color: ColorUtils.slate800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _gradeTypeFilter[type],
                        activeColor: _getPrimaryColor(),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onChanged: (bool? value) {
                          setSheetState(() {
                            _gradeTypeFilter[type] = value ?? false;
                          });
                          setState(_updateFilteredGradeTypes);
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Footer
              Container(
                padding: EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => AppNavigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getPrimaryColor(),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Apply',
                        'id': 'Terapkan',
                      }),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic>? _getGradeForStudentAndHeader(
    Student student,
    String type,
    Map<String, dynamic> header,
  ) {
    try {
      final studentId = student.id.toString();
      final studentClassId = student.studentClassId?.toString();

      final result = _gradeList.firstWhere((gradeItem) {
        final gradeStudentId = gradeItem['siswa_id']?.toString();
        final gradeStudentClassId = gradeItem['student_class_id']?.toString();

        // 1. Match Student: Try direct ID match or student_class_id match
        bool studentMatch = (gradeStudentId == studentId);

        if (!studentMatch &&
            (studentClassId != null || gradeStudentClassId != null)) {
          studentMatch =
              (gradeStudentClassId == studentClassId) ||
              (gradeStudentId == studentClassId);
        }

        if (!studentMatch) return false;

        // 2. Match Header (Assessment)
        final headerId = header['id']?.toString();
        final currentAssessmentId = gradeItem['assessment_id']?.toString();

        if (headerId != null && currentAssessmentId != null) {
          if (headerId != currentAssessmentId) return false;
        } else if (headerId != null || currentAssessmentId != null) {
          // One has ID, other doesn't. If they have same date and title, maybe they ARE the same?
          // For now, be strict if ID exists.
          return false;
        }

        final gradeDate = gradeItem['tanggal']?.toString().split('T')[0];
        final gradeType = gradeItem['jenis']?.toString().toLowerCase();

        final nTitle = (gradeItem['title'] ?? '').toString().trim();
        final hTitle = (header['title'] ?? '').toString().trim();

        return (gradeType == type.toLowerCase() &&
            gradeDate == header['date'] &&
            nTitle == hTitle);
      }, orElse: () => <String, dynamic>{});

      return result.isEmpty ? null : result;
    } catch (e) {
      return null;
    }
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
        ? "$title (${_formatDateDisplay(date)})"
        : _formatDateDisplay(date);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient header bar
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getPrimaryColor(),
                        _getPrimaryColor().withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.assessment_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "${_getGradeTypeLabel(type, languageProvider)} - $displayTitle",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.visibility,
                      color: ColorUtils.corporateBlue600,
                    ),
                  ),
                  title: Text(
                    languageProvider.getTranslatedText({
                      'en': 'View Details',
                      'id': 'Lihat Detail',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate800,
                    ),
                  ),
                  onTap: () {
                    AppNavigator.pop(context);
                    _showAssessmentDetail(type, header, languageProvider);
                  },
                ),
                if (_canEdit && !_isReadOnly) ...[
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: ColorUtils.warning600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit, color: ColorUtils.warning600),
                    ),
                    title: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Edit Assessment',
                        'id': 'Edit Penilaian',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate800,
                      ),
                    ),
                    onTap: () {
                      AppNavigator.pop(context);
                      _enterEditMode(type, header);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: ColorUtils.error600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        color: ColorUtils.error600,
                      ),
                    ),
                    title: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Delete Assessment',
                        'id': 'Hapus Penilaian',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.error600,
                      ),
                    ),
                    subtitle: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Delete all grades for this assessment',
                        'id': 'Hapus semua nilai penilaian ini',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.error600.withValues(alpha: 0.7),
                      ),
                    ),
                    onTap: () {
                      AppNavigator.pop(context);
                      _confirmDeleteAssessment(type, header, languageProvider);
                    },
                  ),
                ],
                SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatGradeValue(dynamic value) {
    if (value == null) return '';
    final double? numVal = double.tryParse(value.toString());
    if (numVal == null) return '';

    // Check if integer
    if (numVal % 1 == 0) {
      return numVal.toInt().toString();
    }

    return numVal.toString();
  }

  Map<String, dynamic>? _editHeader;

  /// Enters inline edit mode for a specific grade column.
  /// Like clicking "Edit" on a table cell in a Vue data table component.
  void _enterEditMode(String type, Map<String, dynamic> header) {
    setState(() {
      _isEditMode = true;
      _editGradeType = type;
      _editHeader = header;
      _editControllers.clear();
      _editFocusNodes.clear();

      // Initialize controllers for all students
      for (var student in _filteredStudentList) {
        final gradeData = _getGradeForStudentAndHeader(student, type, header);

        final scoreKey = "${student.id}_score";
        _editControllers[scoreKey] = TextEditingController(
          text: _formatGradeValue(gradeData?['nilai']),
        );
        _editFocusNodes[scoreKey] = FocusNode();
        _editFocusNodes[scoreKey]!.addListener(() {
          if (!_editFocusNodes[scoreKey]!.hasFocus) {
            _saveInlineGrade(
              student,
              type,
              header,
              'nilai',
              _editControllers[scoreKey]!.text,
            );
          }
        });

        // Deskripsi Controller
        final deskripsiKey = "${student.id}_deskripsi";
        _editControllers[deskripsiKey] = TextEditingController(
          text: gradeData?['deskripsi']?.toString() ?? '',
        );
        _editFocusNodes[deskripsiKey] = FocusNode();
        _editFocusNodes[deskripsiKey]!.addListener(() {
          if (!_editFocusNodes[deskripsiKey]!.hasFocus) {
            _saveInlineGrade(
              student,
              type,
              header,
              'deskripsi',
              _editControllers[deskripsiKey]!.text,
            );
          }
        });
      }
    });
  }

  /// Saves a single grade value to the API (inline edit).
  /// Like calling `axios.post('/api/grades')` after editing a cell.
  Future<void> _saveInlineGrade(
    Student student,
    String type,
    Map<String, dynamic> header,
    String field,
    String value, {
    bool reload = true,
  }) async {
    // Check if value changed
    final currentData = _getGradeForStudentAndHeader(student, type, header);
    final currentValue = currentData?[field]?.toString() ?? '';

    // If value is empty and was empty, do nothing
    if (value.isEmpty && currentValue.isEmpty) return;

    // If value hasn't changed, do nothing
    if (value == currentValue) return;

    try {
      final data = {
        'student_id': student.id,
        'student_class_id': student.studentClassId,
        'teacher_id': widget.teacher['id'],
        'subject_id': widget.subject['id'],
        'type': type,
        'date': header['date'],
        'title': header['title'],
        'assessment_id': header['id'], // Include assessment ID if exists
        'score': field == 'score'
            ? (value.isEmpty ? 0 : double.tryParse(value) ?? 0)
            : (currentData?['nilai'] ?? 0),
        'notes': field == 'deskripsi'
            ? value
            : (currentData?['deskripsi'] ?? ''),
      };

      if (currentData != null && currentData['id'] != null) {
        // Update
        await ApiService().put('/grades/${currentData['id']}', data);
      } else {
        // Create new only if we have a value
        if (value.isNotEmpty) {
          await ApiService().post('/grades', data);
        }
      }

      // Update local data in background
      if (reload) {
        _loadData(showLoading: false);
      }
    } catch (e) {
      AppLogger.error('grades', e);
      _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
    }
  }

  Widget _buildEditTable(LanguageProvider languageProvider) {
    final String date = _editHeader?['date'] ?? '';
    final String? title = _editHeader?['title'];
    final String displayTitle = title != null && title.isNotEmpty
        ? "$title (${_formatDateDisplay(date)})"
        : _formatDateDisplay(date);

    return Column(
      children: [
        // Edit Header
        Container(
          padding: EdgeInsets.all(AppSpacing.lg),
          color: ColorUtils.warning600.withValues(alpha: 0.08),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Edit Mode',
                      style: TextStyle(
                        color: ColorUtils.warning600,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "${_getGradeTypeLabel(_editGradeType!, languageProvider)} - $displayTitle",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: ColorUtils.slate800,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: () async {
                  // Show loading indicator
                  setState(() => _isLoading = true);

                  try {
                    // Iterate and save all
                    for (var student in _filteredStudentList) {
                      final scoreKey = "${student.id}_score";
                      final deskripsiKey = "${student.id}_deskripsi";

                      // Save Nilai
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

                      // Save Deskripsi
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

                    // Reload data once
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
                    _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
                  }
                },
                icon: Icon(Icons.check, size: 16),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Finish',
                    'id': 'Selesai',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimaryColor(),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: MediaQuery.of(context).size.width > 600
                    ? MediaQuery.of(context).size.width
                    : 600,
                child: Column(
                  children: [
                    // Header
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: ColorUtils.corporateBlue600.withValues(
                          alpha: 0.05,
                        ),
                        border: Border(
                          bottom: BorderSide(color: ColorUtils.slate200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 150,
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Name',
                                'id': 'Nama',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 100,
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            alignment: Alignment.center,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Grade',
                                'id': 'Nilai',
                              }),
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Description',
                                  'id': 'Deskripsi',
                                }),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Rows
                    ..._filteredStudentList.map((student) {
                      final scoreKey = "${student.id}_score";
                      final deskripsiKey = "${student.id}_deskripsi";

                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: ColorUtils.slate200),
                          ),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            // Name
                            Container(
                              width: 150,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: ColorUtils.slate900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    student.studentNumber,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: ColorUtils.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Nilai Input
                            Container(
                              width: 100,
                              padding: EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: ColorUtils.slate200),
                                  right: BorderSide(color: ColorUtils.slate200),
                                ),
                              ),
                              child: TextFormField(
                                controller: _editControllers[scoreKey],
                                focusNode: _editFocusNodes[scoreKey],
                                enabled: !_isReadOnly,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: ColorUtils.slate900),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  hintText: '-',
                                  hintStyle: TextStyle(
                                    color: ColorUtils.slate400,
                                  ),
                                ),
                                onFieldSubmitted: (value) {
                                  _saveInlineGrade(
                                    student,
                                    _editGradeType!,
                                    _editHeader!,
                                    'nilai',
                                    value,
                                  );
                                },
                              ),
                            ),
                            // Deskripsi Input
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: TextFormField(
                                  controller: _editControllers[deskripsiKey],
                                  focusNode: _editFocusNodes[deskripsiKey],
                                  enabled: !_isReadOnly,
                                  decoration: InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: languageProvider
                                        .getTranslatedText({
                                          'en': 'Add description...',
                                          'id': 'Tambah deskripsi...',
                                        }),
                                    hintStyle: TextStyle(
                                      color: ColorUtils.slate400,
                                      fontSize: 12,
                                    ),
                                  ),
                                  onFieldSubmitted: (value) {
                                    _saveInlineGrade(
                                      student,
                                      _editGradeType!,
                                      _editHeader!,
                                      'deskripsi',
                                      value,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateDisplay(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}/${parts[0]}";
      }
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }

  void _showAssessmentDetail(
    String type,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    final String date = header['date'];
    final String? title = header['title'];
    // Calculate stats
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

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getPrimaryColor(),
                    _getPrimaryColor().withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.assessment_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  SizedBox(width: AppSpacing.md),
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Assessment Details',
                      'id': 'Detail Penilaian',
                    }),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    languageProvider.getTranslatedText({
                      'en': 'Type',
                      'id': 'Jenis',
                    }),
                    _getGradeTypeLabel(type, languageProvider),
                  ),
                  _buildDetailRow(
                    languageProvider.getTranslatedText({
                      'en': 'Date',
                      'id': 'Tanggal',
                    }),
                    _formatDateDisplay(date),
                  ),
                  if (title != null && title.isNotEmpty)
                    _buildDetailRow(
                      languageProvider.getTranslatedText({
                        'en': 'Title',
                        'id': 'Judul',
                      }),
                      title,
                    ),
                  Divider(color: ColorUtils.slate200),
                  _buildDetailRow(
                    languageProvider.getTranslatedText({
                      'en': 'Total Students',
                      'id': 'Total Siswa',
                    }),
                    totalSiswa.toString(),
                  ),
                  _buildDetailRow(
                    languageProvider.getTranslatedText({
                      'en': 'Graded',
                      'id': 'Sudah Dinilai',
                    }),
                    "$gradedCount / $totalSiswa",
                  ),
                  _buildDetailRow(
                    languageProvider.getTranslatedText({
                      'en': 'Average Score',
                      'id': 'Rata-rata Nilai',
                    }),
                    average.toStringAsFixed(2),
                  ),
                ],
              ),
            ),
            // OK button
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => AppNavigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getPrimaryColor(),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ColorUtils.slate800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAssessment(
    String type,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    final String date = header['date'];
    final String? title = header['title'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Red gradient header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.error600,
                    ColorUtils.error600.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.white, size: 24),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Delete Assessment?',
                        'id': 'Hapus Penilaian?',
                      }),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text(
                languageProvider.getTranslatedText({
                  'en':
                      'Are you sure you want to delete all grades for ${_getGradeTypeLabel(type, languageProvider)} on ${_formatDateDisplay(date)}${title != null ? " ($title)" : ""}? This action cannot be undone.',
                  'id':
                      'Apakah Anda yakin ingin menghapus semua nilai ${_getGradeTypeLabel(type, languageProvider)} pada tanggal ${_formatDateDisplay(date)}${title != null ? " ($title)" : ""}? Tindakan ini tidak dapat dibatalkan.',
                }),
                style: TextStyle(color: ColorUtils.slate700, fontSize: 14),
              ),
            ),
            // Buttons
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Cancel',
                          'id': 'Batal',
                        }),
                        style: TextStyle(color: ColorUtils.slate600),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        AppNavigator.pop(context);
                        _deleteAssessment(type, header);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ColorUtils.error600,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Delete',
                          'id': 'Hapus',
                        }),
                        style: TextStyle(
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

  Future<void> _deleteAssessment(
    String type,
    Map<String, dynamic> header,
  ) async {
    setState(() => _isLoading = true);
    try {
      final apiService = ApiService();

      // If we have assessment_id, ideally we should delete by ID.
      // But keeping legacy implementation for now, using batch delete.
      // Providing title to query params if available.

      final queryParams = {
        'mata_pelajaran_id': widget.subject['id'],
        'jenis': type,
        'tanggal': header['date'],
      };

      if (header['title'] != null) {
        queryParams['title'] = header['title'];
      }

      // If we have assessment_id, maybe backend supports it?
      // Current backend only checks type and date in batch delete?
      // User requested Title addition, so assuming backend handles Title in batch delete.
      // If not, this might over-delete.
      // Note: Backend CreateGradeAction uses firstOrCreate.
      // If we delete, we should be specific.

      final queryString = Uri(queryParameters: queryParams).query;

      await apiService.delete('/grades/batch?$queryString');

      _showSuccessSnackBar('Assessment deleted successfully');
      _loadData(); // Reload to refresh the table
    } catch (e) {
      AppLogger.error('grades', e);
      setState(() => _isLoading = false);
      _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
    }
  }

  Future<void> _addNewAssessment(String type) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      final dateStr =
          "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

      setState(() {
        if (!_assessmentHeaders.containsKey(type)) {
          _assessmentHeaders[type] = [];
        }

        // Add a temporary header. Title is initially null.
        // It will be distinct from existing ones if they have titles.
        // But if there is an existing one with null title and same date,
        // we might just be pointing to that one.

        // Check if we already have a header with this date and (null) title
        final bool exists = _assessmentHeaders[type]!.any(
          (h) => h['date'] == dateStr && h['title'] == null,
        );

        if (!exists) {
          _assessmentHeaders[type]!.add({
            'id': null,
            'date': dateStr,
            'title': null,
            'is_temp': true,
          });

          // Sort
          _assessmentHeaders[type]!.sort((a, b) {
            final dateCompare = a['date'].compareTo(b['date']);
            if (dateCompare != 0) return dateCompare;
            return (a['title'] ?? '').compareTo(b['title'] ?? '');
          });
        }
      });
    }
  }

  Future<void> _exportGrades(LanguageProvider languageProvider) async {
    setState(() => _isLoading = true);
    try {
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id'];
      final endpoint =
          '/grades/export?class_id=${widget.classData['id']}&subject_id=${widget.subject['id']}&teacher_id=${widget.teacher['id']}&academic_year_id=$academicYearId';

      final bytes = await ApiService.downloadFile(endpoint);

      if (kIsWeb) {
        // Handle web download
        await FileSaver.instance.saveFile(
          name: 'grades_export_${DateTime.now().millisecond}',
          bytes: bytes,
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      } else {
        // Handle mobile download
        final directory = await getApplicationDocumentsDirectory();
        final file = File(
          '${directory.path}/grades_export_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        );
        await file.writeAsBytes(bytes);

        await OpenFile.open(file.path);
      }

      _showSuccessSnackBar(
        languageProvider.getTranslatedText({
          'en': 'Export successful',
          'id': 'Ekspor berhasil',
        }),
      );
    } catch (e) {
      AppLogger.error('grades', e);
      _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
    } finally {
      setState(() => _isLoading = false);
    }
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

  Widget _buildGradeTable(LanguageProvider languageProvider) {
    // Left side: Fixed names (120px)
    final leftSide = Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: ColorUtils.slate200, width: 2)),
      ),
      child: Column(
        children: [
          // Header Nama
          Container(
            height: 70,
            width: 120,
            padding: EdgeInsets.all(AppSpacing.md),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: _getPrimaryColor(),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
            ),
            child: Text(
              languageProvider.getTranslatedText({'en': 'Name', 'id': 'Nama'}),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ),
          // Student Names
          ..._filteredStudentList.map((student) {
            return Container(
              height: 60,
              width: 120,
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    student.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: ColorUtils.slate800,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${languageProvider.getTranslatedText({'en': 'NIS', 'id': 'NIS'})}: ${student.studentNumber}',
                    style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    // Right side items calculation
    double rightSideWidth = 0;
    for (var type in _filteredGradeTypeList) {
      final headers = _assessmentHeaders[type] ?? [];
      rightSideWidth +=
          (headers.length * 90.0) +
          (_canEdit && !_isReadOnly ? 65.0 : 0.0); // Increased spacer to 65
    }

    final rightSide = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _horizontalScrollController,
      child: SizedBox(
        width: rightSideWidth,
        child: Column(
          children: [
            // Right Header Row
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: _getPrimaryColor(),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: _filteredGradeTypeList.expand((type) {
                  final headers = _assessmentHeaders[type] ?? [];
                  final List<Widget> widgets = [];

                  // Existing columns headers
                  for (var header in headers) {
                    final String date = header['date'];
                    final String? title = header['title'];
                    final parts = date.split('-');
                    final displayDate = parts.length == 3
                        ? "${parts[2]}/${parts[1]}"
                        : date;

                    widgets.add(
                      InkWell(
                        onTap: () =>
                            _showColumnOptions(type, header, languageProvider),
                        child: Container(
                          width: 90,
                          padding: EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: ColorUtils.slate200),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                title != null && title.isNotEmpty
                                    ? title
                                    : _getGradeTypeLabel(
                                        type,
                                        languageProvider,
                                      ),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                displayDate,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  // Add button header
                  if (_canEdit && !_isReadOnly) {
                    widgets.add(
                      Container(
                        width: 65,
                        padding: EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: ColorUtils.slate300,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getGradeTypeLabel(type, languageProvider),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 2),
                            InkWell(
                              onTap: () => _addNewAssessment(type),
                              child: Icon(
                                Icons.add_circle_outline,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return widgets;
                }).toList(),
              ),
            ),
            // Right Side Rows (Values)
            ..._filteredStudentList.map((student) {
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate200),
                  ),
                ),
                child: Row(
                  children: _filteredGradeTypeList.expand((type) {
                    final headers = _assessmentHeaders[type] ?? [];
                    final List<Widget> widgets = [];

                    for (var header in headers) {
                      final gradeRecord = _getGradeForStudentAndHeader(
                        student,
                        type,
                        header,
                      );
                      final scoreText = gradeRecord?.isNotEmpty == true
                          ? _formatGradeValue(gradeRecord!['nilai'])
                          : '-';
                      final hasValue = gradeRecord?.isNotEmpty == true;

                      widgets.add(
                        Container(
                          width: 90,
                          padding: EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: ColorUtils.slate100),
                            ),
                          ),
                          child: GestureDetector(
                            onTap: (_canEdit && !_isReadOnly)
                                ? () => _openInputForm(
                                    student,
                                    type,
                                    languageProvider,
                                    header: header,
                                  )
                                : null,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: hasValue
                                    ? ColorUtils.success600.withValues(
                                        alpha: 0.08,
                                      )
                                    : ColorUtils.slate50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: hasValue
                                      ? ColorUtils.success600.withValues(
                                          alpha: 0.3,
                                        )
                                      : ColorUtils.slate200,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  scoreText,
                                  style: TextStyle(
                                    fontWeight: hasValue
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: hasValue
                                        ? ColorUtils.success600
                                        : ColorUtils.slate500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (_canEdit && !_isReadOnly) {
                      widgets.add(
                        Container(
                          width: 65,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: ColorUtils.slate200),
                            ),
                            color: ColorUtils.slate50.withValues(alpha: 0.3),
                          ),
                        ),
                      );
                    }

                    return widgets;
                  }).toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          leftSide,
          Expanded(child: rightSide),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final activeFilterCount = _gradeTypeFilter.values.where((v) => v).length;

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
              bottom: 16,
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
                  onTap: () {
                    if (widget.onBack != null) {
                      widget.onBack!();
                    } else {
                      AppNavigator.pop(context);
                    }
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Grade Book',
                          'id': 'Buku Nilai',
                        }),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${widget.subject['name'] ?? widget.subject['nama'] ?? ''} - ${widget.classData['name'] ?? widget.classData['nama'] ?? ''}',
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
                  onTap: () => _exportGrades(languageProvider),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.download, color: Colors.white, size: 20),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                // Filter button with badge
                Stack(
                  key: _filterKey,
                  children: [
                    GestureDetector(
                      onTap: () => _showFilterDialog(languageProvider),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.filter_list_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    if (activeFilterCount < _allGradeTypeList.length)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: ColorUtils.error600,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          constraints: BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '${_allGradeTypeList.length - activeFilterCount}',
                            style: TextStyle(
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
                SizedBox(width: AppSpacing.sm),
                // Refresh button
                GestureDetector(
                  onTap: _loadData,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.refresh, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(
                    padding: EdgeInsets.only(top: 8, bottom: 80),
                  )
                : _isEditMode
                ? _buildEditTable(languageProvider)
                : Column(
                    children: [
                      // Info bar (Pattern from spec)
                      Container(
                        margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.book_outlined,
                                color: _getPrimaryColor(),
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 10),
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
                        margin: EdgeInsets.fromLTRB(16, 10, 16, 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
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
                      SizedBox(height: AppSpacing.sm),

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
                                  borderRadius: BorderRadius.circular(16),
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
                                  child: _buildGradeTable(languageProvider),
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
}
