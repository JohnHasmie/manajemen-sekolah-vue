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
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/attendance/exports/attendance_export_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_report_filter_sheet.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_grid_data.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/admin_attendance_summary_card.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_class_list_view.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_table_view.dart';

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
class AdminAttendanceReportScreen extends ConsumerStatefulWidget {
  const AdminAttendanceReportScreen({super.key});

  @override
  ConsumerState<AdminAttendanceReportScreen> createState() =>
      _AdminAttendanceReportScreenState();
}

/// Mutable state for [AdminAttendanceReportScreen].
///
/// Key state (like Vue `data()`):
/// - [_attendanceSummaryList] - attendance summary records from API
/// - [_showTableView] - toggles between card list and Syncfusion data grid
/// - [_selectedSubjectIds] / [_selectedClassIds] / [_selectedDayIds] - multi-select filters
/// - [_selectedDateFilter] - date range filter ('today', 'week', 'month')
/// - [_studentList] / [_attendanceMap] - raw student attendance data for table view
///
/// setState() is like Vue's reactivity - triggers a re-render when data changes.
class _AdminAttendanceReportScreenState
    extends ConsumerState<AdminAttendanceReportScreen> {
  // Data for View Results mode
  List<AttendanceSummary> _attendanceSummaryList = [];
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
  String? _selectedDateFilter; // 'today', 'week', 'month', or null for all
  final List<String> _selectedSubjectIds = [];
  final List<String> _selectedClassIds = [];
  final List<String> _selectedDayIds = [];
  final List<String> _selectedLessonHourIds = [];
  bool _hasActiveFilter = false;
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _moreKey = GlobalKey();
  final GlobalKey _infoKey = GlobalKey();
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
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
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
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
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
          final cachedLessonHours =
              cached['lessonHours'] as List<dynamic>? ?? [];
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
        getIt<ApiSubjectService>()
            .getSubject()
            .then((value) {
              AppLogger.info('attendance', 'Subjects loaded: ${value.length}');
              return value;
            })
            .catchError((e) {
              AppLogger.error('attendance', 'Error loading subjects: $e');
              return [];
            }),
        getIt<ApiClassService>()
            .getClass(
              academicYearId: ref
                  .read(academicYearRiverpod)
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
        getIt<ApiTeacherService>().getTeacher().catchError((e) {
          AppLogger.error('attendance', 'Error loading teachers: $e');
          return [];
        }),
        getIt<ApiScheduleService>().getJamPelajaran().catchError((e) {
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
        SnackBarUtils.showError(
          context,
          'Gagal memuat data filter: ${ErrorUtils.getFriendlyMessage(e)}',
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
    final List<Map<String, dynamic>> filterChips = [];

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
        final classItem = _classList.firstWhere(
          (k) => k['id'].toString() == classId,
          orElse: () => {'name': 'Class #$classId'},
        );
        filterChips.add({
          'label':
              '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: ${classItem['name'] ?? classItem['nama']}',
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
              _attendanceSummaryList = cachedItems;
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
    if (_attendanceSummaryList.isEmpty && mounted) {
      setState(() {
        _isLoadingSummary = true;
      });
    }

    // Step 2: Fetch fresh from API
    await _fetchData();

    // Step 3: Save to cache (only default view, page 1, non-blocking)
    if (mounted) {
      final cacheKey = _buildSummaryCacheKey();
      if (cacheKey != null && _attendanceSummaryList.isNotEmpty) {
        final serialized = _attendanceSummaryList
            .map(
              (item) => {
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
              },
            )
            .toList();
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
      String? filterDate;
      String? filterDateStart;
      String? filterDateEnd;

      if (_selectedDateFilter == 'today') {
        filterDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      } else if (_selectedDateFilter == 'week') {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(Duration(days: 6));
        filterDateStart = DateFormat('yyyy-MM-dd').format(startOfWeek);
        filterDateEnd = DateFormat('yyyy-MM-dd').format(endOfWeek);
      } else if (_selectedDateFilter == 'month') {
        final now = DateTime.now();
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 0);
        filterDateStart = DateFormat('yyyy-MM-dd').format(startOfMonth);
        filterDateEnd = DateFormat('yyyy-MM-dd').format(endOfMonth);
      }

      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      // Call paginated API
      final result = await AttendanceService.getAttendanceSummaryPaginated(
        page: _currentPage,
        limit: _perPage,
        subjectId: _selectedSubjectIds.isNotEmpty
            ? _selectedSubjectIds.first
            : null,
        classId: _selectedClassIds.isNotEmpty ? _selectedClassIds.first : null,
        date: filterDate,
        dateStart: filterDateStart,
        dateEnd: filterDateEnd,
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
          _attendanceSummaryList = newItems;
        } else {
          _attendanceSummaryList.addAll(newItems);
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
        SnackBarUtils.showError(
          context,
          'Gagal memuat data laporan: ${ErrorUtils.getFriendlyMessage(e)}',
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
    final languageProvider = ref.read(languageRiverpod);

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
              padding: EdgeInsets.all(AppSpacing.lg),
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
                    onPressed: () => AppNavigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.all(AppSpacing.lg),
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
                        AppNavigator.pop(context);
                        AppNavigator.push(
                          context,
                          AttendancePage(teacher: teacher),
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
    showAttendanceReportFilterSheet(
      context: context,
      ref: ref,
      primaryColor: _getPrimaryColor(),
      initialDate: _selectedDateFilter,
      initialSubjectIds: _selectedSubjectIds,
      initialClassIds: _selectedClassIds,
      initialDayIds: _selectedDayIds,
      initialLessonHourIds: _selectedLessonHourIds,
      subjectList: _subjectList,
      classList: _classList,
      lessonHours: _lessonHours,
      onApply: (result) {
        setState(() {
          _selectedDateFilter = result.selectedDate;
          _selectedSubjectIds
            ..clear()
            ..addAll(result.selectedSubjectIds);
          _selectedClassIds
            ..clear()
            ..addAll(result.selectedClassIds);
          _selectedDayIds
            ..clear()
            ..addAll(result.selectedDayIds);
          _selectedLessonHourIds
            ..clear()
            ..addAll(result.selectedLessonHourIds);
          _checkActiveFilter();
        });
        _loadData(); // Reload data with new filters
      },
    );
  }

  Future<void> _loadTableData() async {
    if (!mounted) return;
    if (_selectedClassIds.isEmpty) {
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': 'Please select a class first',
          'id': 'Mohon pilih kelas terlebih dahulu',
        }),
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
      final academicYearId = ref
          .read(academicYearRiverpod)
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
      final students = await getIt<ApiClassService>().getStudentsByClassId(
        classId,
      );

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

      final attendanceResult = await AttendanceService.getAttendancePaginated(
        page: 1,
        limit: 1000,
        classId: classId,
        dateStart: startDate,
        dateEnd: endDate,
        academicYearId: academicYearId,
      );

      final List<dynamic> attendanceData = attendanceResult['data'] ?? [];

      if (!mounted) return;

      // Process Data
      final Set<String> dateSet = {};
      final Set<String> subjectIdSet = {};
      final Map<String, dynamic> attMap = {};

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
      final Map<String, dynamic> subjectMap = {};
      for (var s in _subjectList) {
        subjectMap[s['id'].toString()] = s['name'];
      }

      final List<AttendanceGridData> gridData = [];
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
          AttendanceGridData(
            studentId: id,
            nis: nis.toString(),
            name: name.toString(),
            attendance:
                attMap, // Pass the whole map, but simpler to pass subset?
            // Actually AttendanceGridData expects 'attendance' map.
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
          final DateTime? dt = AppDateUtils.parseApiDate(d);
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
        SnackBarUtils.showInfo(context, 'Failed to load table data: $e');
      }
    }
  }

  void _showExportDialog() {
    final languageProvider = ref.read(languageRiverpod);
    final academicYearProvider = ref.read(academicYearRiverpod);
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
    final List<DateTime> months = [];
    for (int i = 0; i < 12; i++) {
      months.add(DateTime(startYear, 7 + i, 1));
    }

    // Default Selection
    final List<DateTime> selectedMonths = [];

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
                    SizedBox(height: AppSpacing.sm),
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
                    SizedBox(height: AppSpacing.sm),
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
                  onPressed: () => AppNavigator.pop(context),
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
                          AppNavigator.pop(context);
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
    final languageProvider = ref.read(languageRiverpod);

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
        AppNavigator.pop(context); // Close loading
        SnackBarUtils.showSuccess(
          context,
          languageProvider.getTranslatedText({
            'en': 'Exported $successCount files successfully',
            'id': 'Berhasil mengexport $successCount file',
          }),
        );
      }
    } catch (e) {
      if (mounted) {
        AppNavigator.pop(context); // Close loading
        SnackBarUtils.showError(context, 'Export failed: $e');
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

    final academicYearProvider = ref.read(academicYearRiverpod);
    final academicYearId = academicYearProvider.selectedAcademicYear?['id']
        ?.toString();
    final academicYearName =
        academicYearProvider.selectedAcademicYear?['year']?.toString() ?? '-';

    // 1. Fetch Data
    final students = await getIt<ApiClassService>().getStudentsByClassId(
      classId,
    );

    final attendanceResult = await AttendanceService.getAttendancePaginated(
      page: 1,
      limit: 2000, // Ensure enough limit
      classId: classId,
      dateStart: startDate,
      dateEnd: endDate,
      academicYearId: academicYearId,
    );

    final List<dynamic> attendanceData = attendanceResult['data'] ?? [];

    if (attendanceData.isEmpty) {
      return; // Skip empty months? Or export empty file?
    }

    // 2. Map Data
    // Subject Map
    final Map<String, String> subjectMap = {};
    for (var s in _subjectList) {
      subjectMap[s['id'].toString()] = s['name'];
    }

    final List<Map<String, dynamic>> exportList = [];

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
    // Guard against widget being unmounted before the async work completes.
    if (!mounted) return;
    // We pass context for Localization
    await ExcelPresenceService.exportPresenceToExcel(
      presenceData: exportList,
      context: context,
      filters: {},
    );
  }

  List<AttendanceSummary> _getFilteredSummaries() {
    final searchTerm = _searchController.text.toLowerCase();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    return _attendanceSummaryList.where((summary) {
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

  Future<void> _deleteAttendance(
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
              padding: EdgeInsets.all(AppSpacing.xl),
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
              padding: EdgeInsets.all(AppSpacing.xl),
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
                  SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => AppNavigator.pop(context, false),
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
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => AppNavigator.pop(context, true),
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

        await AttendanceService.deleteAttendance(
          subjectId: summary.subjectId,
          classId: summary.classId,
          date: DateFormat('yyyy-MM-dd').format(summary.date),
          lessonHourId: summary.lessonHourId,
        );

        if (!mounted) return;
        SnackBarUtils.showSuccess(
          context,
          languageProvider.getTranslatedText({
            'en': 'Attendance deleted successfully',
            'id': 'Absensi berhasil dihapus',
          }),
        );

        _loadData(useCache: false);
      } catch (e) {
        setState(() {
          _isLoadingSummary = false;
        });
        if (!mounted) return;
        SnackBarUtils.showError(
          context,
          'Gagal menghapus absensi: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  void _navigateToAttendanceDetail(AttendanceSummary summary) {
    AppNavigator.push(
      context,
      AdminAttendanceDetailPage(
        subjectId: summary.subjectId,
        subjectName: summary.subjectName,
        date: summary.date,
        classId: summary.classId,
        className: summary.className,
        lessonHourId: summary.lessonHourId,
        lessonHourName: summary.lessonHourName,
        academicYearId: summary.academicYearId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
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
          // Header with gradient
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
                            _attendanceSummaryList.clear();
                          });
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
                      SizedBox(width: AppSpacing.sm),
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
                              SnackBarUtils.showInfo(
                                context,
                                languageProvider.getTranslatedText({
                                  'en': 'Please select a class first',
                                  'id': 'Mohon pilih kelas terlebih dahulu',
                                }),
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
                              Icon(
                                Icons.refresh,
                                size: 20,
                                color: ColorUtils.info600,
                              ),
                              SizedBox(width: AppSpacing.sm),
                              Text(AppLocalizations.updateData.tr),
                            ],
                          ),
                        ),
                        if (_selectedClassData != null)
                          PopupMenuItem<String>(
                            value: 'export',
                            child: Row(
                              children: [
                                Icon(Icons.file_download, size: 20),
                                SizedBox(width: AppSpacing.sm),
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
                SizedBox(height: AppSpacing.lg),

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
                                style: TextStyle(color: ColorUtils.slate800),
                                decoration: InputDecoration(
                                  hintText: languageProvider.getTranslatedText({
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
                    SizedBox(width: AppSpacing.sm),
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
                                padding: EdgeInsets.all(AppSpacing.xs),
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
                  SizedBox(height: AppSpacing.md),
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
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    side: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
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
                        SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: _clearAllFilters,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: EdgeInsets.all(AppSpacing.sm),
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
                ? AttendanceClassListView(
                    isLoading: _isLoadingClasses,
                    classList: _classList,
                    searchTerm: _searchController.text.toLowerCase(),
                    primaryColor: _getPrimaryColor(),
                    languageProvider: languageProvider,
                    onRefresh: _forceRefresh,
                    onClassSelected: (classItem) {
                      setState(() {
                        _selectedClassData = classItem;
                        _selectedClassIds.clear();
                        _selectedClassIds.add(classItem['id'].toString());
                        _loadData();
                      });
                    },
                  )
                : _showTableView
                ? AttendanceTableView(
                    isLoading: _isTableLoading,
                    selectedClassIds: _selectedClassIds,
                    attendanceDataSource: _attendanceDataSource,
                    studentList: _studentList,
                    uniqueDates: _uniqueDates,
                    uniqueSubjectIds: _uniqueSubjectIds,
                    primaryColor: _getPrimaryColor(),
                    languageProvider: languageProvider,
                  )
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
                      return AdminAttendanceSummaryCard(
                        summary: summary,
                        primaryColor: _getPrimaryColor(),
                        languageProvider: languageProvider,
                        onTap: () => _navigateToAttendanceDetail(summary),
                        onDelete: () =>
                            _deleteAttendance(summary, languageProvider),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    if (_isTourShowing) return;
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'presence_report',
        'admin',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
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
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

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
        getIt<ApiTourService>().completeTour(
          name: 'admin_presence_report_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('presence_report', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        setState(() {
          _isTourShowing = false;
        });
        getIt<ApiTourService>().completeTour(
          name: 'admin_presence_report_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('presence_report', 'admin'),
          {'should_show': false},
        );
        return true;
      },
      onClickOverlay: (target) {
        // Optional handle
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

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

// AttendanceGridData and AttendanceDataSource have been extracted to
// attendance_grid_data.dart in the widgets directory.
