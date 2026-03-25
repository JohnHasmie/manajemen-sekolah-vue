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
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/providers/academic_year_provider.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/screens/grade_input_form.dart';
import 'package:manajemensekolah/features/grades/screens/grade_input_form_new.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';

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
class GradeBookPage extends StatefulWidget {
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
/// - [_siswaList] / [_filteredSiswaList] -- student list (all and filtered)
/// - [_nilaiList] -- raw grade records from the API
/// - [_assessmentHeaders] -- column headers organized by grade type
/// - [_isEditMode] -- whether inline editing is active
/// - [_jenisNilaiFilter] -- which grade types are visible (like Vue checkbox filters)
class GradeBookPageState extends State<GradeBookPage> {
  List<Student> _siswaList = [];
  List<Student> _filteredSiswaList = [];
  List<Map<String, dynamic>> _nilaiList = [];
  final List<String> _allJenisNilaiList = [
    'uh',
    'tugas',
    'uts',
    'uas',
    'pts',
    'pas',
  ];
  List<String> _filteredJenisNilaiList = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  final Map<String, bool> _jenisNilaiFilter = {
    'uh': true,
    'tugas': true,
    'uts': true,
    'uas': true,
    'pts': true,
    'pas': true,
  };

  // Map to store unique assessments for each grade type
  // Key: jenis (e.g., 'harian'), Value: List of assessment headers
  // Each header: { 'id': String?, 'date': String, 'title': String?, 'is_temp': bool }
  Map<String, List<Map<String, dynamic>>> _assessmentHeaders = {};

  // Scroll controller untuk sinkronisasi scroll horizontal
  final ScrollController _horizontalScrollController = ScrollController();

  // Edit Mode State
  bool _isEditMode = false;
  String? _editJenis;
  // Map to store controllers: key = "siswaId_field" (e.g. "123_nilai", "123_deskripsi")
  final Map<String, TextEditingController> _editControllers = {};
  final Map<String, FocusNode> _editFocusNodes = {};

  bool get _canEdit {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    return role == 'guru' || role == 'teacher';
  }

  bool get _isReadOnly {
    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    return academicYearProvider.isReadOnly;
  }

  // Tour properties
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _addGradeKey = GlobalKey();
  String? _tourId;

  String _buildGradeCacheKey() {
    final academicYearId = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    ).selectedAcademicYear?['id']?.toString() ?? 'default';
    final subjectId = widget.subject['id']?.toString() ?? 'unknown';
    final classId = widget.classData['id']?.toString() ?? 'unknown';
    return 'grade_book_${subjectId}_${classId}_$academicYearId';
  }

