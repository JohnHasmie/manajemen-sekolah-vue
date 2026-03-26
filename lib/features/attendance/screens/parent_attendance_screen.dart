// Parent view of student attendance (presence) records.
// Like `pages/parent/Attendance.vue` in a Vue app.
//
// Read-only view of a child's attendance with monthly summary stats
// (hadir/terlambat/izin/sakit/alpha), month/semester filters, and
// auto-marking records as read when scrolled into view.
// In Laravel terms: `AttendanceController@parentIndex`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/models/student.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Parent's read-only view of a child's attendance with monthly summaries
/// and read tracking.
///
/// Props (like Vue props): [parent] data, [studentId], optional [academicYearId].
class PresenceParentPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> parent;
  final String studentId; // Student ID belonging to the parent/guardian
  final String? academicYearId;

  const PresenceParentPage({
    super.key,
    required this.parent,
    required this.studentId,
    this.academicYearId,
  });

  @override
  PresenceParentPageState createState() => PresenceParentPageState();
}

/// State for [PresenceParentPage].
///
/// Like a Vue page component with `data() { return {...} }`. Key state:
/// - [_attendanceData] -- attendance records from API
/// - [_student] -- the child's data (Student model)
/// - [_monthlySummary] -- computed attendance counts per status type
/// - Month/semester filters and visibility-based read tracking
///
/// `setState()` is like Vue's reactivity -- triggers a re-render.
class PresenceParentPageState extends ConsumerState<PresenceParentPage> {
  List<dynamic> _attendanceData = [];
  Student? _student;
  bool _isLoading = true;
  String? _selectedMonthFilter;
  String? _selectedSemesterFilter;
  bool _hasActiveFilter = false;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, int> _monthlySummary = {
    'hadir': 0,
    'terlambat': 0,
    'izin': 0,
    'sakit': 0,
    'alpha': 0,
  };

  final GlobalKey _monthlySummaryKey = GlobalKey();
  final GlobalKey _attendanceListKey = GlobalKey();

  // Visibility Tracking
  final Set<String> _processedIds = {}; // IDs we've already handled/queued
  final Set<String> _pendingReadIds = {}; // IDs waiting to be sent to API
  Timer? _markReadDebounce;

  @override
  void dispose() {
    _markReadDebounce?.cancel(); // Cancel visibility debounce
    if (_pendingReadIds.isNotEmpty) {
      _flushMarkReadSilently(List.from(_pendingReadIds));
      _pendingReadIds.clear();
    }
    super.dispose();
  }

  Future<void> _flushMarkReadSilently(List<String> ids) async {
    try {
      await ApiService.markPresenceAsRead(ids);
    } catch (e) {
      AppLogger.error('attendance', e);
    }
  }

  void _onItemVisible(Map<String, dynamic> record) {
    final id = record['id'].toString();
    final isRead =
        record['is_read'] == true ||
        record['is_read'] == 1 ||
        record['is_read'] == '1';

    if (!isRead && !_processedIds.contains(id)) {
      _processedIds.add(id);
      _pendingReadIds.add(id);
      _scheduleMarkRead();
    }
  }

  void _scheduleMarkRead() {
    if (_markReadDebounce?.isActive ?? false) return;

    _markReadDebounce = Timer(const Duration(seconds: 1), () {
      if (_pendingReadIds.isNotEmpty) {
        final idsToMark = _pendingReadIds.toList();
        _pendingReadIds.clear(); // Clear pending first to avoid duplicates
        _flushMarkRead(idsToMark);
      }
    });
  }

