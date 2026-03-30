// Teaching schedule screen -- the teacher's timetable/calendar view.
// Like `pages/teacher/Schedule.vue` in a Vue app.
//
// Displays the teacher's weekly schedule with two view modes: card view
// and table (grid) view. Supports filtering by day, semester, class,
// real-time sync via FCM push notifications, and quick navigation to
// related screens (attendance, class activity, materials).
// In Laravel terms: `ScheduleController@index` with multiple view formats.
//
// All data-fetching, caching and pure helpers have been extracted into
// [TeacherScheduleController]. This file only owns `setState` calls,
// lifecycle hooks, dialogs, and the widget tree.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/teacher_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_card_view.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_filter_sheet.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';

/// Teacher's weekly schedule screen with card and table view modes.
///
/// A StatefulWidget with no constructor params -- it reads teacher data from
/// SharedPreferences and TeacherProvider internally.
class TeachingScheduleScreen extends ConsumerStatefulWidget {
  const TeachingScheduleScreen({super.key});

  @override
  TeachingScheduleScreenState createState() => TeachingScheduleScreenState();
}

/// State for [TeachingScheduleScreen].
///
/// Like a Vue page component with `data() { return {...} }`. Manages:
/// - [_scheduleList] -- schedule entries from API
/// - [_isTableView] -- toggle between card and table layout
/// - [_isHomeroomView] -- special view for homeroom teachers
/// - Filter state (day, semester, class)
/// - Real-time sync via FCM push notifications
/// - Onboarding tour
///
/// `setState()` is like Vue's reactivity -- triggers a re-render when data changes.
class TeachingScheduleScreenState
    extends ConsumerState<TeachingScheduleScreen> {
  // Static in-memory cache for instant display on revisit (no async needed)
  static List<dynamic>? _memCachedSchedules;
  static List<Map<String, String>>? _memCachedClasses;

  List<dynamic> _scheduleList = [];
  List<dynamic> _termList = [];
  bool _isLoading = true;
  String _teacherId = '';
  String _teacherNama = '';
  // Stored for future year-picker UI; populated by _loadAcademicYearData.
  // ignore: unused_field
  List<dynamic> _academicYearList = [];
  String _selectedTerm = '1'; // Will be set by _setDefaultAcademicPeriod()
  String _selectedAcademicYear =
      '2024/2025'; // Will be set by _setDefaultAcademicPeriod()
  final TextEditingController _searchController = TextEditingController();

  // Filter state
  List<String> _selectedDayIds = [];
  String? _selectedFilterSemester;
  String? _selectedClassId;
  bool _hasActiveFilter = false;
  List<Map<String, String>> _availableClasses = [];

  // Homeroom State
  List<dynamic> _homeroomClassesList = []; // Support multiple classes
  Map<String, dynamic>?
  _selectedHomeroomClass; // Current selected homeroom class
  bool _isHomeroomView = false;

  // RE-ADDED: Toggle between card and table view
  bool _isTableView = false;

  // Last known cache key for early cache loading
  static const String _prefKeyLastCacheKey = 'schedule_last_cache_key';

  // Tour properties
  final GlobalKey _toggleViewKey = GlobalKey();
  final GlobalKey _searchFilterKey = GlobalKey();
  final GlobalKey _firstScheduleKey = GlobalKey();
  final GlobalKey _actionButtonsKey = GlobalKey();

  List<String> _dayOptions = [
    'Semua Hari',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  Map<String, String> _dayIdMap = {
    'Senin': '1',
    'Selasa': '2',
    'Rabu': '3',
    'Kamis': '4',
    'Jumat': '5',
    'Sabtu': '6',
  };

  final Map<String, Color> _dayColorMap = {
    'Senin': ColorUtils.indigo500,
    'Selasa': ColorUtils.emerald500,
    'Rabu': ColorUtils.amber500,
    'Kamis': ColorUtils.red500,
    'Jumat': ColorUtils.violet500,
    'Sabtu': ColorUtils.cyan500,
  };

  /// Like Vue's `mounted()` -- sets academic year defaults, loads teacher data,
  /// and subscribes to FCM real-time sync notifications (like a Vue event bus
  /// or WebSocket listener for live updates).
  @override
  void initState() {
    super.initState();

    // Instantly restore from static in-memory cache (synchronous, no async)
    if (_memCachedSchedules != null && _memCachedClasses != null) {
      _scheduleList = _memCachedSchedules!;
      _availableClasses = _memCachedClasses!;
      _isLoading = false;
      AppLogger.debug('schedule', 'Instant restore from static memory cache');
    }

    _setDefaultAcademicPeriod();
    _loadUserData();

    // Listen to real-time sync trigger
    FCMService().syncTrigger.addListener(_onSyncTriggered);
  }

  void _onSyncTriggered() {
    final trigger = FCMService().syncTrigger.value;
    if (trigger != null && trigger['type'] == 'refresh_schedules') {
      if (mounted) {
        AppLogger.debug('schedule', 'Sync triggered: refresh_schedules');
        _loadSchedule();
      }
    }
  }

  /// Set default academic year based on current date.
  /// Delegates the date calculation to the controller (pure logic).
  void _setDefaultAcademicPeriod() {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    setState(() {
      _selectedAcademicYear = ctrl.getCurrentAcademicYear();
      // Semester will be set by _loadTermData called from _loadUserData
    });
  }

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _searchController.dispose();
    super.dispose();
  }

  /// Loads the current teacher profile and triggers schedule loading.
  /// Uses a multi-layer cache: SharedPreferences -> LocalCacheService -> API.
  Future<void> _loadUserData() async {
    AppLogger.debug(
      'schedule',
      '===== TeachingScheduleScreen: _loadUserData STARTED =====',
    );
    try {
      // ─── Step 1: Try TeacherProvider (populated by Dashboard) ───
      final teacherProvider = ref.read(teacherRiverpod);

      // Early cache load for instant display (while provider/API resolves)
      final prefs = PreferencesService();
      final lastCacheKey = prefs.getString(_prefKeyLastCacheKey);
      if (lastCacheKey != null) {
        try {
          final cached = await LocalCacheService.load(
            lastCacheKey,
            ttl: const Duration(hours: 3),
          );
          if (cached != null && mounted) {
            final cachedData = Map<String, dynamic>.from(cached);
            setState(() {
              _scheduleList = List<dynamic>.from(cachedData['schedules'] ?? []);
              _availableClasses =
                  (cachedData['availableClasses'] as List<dynamic>?)
                      ?.map((e) => Map<String, String>.from(e))
                      .toList() ??
                  [];
              _isLoading = false;
            });
            AppLogger.info(
              'schedule',
              'Early schedule cache loaded (key: $lastCacheKey)',
            );
          }
        } catch (e) {
          AppLogger.error('schedule', 'Early schedule cache failed: $e');
        }
      }

      if (teacherProvider.isLoaded && teacherProvider.teacherId != null) {
        // ✅ Use cached data from provider — no API calls needed
        AppLogger.debug(
          'schedule',
          'Using TeacherProvider cache (teacherId=${teacherProvider.teacherId})',
        );

        setState(() {
          _teacherId = teacherProvider.teacherId!;
          _teacherNama = teacherProvider.teacherName ?? 'Guru';
          _homeroomClassesList = teacherProvider.homeroomClasses
              .map((cls) => Map<String, dynamic>.from(cls))
              .toList();

          if (_homeroomClassesList.isNotEmpty &&
              _selectedHomeroomClass == null) {
            _selectedHomeroomClass = _homeroomClassesList.first;
          }
        });

        // Load reference data in parallel, then fetch schedule
        await Future.wait([
          _loadDayData(),
          _loadTermData(),
          _loadAcademicYearData(),
        ]);
        _loadSchedule();
        return;
      }

      // ─── Step 2: Fallback — fetch from API (direct navigation, deep link, etc.) ───
      AppLogger.debug('schedule', 'TeacherProvider empty, falling back to API');

      final userDataStr = prefs.getString('user');
      final userData = json.decode(userDataStr ?? '{}');
      final userId = userData['id']?.toString() ?? '';

      setState(() {
        _teacherId = userId; // Fallback
        _teacherNama = userData['nama']?.toString() ?? 'Guru';
      });

      if (userId.isNotEmpty) {
        String? resolvedTeacherId;

        try {
          final looksLikeTeacher =
              userData.containsKey('employee_number') ||
              userData.containsKey('nip') ||
              userData.containsKey('user_id');

          if (looksLikeTeacher) {
            resolvedTeacherId = userId;
            AppLogger.debug(
              'schedule',
              'Use ID from prefs directly: $resolvedTeacherId',
            );
          } else {
            String? academicYearId;
            try {
              if (mounted) {
                academicYearId = ref
                    .read(academicYearRiverpod)
                    .selectedAcademicYear?['id']
                    ?.toString();
              }
            } catch (e) {} // ignore: empty_catches

            // Ensure TeacherProvider is loaded for future screens
            await teacherProvider.ensureLoaded(academicYearId: academicYearId);

            if (teacherProvider.teacherId != null) {
              resolvedTeacherId = teacherProvider.teacherId;
            } else {
              final teacherData = await getIt<ApiTeacherService>()
                  .getTeacherByUserId(userId, academicYearId: academicYearId);
              if (teacherData != null && teacherData['id'] != null) {
                resolvedTeacherId = teacherData['id'].toString();
              }
            }
          }
        } catch (e) {
          AppLogger.error('schedule', 'Error resolving teacher ID: $e');
        }

        if (resolvedTeacherId != null) {
          AppLogger.info('schedule', 'Resolved Teacher ID: $resolvedTeacherId');
          setState(() {
            _teacherId = resolvedTeacherId!;
          });

          // Use homeroom classes from provider if available
          if (teacherProvider.isLoaded) {
            setState(() {
              _homeroomClassesList = teacherProvider.homeroomClasses
                  .map((cls) => Map<String, dynamic>.from(cls))
                  .toList();

              if (_homeroomClassesList.isNotEmpty &&
                  _selectedHomeroomClass == null) {
                _selectedHomeroomClass = _homeroomClassesList.first;
              }
            });
          } else {
            // Last resort: fetch classes directly
            String? academicYearId;
            try {
              if (mounted) {
                academicYearId = ref
                    .read(academicYearRiverpod)
                    .selectedAcademicYear?['id']
                    ?.toString();
              }
            } catch (e) {} // ignore: empty_catches

            final allTeacherClasses = await getIt<ApiTeacherService>()
                .getTeacherClasses(
                  resolvedTeacherId,
                  academicYearId: academicYearId,
                );

            final homeroomClasses = <Map<String, dynamic>>[];
            for (var cls in allTeacherClasses) {
              final isHomeroom =
                  cls['is_homeroom'] == true ||
                  cls['is_homeroom'] == 1 ||
                  cls['is_homeroom'].toString().toLowerCase() == 'true' ||
                  cls['is_homeroom'].toString() == '1';
              if (isHomeroom) {
                homeroomClasses.add(Map<String, dynamic>.from(cls));
              }
            }

            setState(() {
              _homeroomClassesList = homeroomClasses;
              if (_homeroomClassesList.isNotEmpty &&
                  _selectedHomeroomClass == null) {
                _selectedHomeroomClass = _homeroomClassesList.first;
              }
            });
          }
        } else {
          AppLogger.error('schedule', 'Failed to resolve Teacher ID');
        }

        // Load reference data in parallel, then fetch schedule
        await Future.wait([
          _loadDayData(),
          _loadTermData(),
          _loadAcademicYearData(),
        ]);
        _loadSchedule();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('schedule', 'Error in _loadUserData: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDayData() async {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    final result = await ctrl.loadDayData();
    if (result != null && mounted) {
      setState(() {
        _dayIdMap = result.dayIdMap;
        _dayOptions = result.dayOptions;
      });
    }
  }

  Future<void> _loadTermData() async {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    final result = await ctrl.loadTermData();
    if (!mounted) return;
    setState(() {
      _termList = result.semesterList;
    });
    if (result.selectedSemester != null) {
      setState(() {
        _selectedTerm = result.selectedSemester!;
      });
    }
  }

  Future<void> _loadAcademicYearData() async {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    final result = await ctrl.loadAcademicYearData();
    if (!mounted) return;
    setState(() {
      _academicYearList = result.academicYearList;
      if (result.selectedAcademicYear != null) {
        _selectedAcademicYear = result.selectedAcademicYear!;
      }
    });
  }

  String? _buildScheduleCacheKey() {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    return ctrl.buildScheduleCacheKey(
      teacherId: _teacherId,
      selectedDayIds: _selectedDayIds,
      selectedClassId: _selectedClassId,
      searchText: _searchController.text,
      selectedFilterSemester: _selectedFilterSemester,
      selectedSemester: _selectedTerm,
      selectedAcademicYear: _selectedAcademicYear,
      isHomeroomView: _isHomeroomView,
      selectedHomeroomClass: _selectedHomeroomClass,
    );
  }

  Future<void> _forceRefresh() async {
    // Clear static in-memory cache
    _memCachedSchedules = null;
    _memCachedClasses = null;

    final ctrl = ref.read(teacherScheduleControllerProvider);
    await ctrl.invalidateScheduleCache(_buildScheduleCacheKey());
    _loadSchedule(useCache: false);
  }

  /// Fetches the teacher's schedule — cache-first, then fresh from API.
  /// Delegates the actual network/cache work to [TeacherScheduleController];
  /// this method only owns setState calls (screen layer concern).
  Future<void> _loadSchedule({bool useCache = true}) async {
    if (_teacherId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final ctrl = ref.read(teacherScheduleControllerProvider);
    final cacheKey = _buildScheduleCacheKey();

    // Step 1: Try loading from cache for instant display
    if (useCache && cacheKey != null) {
      final cached = await ctrl.loadCachedSchedule(cacheKey);
      if (cached.found && mounted) {
        setState(() {
          _scheduleList = cached.schedules;
          _availableClasses = cached.availableClasses;
          _isLoading = false;
        });
        AppLogger.info('schedule', 'Schedule loaded from cache');
      }
    }

    // Step 2: Show skeleton only if no cached data displayed
    final hasData = _scheduleList.isNotEmpty;
    if (!hasData && mounted) {
      setState(() => _isLoading = true);
    }

    // Step 3: Fetch fresh data from API
    final semesterToUse = _selectedFilterSemester ?? _selectedTerm;
    final result = await ctrl.fetchScheduleFromApi(
      teacherId: _teacherId,
      semesterToUse: semesterToUse,
      academicYearToUse: _selectedAcademicYear,
      isHomeroomView: _isHomeroomView,
      selectedHomeroomClass: _selectedHomeroomClass,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final schedules = result.schedules!;
      final classes = result.availableClasses!;

      setState(() {
        _scheduleList = schedules;
        _availableClasses = classes;
        _isLoading = false;
      });

      // Update static in-memory cache for instant restore on revisit
      _memCachedSchedules = schedules;
      _memCachedClasses = classes;

      // Save to local cache + persist key for early loading next launch
      if (cacheKey != null) {
        ctrl.saveScheduleToCache(
          cacheKey: cacheKey,
          schedules: schedules,
          availableClasses: classes,
          prefKeyLastCacheKey: _prefKeyLastCacheKey,
        );
      }

      // Show tour after first successful load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkAndShowTour();
      });
    } else {
      setState(() => _isLoading = false);
      // Only show error if no cached data was already displayed
      if (!hasData) {
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(result.error!));
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      SnackBarUtils.showError(
        context,
        ref.read(languageRiverpod).getTranslatedText({
          'en': message,
          'id': message.replaceAll(
            'Failed to load schedule data:',
            '${AppLocalizations.failedToLoadSchedule.tr}:',
          ),
        }),
      );
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedDayIds.isNotEmpty ||
          _selectedClassId != null ||
          (_selectedFilterSemester != null &&
              _selectedFilterSemester != _selectedTerm);
    });
  }

  void _clearAllFilters() {
    setState(() {
      _selectedDayIds.clear();
      _selectedFilterSemester = null;
      _selectedClassId = null;
      _checkActiveFilter();
    });
    // Reload data to ensure semester and other contexts are correct
    _loadTermData().then((_) => _loadSchedule());
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    final List<Map<String, dynamic>> filterChips = [];

    // Hari chips
    for (var dayId in _selectedDayIds) {
      final dayNameRaw = _dayOptions.firstWhere(
        (h) => _dayIdMap[h] == dayId,
        orElse: () => 'Hari',
      );

      // Localization helper for days
      final dayMap = {
        'senin': {'en': 'Monday', 'id': 'Senin'},
        'selasa': {'en': 'Tuesday', 'id': 'Selasa'},
        'rabu': {'en': 'Wednesday', 'id': 'Rabu'},
        'kamis': {'en': 'Thursday', 'id': 'Kamis'},
        'jumat': {'en': 'Friday', 'id': 'Jumat'},
        'jum\'at': {'en': 'Friday', 'id': 'Jumat'},
        'sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
        'minggu': {'en': 'Sunday', 'id': 'Minggu'},
      };

      final normalizedKey = dayNameRaw.toLowerCase();
      final label = dayMap[normalizedKey] != null
          ? languageProvider.getTranslatedText(dayMap[normalizedKey]!)
          : dayNameRaw;

      filterChips.add({
        'label': label,
        'onRemove': () {
          setState(() {
            _selectedDayIds.remove(dayId);
            _checkActiveFilter();
          });
        },
      });
    }

    // Class Chip
    if (_selectedClassId != null) {
      final cls = _availableClasses.firstWhere(
        (c) => c['id'] == _selectedClassId,
        orElse: () => {'name': 'Class'},
      );
      filterChips.add({
        'label': cls['name'],
        'onRemove': () {
          setState(() {
            _selectedClassId = null;
            _checkActiveFilter();
          });
        },
      });
    }

    // Semester chip
    if (_selectedFilterSemester != null &&
        _selectedFilterSemester != _selectedTerm) {
      final semester = _termList.firstWhere(
        (s) => s['id'].toString() == _selectedFilterSemester,
        orElse: () => {'nama': 'Semester $_selectedFilterSemester'},
      );
      filterChips.add({
        'label': semester['nama'] ?? 'Semester',
        'onRemove': () {
          setState(() {
            _selectedFilterSemester = null;
            _checkActiveFilter();
          });
          _loadSchedule();
        },
      });
    }

    return filterChips;
  }

  /// Opens the filter bottom sheet.
  /// Delegates to [TeacherScheduleFilterSheet]; applies the result via callback.
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TeacherScheduleFilterSheet(
        primaryColor: _getPrimaryColor(),
        dayOptions: _dayOptions,
        dayIdMap: _dayIdMap,
        availableClasses: _availableClasses,
        semesterList: _termList,
        currentSemester: _selectedTerm,
        selectedDayIds: _selectedDayIds,
        selectedClassId: _selectedClassId,
        selectedFilterSemester: _selectedFilterSemester,
        languageProvider: ref.read(languageRiverpod),
        onApply: ({
          required List<String> dayIds,
          required String? classId,
          required String? semester,
          required bool needsReload,
        }) {
          setState(() {
            _selectedDayIds = dayIds;
            _selectedClassId = classId;
            _selectedFilterSemester = semester;
            if (semester != null) _selectedTerm = semester;
            _checkActiveFilter();
          });
          if (needsReload) _loadSchedule();
        },
      ),
    );
  }

  // RE-ADDED: Method to toggle view
  /// Toggles between card view and table (grid) view.
  /// Like a Vue `methods.toggleView()` that flips a boolean flag.
  void _toggleView() {
    setState(() {
      _isTableView = !_isTableView;
    });
  }

  Color _getPrimaryColor() {
    return ref.read(teacherScheduleControllerProvider).getPrimaryColor();
  }

  LinearGradient _getCardGradient() {
    return ref.read(teacherScheduleControllerProvider).getCardGradient();
  }

  List<dynamic> _getFilteredSchedules() {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    return ctrl.getFilteredSchedules(
      scheduleList: _scheduleList,
      searchText: _searchController.text,
      selectedDayIds: _selectedDayIds,
      selectedClassId: _selectedClassId,
      dayIdMap: _dayIdMap,
    );
  }

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'teaching_schedule_screen',
        'guru',
      );
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
      AppLogger.error('schedule', 'Error checking tour status: $e');
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
          name: 'teaching_schedule_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('teaching_schedule_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'teaching_schedule_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('teaching_schedule_screen', 'guru'),
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
        identify: "ToggleView",
        keyTarget: _toggleViewKey,
        alignSkip: Alignment.bottomRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Tampilan Jadwal",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Ketuk ikon ini untuk beralih antara tampilan kartu interaktif atau tabel yang ringkas.",
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

    targets.add(
      TargetFocus(
        identify: "SearchFilter",
        keyTarget: _searchFilterKey,
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
                    "Pencarian & Filter",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      "Cari mata pelajaran, kelas, atau gunakan tombol saring di kanan untuk menampilkan jadwal pada hari tertentu saja.",
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

    if (_scheduleList.isNotEmpty && !_isTableView) {
      targets.add(
        TargetFocus(
          identify: "ScheduleItem",
          keyTarget: _firstScheduleKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 16,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Kartu Jadwal Kelas",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Detail lokasi kelas, mata pelajaran, serta waktu pelaksanaan. Ketuk seluruh area kartu ini langsung untuk masuk ke halaman Presensi Kelas.",
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

      targets.add(
        TargetFocus(
          identify: "ActionButtons",
          keyTarget: _actionButtonsKey,
          alignSkip: Alignment.topRight,
          shape: ShapeLightFocus.RRect,
          radius: 10,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Aksi Cepat",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Gunakan tombol Materi untuk melihat RPP & Bab. Gunakan tombol Aktivitas untuk mencatat absen kelas dan mengisi kehadiran harian siswa.",
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

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    final filteredSchedules = _getFilteredSchedules();

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
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
                      onTap: () => AppNavigator.pop(context),
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
                              'en': 'Teaching Schedule',
                              'id': 'Jadwal Mengajar',
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
                              'en':
                                  _isHomeroomView &&
                                      _selectedHomeroomClass != null
                                  ? 'Viewing Homeroom Schedule'
                                  : 'View your teaching schedule',
                              'id':
                                  _isHomeroomView &&
                                      _selectedHomeroomClass != null
                                  ? 'Melihat Jadwal Wali Kelas'
                                  : 'Lihat jadwal mengajar Anda',
                            }),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // RE-ADDED: Toggle view button
                    GestureDetector(
                      key: _toggleViewKey,
                      onTap: _toggleView,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isTableView ? Icons.grid_view : Icons.list,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'refresh') {
                          _forceRefresh();
                        }
                      },
                      itemBuilder: (context) => [
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
                      ],
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg),

                // Role switcher: only show when user is also wali kelas
                if (_homeroomClassesList.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GestureDetector(
                      onTapDown: (TapDownDetails details) {
                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                            details.globalPosition.dx,
                            details.globalPosition.dy,
                          ),
                          items: [
                            PopupMenuItem(
                              value: 'guru',
                              child: Text('Guru (Lihat Jadwal Mengajar)'),
                            ),
                            ..._homeroomClassesList.map(
                              (c) => PopupMenuItem(
                                value: c,
                                child: Text(
                                  'Wali Kelas - ${c['name'] ?? c['nama']}',
                                ),
                              ),
                            ),
                          ],
                        ).then((value) {
                          if (value != null) {
                            setState(() {
                              if (value == 'guru') {
                                _isHomeroomView = false;
                              } else {
                                _isHomeroomView = true;
                                _selectedHomeroomClass =
                                    value as Map<String, dynamic>;
                              }
                            });
                            _loadSchedule();
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isHomeroomView ? Icons.class_ : Icons.person,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _teacherNama,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  _isHomeroomView &&
                                          _selectedHomeroomClass != null
                                      ? 'Wali Kelas - ${(_selectedHomeroomClass!['name'] ?? _selectedHomeroomClass!['nama'] ?? '').toString()}'
                                      : 'Guru',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.swap_horiz_rounded,
                            color: Colors.white.withValues(alpha: 0.8),
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                SizedBox(height: AppSpacing.lg),

                // Search Bar with Filter using SeparatedSearchFilter
                // Search Bar with Filter Button
                Row(
                  key: _searchFilterKey,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: ColorUtils.slate800),
                                decoration: InputDecoration(
                                  hintText: languageProvider.getTranslatedText({
                                    'en': 'Search schedules...',
                                    'id': 'Cari jadwal...',
                                  }),
                                  hintStyle: TextStyle(
                                    color: ColorUtils.slate400,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: ColorUtils.slate500,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                onSubmitted: (_) {
                                  setState(() {});
                                },
                              ),
                            ),
                            Container(
                              margin: EdgeInsets.only(right: 4),
                              child: IconButton(
                                icon: Icon(
                                  Icons.search,
                                  color: _getPrimaryColor(),
                                ),
                                onPressed: () {
                                  setState(() {});
                                },
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
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: ColorUtils.error600,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
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
                                return GestureDetector(
                                  onTap: filter['onRemove'],
                                  child: Container(
                                    margin: EdgeInsets.only(right: 6),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          filter['label'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        SizedBox(width: AppSpacing.xs),
                                        Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: _clearAllFilters,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Clear All',
                                'id': 'Hapus Semua',
                              }),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
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
          ),

          // Content
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(itemCount: 5, infoTagCount: 2)
                : Column(
                    children: [
                      // View Toggle Info
                      SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text(
                              '${filteredSchedules.length} ${languageProvider.getTranslatedText({'en': 'schedules found', 'id': 'jadwal ditemukan'})}',
                              style: TextStyle(
                                color: ColorUtils.slate500,
                                fontSize: 12,
                              ),
                            ),
                            Spacer(),
                            Text(
                              _isTableView
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Table View',
                                      'id': 'Tampilan Tabel',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Card View',
                                      'id': 'Tampilan Kartu',
                                    }),
                              style: TextStyle(
                                color: _getPrimaryColor(),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),

                      Expanded(
                        child: filteredSchedules.isEmpty
                            ? EmptyState(
                                icon: Icons.schedule_outlined,
                                title: languageProvider.getTranslatedText({
                                  'en': 'No Teaching Schedules',
                                  'id': 'Tidak Ada Jadwal Mengajar',
                                }),
                                subtitle: languageProvider.getTranslatedText({
                                  'en':
                                      _searchController.text.isNotEmpty ||
                                          _hasActiveFilter
                                      ? 'No schedules found for your search and filters'
                                      : 'There are no teaching schedules available',
                                  'id':
                                      _searchController.text.isNotEmpty ||
                                          _hasActiveFilter
                                      ? 'Tidak ada jadwal yang sesuai dengan pencarian dan filter'
                                      : 'Tidak ada jadwal mengajar yang tersedia',
                                }),
                                buttonText: languageProvider.getTranslatedText({
                                  'en': 'Refresh',
                                  'id': 'Muat Ulang',
                                }),
                                onPressed: _loadSchedule,
                              )
                            : RefreshIndicator(
                                onRefresh: _loadSchedule,
                                color: _getPrimaryColor(),
                                backgroundColor: Colors.white,
                                child: _isTableView
                                    ? TeacherScheduleTableView(
                                        schedules: filteredSchedules,
                                        dayIdMap: _dayIdMap,
                                        dayColorMap: _dayColorMap,
                                        primaryColor: _getPrimaryColor(),
                                      )
                                    : TeacherScheduleCardView(
                                        schedules: filteredSchedules,
                                        languageProvider: languageProvider,
                                        dayIdMap: _dayIdMap,
                                        dayColorMap: _dayColorMap,
                                        dayOptions: _dayOptions,
                                        selectedAcademicYear:
                                            _selectedAcademicYear,
                                        teacherId: _teacherId,
                                        teacherNama: _teacherNama,
                                        firstScheduleKey: _firstScheduleKey,
                                        actionButtonsKey: _actionButtonsKey,
                                      ),
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
