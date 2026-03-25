// Admin presence/attendance report screen.
//
// Like `pages/admin/attendance-report.vue` - displays attendance summaries
// across classes, subjects, and dates. Supports both list view and table view,
// with filters by date range, subject, class, day, and lesson hour.
// Can export reports to Excel.
//
// In Laravel terms, this consumes AttendanceController with complex query filters,
// similar to `Attendance::with(['student','subject'])->filter(...)->paginate()`.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/attendance/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/classrooms/services/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/schedule/services/schedule_service.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/features/teachers/services/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/attendance/exports/attendance_export_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Data model for a single attendance summary record.
/// Like a Laravel Eloquent model or a TypeScript interface in Vue.
/// Represents aggregated attendance data for one subject/class/date combination.
class AttendanceSummary {
  final String subjectId;
  final String subjectName;
  final DateTime date;
  final int totalStudents;
  final int present;
  final int absent;
  final String classId;
  final String className;
  final String? lessonHourId;
  final String? lessonHourName;
  final String? academicYearId;

  AttendanceSummary({
    required this.subjectId,
    required this.subjectName,
    required this.date,
    required this.totalStudents,
    required this.present,
    required this.absent,
    required this.classId,
    required this.className,
    this.lessonHourId,
    this.lessonHourName,
    this.academicYearId,
  });

  String get key =>
      '$subjectId-$classId-${DateFormat('yyyy-MM-dd').format(date)}-$lessonHourId';
}

/// Admin attendance report screen with list and table views, multi-filter support.
///
/// This is a [StatefulWidget] - like a Vue page with extensive local state
/// for filters, pagination, and two view modes (list vs table/grid).
class AdminPresenceReportScreen extends StatefulWidget {
  const AdminPresenceReportScreen({super.key});

  @override
  State<AdminPresenceReportScreen> createState() =>
      _AdminPresenceReportScreenState();
}

/// Mutable state for [AdminPresenceReportScreen].
///
/// Key state (like Vue `data()`):
/// - [_absensiSummaryList] - attendance summary records from API
/// - [_showTableView] - toggles between card list and Syncfusion data grid
/// - [_selectedSubjectIds] / [_selectedClassIds] / [_selectedDayIds] - multi-select filters
/// - [_selectedDateFilter] - date range filter ('today', 'week', 'month')
/// - [_studentList] / [_attendanceMap] - raw student attendance data for table view
///
/// setState() is like Vue's reactivity - triggers a re-render when data changes.
class _AdminPresenceReportScreenState extends State<AdminPresenceReportScreen> {
  // Data untuk mode View Results
  List<AttendanceSummary> _absensiSummaryList = [];
  bool _isLoadingSummary = false;

  // Pagination State
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Table View State
  bool _showTableView = false;
  final List<dynamic> _studentList = [];
  final Map<String, dynamic> _attendanceMap =
      {}; // Key: studentId-date -> [subjects]
  AttendanceDataSource? _attendanceDataSource;
  final List<String> _uniqueDates = [];
  final List<String> _uniqueSubjectIds = [];
  final Map<String, String> _dateLabels = {}; // date -> label (1, 2, 3...)
  bool _isTableLoading = false;

  // Search dan Filter
  final TextEditingController _searchController = TextEditingController();

  // Filter States
  String?
  _selectedDateFilter; // 'today', 'week', 'month', atau null untuk semua
  final List<String> _selectedSubjectIds = [];
  final List<String> _selectedClassIds = [];
  final List<String> _selectedDayIds = [];
  final List<String> _selectedLessonHourIds = [];
  bool _hasActiveFilter = false;
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _moreKey = GlobalKey();
  final GlobalKey _infoKey = GlobalKey();
  String? _tourId;
  bool _isTourShowing = false;

  // Data for filters
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _lessonHours = [];
  Map<String, dynamic>? _selectedClassData;
  bool _isLoadingClasses = true;
  List<dynamic> _fullTeacherList = [];