  Future<void> _flushMarkRead(List<String> ids) async {
    try {
      AppLogger.debug('attendance', 'Auto-marking ${ids.length} visible presence as read...');

      // Optimistic Update (update local list UI immediately)
      if (!mounted) return;
      setState(() {
        for (var item in _attendanceData) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await ApiService.markPresenceAsRead(ids);
    } catch (e) {
      AppLogger.error('attendance', e);
    }
  }

  String get _cacheKey =>
      'parent_presence_${widget.studentId}_${widget.academicYearId ?? "default"}';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.invalidate(_cacheKey);
    await LocalCacheService.clearStartingWith('tour_parent_presence_');
    _loadData(useCache: false);
  }

  Future<void> _loadData({bool useCache = true}) async {
    // Try cache — return early if hit
    if (useCache) {
      final cached = await LocalCacheService.load(_cacheKey, ttl: const Duration(hours: 3));
      if (cached != null && cached is Map<String, dynamic>) {
        if (!mounted) return;
        if (cached['attendanceData'] != null) {
          setState(() {
            _attendanceData = cached['attendanceData'] as List;
            if (cached['studentData'] != null) {
              _student = Student.fromJson(
                Map<String, dynamic>.from(cached['studentData'] as Map),
              );
            }
            _calculateMonthlySummary();
            _isLoading = false;
          });
          AppLogger.debug('attendance', 'PresenceParent: from cache (${_attendanceData.length})');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _student != null) _checkAndShowTour();
          });
          return;
        }
      }
    }

    // No cache — fetch from API
    if (_attendanceData.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final userId = widget.parent['id']?.toString();
      final guardianEmail = widget.parent['email']?.toString();

      final studentData = await getIt<ApiStudentService>().getStudent(
        userId: userId,
        guardianEmail: guardianEmail,
      );
      final student = studentData
          .map((s) => Student.fromJson(s))
          .firstWhere((s) => s.id == widget.studentId);

      final attendanceData = await ApiService.getAttendance(
        studentId: widget.studentId,
        academicYearId: widget.academicYearId,
      );

      if (!mounted) return;
      setState(() {
        _student = student;
        _attendanceData = attendanceData;
        _calculateMonthlySummary();
        _isLoading = false;
      });

      // Save to cache (non-blocking)
      LocalCacheService.save(_cacheKey, {
        'studentData': student.toJson(),
        'attendanceData': attendanceData,
      });

      // Mark notifications as read — only if there are unread items
      final hasUnread = attendanceData.any((a) =>
          a['is_read'] != true && a['is_read'] != 1 && a['is_read'] != '1');
      if (hasUnread) {
        ApiService.markAttendanceRead(studentId: widget.studentId);
      }
    } catch (e) {
      AppLogger.error('attendance', e);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (_attendanceData.isEmpty && mounted) {
                SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _student != null) _checkAndShowTour();
      });
    }
  }

  Future<void> _checkAndShowTour() async {
    try {
      // Cache-only: tour status pre-fetched from dashboard
      final tourCacheKey = CacheKeyBuilder.tourStatus('parent_presence_screen', 'wali');
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
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
      AppLogger.error('attendance', e);
    }
  }

  void _showTour() {
    List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

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
        getIt<ApiTourService>().completeTour(name: 'parent_presence_screen_tour', role: 'wali', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('parent_presence_screen', 'wali'), {'should_show': false});
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(name: 'parent_presence_screen_tour', role: 'wali', platform: 'mobile');
        LocalCacheService.save(CacheKeyBuilder.tourStatus('parent_presence_screen', 'wali'), {'should_show': false});
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "MonthlySummary",
        keyTarget: _monthlySummaryKey,
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
                      'en': 'Attendance Recap',
                      'id': 'Rekap Absensi',
                    }),
                    style: const TextStyle(
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
                            'See the overall attendance percentage and the breakdown of present, late, permitted, sick, and absent.',
                        'id':
                            'Lihat persentase kehadiran keseluruhan dan rincian hadir, terlambat, izin, sakit, dan alpha.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
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
        identify: "AbsensiList",
        keyTarget: _attendanceListKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Attendance History',
                      'id': 'Riwayat Kehadiran',
                    }),
                    style: const TextStyle(
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
                            'The list of your child\'s detailed daily attendance history.',
                        'id':
                            'Daftar riwayat kehadiran harian anak Anda secara rinci.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
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

  void _calculateMonthlySummary() {
    // Reset summary
    _monthlySummary.updateAll((key, value) => 0);

    for (var record in _attendanceData) {
      final date = _parseLocalDate(record['tanggal']);

      // Apply same filter logic for summary
      if (_selectedMonthFilter != null) {
        if (date.month.toString() != _selectedMonthFilter) continue;
      }

      if (_selectedSemesterFilter != null) {
        final month = date.month;
        final semester = (month >= 7) ? '1' : '2';
        if (semester != _selectedSemesterFilter) continue;
      }

      final status = _normalizeStatus(record['status']);
      _monthlySummary[status] = (_monthlySummary[status] ?? 0) + 1;
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedMonthFilter != null ||
          _selectedSemesterFilter != null ||
          _searchController.text.isNotEmpty;
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedMonthFilter = null;
      _selectedSemesterFilter = null;
      _searchController.clear();
      _hasActiveFilter = false;
    });
  }

  void _showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);

    String? tempMonthFilter = _selectedMonthFilter;
    String? tempSemesterFilter = _selectedSemesterFilter;

    final months = [
      {'en': 'January', 'id': 'Januari', 'val': '1'},
      {'en': 'February', 'id': 'Februari', 'val': '2'},
      {'en': 'March', 'id': 'Maret', 'val': '3'},
      {'en': 'April', 'id': 'April', 'val': '4'},
      {'en': 'May', 'id': 'Mei', 'val': '5'},
      {'en': 'June', 'id': 'Juni', 'val': '6'},
      {'en': 'July', 'id': 'Juli', 'val': '7'},
      {'en': 'August', 'id': 'Agustus', 'val': '8'},
      {'en': 'September', 'id': 'September', 'val': '9'},
      {'en': 'October', 'id': 'Oktober', 'val': '10'},
      {'en': 'November', 'id': 'November', 'val': '11'},
      {'en': 'December', 'id': 'Desember', 'val': '12'},
    ];

    final semesters = [
      {'en': 'Semester 1', 'id': 'Semester 1', 'val': '1'},
      {'en': 'Semester 2', 'id': 'Semester 2', 'val': '2'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
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
                  padding: EdgeInsets.fromLTRB(20, 14, 16, 20),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.filter_list,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Filter Attendance',
                                'id': 'Filter Absensi',
                              }),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempMonthFilter = null;
                                tempSemesterFilter = null;
                              });
                            },
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Reset',
                                'id': 'Reset',
                              }),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month section
                        _buildSectionHeader(
                          languageProvider.getTranslatedText({
                            'en': 'Month',
                            'id': 'Bulan',
                          }),
                          Icons.calendar_month_outlined,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: months.map((m) {
                            final val = m['val']!;
                            final isSelected = tempMonthFilter == val;
                            final label = languageProvider.getTranslatedText({
                              'en': m['en']!,
                              'id': m['id']!,
                            });
                            return FilterChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (selected) {
                                setSheetState(() {
                                  tempMonthFilter = selected ? val : null;
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

                        // Semester section
                        _buildSectionHeader(
                          languageProvider.getTranslatedText({
                            'en': 'Semester',
                            'id': 'Semester',
                          }),
                          Icons.school_outlined,
                        ),
                        SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: semesters.map((s) {
                            final val = s['val']!;
                            final isSelected = tempSemesterFilter == val;
                            final label = languageProvider.getTranslatedText({
                              'en': s['en']!,
                              'id': s['id']!,
                            });
                            return FilterChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (selected) {
                                setSheetState(() {
                                  tempSemesterFilter = selected ? val : null;
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

                // Footer buttons
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: ColorUtils.slate200)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => AppNavigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 13),
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
                            style: TextStyle(
                              color: ColorUtils.slate700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedMonthFilter = tempMonthFilter;
                              _selectedSemesterFilter = tempSemesterFilter;
                              _checkActiveFilter();
                            });
                            AppNavigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 13),
                            backgroundColor: _getPrimaryColor(),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            languageProvider.getTranslatedText({
                              'en': 'Apply Filter',
                              'id': 'Terapkan Filter',
                            }),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

    if (_selectedMonthFilter != null) {
      final months = [
        {'en': 'January', 'id': 'Januari', 'val': '1'},
        {'en': 'February', 'id': 'Februari', 'val': '2'},
        {'en': 'March', 'id': 'Maret', 'val': '3'},
        {'en': 'April', 'id': 'April', 'val': '4'},
        {'en': 'May', 'id': 'Mei', 'val': '5'},
        {'en': 'June', 'id': 'Juni', 'val': '6'},
        {'en': 'July', 'id': 'Juli', 'val': '7'},
        {'en': 'August', 'id': 'Agustus', 'val': '8'},
        {'en': 'September', 'id': 'September', 'val': '9'},
        {'en': 'October', 'id': 'Oktober', 'val': '10'},
        {'en': 'November', 'id': 'November', 'val': '11'},
        {'en': 'December', 'id': 'Desember', 'val': '12'},
      ];
      final month = months.firstWhere((m) => m['val'] == _selectedMonthFilter);
      final label = languageProvider.getTranslatedText({
        'en': month['en']!,
        'id': month['id']!,
      });
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Month', 'id': 'Bulan'})}: $label',
        'onRemove': () {
          setState(() {
            _selectedMonthFilter = null;
            _checkActiveFilter();
          });
        },
      });
    }

    if (_selectedSemesterFilter != null) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Semester', 'id': 'Semester'})}: $_selectedSemesterFilter',
        'onRemove': () {
          setState(() {
            _selectedSemesterFilter = null;
            _checkActiveFilter();
          });
        },
      });
    }

    if (_searchController.text.isNotEmpty) {
      filterChips.add({
        'label':
            '${languageProvider.getTranslatedText({'en': 'Search', 'id': 'Cari'})}: ${_searchController.text}',
        'onRemove': () {
          setState(() {
            _searchController.clear();
            _checkActiveFilter();
          });
        },
      });
    }

    return filterChips;
  }

  // Pattern #11 filter section header
  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(top: 24, bottom: 0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: ColorUtils.slate700),
          SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  // Pattern #8 info tag chip
  Widget _buildInfoTag(IconData icon, String text, {Color? tagColor}) {
    final c = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tagColor != null
              ? tagColor.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary() {
    final languageProvider = ref.read(languageRiverpod);
    final totalDays = _monthlySummary.values.reduce((a, b) => a + b);
    final presentaseAbsensi = totalDays > 0
        ? ((_monthlySummary['hadir']! + _monthlySummary['terlambat']!) /
                  totalDays *
                  100)
              .round()
        : 0;

    return Container(
      key: _monthlySummaryKey,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        children: [
          // Header with month
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _hasActiveFilter
                    ? languageProvider.getTranslatedText({
                        'en': 'Filtered Recap',
                        'id': 'Rekap Terfilter',
                      })
                    : languageProvider.getTranslatedText({
                        'en': 'Yearly Recap',
                        'id': 'Rekap Tahunan',
                      }),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Persentase kehadiran
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: _getPrimaryColor().withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getPrimaryColor().withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$presentaseAbsensi%',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _getPrimaryColor(),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppLocalizations.attendanceRate.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: _getPrimaryColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Detail status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                AppLocalizations.present.tr,
                _monthlySummary['hadir']!,
                _getStatusColor('hadir'),
              ),
              _buildStatItem(
                AppLocalizations.late.tr,
                _monthlySummary['terlambat']!,
                _getStatusColor('terlambat'),
              ),
              _buildStatItem(
                AppLocalizations.permission.tr,
                _monthlySummary['izin']!,
                _getStatusColor('izin'),
              ),
              _buildStatItem(
                AppLocalizations.sick.tr,
                _monthlySummary['sakit']!,
                _getStatusColor('sakit'),
              ),
              _buildStatItem(
                AppLocalizations.alpha.tr,
                _monthlySummary['alpha']!,
                _getStatusColor('alpha'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: ColorUtils.slate500),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAttendanceList() {
    final filteredAttendance =
        _attendanceData.where((record) {
          final date = _parseLocalDate(record['tanggal']);

          // Month Filter
          if (_selectedMonthFilter != null) {
            if (date.month.toString() != _selectedMonthFilter) {
              return false;
            }
          }

          // Semester Filter (1: July-Dec, 2: Jan-June)
          if (_selectedSemesterFilter != null) {
            final month = date.month;
            final semester = (month >= 7) ? '1' : '2';
            if (semester != _selectedSemesterFilter) {
              return false;
            }
          }

          // Search Filter
          if (_searchController.text.isNotEmpty) {
            final query = _searchController.text.toLowerCase();
            final subject = (record['mata_pelajaran_nama'] ?? '')
                .toString()
                .toLowerCase();
            final status = (record['status'] ?? '').toString().toLowerCase();
            if (!subject.contains(query) && !status.contains(query)) {
              return false;
            }
          }

          return true;
        }).toList()..sort((a, b) {
          final dateA = a['tanggal']?.toString() ?? '';
          final dateB = b['tanggal']?.toString() ?? '';
          return dateB.compareTo(dateA);
        });

    if (filteredAttendance.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.calendar_today,
                size: 36,
                color: ColorUtils.slate400,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppLocalizations.noPresenceData.tr,
              style: TextStyle(
                color: ColorUtils.slate700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_hasActiveFilter) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Try adjusting your filters',
                style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No attendance records found for this year',
                style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: filteredAttendance.length,
      itemBuilder: (context, index) {
        final record = filteredAttendance[index];
        return Builder(
          builder: (context) {
            _onItemVisible(record);
            return _buildAttendanceItem(record);
          },
        );
      },
    );
  }

  // Pattern #8: Material > InkWell > Container with corporateShadow
  Widget _buildAttendanceItem(Map<String, dynamic> record) {
    final status = _normalizeStatus(record['status']);
    final date = _parseLocalDate(record['tanggal']);
    final subjectName =
        record['mata_pelajaran_nama'] ?? AppLocalizations.subject.tr;
    final Color statusColor = _getStatusColor(status);
    final String statusText = _getTranslatedStatus(status);
    final String day = DateFormat(
      'EEEE',
      ref.watch(languageRiverpod).currentLanguage == 'id'
          ? 'id_ID'
          : 'en_US',
    ).format(date);

    final isRead =
        record['is_read'] == true ||
        record['is_read'] == 1 ||
        record['is_read'] == '1';

    // Get lesson hour name
    final lessonHourName =
        (record['lesson_hour_name'] ??
                record['jam_pelajaran_nama'] ??
                (record['lesson_hour'] != null
                    ? record['lesson_hour']['name']
                    : null))
            ?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: date box
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getPrimaryColor().withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getPrimaryColor().withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _getPrimaryColor(),
                        ),
                      ),
                      Text(
                        DateFormat(
                          'MMM',
                          ref.watch(languageRiverpod).currentLanguage ==
                                  'id'
                              ? 'id_ID'
                              : 'en_US',
                        ).format(date),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getPrimaryColor(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Middle: subject + day + info tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      // Info tags row
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          _buildInfoTag(
                            Icons.calendar_today_outlined,
                            DateFormat(
                              'dd MMM yyyy',
                              ref.watch(languageRiverpod)
                                          .currentLanguage ==
                                      'id'
                                  ? 'id_ID'
                                  : 'en_US',
                            ).format(date),
                          ),
                          if (lessonHourName != null &&
                              lessonHourName.isNotEmpty)
                            _buildInfoTag(
                              Icons.access_time_outlined,
                              lessonHourName,
                            ),
                          _buildInfoTag(
                            _getStatusIcon(status),
                            statusText,
                            tagColor: statusColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),

                // Right: unread dot
                if (!isRead)
                  Container(
                    width: 8,
                    height: 8,
                    margin: EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: ColorUtils.error600,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'hadir':
        return Icons.check_circle_outline;
      case 'terlambat':
        return Icons.watch_later_outlined;
      case 'izin':
        return Icons.assignment_turned_in_outlined;
      case 'sakit':
        return Icons.local_hospital_outlined;
      case 'alpha':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'izin':
        return ColorUtils.info600;
      case 'sakit':
        return ColorUtils.warning600;
      case 'alpha':
        return ColorUtils.error600;
      case 'terlambat':
        return ColorUtils.corporateBlue600;
      default: // hadir
        return ColorUtils.success600;
    }
  }

  String _getTranslatedStatus(String? status) {
    if (status == null) return '-';
    // Normalize status just in case
    String s = status.trim();
    if (s.toLowerCase() == 'hadir') return AppLocalizations.present.tr;
    if (s.toLowerCase() == 'telat' || s.toLowerCase() == 'terlambat') {
      return AppLocalizations.late.tr;
    }
    if (s.toLowerCase() == 'izin') return AppLocalizations.permission.tr;
    if (s.toLowerCase() == 'sakit') return AppLocalizations.sick.tr;
    if (s.toLowerCase() == 'alpha') return AppLocalizations.alpha.tr;
    return status;
  }

  String _normalizeStatus(dynamic rawStatus) {
    String status = (rawStatus ?? 'alpha').toString().toLowerCase();

    // Map English/Mixed to standard keys
    if (status == 'present') return 'hadir';
    if (status == 'permission') return 'izin';
    if (status == 'excused') return 'izin'; // excused = izin
    if (status == 'sick') return 'sakit';
    if (status == 'late') return 'terlambat';
    if (status == 'absent') return 'alpha';

    // Map capitalized Indonesian to lowercase
    if (status == 'hadir') return 'hadir';
    if (status == 'izin') return 'izin';
    if (status == 'sakit') return 'sakit';
    if (status == 'terlambat') return 'terlambat';
    if (status == 'alpha') return 'alpha';
    if (status == 'alpa') return 'alpha';

    // Default fallback if it matches one of our keys
    if (_monthlySummary.containsKey(status)) return status;

    return 'alpha'; // Default to alpha for unknown status (safer than hadir)
  }

  // Helper function to parse date string as local date (not UTC)
  DateTime _parseLocalDate(dynamic dateValue) {
    // Use AppDateUtils for consistent and correct parsing
    return AppDateUtils.parseApiDate(dateValue) ?? DateTime.now();
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('wali');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  // Pattern #7: Gradient header
  Widget _buildHeader() {
    final languageProvider = ref.read(languageRiverpod);
    return Container(
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
                onTap: () => AppNavigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.childPresence.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_student != null) ...[
                      SizedBox(height: 2),
                      Text(
                        _student!.name,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'refresh') _forceRefresh();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                        SizedBox(width: AppSpacing.sm),
                        Text('Perbarui Data'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),

          // Search and Filter Row
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _checkActiveFilter();
                      _calculateMonthlySummary();
                      setState(() {});
                    },
                    style: TextStyle(color: ColorUtils.slate900),
                    decoration: InputDecoration(
                      hintText: languageProvider.getTranslatedText({
                        'en': 'Search subject or status...',
                        'id': 'Cari mapel atau status...',
                      }),
                      hintStyle: TextStyle(color: ColorUtils.slate400),
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
              ),
              SizedBox(width: AppSpacing.md),
              GestureDetector(
                onTap: _showFilterSheet,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _hasActiveFilter
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.tune_rounded,
                          color: _hasActiveFilter
                              ? _getPrimaryColor()
                              : Colors.white,
                          size: 22,
                        ),
                      ),
                      if (_hasActiveFilter)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: ColorUtils.error600,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Filter Chips
          if (_hasActiveFilter) ...[
            SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._buildFilterChips(languageProvider).map((chip) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: chip['onRemove'],
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chip['label'],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.close, size: 14, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  InkWell(
                    onTap: _clearAllFilters,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Clear All',
                          'id': 'Hapus Semua',
                        }),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.read(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(
                    itemCount: 6,
                    infoTagCount: 2,
                    baseColor: _getPrimaryColor().withValues(alpha: 0.15),
                    highlightColor: _getPrimaryColor().withValues(alpha: 0.05),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info siswa
                      Container(
                        margin: const EdgeInsets.all(AppSpacing.lg),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ColorUtils.slate200),
                          boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: _getPrimaryColor().withValues(
                                  alpha: 0.1,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _getPrimaryColor().withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Icon(
                                Icons.person,
                                color: _getPrimaryColor(),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _student?.name ??
                                        AppLocalizations.studentName.tr,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: ColorUtils.slate900,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'NIS: ${_student?.studentNumber ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: ColorUtils.slate600,
                                    ),
                                  ),
                                  Text(
                                    'Kelas: ${_student?.className ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: ColorUtils.slate600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Summary bulanan
                      _buildMonthlySummary(),

                      // Daftar absensi
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Attendance History',
                            'id': 'Riwayat Absensi',
                          }),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: ColorUtils.slate900,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      Expanded(
                        child: Container(
                          key: _attendanceListKey,
                          child: _buildAttendanceList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