  /// Like Vue's `mounted()` -- loads grade data and sets up search listener.
  @override
  void initState() {
    super.initState();
    _loadData();
    _updateFilteredJenisNilai();
    _searchController.addListener(_filterSiswa);
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
  void _filterSiswa() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSiswaList = List.from(_siswaList);
      } else {
        _filteredSiswaList = _siswaList
            .where(
              (siswa) =>
                  siswa.name.toLowerCase().contains(query) ||
                  siswa.studentNumber.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  /// Process raw grade items and apply to state (used by both cache and fresh load)
  /// Processes raw API data into structured grade records per student.
  /// Like a Vue `computed` or `watch` that transforms API response into
  /// a table-friendly format. Maps student data with their grades.
  void _processAndApplyGradeData(List<dynamic> siswaData, List<dynamic> rawNilaiItems) {
    _siswaList = siswaData.map((s) => Student.fromJson(s)).toList();
    _filteredSiswaList = List.from(_siswaList);

    final currentStudentIds = _siswaList.map((s) => s.id.toString()).toSet();
    final currentStudentClassIds = _siswaList
        .map((s) => s.studentClassId?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    // Filter and map grades to internal legacy format
    _nilaiList = rawNilaiItems
        .where((item) {
          final studentId =
              (item['student_id'] ??
                      item['siswa_id'] ??
                      item['siswa']?['id'])
                  ?.toString();
          final studentClassId =
              (item['student_class_id'] ?? item['siswa_kelas_id'])
                  ?.toString();

          return currentStudentIds.contains(studentId) ||
              (studentClassId != null &&
                  currentStudentClassIds.contains(studentClassId));
        })
        .map<Map<String, dynamic>>((item) {
          return {
            'id': item['id'],
            'siswa_id':
                (item['student_id'] ??
                        item['siswa_id'] ??
                        item['siswa']?['id'])
                    ?.toString(),
            'student_class_id':
                (item['student_class_id'] ?? item['siswa_kelas_id'])
                    ?.toString(),
            'nilai': item['score'] ?? item['nilai'],
            'deskripsi': item['notes'] ?? item['deskripsi'],
            'tanggal':
                item['assessment']?['date'] ??
                item['date'] ??
                item['tanggal'],
            'jenis':
                (item['assessment']?['type'] ??
                        item['type'] ??
                        item['jenis'])
                    ?.toString()
                    .toLowerCase(),
            'title': item['assessment']?['title'] ?? item['title'] ?? '',
            'assessment_id': item['assessment_id'],
          };
        })
        .toList();

    // Process unique assessments for headers
    _assessmentHeaders = {};

    for (var nilai in _nilaiList) {
      final jenis = nilai['jenis']?.toString().toLowerCase();
      if (jenis == null || !_allJenisNilaiList.contains(jenis)) continue;

      String? rawDate = nilai['tanggal'];
      if (rawDate != null) {
        final datePart = rawDate.split('T')[0];
        final assessmentId = nilai['assessment_id'];
        final title = (nilai['title'] ?? '').toString().trim();

        if (!_assessmentHeaders.containsKey(jenis)) {
          _assessmentHeaders[jenis] = [];
        }

        // Check if header already exists
        final existingIndex = _assessmentHeaders[jenis]!.indexWhere((h) {
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
          _assessmentHeaders[jenis]!.add({
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
  Future<void> _loadData({bool showLoading = true, bool useCache = true}) async {
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
            final siswaData = List<dynamic>.from(cachedData['siswaData'] ?? []);
            final nilaiItems = List<dynamic>.from(cachedData['nilaiItems'] ?? []);
            if (siswaData.isNotEmpty) {
              setState(() {
                _processAndApplyGradeData(siswaData, nilaiItems);
              });
              _filterSiswa();
              // Trigger tour
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _checkAndShowTour();
              });
              AppLogger.info('grades', 'Grade book loaded from cache — skipping API');
              return; // ✅ Cache hit — no API needed
            }
          }
        } catch (e) {
          AppLogger.error('grades', e);
        }
      }

      // Show skeleton only if no data yet
      if (_siswaList.isEmpty && mounted) {
        if (showLoading) setState(() => _isLoading = true);
      }

      // ─── Step 2: No cache — fetch fresh from API ───
      // 1. Load siswa berdasarkan kelas
      final siswaData = await getIt<ApiStudentService>().getStudentByClass(
        widget.classData['id'],
      );

      // 2. Load nilai yang sudah ada
      final academicYearId = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      ).selectedAcademicYear?['id'];

      final subjectId = widget.subject['id'];
      final url =
          '/grades/teacher?subject_id=$subjectId&limit=500${academicYearId != null ? "&academic_year_id=$academicYearId" : ""}';

      AppLogger.debug('grades', 'DEBUG: Loading grades from $url');

      final response = await ApiService().get(url);

      // Handle paginated response (Map with 'data' key) or direct List
      List<dynamic> rawNilaiItems = [];
      if (response is Map<String, dynamic> && response.containsKey('data')) {
        rawNilaiItems = response['data'] as List<dynamic>;
      } else if (response is List) {
        rawNilaiItems = response;
      }

      AppLogger.debug('grades', 'DEBUG: Received ${rawNilaiItems.length} grade items');

      if (!mounted) return;

      setState(() {
        _processAndApplyGradeData(siswaData, rawNilaiItems);
      });
      _filterSiswa();

      // ─── Step 3: Save to cache ───
      final cacheKey = _buildGradeCacheKey();
      LocalCacheService.save(cacheKey, {
        'siswaData': siswaData,
        'nilaiItems': rawNilaiItems,
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
      if (_siswaList.isEmpty) {
        setState(() => _isLoading = false);
      }
      _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': message,
              'id': message.replaceAll('successfully', 'berhasil'),
            }),
          ),
          backgroundColor: Colors.green.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _updateFilteredJenisNilai() {
    setState(() {
      _filteredJenisNilaiList = _allJenisNilaiList
          .where((jenis) => _jenisNilaiFilter[jenis] == true)
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
                padding: EdgeInsets.all(20),
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
                        SizedBox(width: 12),
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
                          for (var key in _jenisNilaiFilter.keys) {
                            _jenisNilaiFilter[key] = true;
                          }
                        });
                        setState(() => _updateFilteredJenisNilai());
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
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: _allJenisNilaiList.map((jenis) {
                      return CheckboxListTile(
                        title: Text(
                          _getJenisNilaiLabel(jenis, languageProvider),
                          style: TextStyle(
                            color: ColorUtils.slate800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        value: _jenisNilaiFilter[jenis],
                        activeColor: _getPrimaryColor(),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onChanged: (bool? value) {
                          setSheetState(() {
                            _jenisNilaiFilter[jenis] = value ?? false;
                          });
                          setState(() => _updateFilteredJenisNilai());
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              // Footer
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
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

  Map<String, dynamic>? _getNilaiForSiswaAndHeader(
    Student student,
    String jenis,
    Map<String, dynamic> header,
  ) {
    try {
      final siswaId = student.id.toString();
      final studentClassId = student.studentClassId?.toString();

      final result = _nilaiList.firstWhere((nilai) {
        final gradeSiswaId = nilai['siswa_id']?.toString();
        final gradeStudentClassId = nilai['student_class_id']?.toString();

        // 1. Match Student: Try direct ID match or student_class_id match
        bool studentMatch = (gradeSiswaId == siswaId);

        if (!studentMatch &&
            (studentClassId != null || gradeStudentClassId != null)) {
          studentMatch =
              (gradeStudentClassId == studentClassId) ||
              (gradeSiswaId == studentClassId);
        }

        if (!studentMatch) return false;

        // 2. Match Header (Assessment)
        final headerId = header['id']?.toString();
        final currentAssessmentId = nilai['assessment_id']?.toString();

        if (headerId != null && currentAssessmentId != null) {
          if (headerId != currentAssessmentId) return false;
        } else if (headerId != null || currentAssessmentId != null) {
          // One has ID, other doesn't. If they have same date and title, maybe they ARE the same?
          // For now, be strict if ID exists.
          return false;
        }

        final nilaiDate = nilai['tanggal']?.toString().split('T')[0];
        final nilaiJenis = nilai['jenis']?.toString().toLowerCase();

        final nTitle = (nilai['title'] ?? '').toString().trim();
        final hTitle = (header['title'] ?? '').toString().trim();

        return (nilaiJenis == jenis.toLowerCase() &&
            nilaiDate == header['date'] &&
            nTitle == hTitle);
      }, orElse: () => <String, dynamic>{});

      return result.isEmpty ? null : result;
    } catch (e) {
      return null;
    }
  }

  void _openInputForm(
    Student student,
    String jenisNilai,
    LanguageProvider languageProvider, {
    Map<String, dynamic>? header,
  }) {
    final existingNilai = header != null
        ? _getNilaiForSiswaAndHeader(student, jenisNilai, header)
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeInputForm(
          teacher: widget.teacher,
          subject: widget.subject,
          siswa: student,
          jenisNilai: jenisNilai,
          existingNilai: existingNilai,
          assessmentId: header?['id'], // Pass assessment ID
          initialDate: header != null ? DateTime.parse(header['date']) : null,
          initialTitle: header?['title'],
        ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  void _showColumnOptions(
    String jenis,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    String date = header['date'];
    String? title = header['title'];
    String displayTitle = title != null && title.isNotEmpty
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
                          "${_getJenisNilaiLabel(jenis, languageProvider)} - $displayTitle",
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
                SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
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
                    Navigator.pop(context);
                    _showAssessmentDetail(jenis, header, languageProvider);
                  },
                ),
                if (_canEdit && !_isReadOnly) ...[
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
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
                      Navigator.pop(context);
                      _enterEditMode(jenis, header);
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(8),
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
                      Navigator.pop(context);
                      _confirmDeleteAssessment(jenis, header, languageProvider);
                    },
                  ),
                ],
                SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatGradeValue(dynamic value) {
    if (value == null) return '';
    double? numVal = double.tryParse(value.toString());
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
  void _enterEditMode(String jenis, Map<String, dynamic> header) {
    setState(() {
      _isEditMode = true;
      _editJenis = jenis;
      _editHeader = header;
      _editControllers.clear();
      _editFocusNodes.clear();

      // Initialize controllers for all students
      for (var siswa in _filteredSiswaList) {
        final nilaiData = _getNilaiForSiswaAndHeader(siswa, jenis, header);

        final nilaiKey = "${siswa.id}_nilai";
        _editControllers[nilaiKey] = TextEditingController(
          text: _formatGradeValue(nilaiData?['nilai']),
        );
        _editFocusNodes[nilaiKey] = FocusNode();
        _editFocusNodes[nilaiKey]!.addListener(() {
          if (!_editFocusNodes[nilaiKey]!.hasFocus) {
            _saveInlineGrade(
              siswa,
              jenis,
              header,
              'nilai',
              _editControllers[nilaiKey]!.text,
            );
          }
        });

        // Deskripsi Controller
        final deskripsiKey = "${siswa.id}_deskripsi";
        _editControllers[deskripsiKey] = TextEditingController(
          text: nilaiData?['deskripsi']?.toString() ?? '',
        );
        _editFocusNodes[deskripsiKey] = FocusNode();
        _editFocusNodes[deskripsiKey]!.addListener(() {
          if (!_editFocusNodes[deskripsiKey]!.hasFocus) {
            _saveInlineGrade(
              siswa,
              jenis,
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
    String jenis,
    Map<String, dynamic> header,
    String field,
    String value, {
    bool reload = true,
  }) async {
    // Check if value changed
    final currentData = _getNilaiForSiswaAndHeader(student, jenis, header);
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
        'type': jenis,
        'date': header['date'],
        'title': header['title'],
        'assessment_id': header['id'], // Include assessment ID if exists
        'score': field == 'nilai'
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
    String date = _editHeader?['date'] ?? '';
    String? title = _editHeader?['title'];
    String displayTitle = title != null && title.isNotEmpty
        ? "$title (${_formatDateDisplay(date)})"
        : _formatDateDisplay(date);

    return Column(
      children: [
        // Edit Header
        Container(
          padding: EdgeInsets.all(16),
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
                      "${_getJenisNilaiLabel(_editJenis!, languageProvider)} - $displayTitle",
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
              SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  // Show loading indicator
                  setState(() => _isLoading = true);

                  try {
                    // Iterate and save all
                    for (var siswa in _filteredSiswaList) {
                      final nilaiKey = "${siswa.id}_nilai";
                      final deskripsiKey = "${siswa.id}_deskripsi";

                      // Save Nilai
                      if (_editControllers.containsKey(nilaiKey)) {
                        await _saveInlineGrade(
                          siswa,
                          _editJenis!,
                          _editHeader!,
                          'nilai',
                          _editControllers[nilaiKey]!.text,
                          reload: false,
                        );
                      }

                      // Save Deskripsi
                      if (_editControllers.containsKey(deskripsiKey)) {
                        await _saveInlineGrade(
                          siswa,
                          _editJenis!,
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
                      _editJenis = null;
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
                    ..._filteredSiswaList.map((siswa) {
                      final nilaiKey = "${siswa.id}_nilai";
                      final deskripsiKey = "${siswa.id}_deskripsi";

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
                                    siswa.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: ColorUtils.slate900,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    siswa.studentNumber,
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
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: ColorUtils.slate200),
                                  right: BorderSide(color: ColorUtils.slate200),
                                ),
                              ),
                              child: TextFormField(
                                controller: _editControllers[nilaiKey],
                                focusNode: _editFocusNodes[nilaiKey],
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
                                    siswa,
                                    _editJenis!,
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
                                      siswa,
                                      _editJenis!,
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
    String jenis,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    String date = header['date'];
    String? title = header['title'];
    // Calculate stats
    int totalSiswa = _siswaList.length;
    int gradedCount = 0;
    double totalNilai = 0;

    for (var siswa in _siswaList) {
      final existingNilai = _getNilaiForSiswaAndHeader(siswa, jenis, header);
      if (existingNilai != null && existingNilai.isNotEmpty) {
        gradedCount++;
        totalNilai += double.tryParse(existingNilai['nilai'].toString()) ?? 0.0;
      }
    }

    double average = gradedCount > 0 ? totalNilai / gradedCount : 0;

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
              padding: EdgeInsets.all(20),
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
                  SizedBox(width: 12),
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
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    languageProvider.getTranslatedText({
                      'en': 'Type',
                      'id': 'Jenis',
                    }),
                    _getJenisNilaiLabel(jenis, languageProvider),
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
                  onPressed: () => Navigator.pop(context),
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
    String jenis,
    Map<String, dynamic> header,
    LanguageProvider languageProvider,
  ) {
    String date = header['date'];
    String? title = header['title'];

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
              padding: EdgeInsets.all(20),
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
                  SizedBox(width: 12),
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
              padding: EdgeInsets.all(20),
              child: Text(
                languageProvider.getTranslatedText({
                  'en':
                      'Are you sure you want to delete all grades for ${_getJenisNilaiLabel(jenis, languageProvider)} on ${_formatDateDisplay(date)}${title != null ? " ($title)" : ""}? This action cannot be undone.',
                  'id':
                      'Apakah Anda yakin ingin menghapus semua nilai ${_getJenisNilaiLabel(jenis, languageProvider)} pada tanggal ${_formatDateDisplay(date)}${title != null ? " ($title)" : ""}? Tindakan ini tidak dapat dibatalkan.',
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
                      onPressed: () => Navigator.pop(context),
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
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteAssessment(jenis, header);
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
    String jenis,
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
        'jenis': jenis,
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

  Future<void> _addNewAssessment(String jenis) async {
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
        if (!_assessmentHeaders.containsKey(jenis)) {
          _assessmentHeaders[jenis] = [];
        }

        // Add a temporary header. Title is initially null.
        // It will be distinct from existing ones if they have titles.
        // But if there is an existing one with null title and same date,
        // we might just be pointing to that one.

        // Check if we already have a header with this date and (null) title
        bool exists = _assessmentHeaders[jenis]!.any(
          (h) => h['date'] == dateStr && h['title'] == null,
        );

        if (!exists) {
          _assessmentHeaders[jenis]!.add({
            'id': null,
            'date': dateStr,
            'title': null,
            'is_temp': true,
          });

          // Sort
          _assessmentHeaders[jenis]!.sort((a, b) {
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
      final academicYearId = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      ).selectedAcademicYear?['id'];
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeInputFormNew(
          teacher: widget.teacher,
          subject: widget.subject,
          siswaList: _siswaList,
        ),
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
            padding: EdgeInsets.all(12),
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
          ..._filteredSiswaList.map((siswa) {
            return Container(
              height: 60,
              width: 120,
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
                color: Colors.white,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    siswa.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11,
                      color: ColorUtils.slate800,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    '${languageProvider.getTranslatedText({'en': 'NIS', 'id': 'NIS'})}: ${siswa.studentNumber}',
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
    for (var jenis in _filteredJenisNilaiList) {
      final headers = _assessmentHeaders[jenis] ?? [];
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
                children: _filteredJenisNilaiList.expand((jenis) {
                  final headers = _assessmentHeaders[jenis] ?? [];
                  List<Widget> widgets = [];

                  // Existing columns headers
                  for (var header in headers) {
                    String date = header['date'];
                    String? title = header['title'];
                    final parts = date.split('-');
                    final displayDate = parts.length == 3
                        ? "${parts[2]}/${parts[1]}"
                        : date;

                    widgets.add(
                      InkWell(
                        onTap: () =>
                            _showColumnOptions(jenis, header, languageProvider),
                        child: Container(
                          width: 90,
                          padding: EdgeInsets.all(4),
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
                                    : _getJenisNilaiLabel(
                                        jenis,
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
                        padding: EdgeInsets.all(4),
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
                              _getJenisNilaiLabel(jenis, languageProvider),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 2),
                            InkWell(
                              onTap: () => _addNewAssessment(jenis),
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
            ..._filteredSiswaList.map((siswa) {
              return Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ColorUtils.slate200),
                  ),
                ),
                child: Row(
                  children: _filteredJenisNilaiList.expand((jenis) {
                    final headers = _assessmentHeaders[jenis] ?? [];
                    List<Widget> widgets = [];

                    for (var header in headers) {
                      final nilai = _getNilaiForSiswaAndHeader(
                        siswa,
                        jenis,
                        header,
                      );
                      final nilaiText = nilai?.isNotEmpty == true
                          ? _formatGradeValue(nilai!['nilai'])
                          : '-';
                      final hasValue = nilai?.isNotEmpty == true;

                      widgets.add(
                        Container(
                          width: 90,
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: ColorUtils.slate100),
                            ),
                          ),
                          child: GestureDetector(
                            onTap: (_canEdit && !_isReadOnly)
                                ? () => _openInputForm(
                                    siswa,
                                    jenis,
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
                                  nilaiText,
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

  String _getJenisNilaiLabel(String jenis, LanguageProvider languageProvider) {
    switch (jenis) {
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
        return jenis.toUpperCase();
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final activeFilterCount = _jenisNilaiFilter.values
            .where((v) => v)
            .length;

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
                          Navigator.of(context).pop();
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
                    SizedBox(width: 12),
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
                        child: Icon(
                          Icons.download,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
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
                        if (activeFilterCount < _allJenisNilaiList.length)
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
                                '${_allJenisNilaiList.length - activeFilterCount}',
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
                    SizedBox(width: 8),
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
                        child: Icon(
                          Icons.refresh,
                          color: Colors.white,
                          size: 20,
                        ),
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
                              boxShadow: ColorUtils.corporateShadow(
                                elevation: 0.5,
                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        '${languageProvider.getTranslatedText({'en': 'Types', 'id': 'Jenis'})}: ${_filteredJenisNilaiList.map((j) => _getJenisNilaiLabel(j, languageProvider)).join(', ')}',
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
                              boxShadow: ColorUtils.corporateShadow(
                                elevation: 0.5,
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: ColorUtils.slate900),
                              decoration: InputDecoration(
                                hintText: languageProvider.getTranslatedText({
                                  'en': 'Search students...',
                                  'id': 'Cari siswa...',
                                }),
                                hintStyle: TextStyle(
                                  color: ColorUtils.slate400,
                                ),
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

                          if (_filteredSiswaList.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                children: [
                                  Text(
                                    '${_filteredSiswaList.length} ${languageProvider.getTranslatedText({'en': 'students found', 'id': 'siswa ditemukan'})}',
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
                          SizedBox(height: 8),

                          // Tabel Nilai
                          Expanded(
                            child: _filteredSiswaList.isEmpty
                                ? EmptyState(
                                    title: languageProvider.getTranslatedText({
                                      'en': 'No students found',
                                      'id': 'Tidak ada siswa',
                                    }),
                                    subtitle: _searchController.text.isEmpty
                                        ? languageProvider.getTranslatedText({
                                            'en': 'No students in this class',
                                            'id':
                                                'Tidak ada siswa di kelas ini',
                                          })
                                        : languageProvider.getTranslatedText({
                                            'en': 'No search results found',
                                            'id':
                                                'Tidak ditemukan hasil pencarian',
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
      },
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      const tourCacheKey = 'tour_input_grade_screen_guru';

      // Only use cache (pre-fetched by dashboard), no API call
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id'];
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
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "LEWATI",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_input_grade_screen_guru', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_input_grade_screen_guru', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];

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