  /// Like Vue's `mounted()` - sets up scroll listener and loads filter data.
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFilterData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreData();
    }
  }

  String? _buildFilterDataCacheKey() {
    final yearId = context
        .read<AcademicYearProvider>()
        .selectedAcademicYear?['id']
        ?.toString() ?? 'default';
    return 'presence_filter_data_$yearId';
  }

  String? _buildSummaryCacheKey() {
    if (_currentPage != 1) return null;
    if (_selectedDateFilter != null ||
        _selectedSubjectIds.isNotEmpty ||
        _selectedClassIds.isNotEmpty ||
        _selectedDayIds.isNotEmpty ||
        _selectedLessonHourIds.isNotEmpty ||
        _searchController.text.trim().isNotEmpty ||
        _showTableView) {
      return null;
    }
    final yearId = context
        .read<AcademicYearProvider>()
        .selectedAcademicYear?['id']
        ?.toString() ?? 'default';
    return 'presence_summary_$yearId';
  }

  Future<void> _forceRefresh() async {
    final filterKey = _buildFilterDataCacheKey();
    if (filterKey != null) await LocalCacheService.invalidate(filterKey);
    final summaryKey = _buildSummaryCacheKey();
    if (summaryKey != null) await LocalCacheService.invalidate(summaryKey);
    await LocalCacheService.clearStartingWith('tour_presence_report_');
    if (_selectedClassData == null) {
      _loadFilterData(useCache: false);
    } else {
      _loadData(useCache: false);
    }
  }

  Future<void> _loadFilterData({bool useCache = true}) async {
    // Step 1: Try cache for instant display
    if (useCache) {
      final cacheKey = _buildFilterDataCacheKey();
      if (cacheKey != null) {
        final cached = await LocalCacheService.load(cacheKey);
        if (cached != null && mounted) {
          final cachedSubjects = cached['subjects'] as List<dynamic>? ?? [];
          final cachedClasses = cached['classes'] as List<dynamic>? ?? [];
          final cachedTeachers = cached['teachers'] as List<dynamic>? ?? [];
          final cachedLessonHours = cached['lessonHours'] as List<dynamic>? ?? [];
          if (cachedSubjects.isNotEmpty || cachedClasses.isNotEmpty) {
            setState(() {
              _subjectList = cachedSubjects;
              _classList = cachedClasses;
              _fullTeacherList = cachedTeachers;
              _lessonHours = cachedLessonHours;
              _isLoadingClasses = false;
            });
            AppLogger.info('attendance', 'Filter data loaded from cache');
            // Trigger tour from cache path
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _checkAndShowTour();
            });
            return;
          }
        }
      }
    }

    // Show loading only if data is empty
    if (_classList.isEmpty && mounted) {
      setState(() => _isLoadingClasses = true);
    }

    // Step 2: Fetch fresh from API
    List<dynamic> subjects = [];
    List<dynamic> classes = [];

    try {
      final results = await Future.wait([
        ApiSubjectService()
            .getSubject()
            .then((value) {
              AppLogger.info('attendance', 'Subjects loaded: ${value.length}');
              return value;
            })
            .catchError((e) {
              AppLogger.error('attendance', 'Error loading subjects: $e');
              return [];
            }),
        getIt<ApiClassService>().getClass(
              academicYearId: context
                  .read<AcademicYearProvider>()
                  .selectedAcademicYear?['id']
                  ?.toString(),
            )
            .then((value) {
              AppLogger.info('attendance', 'Classes loaded: ${value.length}');
              return value;
            })
            .catchError((e) {
              AppLogger.error('attendance', 'Error loading classes: $e');
              return [];
            }),
        ApiTeacherService().getTeacher().catchError((e) {
          AppLogger.error('attendance', 'Error loading teachers: $e');
          return [];
        }),
        ApiScheduleService.getJamPelajaran().catchError((e) {
          AppLogger.error('attendance', 'Error loading lesson hours: $e');
          return [];
        }),
      ]);

      subjects = results[0];
      classes = results[1];
      final teachers = results[2];
      final lessonHours = results[3];

      if (mounted) {
        setState(() {
          _subjectList = subjects;
          _classList = classes;
          _fullTeacherList = teachers;
          _lessonHours = lessonHours;
        });
      }

      // Step 3: Save to cache (non-blocking)
      final cacheKey = _buildFilterDataCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'subjects': subjects,
          'classes': classes,
          'teachers': teachers,
          'lessonHours': lessonHours,
        });
      }
    } catch (e) {
      AppLogger.error('attendance', 'Error loading filter data (critical): $e');
      if (mounted && _classList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat data filter: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingClasses = false);
        // Trigger tour
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkAndShowTour();
          }
        });
      }
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedDateFilter != null ||
          _selectedSubjectIds.isNotEmpty ||
          _selectedClassIds.isNotEmpty ||
          _selectedDayIds.isNotEmpty ||
          _selectedLessonHourIds.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDateFilter = null;
      _selectedSubjectIds.clear();
      _selectedClassIds.clear();
      _selectedDayIds.clear();
      _selectedLessonHourIds.clear();
      _hasActiveFilter = false;
    });
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedDateFilter != null) {
      final label = _selectedDateFilter == 'today'
          ? languageProvider.getTranslatedText({
              'en': 'Today',
              'id': 'Hari Ini',
            })
          : _selectedDateFilter == 'week'
          ? languageProvider.getTranslatedText({
              'en': 'This Week',
              'id': 'Minggu Ini',
            })
          : languageProvider.getTranslatedText({
              'en': 'This Month',
              'id': 'Bulan Ini',
            });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Date', 'id': 'Tanggal'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedDateFilter = null;
          });
          _checkActiveFilter();
          _loadData();
        },
      });
    }

    // Show individual chips for each selected subject
    if (_selectedSubjectIds.isNotEmpty) {
      for (var subjectId in _selectedSubjectIds) {
        final subject = _subjectList.firstWhere(
          (s) => s['id'].toString() == subjectId,
          orElse: () => {'nama': 'Subject #$subjectId'},
        );
        filterChips.add({
          'label':
              '${languageProvider.getTranslatedText({'en': 'Subject', 'id': 'Mapel'})}: ${subject['name']}',
          'onRemove': () {
            setState(() {
              _selectedSubjectIds.remove(subjectId);
            });
            _checkActiveFilter();
            _loadData();
          },
        });
      }
    }

    // Show individual chips for each selected class
    if (_selectedClassIds.isNotEmpty) {
      for (var classId in _selectedClassIds) {
        final kelas = _classList.firstWhere(
          (k) => k['id'].toString() == classId,
          orElse: () => {'name': 'Class #$classId'},
        );
        filterChips.add({
          'label':
              '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: ${kelas['name'] ?? kelas['nama']}',
          'onRemove': () {
            setState(() {
              _selectedClassIds.remove(classId);
            });
            _checkActiveFilter();
            _loadData();
          },
        });
      }
    }

    if (_selectedDayIds.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Day', 'id': 'Hari'})}: ${_selectedDayIds.length}',
        'onRemove': () {
          setState(() {
            _selectedDayIds.clear();
            _checkActiveFilter();
            _loadData();
          });
        },
      });
    }

    if (_selectedLessonHourIds.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Hour', 'id': 'Jam'})}: ${_selectedLessonHourIds.length}',
        'onRemove': () {
          setState(() {
            _selectedLessonHourIds.clear();
            _checkActiveFilter();
            _loadData();
          });
        },
      });
    }

    return filterChips;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool useCache = true}) async {
    if (!mounted) return;

    _currentPage = 1;
    _hasMoreData = true;

    // Step 1: Try cache for instant display
    if (useCache) {
      final cacheKey = _buildSummaryCacheKey();
      if (cacheKey != null) {
        final cached = await LocalCacheService.load(cacheKey);
        if (cached != null && cached['data'] != null && mounted) {
          final cachedList = cached['data'] as List<dynamic>;
          if (cachedList.isNotEmpty) {
            final cachedItems = cachedList.map((item) {
              return AttendanceSummary(
                subjectId: item['subjectId']?.toString() ?? '',
                subjectName: item['subjectName'] ?? 'Unknown',
                date: DateTime.tryParse(item['date'] ?? '') ?? DateTime.now(),
                totalStudents: item['totalStudents'] ?? 0,
                present: item['present'] ?? 0,
                absent: item['absent'] ?? 0,
                classId: item['classId']?.toString() ?? '',
                className: item['className'] ?? 'Unknown',
                lessonHourId: item['lessonHourId'],
                lessonHourName: item['lessonHourName'],
                academicYearId: item['academicYearId'],
              );
            }).toList();
            setState(() {
              _absensiSummaryList = cachedItems;
              _hasMoreData = cached['hasMoreData'] ?? false;
              _isLoadingSummary = false;
            });
            AppLogger.info('attendance', 'Summary data loaded from cache');
            return;
          }
        }
      }
    }

    // Show skeleton only if list is empty
    if (_absensiSummaryList.isEmpty && mounted) {
      setState(() {
        _isLoadingSummary = true;
      });
    }

    // Step 2: Fetch fresh from API
    await _fetchData();

    // Step 3: Save to cache (only default view, page 1, non-blocking)
    if (mounted) {
      final cacheKey = _buildSummaryCacheKey();
      if (cacheKey != null && _absensiSummaryList.isNotEmpty) {
        final serialized = _absensiSummaryList.map((item) => {
          'subjectId': item.subjectId,
          'subjectName': item.subjectName,
          'date': item.date.toIso8601String(),
          'totalStudents': item.totalStudents,
          'present': item.present,
          'absent': item.absent,
          'classId': item.classId,
          'className': item.className,
          'lessonHourId': item.lessonHourId,
          'lessonHourName': item.lessonHourName,
          'academicYearId': item.academicYearId,
        }).toList();
        LocalCacheService.save(cacheKey, {
          'data': serialized,
          'hasMoreData': _hasMoreData,
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (!mounted || _isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Prepare filter parameters
      String? tanggal;
      String? tanggalStart;
      String? tanggalEnd;

      if (_selectedDateFilter == 'today') {
        tanggal = DateFormat('yyyy-MM-dd').format(DateTime.now());
      } else if (_selectedDateFilter == 'week') {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6));
        tanggalStart = DateFormat('yyyy-MM-dd').format(startOfWeek);
        tanggalEnd = DateFormat('yyyy-MM-dd').format(endOfWeek);
      } else if (_selectedDateFilter == 'month') {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        tanggalStart = DateFormat('yyyy-MM-dd').format(startOfMonth);
        tanggalEnd = DateFormat('yyyy-MM-dd').format(endOfMonth);
      }

      final academicYearId = context
          .read<AcademicYearProvider>()
          .selectedAcademicYear?['id']
          ?.toString();

      // Call paginated API
      final result = await ApiService.getAttendanceSummaryPaginated(
        page: _currentPage,
        limit: _perPage,
        subjectId: _selectedSubjectIds.isNotEmpty
            ? _selectedSubjectIds.first
            : null,
        classId: _selectedClassIds.isNotEmpty ? _selectedClassIds.first : null,
        tanggal: tanggal,
        tanggalStart: tanggalStart,
        tanggalEnd: tanggalEnd,
        academicYearId: academicYearId,
        dayIds: _selectedDayIds,
        lessonHourIds: _selectedLessonHourIds,
      );

      if (!mounted) return;

      final List<dynamic> data = result['data'] ?? [];
      final Map<String, dynamic> pagination = result['pagination'] ?? {};

      final List<AttendanceSummary> newItems = data.map((item) {
        final lessonHourId = item['lesson_hour_id']?.toString();
        String? lessonHourName;
        if (lessonHourId != null && lessonHourId.isNotEmpty) {
          final lh = _lessonHours.firstWhere(
            (h) => h['id']?.toString() == lessonHourId,
            orElse: () => null,
          );
          if (lh != null) {
            lessonHourName = lh['name'];
          }
        }

        return AttendanceSummary(
          subjectId: item['subject_id']?.toString() ?? '',
          subjectName: item['subject_name'] ?? 'Unknown',
          date: AppDateUtils.parseApiDate(item['date']) ?? DateTime.now(),
          totalStudents:
              int.tryParse(item['total_students']?.toString() ?? '0') ?? 0,
          present: int.tryParse(item['present']?.toString() ?? '0') ?? 0,
          absent: int.tryParse(item['absent']?.toString() ?? '0') ?? 0,
          classId: item['class_id']?.toString() ?? '',
          className: item['class_name'] ?? 'Unknown',
          lessonHourId: lessonHourId,
          lessonHourName: lessonHourName,
          academicYearId: academicYearId,
        );
      }).toList();

      setState(() {
        if (_currentPage == 1) {
          _absensiSummaryList = newItems;
        } else {
          _absensiSummaryList.addAll(newItems);
        }

        _hasMoreData = pagination['has_next_page'] ?? false;
        if (_hasMoreData) {
          _currentPage++;
        }

        _isLoadingSummary = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading absensi summary: $e');
      if (mounted) {
        setState(() {
          _isLoadingSummary = false;
          _isLoadingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal memuat data laporan: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.85)],
    );
  }

  void _showTeacherSelectionDialog() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: ColorUtils.slate200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Select Teacher',
                      'id': 'Pilih Guru',
                    }),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _fullTeacherList.length,
                itemBuilder: (context, index) {
                  final teacher = _fullTeacherList[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getPrimaryColor().withValues(
                          alpha: 0.1,
                        ),
                        child: Text(
                          (teacher['name'] ?? 'G')[0].toUpperCase(),
                          style: TextStyle(color: _getPrimaryColor()),
                        ),
                      ),
                      title: Text(
                        teacher['name'] ?? 'Unknown',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(teacher['nuptk'] ?? 'N/A'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PresencePage(teacher: teacher),
                          ),
                        ).then((_) => _loadData(useCache: false));
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    String? tempSelectedDate = _selectedDateFilter;
    List<String> tempSelectedSubjects = List.from(_selectedSubjectIds);
    List<String> tempSelectedClasses = List.from(_selectedClassIds);
    List<String> tempSelectedDays = List.from(_selectedDayIds);
    List<String> tempSelectedLessonHours = List.from(_selectedLessonHourIds);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getPrimaryColor(),
                      _getPrimaryColor().withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: Colors.white, size: 22),
                        SizedBox(width: 10),
                        Text(
                          languageProvider.getTranslatedText({
                            'en': 'Filter',
                            'id': 'Filter',
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
                        setModalState(() {
                          tempSelectedDate = null;
                          tempSelectedSubjects.clear();
                          tempSelectedClasses.clear();
                          tempSelectedDays.clear();
                          tempSelectedLessonHours.clear();
                        });
                      },
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Reset',
                          'id': 'Reset',
                        }),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Filter Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date Filter
                      Row(
                        children: [
                          Icon(
                            Icons.date_range,
                            size: 16,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Date Range',
                              'id': 'Rentang Tanggal',
                            }),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['today', 'week', 'month'].map((period) {
                          final isSelected = tempSelectedDate == period;
                          final label = period == 'today'
                              ? languageProvider.getTranslatedText({
                                  'en': 'Today',
                                  'id': 'Hari Ini',
                                })
                              : period == 'week'
                              ? languageProvider.getTranslatedText({
                                  'en': 'This Week',
                                  'id': 'Minggu Ini',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'This Month',
                                  'id': 'Bulan Ini',
                                });
                          return FilterChip(
                            label: Text(label),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                tempSelectedDate = selected ? period : null;
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: _getPrimaryColor().withValues(
                              alpha: 0.2,
                            ),
                            checkmarkColor: _getPrimaryColor(),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getPrimaryColor()
                                  : ColorUtils.slate600,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 24),

                      // Subject Filter
                      Row(
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 16,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Subject',
                              'id': 'Mata Pelajaran',
                            }),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _subjectList.map<Widget>((subject) {
                          final subjectId = subject['id'].toString();
                          final subjectName = subject['name'] ?? 'Subject';
                          final isSelected = tempSelectedSubjects.contains(
                            subjectId,
                          );
                          return FilterChip(
                            label: Text(subjectName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempSelectedSubjects.add(subjectId);
                                } else {
                                  tempSelectedSubjects.remove(subjectId);
                                }
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: _getPrimaryColor().withValues(
                              alpha: 0.2,
                            ),
                            checkmarkColor: _getPrimaryColor(),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getPrimaryColor()
                                  : ColorUtils.slate600,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 24),

                      // Day Filter
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Day',
                              'id': 'Hari',
                            }),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              {'en': 'Monday', 'id': 'Senin', 'val': '1'},
                              {'en': 'Tuesday', 'id': 'Selasa', 'val': '2'},
                              {'en': 'Wednesday', 'id': 'Rabu', 'val': '3'},
                              {'en': 'Thursday', 'id': 'Kamis', 'val': '4'},
                              {'en': 'Friday', 'id': 'Jumat', 'val': '5'},
                              {'en': 'Saturday', 'id': 'Sabtu', 'val': '6'},
                              {'en': 'Sunday', 'id': 'Minggu', 'val': '7'},
                            ].map<Widget>((d) {
                              final val = d['val']!;
                              final label = languageProvider.getTranslatedText({
                                'en': d['en']!,
                                'id': d['id']!,
                              });
                              final isSelected = tempSelectedDays.contains(val);
                              return FilterChip(
                                label: Text(label),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setModalState(() {
                                    if (selected) {
                                      tempSelectedDays.add(val);
                                    } else {
                                      tempSelectedDays.remove(val);
                                    }
                                  });
                                },
                                backgroundColor: Colors.white,
                                selectedColor: _getPrimaryColor().withValues(
                                  alpha: 0.2,
                                ),
                                checkmarkColor: _getPrimaryColor(),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? _getPrimaryColor()
                                      : ColorUtils.slate600,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                      ),
                      SizedBox(height: 24),

                      // Lesson Hour Filter
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: 16,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Lesson Hour',
                              'id': 'Jam Pelajaran',
                            }),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _lessonHours.map<Widget>((lh) {
                          final lhId = lh['id'].toString();
                          final lhName = lh['name'] ?? 'Jam';
                          final isSelected = tempSelectedLessonHours.contains(
                            lhId,
                          );
                          return FilterChip(
                            label: Text(lhName),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempSelectedLessonHours.add(lhId);
                                } else {
                                  tempSelectedLessonHours.remove(lhId);
                                }
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: _getPrimaryColor().withValues(
                              alpha: 0.2,
                            ),
                            checkmarkColor: _getPrimaryColor(),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getPrimaryColor()
                                  : ColorUtils.slate600,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 24),

                      // Class Filter
                      Row(
                        children: [
                          Icon(
                            Icons.class_outlined,
                            size: 16,
                            color: ColorUtils.slate700,
                          ),
                          SizedBox(width: 8),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Class',
                              'id': 'Kelas',
                            }),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _classList.map<Widget>((classItem) {
                          final classId = classItem['id'].toString();
                          final className = classItem['name'] ?? 'Class';
                          final isSelected = tempSelectedClasses.contains(
                            classId,
                          );
                          return FilterChip(
                            label: Text(className),
                            selected: isSelected,
                            onSelected: (selected) {
                              setModalState(() {
                                if (selected) {
                                  tempSelectedClasses.add(classId);
                                } else {
                                  tempSelectedClasses.remove(classId);
                                }
                              });
                            },
                            backgroundColor: Colors.white,
                            selectedColor: _getPrimaryColor().withValues(
                              alpha: 0.2,
                            ),
                            checkmarkColor: _getPrimaryColor(),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? _getPrimaryColor()
                                  : ColorUtils.slate600,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              // Apply Button
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: ColorUtils.slate200)),
                  boxShadow: [
                    BoxShadow(
                      color: ColorUtils.slate900.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
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
                          style: TextStyle(color: ColorUtils.slate700),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _selectedDateFilter = tempSelectedDate;
                            _selectedSubjectIds.clear();
                            _selectedSubjectIds.addAll(tempSelectedSubjects);
                            _selectedClassIds.clear();
                            _selectedClassIds.addAll(tempSelectedClasses);
                            _selectedDayIds.clear();
                            _selectedDayIds.addAll(tempSelectedDays);
                            _selectedLessonHourIds.clear();
                            _selectedLessonHourIds.addAll(
                              tempSelectedLessonHours,
                            );
                            _checkActiveFilter();
                          });
                          _loadData(); // Reload data with new filters
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: _getPrimaryColor(),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Apply',
                            'id': 'Terapkan',
                          }),
                          style: TextStyle(color: Colors.white),
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

  Widget _buildClassList(LanguageProvider languageProvider) {
    if (_isLoadingClasses) {
      return SkeletonListLoading(
        itemCount: 8,
        infoTagCount: 1,
        showActions: false,
      );
    }

    final searchTerm = _searchController.text.toLowerCase();
    final filteredClasses = _classList.where((kelas) {
      final className = kelas['name']?.toString().toLowerCase() ?? '';
      return className.contains(searchTerm);
    }).toList();

    if (filteredClasses.isEmpty) {
      return Center(
        child: Text(
          languageProvider.getTranslatedText({
            'en': 'No classes found',
            'id': 'Tidak ada data kelas',
          }),
          style: TextStyle(color: ColorUtils.slate400),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _forceRefresh,
      color: _getPrimaryColor(),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        physics: AlwaysScrollableScrollPhysics(),
        itemCount: filteredClasses.length,
        itemBuilder: (context, index) {
          final kelas = filteredClasses[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedClassData = kelas;
                  _selectedClassIds.clear();
                  _selectedClassIds.add(kelas['id'].toString());
                  _loadData();
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ColorUtils.slate200),
                  boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _getPrimaryColor().withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        Icons.class_,
                        color: _getPrimaryColor(),
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kelas['name'] ?? 'Unknown Class',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'Grade', 'id': 'Tingkat'})}: ${kelas['grade_level'] ?? '-'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: ColorUtils.slate400,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadTableData() async {
    if (!mounted) return;
    if (_selectedClassIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).getTranslatedText({
              'en': 'Please select a class first',
              'id': 'Mohon pilih kelas terlebih dahulu',
            }),
          ),
          backgroundColor: ColorUtils.error600,
        ),
      );
      setState(() => _showTableView = false);
      return;
    }

    setState(() {
      _isTableLoading = true;
      _attendanceMap.clear();
      _studentList.clear();
      _uniqueDates.clear();
      _uniqueSubjectIds.clear();
    });

    try {
      final classId = _selectedClassIds.first;
      final academicYearId = context
          .read<AcademicYearProvider>()
          .selectedAcademicYear?['id']
          ?.toString();

      // Determine Date Range
      String? startDate;
      String? endDate;
      final now = DateTime.now();

      if (_selectedDateFilter == 'today') {
        startDate = DateFormat('yyyy-MM-dd').format(now);
        endDate = startDate;
      } else if (_selectedDateFilter == 'week') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6));
        startDate = DateFormat('yyyy-MM-dd').format(startOfWeek);
        endDate = DateFormat('yyyy-MM-dd').format(endOfWeek);
      } else if (_selectedDateFilter == 'month' ||
          _selectedDateFilter == null) {
        // Default to current month if no filter or monthly filter
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
        endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);
      }

      // 1. Fetch Students
      final students = await getIt<ApiClassService>().getStudentsByClassId(classId);

      // 2. Fetch Attendance
      // We use a large limit to get all records for the range.
      final attendanceParams = <String, dynamic>{
        'classId': classId,
        'limit': '1000', // Adjust as needed
        'tanggalStart': startDate,
        'tanggalEnd': endDate,
      };

      if (academicYearId != null) {
        attendanceParams['academicYearId'] = academicYearId;
      }

      final attendanceResult = await ApiService.getAttendancePaginated(
        page: 1,
        limit: 1000,
        classId: classId,
        tanggalStart: startDate,
        tanggalEnd: endDate,
        academicYearId: academicYearId,
      );

      final List<dynamic> attendanceData = attendanceResult['data'] ?? [];

      if (!mounted) return;

      // Process Data
      Set<String> dateSet = {};
      Set<String> subjectIdSet = {};
      Map<String, dynamic> attMap = {};

      for (var record in attendanceData) {
        final String? date = record['date'];
        final String? sId = record['student_id']?.toString();
        final String? subjId = record['subject_id']?.toString();
        final String? status = record['status'];

        if (date != null && sId != null && subjId != null) {
          dateSet.add(date);
          subjectIdSet.add(subjId);
          attMap['$sId-$date-$subjId'] = status;
        }
      }

      // Create Subject Map for labels
      Map<String, dynamic> subjectMap = {};
      for (var s in _subjectList) {
        subjectMap[s['id'].toString()] = s['name'];
      }

      List<PresenceGridData> gridData = [];
      for (var student in students) {
        // Handle student structure if it's nested or direct
        final sData = student is Map ? student : {};
        var id =
            sData['id']?.toString() ?? sData['student_id']?.toString() ?? '';
        var nis = sData['nis'] ?? sData['student_number'] ?? '-';
        var name = sData['name'] ?? sData['nama'] ?? 'Unknown';

        // Sometimes student data is nested in 'student' key if fetched via enrollment
        if (sData.containsKey('student')) {
          final inner = sData['student'];
          if (id.isEmpty) {
            id = inner['id']?.toString() ?? '';
          }
          nis = inner['nis'] ?? inner['student_number'] ?? nis;
          name = inner['name'] ?? inner['nama'] ?? name;
        }

        gridData.add(
          PresenceGridData(
            studentId: id,
            nis: nis.toString(),
            name: name.toString(),
            attendance:
                attMap, // Pass the whole map, but simpler to pass subset?
            // Actually PresenceGridData expects 'attendance' map.
            // But wait, the key for grid data inside DataSource uses specific logic.
            // Let's pass the global attMap for now, assuming unique keys $sId-$date-$subjId
          ),
        );
      }

      setState(() {
        _studentList.clear();
        _studentList.addAll(students);
        _uniqueDates.clear();
        _uniqueDates.addAll(dateSet.toList()..sort());
        _uniqueSubjectIds.clear();
        _uniqueSubjectIds.addAll(subjectIdSet.toList());

        // Build Date Labels (Day of month)
        _dateLabels.clear();
        for (var d in _uniqueDates) {
          DateTime? dt = AppDateUtils.parseApiDate(d);
          _dateLabels[d] = dt != null ? dt.day.toString() : d;
        }

        _attendanceDataSource = AttendanceDataSource(
          students: gridData,
          dates: _uniqueDates,
          subjectIds: _uniqueSubjectIds,
          subjectMap: subjectMap,
        );
        _isTableLoading = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading table data: $e');
      if (mounted) {
        setState(() => _isTableLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load table data: $e')),
        );
      }
    }
  }

  Widget _buildTableView() {
    final languageProvider = Provider.of<LanguageProvider>(context);

    if (_isTableLoading) {
      return SkeletonListLoading(
        itemCount: 10,
        infoTagCount: 1,
        showActions: false,
      );
    }

    if (_selectedClassIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 64, color: ColorUtils.slate400),
            SizedBox(height: 16),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Please select a class to view the table',
                'id': 'Silakan pilih kelas untuk melihat tabel',
              }),
              style: TextStyle(color: ColorUtils.slate600),
            ),
          ],
        ),
      );
    }

    if (_attendanceDataSource == null || _studentList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No data available',
          'id': 'Tidak ada data',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'Please select a different class or criteria',
          'id': 'Silakan pilih kelas atau kriteria lain',
        }),
      );
    }

    // Calculate columns
    // Dynamic columns width?

    // Group dates by month
    Map<String, List<String>> monthsMap = {};
    for (var dateStr in _uniqueDates) {
      try {
        final date = DateTime.parse(dateStr);
        final monthKey = DateFormat(
          'MMMM yyyy',
          languageProvider.currentLanguage,
        ).format(date);
        monthsMap.putIfAbsent(monthKey, () => []).add(dateStr);
      } catch (e) {
        monthsMap.putIfAbsent('', () => []).add(dateStr);
      }
    }

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate100,
            blurRadius: 10,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SfDataGrid(
          source: _attendanceDataSource!,
          frozenColumnsCount: 1,
          gridLinesVisibility: GridLinesVisibility.horizontal,
          headerGridLinesVisibility: GridLinesVisibility.horizontal,
          rowHeight: 60,
          headerRowHeight: 50,
          stackedHeaderRows: [
            if (monthsMap.isNotEmpty)
              StackedHeaderRow(
                cells: [
                  StackedHeaderCell(
                    child: Container(
                      color: _getPrimaryColor().withValues(alpha: 0.05),
                    ),
                    columnNames: ['student_info'],
                  ),
                  ...monthsMap.entries.map((entry) {
                    final columns = entry.value
                        .expand(
                          (date) =>
                              _uniqueSubjectIds.map((sId) => '$date-$sId'),
                        )
                        .toList();

                    return StackedHeaderCell(
                      child: Container(
                        color: _getPrimaryColor(),
                        alignment: Alignment.center,
                        child: Text(
                          entry.key.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      columnNames: columns,
                    );
                  }),
                ],
              ),
            StackedHeaderRow(
              cells: [
                StackedHeaderCell(
                  child: Container(
                    color: _getPrimaryColor().withValues(alpha: 0.05),
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'STUDENT INFO',
                        'id': 'INFORMASI SISWA',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getPrimaryColor(),
                        fontSize: 11,
                      ),
                    ),
                  ),
                  columnNames: ['student_info'],
                ),
                ..._uniqueDates.map((dateStr) {
                  String dayLabel = '';
                  try {
                    final date = DateTime.parse(dateStr);
                    dayLabel = DateFormat('d').format(date);
                  } catch (_) {
                    dayLabel = dateStr;
                  }

                  return StackedHeaderCell(
                    child: Container(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      alignment: Alignment.center,
                      child: Text(
                        dayLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getPrimaryColor(),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    columnNames: _uniqueSubjectIds
                        .map((sId) => '$dateStr-$sId')
                        .toList(),
                  );
                }),
              ],
            ),
          ],
          columns: [
            GridColumn(
              columnName: 'student_info',
              width: 250,
              label: Container(
                color: _getPrimaryColor().withValues(alpha: 0.05),
              ),
            ),
            ..._uniqueDates.expand((date) {
              return _uniqueSubjectIds.map((sId) {
                final subjectName =
                    _attendanceDataSource?.subjectMap[sId] ?? sId;
                return GridColumn(
                  columnName: '$date-$sId',
                  width: 100,
                  label: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: ColorUtils.slate200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Text(
                      subjectName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate600,
                      ),
                    ),
                  ),
                );
              });
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    AttendanceSummary summary,
    LanguageProvider languageProvider,
    int index,
  ) {
    final presentaseHadir = summary.totalStudents > 0
        ? (summary.present / summary.totalStudents * 100).round()
        : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateToDetailAbsensi(summary),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: subject name + student count badge + delete button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Subject icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _getPrimaryColor().withValues(alpha: 0.15),
                      ),
                    ),
                    child: Icon(
                      Icons.book_outlined,
                      color: _getPrimaryColor(),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  // Subject + class + date info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.subjectName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ColorUtils.slate900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.class_outlined,
                              size: 12,
                              color: _getPrimaryColor(),
                            ),
                            SizedBox(width: 4),
                            Text(
                              summary.className,
                              style: TextStyle(
                                fontSize: 12,
                                color: _getPrimaryColor(),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (summary.lessonHourName != null &&
                                summary.lessonHourName!.isNotEmpty) ...[
                              Text(
                                ' • ',
                                style: TextStyle(
                                  color: ColorUtils.slate400,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                summary.lessonHourName!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorUtils.slate600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          DateFormat(
                            'EEEE, dd MMMM yyyy',
                            'id_ID',
                          ).format(summary.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: ColorUtils.slate500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8),
                  // Delete button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _deleteAbsensi(summary, languageProvider),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ColorUtils.error600.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ColorUtils.error600.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: ColorUtils.error600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 12),
              Divider(color: ColorUtils.slate100, height: 1),
              SizedBox(height: 10),

              // Attendance info row
              Row(
                children: [
                  _buildInfoTag(
                    icon: Icons.check_circle_outline,
                    label: '${summary.present} Hadir',
                    tagColor: ColorUtils.success600,
                  ),
                  SizedBox(width: 8),
                  _buildInfoTag(
                    icon: Icons.cancel_outlined,
                    label: '${summary.absent} Absen',
                    tagColor: ColorUtils.error600,
                  ),
                  SizedBox(width: 8),
                  _buildInfoTag(
                    icon: Icons.people_outline,
                    label: '${summary.totalStudents} Siswa',
                    tagColor: _getPrimaryColor(),
                  ),
                  Spacer(),
                  // Detail button
                  GestureDetector(
                    onTap: () => _navigateToDetailAbsensi(summary),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getPrimaryColor().withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 12,
                            color: _getPrimaryColor(),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Detail',
                            style: TextStyle(
                              fontSize: 11,
                              color: _getPrimaryColor(),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 10),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: summary.totalStudents > 0
                      ? summary.present / summary.totalStudents
                      : 0,
                  minHeight: 6,
                  backgroundColor: ColorUtils.slate200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    presentaseHadir >= 80
                        ? ColorUtils.success600
                        : presentaseHadir >= 60
                        ? ColorUtils.warning600
                        : ColorUtils.error600,
                  ),
                ),
              ),
              SizedBox(height: 4),
              Text(
                '$presentaseHadir% ${languageProvider.getTranslatedText({'en': 'Attendance', 'id': 'Kehadiran'})}',
                style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showExportDialog() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    final activeYearName =
        academicYearProvider.selectedAcademicYear?['name'] ??
        '${DateTime.now().year}/${DateTime.now().year + 1}';
    final activeYearString =
        academicYearProvider.selectedAcademicYear?['year']?.toString() ??
        '${DateTime.now().year}/${DateTime.now().year + 1}';

    // Parse years
    int startYear = DateTime.now().year;
    try {
      final parts = activeYearString.split('/');
      if (parts.isNotEmpty) startYear = int.parse(parts[0]);
    } catch (_) {}

    // Generate 12 months starting from July of startYear
    List<DateTime> months = [];
    for (int i = 0; i < 12; i++) {
      months.add(DateTime(startYear, 7 + i, 1));
    }

    // Default Selection
    List<DateTime> selectedMonths = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                languageProvider.getTranslatedText({
                  'en': 'Export Attendance',
                  'id': 'Export Absensi',
                }),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tahun Ajaran $activeYearName',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Select month(s) to export:',
                        'id': 'Pilih bulan yang akan diexport:',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate400,
                      ),
                    ),
                    SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: months.length,
                        itemBuilder: (context, index) {
                          final date = months[index];
                          final label = DateFormat(
                            'MMMM yyyy',
                            languageProvider.currentLanguage,
                          ).format(date);
                          final isSelected = selectedMonths.contains(date);
                          return CheckboxListTile(
                            title: Text(label),
                            value: isSelected,
                            onChanged: (val) {
                              setStateDialog(() {
                                if (val == true) {
                                  selectedMonths.add(date);
                                } else {
                                  selectedMonths.remove(date);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Cancel',
                      'id': 'Batal',
                    }),
                  ),
                ),
                ElevatedButton(
                  onPressed: selectedMonths.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          _processExport(selectedMonths);
                        },
                  child: Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _processExport(List<DateTime> months) async {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    // Sort months
    months.sort();

    int successCount = 0;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    try {
      for (var month in months) {
        await _exportMonth(month);
        successCount++;
        // Optional delay to prevent rate limits
        await Future.delayed(Duration(seconds: 1));
      }

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Exported $successCount files successfully',
                'id': 'Berhasil mengexport $successCount file',
              }),
            ),
            backgroundColor: ColorUtils.success600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    }
  }

  Future<void> _exportMonth(DateTime month) async {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final startDate = DateFormat('yyyy-MM-dd').format(startOfMonth);
    final endDate = DateFormat('yyyy-MM-dd').format(endOfMonth);

    final classId = _selectedClassData!['id'];
    final className = _selectedClassData!['name'];

    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    final academicYearId = academicYearProvider.selectedAcademicYear?['id']
        ?.toString();
    final academicYearName =
        academicYearProvider.selectedAcademicYear?['year']?.toString() ?? '-';

    // 1. Fetch Data
    final students = await getIt<ApiClassService>().getStudentsByClassId(classId);

    final attendanceResult = await ApiService.getAttendancePaginated(
      page: 1,
      limit: 2000, // Ensure enough limit
      classId: classId,
      tanggalStart: startDate,
      tanggalEnd: endDate,
      academicYearId: academicYearId,
    );

    final List<dynamic> attendanceData = attendanceResult['data'] ?? [];

    if (attendanceData.isEmpty) {
      return; // Skip empty months? Or export empty file?
    }

    // 2. Map Data
    // Subject Map
    Map<String, String> subjectMap = {};
    for (var s in _subjectList) {
      subjectMap[s['id'].toString()] = s['name'];
    }

    List<Map<String, dynamic>> exportList = [];

    for (var record in attendanceData) {
      final sId = record['student_id'].toString();
      // Find student
      var studentMap = students.firstWhere((s) {
        final id = s['id']?.toString();
        // Nested check
        if (id != null && id == sId) return true;
        if (s['student'] != null && s['student']['id']?.toString() == sId) {
          return true;
        }
        return false;
      }, orElse: () => null);

      if (studentMap == null) continue;

      // Normalize student data
      if (studentMap['student'] != null) studentMap = studentMap['student'];

      final nis = studentMap['nis'] ?? studentMap['student_number'] ?? '';
      final name = studentMap['name'] ?? studentMap['nama'] ?? 'Unknown';

      final subjId = record['subject_id'].toString();
      final subjectName =
          subjectMap[subjId] ?? record['subject_name'] ?? 'Unknown';

      exportList.add({
        'nis': nis,
        'student_name': name,
        'class_name': className,
        'academic_year': academicYearName,
        'date': record['date'],
        'subject_name': subjectName,
        'status': record['status'],
      });
    }

    if (exportList.isEmpty) return;

    // 3. Call Service
    // We pass context for Localization
    await ExcelPresenceService.exportPresenceToExcel(
      presenceData: exportList,
      context: context,
      filters: {},
    );
  }

  Widget _buildInfoTag({
    required IconData icon,
    required String label,
    Color? tagColor,
  }) {
    final color = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<AttendanceSummary> _getFilteredSummaries() {
    final searchTerm = _searchController.text.toLowerCase();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return _absensiSummaryList.where((summary) {
      // Search filter
      final matchesSearch =
          searchTerm.isEmpty ||
          summary.subjectName.toLowerCase().contains(searchTerm) ||
          summary.className.toLowerCase().contains(searchTerm);

      // Date filter
      bool matchesDateFilter = true;
      if (_selectedDateFilter != null) {
        if (_selectedDateFilter == 'today') {
          matchesDateFilter = _isSameDay(summary.date, now);
        } else if (_selectedDateFilter == 'week') {
          matchesDateFilter =
              summary.date.isAfter(startOfWeek.subtract(Duration(days: 1))) &&
              summary.date.isBefore(endOfWeek.add(Duration(days: 1)));
        } else if (_selectedDateFilter == 'month') {
          matchesDateFilter =
              summary.date.isAfter(startOfMonth.subtract(Duration(days: 1))) &&
              summary.date.isBefore(endOfMonth.add(Duration(days: 1)));
        }
      }

      // Subject filter
      final matchesSubject =
          _selectedSubjectIds.isEmpty ||
          _selectedSubjectIds.contains(summary.subjectId);

      // Class filter
      final matchesClass =
          _selectedClassIds.isEmpty ||
          _selectedClassIds.contains(summary.classId);

      // Day filter
      final matchesDay =
          _selectedDayIds.isEmpty ||
          _selectedDayIds.contains(summary.date.weekday.toString());

      // Lesson Hour filter
      final matchesLessonHour =
          _selectedLessonHourIds.isEmpty ||
          _selectedLessonHourIds.contains(summary.lessonHourId);

      return matchesSearch &&
          matchesDateFilter &&
          matchesSubject &&
          matchesClass &&
          matchesDay &&
          matchesLessonHour;
    }).toList();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _deleteAbsensi(
    AttendanceSummary summary,
    LanguageProvider languageProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient danger header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    ColorUtils.error600,
                    ColorUtils.error600.withValues(alpha: 0.85),
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
                    Icons.warning_amber_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Delete Attendance',
                      'id': 'Hapus Absensi',
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
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    languageProvider.getTranslatedText({
                      'en':
                          'Are you sure you want to delete this attendance record?',
                      'id':
                          'Apakah Anda yakin ingin menghapus data absensi ini?',
                    }),
                    style: TextStyle(fontSize: 14, color: ColorUtils.slate700),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: ColorUtils.slate300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Cancel',
                              'id': 'Batal',
                            }),
                            style: TextStyle(color: ColorUtils.slate700),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: ColorUtils.error600,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoadingSummary = true;
        });

        await ApiService.deleteAttendance(
          subjectId: summary.subjectId,
          classId: summary.classId,
          date: DateFormat('yyyy-MM-dd').format(summary.date),
          lessonHourId: summary.lessonHourId,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Attendance deleted successfully',
                'id': 'Absensi berhasil dihapus',
              }),
            ),
            backgroundColor: ColorUtils.success600,
          ),
        );

        _loadData(useCache: false);
      } catch (e) {
        setState(() {
          _isLoadingSummary = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menghapus absensi: ${ErrorUtils.getFriendlyMessage(e)}',
            ),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    }
  }

  void _navigateToDetailAbsensi(AttendanceSummary summary) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminAbsensiDetailPage(
          subjectId: summary.subjectId,
          subjectName: summary.subjectName,
          date: summary.date,
          classId: summary.classId,
          className: summary.className,
          lessonHourId: summary.lessonHourId,
          lessonHourName: summary.lessonHourName,
          academicYearId: summary.academicYearId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final filteredSummaries = _getFilteredSummaries();

        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          floatingActionButton: FloatingActionButton(
            onPressed: _showTeacherSelectionDialog,
            backgroundColor: _getPrimaryColor(),
            tooltip: languageProvider.getTranslatedText({
              'en': 'Add Attendance',
              'id': 'Tambah Absensi',
            }),
            child: Icon(Icons.add, color: Colors.white),
          ),
          body: Column(
            children: [
              // Header dengan gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  gradient: _getCardGradient(),
                  boxShadow: [
                    BoxShadow(
                      color: _getPrimaryColor().withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_selectedClassData != null) {
                              setState(() {
                                _selectedClassData = null;
                                _selectedClassIds.clear();
                                _absensiSummaryList.clear();
                              });
                            } else {
                              Navigator.pop(context);
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
                            key: _infoKey,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Attendance Report',
                                  'id': 'Laporan Absensi',
                                }),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'View attendance reports',
                                  'id': 'Lihat laporan absensi',
                                }),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedClassData != null) ...[
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showTableView = !_showTableView;
                                if (_showTableView) {
                                  _loadTableData();
                                }
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _showTableView
                                    ? Icons.view_list
                                    : Icons.table_chart,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                        ],
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'refresh':
                                _forceRefresh();
                                break;
                              case 'export':
                                if (_selectedClassData != null) {
                                  _showExportDialog();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        languageProvider.getTranslatedText({
                                          'en': 'Please select a class first',
                                          'id':
                                              'Mohon pilih kelas terlebih dahulu',
                                        }),
                                      ),
                                    ),
                                  );
                                }
                                break;
                            }
                          },
                          icon: Container(
                            width: 40,
                            height: 40,
                            key: _moreKey,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          itemBuilder: (BuildContext context) => [
                            PopupMenuItem<String>(
                              value: 'refresh',
                              child: Row(
                                children: [
                                  Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                                  SizedBox(width: 8),
                                  Text('Perbarui Data'),
                                ],
                              ),
                            ),
                            if (_selectedClassData != null)
                              PopupMenuItem<String>(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.file_download, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Export Excel',
                                        'id': 'Export Excel',
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: 16),

                    // Search Bar with Filter Button
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            key: _searchKey,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onSubmitted: (_) => setState(() {}),
                                    style: TextStyle(
                                      color: ColorUtils.slate800,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: languageProvider
                                          .getTranslatedText({
                                            'en': 'Search attendance...',
                                            'id': 'Cari absensi...',
                                          }),
                                      hintStyle: TextStyle(
                                        color: ColorUtils.slate400,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: ColorUtils.slate400,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                Container(
                                  margin: EdgeInsets.only(right: 4),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.search,
                                      color: _getPrimaryColor(),
                                    ),
                                    onPressed: () => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Filter Button
                        Container(
                          decoration: BoxDecoration(
                            color: _hasActiveFilter
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          key: _filterKey,
                          child: Stack(
                            children: [
                              IconButton(
                                onPressed: _showFilterSheet,
                                icon: Icon(
                                  Icons.tune,
                                  color: _hasActiveFilter
                                      ? _getPrimaryColor()
                                      : Colors.white,
                                ),
                                tooltip: languageProvider.getTranslatedText({
                                  'en': 'Filter',
                                  'id': 'Filter',
                                }),
                              ),
                              if (_hasActiveFilter)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.error600,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 8,
                                      minHeight: 8,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Filter Chips
                    if (_hasActiveFilter) ...[
                      SizedBox(height: 12),
                      SizedBox(
                        height: 32,
                        child: Row(
                          children: [
                            Expanded(
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  ..._buildFilterChips(languageProvider).map((
                                    filter,
                                  ) {
                                    return Container(
                                      margin: EdgeInsets.only(right: 6),
                                      child: Chip(
                                        label: Text(
                                          filter['label'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        deleteIcon: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                        onDeleted: filter['onRemove'],
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.2),
                                        side: BorderSide(
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        labelPadding: EdgeInsets.only(left: 4),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            SizedBox(width: 8),
                            InkWell(
                              onTap: _clearAllFilters,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ColorUtils.error600,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.clear_all,
                                  size: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _selectedClassData == null
                    ? _buildClassList(languageProvider)
                    : _showTableView
                    ? _buildTableView()
                    : _isLoadingSummary
                    ? SkeletonListLoading(
                        itemCount: 8,
                        infoTagCount: 2,
                        showActions: false,
                      )
                    : filteredSummaries.isEmpty
                    ? EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No attendance records',
                          'id': 'Belum ada data absensi',
                        }),
                        subtitle:
                            _searchController.text.isEmpty && !_hasActiveFilter
                            ? languageProvider.getTranslatedText({
                                'en': 'No attendance data available',
                                'id': 'Tidak ada data absensi tersedia',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.list_alt,
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        itemCount: filteredSummaries.length,
                        itemBuilder: (context, index) {
                          final summary = filteredSummaries[index];
                          return _buildSummaryCard(
                            summary,
                            languageProvider,
                            index,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkAndShowTour() async {
    if (_isTourShowing) return;
    try {
      const tourCacheKey = 'tour_presence_report_admin';
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
          if (mounted && !_isTourShowing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isTourShowing) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('attendance', 'Error checking tour status: $e');
    }
  }

  void _showTour() {
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = context.read<LanguageProvider>();

    setState(() {
      _isTourShowing = true;
    });

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        setState(() {
          _isTourShowing = false;
        });
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
        }
        LocalCacheService.save('tour_presence_report_admin', {'should_show': false});
      },
      onSkip: () {
        setState(() {
          _isTourShowing = false;
        });
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
        }
        LocalCacheService.save('tour_presence_report_admin', {'should_show': false});
        return true;
      },
      onClickOverlay: (target) {
        // Optional handle
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = context.read<LanguageProvider>();

    targets.add(
      TargetFocus(
        identify: "PresenceReportInfo",
        keyTarget: _infoKey,
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
                    languageProvider.getTranslatedText({
                      'en': 'Attendance Reports',
                      'id': 'Laporan Absensi',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en':
                            'View and manage student attendance reports across all classes.',
                        'id':
                            'Lihat dan kelola laporan absensi siswa di semua kelas.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "PresenceReportSearch",
        keyTarget: _searchKey,
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
                    languageProvider.getTranslatedText({
                      'en': 'Search Attendance',
                      'id': 'Cari Absensi',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Search for specific classes or subjects.',
                        'id': 'Cari kelas atau mata pelajaran tertentu.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "PresenceReportFilter",
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
                    languageProvider.getTranslatedText({
                      'en': 'Filter Options',
                      'id': 'Opsi Filter',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Narrow down results by date, subject, or class.',
                        'id':
                            'Persempit hasil berdasarkan tanggal, mata pelajaran, atau kelas.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "PresenceReportMore",
        keyTarget: _moreKey,
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
                    languageProvider.getTranslatedText({
                      'en': 'More Options',
                      'id': 'Opsi Lanjutan',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Refresh data or export reports to Excel.',
                        'id': 'Segarkan data atau export laporan ke Excel.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }
}

// ========== ADMIN ABSENSI DETAIL PAGE ==========
class AdminAbsensiDetailPage extends StatefulWidget {
  final String subjectId;
  final String classId;
  final DateTime date;
  final String subjectName;
  final String className;
  final String? lessonHourId;
  final String? lessonHourName;
  final String? academicYearId;

  const AdminAbsensiDetailPage({
    Key? key,
    required this.subjectId,
    required this.classId,
    required this.date,
    required this.subjectName,
    required this.className,
    this.lessonHourId,
    this.lessonHourName,
    this.academicYearId,
  }) : super(key: key);

  @override
  State<AdminAbsensiDetailPage> createState() => _AdminAbsensiDetailPageState();
}

class _AdminAbsensiDetailPageState extends State<AdminAbsensiDetailPage> {
  List<dynamic> _absensiData = [];
  List<Student> _siswaList = [];
  bool _isLoading = true;
  bool _isEditing = false;
  final Map<String, String> _tempAbsensiStatus = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // 1. Load attendance data
      final absensiData = await ApiService.getAttendance(
        subjectId: widget.subjectId,
        date: DateFormat('yyyy-MM-dd').format(widget.date),
        classId: widget.classId,
        lessonHourId: widget.lessonHourId,
        academicYearId: widget.academicYearId,
      );

      // 2. Load students by class ID (from widget parameter)
      List<dynamic> siswaData;
      if (widget.classId.isNotEmpty) {
        siswaData = await ApiStudentService.getStudentByClass(
          widget.classId,
          academicYearId: widget.academicYearId,
        );
        AppLogger.info('attendance', 'Loaded ${siswaData.length} students for class: ${widget.classId} in year: ${widget.academicYearId}',);
      } else {
        // Fallback: if no classId provided, try to get from attendance data
        if (absensiData.isNotEmpty) {
          final classIdFromData = absensiData.first['class_id']?.toString();
          if (classIdFromData != null && classIdFromData.isNotEmpty) {
            siswaData = await ApiStudentService.getStudentByClass(
              classIdFromData,
              academicYearId: widget.academicYearId,
            );
            AppLogger.info('attendance', 'Loaded ${siswaData.length} students for class: $classIdFromData (from attendance data)',);
          } else {
            siswaData = await ApiStudentService.getStudent();
            AppLogger.info('attendance', 'Loaded all students (no class ID available)');
          }
        } else {
          siswaData = await ApiStudentService.getStudent();
          AppLogger.info('attendance', 'Loaded all students (no attendance data)');
        }
      }

      AppLogger.info('attendance', 'Loaded ${absensiData.length} attendance records');

      setState(() {
        _siswaList = siswaData.map((s) => Student.fromJson(s)).toList();
        _absensiData = absensiData;

        // Initialize temp status
        _tempAbsensiStatus.clear();
        for (var s in _siswaList) {
          _tempAbsensiStatus[s.id] = _getStudentStatus(s.id);
        }

        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading absensi detail for admin: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> exportDetail() async {
    if (_absensiData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak ada data kegiatan untuk diexport'),
          backgroundColor: ColorUtils.warning600,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ExcelPresenceService.exportPresenceToExcel(
        presenceData: _absensiData,
        context: context,
      );
    } catch (e) {
      AppLogger.error('attendance', 'Error exporting activities: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_getPrimaryColor(), _getPrimaryColor().withValues(alpha: 0.85)],
    );
  }

  // Method untuk mendapatkan status absensi siswa
  String _getStudentStatus(String siswaId) {
    try {
      final absenRecord = _absensiData.firstWhere(
        (a) => a['student_id']?.toString() == siswaId.toString(),
        orElse: () => {'status': 'alpha'}, // Fallback if not found
      );
      return (absenRecord['status'] ?? 'alpha').toString().toLowerCase();
    } catch (e) {
      return 'alpha';
    }
  }

  String _mapStatusToBackend(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'present';
      case 'terlambat':
        return 'late';
      case 'izin':
        return 'excused';
      case 'sakit':
        return 'sick';
      case 'alpha':
      case 'absent':
        return 'absent';
      default:
        return 'present';
    }
  }

  Future<void> _saveChanges() async {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );

    setState(() => _isSaving = true);

    String? teacherId;
    if (_absensiData.isNotEmpty) {
      teacherId =
          _absensiData.first['teacher_id']?.toString() ??
          _absensiData.first['guru_id']?.toString();
    }

    if (teacherId == null) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Guru ID tidak ditemukan'),
          backgroundColor: ColorUtils.error600,
        ),
      );
      return;
    }

    int successCount = 0;
    int errorCount = 0;
    String lastError = '';

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);

      for (var siswa in _siswaList) {
        try {
          final status = _tempAbsensiStatus[siswa.id] ?? 'alpha';

          await ApiService.createAttendance({
            'student_id': siswa.id,
            'teacher_id': teacherId,
            'subject_id': widget.subjectId,
            'class_id': widget.classId,
            'date': dateStr,
            'status': _mapStatusToBackend(status),
            'lesson_hour_id': widget.lessonHourId,
            'notes': '',
          });
          successCount++;
        } catch (e) {
          errorCount++;
          lastError = e.toString();
          AppLogger.error('attendance', 'Error saving for student ${siswa.name}: $e');
        }
      }

      if (successCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en':
                    'Attendance updated successfully ($successCount students)',
                'id': 'Absensi berhasil diperbarui ($successCount siswa)',
              }),
            ),
            backgroundColor: errorCount > 0
                ? ColorUtils.warning600
                : ColorUtils.success600,
          ),
        );

        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        _loadData(); // Reload to get fresh data from server
      } else {
        throw Exception('Gagal menyimpan semua data. Terakhir: $lastError');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan perubahan: ${ErrorUtils.getFriendlyMessage(e)}',
          ),
          backgroundColor: ColorUtils.error600,
        ),
      );
    }
  }

  Widget _buildStudentCard(
    Student student,
    LanguageProvider languageProvider,
    int index,
  ) {
    final status = _getStudentStatus(student.id);
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getStatusText(status, languageProvider);
    final avatarColor = ColorUtils.getColorForIndex(index);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'NIS: ${student.studentNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (_isEditing) ...[
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickStatusButton(
                      'hadir',
                      'H',
                      ColorUtils.success600,
                      student.id,
                    ),
                    _buildQuickStatusButton(
                      'sakit',
                      'S',
                      ColorUtils.warning600,
                      student.id,
                    ),
                    _buildQuickStatusButton(
                      'izin',
                      'I',
                      ColorUtils.info600,
                      student.id,
                    ),
                    _buildQuickStatusButton(
                      'alpha',
                      'A',
                      ColorUtils.error600,
                      student.id,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Helper functions
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return ColorUtils.success600;
      case 'izin':
      case 'excused':
      case 'permission':
        return ColorUtils.info600;
      case 'sakit':
      case 'sick':
        return ColorUtils.warning600;
      case 'alpha':
      case 'absent':
        return ColorUtils.error600;
      case 'terlambat':
      case 'late':
        return Color(0xFF7C3AED);
      default:
        return ColorUtils.slate400;
    }
  }

  String _getStatusText(String status, LanguageProvider languageProvider) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        });
      case 'izin':
      case 'excused':
      case 'permission':
        return languageProvider.getTranslatedText({
          'en': 'Permission',
          'id': 'Izin',
        });
      case 'sakit':
      case 'sick':
        return languageProvider.getTranslatedText({
          'en': 'Sick',
          'id': 'Sakit',
        });
      case 'alpha':
      case 'absent':
        return languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Alpha',
        });
      case 'terlambat':
      case 'late':
        return languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        });
      default:
        return languageProvider.getTranslatedText({
          'en': 'Unknown',
          'id': 'Tidak Diketahui',
        });
    }
  }

  // Method untuk menghitung statistik
  Map<String, int> _calculateStatistics() {
    int hadir = 0;
    int terlambat = 0;
    int izin = 0;
    int sakit = 0;
    int alpha = 0;

    for (var siswa in _siswaList) {
      final status = _getStudentStatus(siswa.id);
      switch (status.toLowerCase()) {
        case 'hadir':
        case 'present':
          hadir++;
          break;
        case 'terlambat':
        case 'late':
          terlambat++;
          break;
        case 'izin':
        case 'excused':
        case 'permission':
          izin++;
          break;
        case 'sakit':
        case 'sick':
          sakit++;
          break;
        case 'alpha':
        case 'absent':
          alpha++;
          break;
      }
    }

    return {
      'hadir': hadir,
      'terlambat': terlambat,
      'izin': izin,
      'sakit': sakit,
      'alpha': alpha,
      'total': _siswaList.length,
    };
  }

  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 90,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatusButton(
    String status,
    String label,
    Color color,
    String studentId,
  ) {
    final isSelected = _tempAbsensiStatus[studentId] == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tempAbsensiStatus[studentId] = status;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final stats = _calculateStatistics();
        final totalTidakHadir = stats['alpha']!;

        return Scaffold(
          backgroundColor: ColorUtils.slate50,
          bottomNavigationBar: _isEditing
              ? SafeArea(
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: ColorUtils.slate900.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getPrimaryColor(),
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              languageProvider.getTranslatedText({
                                'en': 'Save Changes',
                                'id': 'Simpan Perubahan',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                )
              : null,
          body: Column(
            children: [
              // Pattern #7 Inline Gradient Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  gradient: _getCardGradient(),
                  boxShadow: [
                    BoxShadow(
                      color: _getPrimaryColor().withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_isEditing) {
                              setState(() {
                                _isEditing = false;
                                for (var s in _siswaList) {
                                  _tempAbsensiStatus[s.id] = _getStudentStatus(
                                    s.id,
                                  );
                                }
                              });
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
                              _isEditing ? Icons.close : Icons.arrow_back,
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
                                _isEditing
                                    ? languageProvider.getTranslatedText({
                                        'en': 'Edit Attendance',
                                        'id': 'Edit Absensi',
                                      })
                                    : languageProvider.getTranslatedText({
                                        'en': 'Attendance Details',
                                        'id': 'Detail Absensi',
                                      }),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                widget.subjectName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_isEditing) {
                              _saveChanges();
                            } else {
                              setState(() => _isEditing = true);
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
                              _isEditing ? Icons.check : Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        if (!_isEditing)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'refresh') _loadData();
                              if (value == 'export') exportDetail();
                            },
                            icon: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'export',
                                child: Row(
                                  children: [
                                    Icon(Icons.file_download, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Export to Excel',
                                        'id': 'Export ke Excel',
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'refresh',
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Refresh',
                                        'id': 'Refresh',
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                        SizedBox(width: 6),
                        Text(
                          DateFormat(
                            'EEEE, dd MMMM yyyy',
                            'id_ID',
                          ).format(widget.date),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        if (widget.lessonHourName != null &&
                            widget.lessonHourName!.isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                          Text(
                            widget.lessonHourName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Statistics Cards
              SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildStatCard(
                      languageProvider.getTranslatedText({
                        'en': 'Present',
                        'id': 'Hadir',
                      }),
                      stats['hadir']!,
                      ColorUtils.success600,
                      Icons.check_circle,
                    ),
                    _buildStatCard(
                      languageProvider.getTranslatedText({
                        'en': 'Late',
                        'id': 'Terlambat',
                      }),
                      stats['terlambat']!,
                      ColorUtils.warning600,
                      Icons.access_time,
                    ),
                    _buildStatCard(
                      languageProvider.getTranslatedText({
                        'en': 'Absent',
                        'id': 'Tidak Hadir',
                      }),
                      totalTidakHadir,
                      ColorUtils.error600,
                      Icons.cancel,
                    ),
                    if (stats['izin']! > 0)
                      _buildStatCard(
                        languageProvider.getTranslatedText({
                          'en': 'Permission',
                          'id': 'Izin',
                        }),
                        stats['izin']!,
                        ColorUtils.info600,
                        Icons.event_note,
                      ),
                    if (stats['sakit']! > 0)
                      _buildStatCard(
                        languageProvider.getTranslatedText({
                          'en': 'Sick',
                          'id': 'Sakit',
                        }),
                        stats['sakit']!,
                        Color(0xFF7C3AED),
                        Icons.medical_services,
                      ),
                  ],
                ),
              ),

              // Student List Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Student List',
                        'id': 'Daftar Siswa',
                      }),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate600,
                      ),
                    ),
                    Spacer(),
                    Text(
                      '${_siswaList.length} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate600,
                      ),
                    ),
                  ],
                ),
              ),

              // Student List
              Expanded(
                child: _isLoading
                    ? SkeletonListLoading(
                        itemCount: 8,
                        infoTagCount: 1,
                        showActions: false,
                      )
                    : _siswaList.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          title: languageProvider.getTranslatedText({
                            'en': 'No Students Found',
                            'id': 'Siswa Tidak Ditemukan',
                          }),
                          subtitle: languageProvider.getTranslatedText({
                            'en':
                                'No students were found matching the selected class and criteria.',
                            'id':
                                'Tidak ada siswa yang ditemukan untuk kelas dan kriteria yang dipilih.',
                          }),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.only(bottom: 16),
                        itemCount: _siswaList.length,
                        itemBuilder: (context, index) => _buildStudentCard(
                          _siswaList[index],
                          languageProvider,
                          index,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PresenceGridData {
  final String studentId;
  final String nis;
  final String name;
  final Map<String, dynamic> attendance; // date -> {subjectId: status}

  PresenceGridData({
    required this.studentId,
    required this.nis,
    required this.name,
    required this.attendance,
  });
}

class AttendanceDataSource extends DataGridSource {
  final List<PresenceGridData> students;
  final List<String> dates;
  final List<String> subjectIds;
  final Map<String, dynamic> subjectMap; // id -> name

  List<DataGridRow> dataGridRows = [];

  AttendanceDataSource({
    required this.students,
    required this.dates,
    required this.subjectIds,
    required this.subjectMap,
  }) {
    dataGridRows = students.map<DataGridRow>((data) {
      final List<DataGridCell> cells = [
        DataGridCell<PresenceGridData>(columnName: 'student_info', value: data),
      ];

      for (var date in dates) {
        for (var subjectId in subjectIds) {
          final columnKey = '$date-$subjectId';
          final lookupKey = '${data.studentId}-$date-$subjectId';
          final status = data.attendance[lookupKey] ?? '-';
          cells.add(DataGridCell<String>(columnName: columnKey, value: status));
        }
      }

      return DataGridRow(cells: cells);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        if (dataGridCell.columnName == 'student_info') {
          final data = dataGridCell.value as PresenceGridData;
          return Container(
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: ColorUtils.corporateBlue600.withValues(
                    alpha: 0.1,
                  ),
                  child: Text(
                    data.name.isNotEmpty ? data.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: ColorUtils.corporateBlue600,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: ColorUtils.slate800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        data.nis,
                        style: TextStyle(
                          fontSize: 11,
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
          );
        }

        final status = dataGridCell.value.toString();
        Color bgColor = Colors.transparent;
        Color textColor = ColorUtils.slate900;
        String text = '';

        if (status != '-') {
          text = getStatusAbbreviation(status);
          bgColor = getStatusColor(status);
          textColor = getStatusTextColor(status);
        }

        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: ColorUtils.slate200, width: 0.5),
            ),
          ),
          child: status == '-'
              ? Text('-', style: TextStyle(color: ColorUtils.slate300))
              : Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
        );
      }).toList(),
    );
  }

  Color getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'hadir' || s == 'present') {
      return ColorUtils.success600.withValues(alpha: 0.15);
    }
    if (s == 'sakit' || s == 'sick') {
      return ColorUtils.warning600.withValues(alpha: 0.15);
    }
    if (s == 'izin' || s == 'permit') {
      return ColorUtils.info600.withValues(alpha: 0.15);
    }
    if (s == 'alpa' || s == 'alpha' || s == 'absent') {
      return ColorUtils.error600.withValues(alpha: 0.15);
    }
    return Colors.transparent;
  }

  Color getStatusTextColor(String status) {
    final s = status.toLowerCase();
    if (s == 'hadir' || s == 'present') {
      return ColorUtils.success600;
    }
    if (s == 'sakit' || s == 'sick') {
      return ColorUtils.warning600;
    }
    if (s == 'izin' || s == 'permit') {
      return ColorUtils.info600;
    }
    if (s == 'alpa' || s == 'alpha' || s == 'absent') {
      return ColorUtils.error600;
    }
    return ColorUtils.slate900;
  }

  String getStatusAbbreviation(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return 'H';
      case 'sakit':
      case 'sick':
        return 'S';
      case 'izin':
      case 'permit':
        return 'I';
      case 'alpa':
      case 'absent':
        return 'A';
      default:
        return '-';
    }
  }
}
