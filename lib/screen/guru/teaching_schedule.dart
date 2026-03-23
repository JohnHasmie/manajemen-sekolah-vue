// Teaching schedule screen -- the teacher's timetable/calendar view.
// Like `pages/teacher/Schedule.vue` in a Vue app.
//
// Displays the teacher's weekly schedule with two view modes: card view
// and table (grid) view. Supports filtering by day, semester, class,
// real-time sync via FCM push notifications, and quick navigation to
// related screens (attendance, class activity, materials).
// In Laravel terms: `ScheduleController@index` with multiple view formats.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/providers/teacher_provider.dart';
import 'package:manajemensekolah/screen/guru/class_activity.dart';
import 'package:manajemensekolah/screen/guru/materi_screen.dart';
import 'package:manajemensekolah/screen/guru/presence_teacher.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/api_tour_services.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:manajemensekolah/services/fcm_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Teacher's weekly schedule screen with card and table view modes.
///
/// A StatefulWidget with no constructor params -- it reads teacher data from
/// SharedPreferences and TeacherProvider internally.
class TeachingScheduleScreen extends StatefulWidget {
  const TeachingScheduleScreen({super.key});

  @override
  TeachingScheduleScreenState createState() => TeachingScheduleScreenState();
}

/// State for [TeachingScheduleScreen].
///
/// Like a Vue page component with `data() { return {...} }`. Manages:
/// - [_jadwalList] -- schedule entries from API
/// - [_isTableView] -- toggle between card and table layout
/// - [_isHomeroomView] -- special view for homeroom teachers
/// - Filter state (day, semester, class)
/// - Real-time sync via FCM push notifications
/// - Onboarding tour
///
/// `setState()` is like Vue's reactivity -- triggers a re-render when data changes.
class TeachingScheduleScreenState extends State<TeachingScheduleScreen> {
  // Static in-memory cache for instant display on revisit (no async needed)
  static List<dynamic>? _memCachedJadwal;
  static List<Map<String, String>>? _memCachedClasses;

  List<dynamic> _jadwalList = [];
  List<dynamic> _semesterList = [];
  bool _isLoading = true;
  String _teacherId = '';
  String _teacherNama = '';
  List<dynamic> _academicYearList = [];
  String _selectedSemester = '1'; // Will be set by _setDefaultAcademicPeriod()
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

  // DITAMBAHKAN KEMBALI: Toggle antara card dan table view
  bool _isTableView = false;

  // Last known cache key for early cache loading
  static const String _prefKeyLastCacheKey = 'schedule_last_cache_key';

  // Tour properties
  final GlobalKey _toggleViewKey = GlobalKey();
  final GlobalKey _searchFilterKey = GlobalKey();
  final GlobalKey _firstScheduleKey = GlobalKey();
  final GlobalKey _actionButtonsKey = GlobalKey();
  String? _tourId;

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
    'Senin': Color(0xFF6366F1),
    'Selasa': Color(0xFF10B981),
    'Rabu': Color(0xFFF59E0B),
    'Kamis': Color(0xFFEF4444),
    'Jumat': Color(0xFF8B5CF6),
    'Sabtu': Color(0xFF06B6D4),
  };

  /// Like Vue's `mounted()` -- sets academic year defaults, loads teacher data,
  /// and subscribes to FCM real-time sync notifications (like a Vue event bus
  /// or WebSocket listener for live updates).
  @override
  void initState() {
    super.initState();

    // Instantly restore from static in-memory cache (synchronous, no async)
    if (_memCachedJadwal != null && _memCachedClasses != null) {
      _jadwalList = _memCachedJadwal!;
      _availableClasses = _memCachedClasses!;
      _isLoading = false;
      if (kDebugMode) print('⚡ Instant restore from static memory cache');
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
        if (kDebugMode) print('📦 Sync triggered: refresh_schedules');
        _loadJadwal();
      }
    }
  }

  /// Calculate current academic year based on current date
  String _getCurrentAcademicYear() {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    // Academic year runs from July to June
    // If current month is July or later, academic year is currentYear/nextYear
    // Otherwise, academic year is previousYear/currentYear
    if (currentMonth >= 7) {
      return '$currentYear/${currentYear + 1}';
    } else {
      return '${currentYear - 1}/$currentYear';
    }
  }

  /// Set default academic year and semester based on current date
  void _setDefaultAcademicPeriod() {
    setState(() {
      _selectedAcademicYear = _getCurrentAcademicYear();
      // Semester will be set by _loadSemesterData called from _loadUserData
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
    if (kDebugMode) {
      print(
        '===== TeachingScheduleScreen: _loadUserData STARTED =====',
      );
    }
    try {
      // ─── Step 1: Try TeacherProvider (populated by Dashboard) ───
      final teacherProvider = Provider.of<TeacherProvider>(
        context,
        listen: false,
      );

      // Early cache load for instant display (while provider/API resolves)
      final prefs = await SharedPreferences.getInstance();
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
              _jadwalList = List<dynamic>.from(cachedData['jadwal'] ?? []);
              _availableClasses =
                  (cachedData['availableClasses'] as List<dynamic>?)
                          ?.map((e) => Map<String, String>.from(e))
                          .toList() ??
                      [];
              _isLoading = false;
            });
            if (kDebugMode) print('⚡ Early schedule cache loaded (key: $lastCacheKey)');
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Early schedule cache failed: $e');
        }
      }

      if (teacherProvider.isLoaded && teacherProvider.teacherId != null) {
        // ✅ Use cached data from provider — no API calls needed
        if (kDebugMode) {
          print('⚡ Using TeacherProvider cache (teacherId=${teacherProvider.teacherId})');
        }

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
          _loadSemesterData(),
          _loadAcademicYearData(),
        ]);
        _loadJadwal();
        return;
      }

      // ─── Step 2: Fallback — fetch from API (direct navigation, deep link, etc.) ───
      if (kDebugMode) {
        print('📡 TeacherProvider empty, falling back to API');
      }

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
            if (kDebugMode)
              print('Use ID from prefs directly: $resolvedTeacherId');
          } else {
            String? academicYearId;
            try {
              if (mounted) {
                academicYearId = Provider.of<AcademicYearProvider>(
                  context,
                  listen: false,
                ).selectedAcademicYear?['id']?.toString();
              }
            } catch (e) {}

            // Ensure TeacherProvider is loaded for future screens
            await teacherProvider.ensureLoaded(academicYearId: academicYearId);

            if (teacherProvider.teacherId != null) {
              resolvedTeacherId = teacherProvider.teacherId;
            } else {
              final teacherData = await ApiTeacherService.getGuruByUserId(
                userId,
                academicYearId: academicYearId,
              );
              if (teacherData != null && teacherData['id'] != null) {
                resolvedTeacherId = teacherData['id'].toString();
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print('Error resolving teacher ID: $e');
        }

        if (resolvedTeacherId != null) {
          if (kDebugMode) print('✅ Resolved Teacher ID: $resolvedTeacherId');
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
                academicYearId = Provider.of<AcademicYearProvider>(
                  context,
                  listen: false,
                ).selectedAcademicYear?['id']?.toString();
              }
            } catch (e) {}

            final allTeacherClasses = await ApiTeacherService.getTeacherClasses(
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
          if (kDebugMode) print('❌ Failed to resolve Teacher ID');
        }

        // Load reference data in parallel, then fetch schedule
        await Future.wait([
          _loadDayData(),
          _loadSemesterData(),
          _loadAcademicYearData(),
        ]);
        _loadJadwal();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in _loadUserData: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDayData() async {
    try {
      // Try cache first (day data is static, cache for 24h)
      final cached = await LocalCacheService.load(
        'school_day_data',
        ttl: const Duration(hours: 24),
      );

      List<dynamic> dayData;
      if (cached != null) {
        dayData = List<dynamic>.from(cached);
        if (kDebugMode) print('⚡ Day data loaded from cache');
      } else {
        dayData = await ApiScheduleService.getHari();
        if (dayData.isNotEmpty) {
          LocalCacheService.save('school_day_data', dayData);
        }
      }

      if (dayData.isNotEmpty) {
        final Map<String, String> newDayIdMap = {};
        final List<String> newDayOptions = ['Semua Hari'];

        for (var day in dayData) {
          final name =
              day['name_id']?.toString() ?? day['name']?.toString() ?? '';
          final id = day['id']?.toString() ?? '';
          if (name.isNotEmpty && id.isNotEmpty) {
            newDayIdMap[name] = id;
            newDayOptions.add(name);
          }
        }

        if (newDayIdMap.isNotEmpty) {
          setState(() {
            _dayIdMap = newDayIdMap;
            _dayOptions = newDayOptions;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading day data: $e');
      }
    }
  }

  Future<void> _loadSemesterData() async {
    try {
      // ─── Try cache first (semester list rarely changes, cache 12h) ───
      List<dynamic> semesterData;
      final cachedSemester = await LocalCacheService.load(
        'school_semester_data',
        ttl: const Duration(hours: 12),
      );

      if (cachedSemester != null) {
        semesterData = List<dynamic>.from(cachedSemester);
        if (kDebugMode) print('⚡ Semester list loaded from cache');
      } else {
        semesterData = await ApiScheduleService.getSemester();
        if (semesterData.isNotEmpty) {
          LocalCacheService.save('school_semester_data', semesterData);
        }
      }

      setState(() {
        _semesterList = semesterData;
      });

      String? semesterId;

      // ─── Try cached current-date-based semester (cache 6h) ───
      try {
        Map<String, dynamic> result;
        final cachedDateBased = await LocalCacheService.load(
          'school_current_semester',
          ttl: const Duration(hours: 6),
        );

        if (cachedDateBased != null) {
          result = Map<String, dynamic>.from(cachedDateBased);
          if (kDebugMode) print('⚡ Current semester loaded from cache');
        } else {
          result = await ApiScheduleService.getDateBasedSemester();
          if (result.isNotEmpty) {
            LocalCacheService.save('school_current_semester', result);
          }
        }

        if (result.isNotEmpty && result.containsKey('semester')) {
          final targetSemesterName = result['semester'].toString();

          final dateBasedSemester = semesterData.firstWhere((s) {
            final name = (s['name'] ?? s['nama'] ?? '').toString();
            return name.contains(targetSemesterName);
          }, orElse: () => null);

          if (dateBasedSemester != null) {
            semesterId = dateBasedSemester['id'].toString();
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching date based semester: $e');
        }
      }

      // 2. Fallback to backend 'current' flag
      if (semesterId == null) {
        final currentSem = semesterData.firstWhere(
          (s) =>
              s['current'] == true ||
              s['current'] == 1 ||
              s['current'].toString() == '1',
          orElse: () => null,
        );

        if (currentSem != null) {
          semesterId = currentSem['id'].toString();
        }
      }

      // 3. Last fallback
      if (semesterId == null && semesterData.isNotEmpty) {
        semesterId = semesterData.first['id'].toString();
      }

      if (semesterId != null && mounted) {
        setState(() {
          _selectedSemester = semesterId!;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading semester data: $e');
      }
    }
  }

  Future<void> _loadAcademicYearData() async {
    try {
      // ─── Read from AcademicYearProvider (already fetched by Dashboard) ───
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );

      List<dynamic> academicYears = academicYearProvider.academicYears;

      // Fallback: if provider is empty (e.g. deep link), fetch from API
      if (academicYears.isEmpty) {
        if (kDebugMode) print('📡 AcademicYearProvider empty, fetching from API');
        await academicYearProvider.fetchAcademicYears();
        academicYears = academicYearProvider.academicYears;
      } else {
        if (kDebugMode) print('⚡ Academic years loaded from provider (${academicYears.length} items)');
      }

      final globalSelectedYear = academicYearProvider.selectedAcademicYear;

      setState(() {
        _academicYearList = academicYears
            .where(
              (ay) => (ay['year'] ?? '').toString() != 'Status Kepegawaian',
            )
            .toList();

        // 1. Prioritize Global Provider Selection
        if (globalSelectedYear != null) {
          _selectedAcademicYear = globalSelectedYear['year'].toString();
        } else {
          // 2. Fallback to existing logic if provider is empty
          final currentAY = _academicYearList.firstWhere(
            (ay) =>
                ay['current'] == true ||
                ay['current'] == 1 ||
                ay['current'].toString() == '1',
            orElse: () => null,
          );

          if (currentAY != null) {
            _selectedAcademicYear = currentAY['year'].toString();
          } else if (academicYears.isNotEmpty) {
            _selectedAcademicYear = academicYears.last['year'].toString();
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error loading academic year data: $e');
      }
    }
  }

  String? _buildScheduleCacheKey() {
    // Don't cache when filters or search are active
    if (_selectedDayIds.isNotEmpty ||
        _selectedClassId != null ||
        _searchController.text.isNotEmpty ||
        (_selectedFilterSemester != null &&
            _selectedFilterSemester != _selectedSemester)) {
      return null;
    }
    if (_teacherId.isEmpty) return null;

    final semesterToUse = _selectedFilterSemester ?? _selectedSemester;
    if (_isHomeroomView && _selectedHomeroomClass != null) {
      final classId = _selectedHomeroomClass!['id'].toString();
      return 'schedule_homeroom_${classId}_${semesterToUse}_$_selectedAcademicYear';
    }
    return 'schedule_teacher_${_teacherId}_${semesterToUse}_$_selectedAcademicYear';
  }

  Future<void> _forceRefresh() async {
    // Clear static in-memory cache
    _memCachedJadwal = null;
    _memCachedClasses = null;

    final cacheKey = _buildScheduleCacheKey();
    if (cacheKey != null) {
      await LocalCacheService.invalidate(cacheKey);
    }
    await LocalCacheService.clearStartingWith('schedule_');
    _loadJadwal(useCache: false);
  }

  /// Fetches the teacher's schedule from API with cache-first strategy.
  /// Like `axios.get('/api/schedules')` in Vue with localStorage caching.
  Future<void> _loadJadwal({bool useCache = true}) async {
    if (_teacherId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final cacheKey = _buildScheduleCacheKey();

    // Step 1: Try loading from cache for instant display
    if (useCache && cacheKey != null) {
      try {
        final cached = await LocalCacheService.load(
          cacheKey,
          ttl: const Duration(hours: 3),
        );
        if (cached != null && mounted) {
          final cachedData = Map<String, dynamic>.from(cached);
          setState(() {
            _jadwalList = List<dynamic>.from(cachedData['jadwal'] ?? []);
            _availableClasses = (cachedData['availableClasses'] as List<dynamic>?)
                    ?.map((e) => Map<String, String>.from(e))
                    .toList() ??
                [];
            _isLoading = false;
          });
          if (kDebugMode) print('⚡ Schedule loaded from cache');
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Schedule cache load failed: $e');
      }
    }

    // Step 2: Show skeleton only if no cached data displayed
    final hasData = _jadwalList.isNotEmpty;
    if (!hasData && mounted) {
      setState(() => _isLoading = true);
    }

    // Step 3: Fetch fresh data from API
    try {
      // Use filter semester/year if set, otherwise use selected
      final semesterToUse = _selectedFilterSemester ?? _selectedSemester;
      final academicYearToUse = _selectedAcademicYear;

      if (kDebugMode) {
        print('FETCHING SCHEDULE WITH:');
        print('- Teacher ID: $_teacherId');
        print('- Semester: $semesterToUse');
        print('- Academic Year: $academicYearToUse');
      }

      dynamic jadwalData;

      if (_isHomeroomView && _selectedHomeroomClass != null) {
        // Fetch schedule for the homeroom class
        final classId = _selectedHomeroomClass!['id'].toString();
        final result = await ApiScheduleService.getSchedulesPaginated(
          classId: classId,
          semesterId: semesterToUse,
          tahunAjaran: academicYearToUse,
          limit: 100, // Fetch all for now
        );
        jadwalData = result['data'] ?? [];
      } else {
        // Fetch teaching schedule for the teacher
        jadwalData = await ApiScheduleService.getFilteredSchedule(
          teacherId: _teacherId,
          semester: semesterToUse,
          academicYear: academicYearToUse,
        );
      }

      final jadwal = jadwalData is List ? jadwalData : [];

      if (kDebugMode) {
        print('Total schedule items loaded: ${jadwal.length}');
      }

      // Extract unique classes for filter
      final uniqueClasses = <String, String>{};
      for (var item in jadwal) {
        final id =
            item['class_id']?.toString() ??
            item['kelas_id']?.toString() ??
            '';
        final name =
            item['class_name']?.toString() ??
            item['kelas_nama']?.toString() ??
            '';
        if (id.isNotEmpty && name.isNotEmpty) {
          uniqueClasses[id] = name;
        }
      }
      final classes = uniqueClasses.entries
          .map((e) => {'id': e.key, 'name': e.value})
          .toList()
        ..sort((a, b) => a['name']!.compareTo(b['name']!));

      setState(() {
        _jadwalList = jadwal;
        _availableClasses = classes;
        _isLoading = false;
      });

      // Update static in-memory cache for instant restore on revisit
      _memCachedJadwal = jadwal;
      _memCachedClasses = classes;

      // Save to cache and persist the cache key for early loading next time
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'jadwal': jadwal,
          'availableClasses': classes,
        });
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString(_prefKeyLastCacheKey, cacheKey);
        });
      }

      // Show tour
      Future.delayed(Duration(milliseconds: 1000), () {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error load jadwal: $e');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Only show error if no cached data displayed
        if (!hasData) {
          _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
        }
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LanguageProvider>().getTranslatedText({
              'en': message,
              'id': message.replaceAll(
                'Failed to load schedule data:',
                'Gagal memuat data jadwal:',
              ),
            }),
          ),
          backgroundColor: ColorUtils.error600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _checkActiveFilter() {
    setState(() {
      _hasActiveFilter =
          _selectedDayIds.isNotEmpty ||
          _selectedClassId != null ||
          (_selectedFilterSemester != null &&
              _selectedFilterSemester != _selectedSemester);
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
    _loadSemesterData().then((_) => _loadJadwal());
  }

  List<Map<String, dynamic>> _buildFilterChips(
    LanguageProvider languageProvider,
  ) {
    List<Map<String, dynamic>> filterChips = [];

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
        _selectedFilterSemester != _selectedSemester) {
      final semester = _semesterList.firstWhere(
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
          _loadJadwal();
        },
      });
    }

    return filterChips;
  }

  void _showFilterSheet() {
    final languageProvider = Provider.of<LanguageProvider>(
      context,
      listen: false,
    );
    final primary = _getPrimaryColor();

    String getLocalizedDay(String dayRaw) {
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
      final key = dayRaw.toLowerCase();
      return dayMap[key] != null
          ? languageProvider.getTranslatedText(dayMap[key]!)
          : dayRaw;
    }

    List<String> tempDayIds = List.from(_selectedDayIds);
    String? tempClassId = _selectedClassId;
    String? tempSemester = _selectedFilterSemester ?? _selectedSemester;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Widget buildSectionHeader(String title, IconData icon) {
            return Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 15, color: primary),
                  ),
                  SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                ],
              ),
            );
          }

          Widget buildChip(String label, bool selected, VoidCallback onTap) {
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? primary.withValues(alpha: 0.12)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? primary : ColorUtils.slate300,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: selected ? primary : ColorUtils.slate600,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.fromLTRB(20, 10, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary, primary.withValues(alpha: 0.85)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
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
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Filter Schedule',
                                'id': 'Filter Jadwal',
                              }),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                tempDayIds.clear();
                                tempClassId = null;
                                tempSemester = _selectedSemester;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildSectionHeader(
                          languageProvider.getTranslatedText({
                            'en': 'Day',
                            'id': 'Hari',
                          }),
                          Icons.calendar_today_rounded,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _dayOptions
                              .where((d) => d != 'Semua Hari')
                              .map((day) {
                                final dayId = _dayIdMap[day] ?? '';
                                final selected = tempDayIds.contains(dayId);
                                return buildChip(
                                  getLocalizedDay(day),
                                  selected,
                                  () => setSheetState(() {
                                    if (selected) {
                                      tempDayIds.remove(dayId);
                                    } else {
                                      tempDayIds.add(dayId);
                                    }
                                  }),
                                );
                              })
                              .toList(),
                        ),
                        if (_availableClasses.isNotEmpty) ...[
                          SizedBox(height: 20),
                          buildSectionHeader(
                            languageProvider.getTranslatedText({
                              'en': 'Class',
                              'id': 'Kelas',
                            }),
                            Icons.class_rounded,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableClasses.map((cls) {
                              final selected = tempClassId == cls['id'];
                              return buildChip(
                                cls['name']!,
                                selected,
                                () => setSheetState(() {
                                  tempClassId = selected ? null : cls['id'];
                                }),
                              );
                            }).toList(),
                          ),
                        ],
                        if (_semesterList.isNotEmpty) ...[
                          SizedBox(height: 20),
                          buildSectionHeader(
                            languageProvider.getTranslatedText({
                              'en': 'Semester',
                              'id': 'Semester',
                            }),
                            Icons.school_rounded,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _semesterList.map((sem) {
                              final semId = sem['id'].toString();
                              final label =
                                  sem['name'] ?? sem['nama'] ?? 'Semester';
                              final selected = tempSemester == semId;
                              return buildChip(
                                label,
                                selected,
                                () => setSheetState(() {
                                  tempSemester = selected ? null : semId;
                                }),
                              );
                            }).toList(),
                          ),
                        ],
                        SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Batal',
                              style: TextStyle(
                                color: ColorUtils.slate600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              final needsReload =
                                  tempSemester != _selectedSemester;
                              setState(() {
                                _selectedDayIds = List<String>.from(tempDayIds);
                                _selectedClassId = tempClassId;
                                _selectedFilterSemester = tempSemester;
                                if (tempSemester != null) {
                                  _selectedSemester = tempSemester!;
                                }
                                _checkActiveFilter();
                              });
                              if (needsReload) _loadJadwal();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              padding: EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
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
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // DITAMBAHKAN KEMBALI: Method untuk toggle view
  /// Toggles between card view and table (grid) view.
  /// Like a Vue `methods.toggleView()` that flips a boolean flag.
  void _toggleView() {
    setState(() {
      _isTableView = !_isTableView;
    });
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
    );
  }

  Color _getDayColor(String day) {
    return _dayColorMap[day] ?? Color(0xFF6B7280);
  }

  String _normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) return 'Senin';
    if (name.contains('selasa') || name.contains('tuesday')) return 'Selasa';
    if (name.contains('rabu') || name.contains('wednesday')) return 'Rabu';
    if (name.contains('kamis') || name.contains('thursday')) return 'Kamis';
    if (name.contains('jumat') || name.contains('friday')) return 'Jumat';
    if (name.contains('sabtu') || name.contains('saturday')) return 'Sabtu';
    if (name.contains('minggu') || name.contains('sunday')) return 'Minggu';
    return name;
  }

  List<String> _extractDayIds(dynamic schedule) {
    final List<String> ids = [];
    final rawDaysIds = schedule['days_ids'];

    if (rawDaysIds != null) {
      if (rawDaysIds is List) {
        ids.addAll(rawDaysIds.map((id) => id.toString()));
      } else if (rawDaysIds is String) {
        try {
          final clean = rawDaysIds
              .replaceAll('[', '')
              .replaceAll(']', '')
              .trim();
          if (clean.isNotEmpty) {
            ids.addAll(
              clean
                  .split(',')
                  .map((id) => id.trim())
                  .where((id) => id.isNotEmpty),
            );
          }
        } catch (e) {}
      }
    }

    // Fallback
    if (ids.isEmpty) {
      final fallbackId = schedule['day_id'] ?? schedule['hari_id'];
      if (fallbackId != null) {
        ids.add(fallbackId.toString());
      }
    }
    return ids;
  }

  List<dynamic> _getFilteredSchedules() {
    final searchTerm = _searchController.text.toLowerCase();
    final now = DateTime.now();

    // Standard mappings for maximum stability
    final dayNamesISO = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayOrder = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final weekdayToIndo = {
      1: 'Senin',
      2: 'Selasa',
      3: 'Rabu',
      4: 'Kamis',
      5: 'Jumat',
      6: 'Sabtu',
      7: 'Minggu',
    };

    final currentDayISO =
        dayNamesISO[now.weekday - 1]; // 1-based (Mon=1, ..., Sun=7)
    final currentDayIndo = _normalizeDayName(currentDayISO);

    // Find the current day ID from the dynamic map with robust normalized matching
    String? currentDayId;
    _dayIdMap.forEach((key, value) {
      if (_normalizeDayName(key) == currentDayIndo) {
        currentDayId = value.toString();
      }
    });

    final filtered = _jadwalList.where((schedule) {
      final subjectName =
          schedule['mata_pelajaran_nama']?.toString().toLowerCase() ?? '';
      final className = schedule['kelas_nama']?.toString().toLowerCase() ?? '';

      final daysIds = _extractDayIds(schedule);

      final dayNamesStr = daysIds
          .map((id) {
            final entry = _dayIdMap.entries.firstWhere(
              (e) => e.value.toString() == id,
              orElse: () => MapEntry('', ''),
            );
            return entry.key.isNotEmpty
                ? entry.key
                : (weekdayToIndo[int.tryParse(id) ?? 0] ?? '');
          })
          .where((k) => k.isNotEmpty)
          .join(' ')
          .toLowerCase();

      final matchesSearch =
          searchTerm.isEmpty ||
          subjectName.contains(searchTerm) ||
          className.contains(searchTerm) ||
          dayNamesStr.contains(searchTerm);

      // Filter by hari
      final matchesDay =
          _selectedDayIds.isEmpty ||
          _selectedDayIds.any((selectedId) {
            return daysIds.any(
              (dId) => dId.toString() == selectedId.toString(),
            );
          });

      // Filter by class
      final matchesClass =
          _selectedClassId == null ||
          _selectedClassId!.isEmpty ||
          (schedule['class_id']?.toString() == _selectedClassId ||
              schedule['kelas_id']?.toString() == _selectedClassId);

      return matchesSearch && matchesDay && matchesClass;
    }).toList();

    // Sort with multiple fallback layers for "Today" prioritization
    filtered.sort((a, b) {
      final dayIdA = _extractDayIds(a);
      final dayIdB = _extractDayIds(b);

      // Robust "Today" detection
      bool belongsToToday(Map<String, dynamic> item, List<String> ids) {
        // Tier 1: Direct name field check (hari_nama)
        final hariNama = (item['hari_nama'] ?? item['day_name'] ?? '')
            .toString();
        if (hariNama.isNotEmpty &&
            _normalizeDayName(hariNama) == currentDayIndo) {
          return true;
        }

        // Tier 2: ID match using dynamically loaded map
        if (currentDayId != null && ids.any((id) => id == currentDayId)) {
          return true;
        }

        // Tier 3: Direct ISO weekday number match (the ultimate fallback)
        if (ids.any((id) => id == now.weekday.toString())) {
          return true;
        }

        // Tier 4: Map key normalized match
        return ids.any((id) {
          final entry = _dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => MapEntry('', ''),
          );
          return entry.key.isNotEmpty &&
              _normalizeDayName(entry.key) == currentDayIndo;
        });
      }

      final isTodayA = belongsToToday(a, dayIdA);
      final isTodayB = belongsToToday(b, dayIdB);

      // 1. Priority: Today First
      if (isTodayA && !isTodayB) return -1;
      if (!isTodayA && isTodayB) return 1;

      // 2. Secondary: Sequential Day-of-Week (Mon -> Sun)
      int getMinDayRank(List<String> ids) {
        if (ids.isEmpty) return 99;
        int minIdx = 99;
        for (var id in ids) {
          String name = '';
          final entry = _dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => MapEntry('', ''),
          );
          if (entry.key.isNotEmpty) {
            name = _normalizeDayName(entry.key);
          } else {
            // Mapping failed, try standard ISO assumption
            name = weekdayToIndo[int.tryParse(id) ?? 0] ?? '';
          }

          int idx = dayOrder.indexOf(name);
          if (idx != -1 && idx < minIdx) minIdx = idx;
        }
        return minIdx;
      }

      final rankA = getMinDayRank(dayIdA);
      final rankB = getMinDayRank(dayIdB);
      if (rankA != rankB) return rankA.compareTo(rankB);

      // 3. Tertiary: Item Density (Fewer days first)
      if (dayIdA.length != dayIdB.length) {
        return dayIdA.length.compareTo(dayIdB.length);
      }

      // 4. Quaternary: Chronological (Start Time)
      final timeA = (a['jam_mulai'] ?? a['start_time'] ?? '00:00').toString();
      final timeB = (b['jam_mulai'] ?? b['start_time'] ?? '00:00').toString();
      return timeA.compareTo(timeB);
    });

    return filtered;
  }

  Future<void> _checkAndShowTour() async {
    try {
      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'guru',
        name: 'teaching_schedule_tour',
      );

      if (status['should_show'] == true && status['tour'] != null) {
        _tourId = status['tour']['id'];

        if (!mounted) return;
        _showTour();
      }
    } catch (e) {
      if (kDebugMode) print('Error checking tour status: $e');
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
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_teaching_schedule_screen_guru', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_teaching_schedule_screen_guru', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];

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

    if (_jadwalList.isNotEmpty && !_isTableView) {
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
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final filteredSchedules = _getFilteredSchedules();

        return Scaffold(
          backgroundColor: ColorUtils.slate50,
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
                          onTap: () => Navigator.pop(context),
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
                        // DITAMBAHKAN KEMBALI: Tombol toggle view
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
                        SizedBox(width: 8),
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
                                  Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                                  SizedBox(width: 8),
                                  Text('Perbarui Data'),
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
                    SizedBox(height: 16),

                    // Role switcher: only show when user is also wali kelas
                    if (_homeroomClassesList.isNotEmpty)
                      Container(
                        padding: EdgeInsets.all(12),
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
                                  child: Text(
                                    'Guru (Lihat Jadwal Mengajar)',
                                  ),
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
                                _loadJadwal();
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
                              SizedBox(width: 12),
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
                                      _isHomeroomView && _selectedHomeroomClass != null
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
                    SizedBox(height: 16),

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
                                    style: TextStyle(
                                      color: ColorUtils.slate800,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: languageProvider
                                          .getTranslatedText({
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
                                    return GestureDetector(
                                      onTap: filter['onRemove'],
                                      child: Container(
                                        margin: EdgeInsets.only(right: 6),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.3),
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
                                            SizedBox(width: 4),
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
                            SizedBox(width: 8),
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
                          SizedBox(height: 8),
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
                          SizedBox(height: 4),

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
                                    buttonText: languageProvider
                                        .getTranslatedText({
                                          'en': 'Refresh',
                                          'id': 'Muat Ulang',
                                        }),
                                    onPressed: _loadJadwal,
                                  )
                                : RefreshIndicator(
                                    onRefresh: _loadJadwal,
                                    color: _getPrimaryColor(),
                                    backgroundColor: Colors.white,
                                    child: _isTableView
                                        ? _buildTableView(
                                            languageProvider,
                                            filteredSchedules,
                                          )
                                        : _buildCardView(
                                            languageProvider,
                                            filteredSchedules,
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
    );
  }

  // DITAMBAHKAN KEMBALI: Method untuk table view dengan format seperti Excel
  /// Builds the table/grid view of the weekly schedule.
  /// Like a Vue `<ScheduleTable>` component with days as columns and
  /// time slots as rows.
  Widget _buildTableView(
    LanguageProvider languageProvider,
    List<dynamic> schedules,
  ) {
    // Group schedules by day and class
    final Map<String, Map<String, List<dynamic>>> scheduleMap = {};

    for (var schedule in schedules) {
      final daysIds = [];
      if (schedule['days_ids'] != null) {
        if (schedule['days_ids'] is List)
          daysIds.addAll(schedule['days_ids']);
        else if (schedule['days_ids'] is String) {
          try {
            final parsed = (schedule['days_ids'] as String)
                .replaceAll('[', '')
                .replaceAll(']', '')
                .split(',');
            daysIds.addAll(parsed);
          } catch (e) {}
        }
      }
      if (daysIds.isEmpty) {
        if (schedule['day_id'] != null)
          daysIds.add(schedule['day_id']);
        else if (schedule['hari_id'] != null)
          daysIds.add(schedule['hari_id']);
      }

      for (var rawDayId in daysIds) {
        final entry = _dayIdMap.entries.firstWhere(
          (e) => e.value.toString() == rawDayId.toString(),
          orElse: () => MapEntry('Unknown', ''),
        );
        final hari = entry.key;
        if (hari == 'Unknown') continue;

        final kelas = schedule['kelas_nama']?.toString() ?? 'Unknown';

        if (!scheduleMap.containsKey(hari)) {
          scheduleMap[hari] = {};
        }
        if (!scheduleMap[hari]!.containsKey(kelas)) {
          scheduleMap[hari]![kelas] = [];
        }

        scheduleMap[hari]![kelas]!.add(schedule);
      }
    }

    // Get unique classes and days
    final classes =
        scheduleMap.values.expand((dayMap) => dayMap.keys).toSet().toList()
          ..sort();

    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    final availableDays = days
        .where((day) => scheduleMap.containsKey(day))
        .toList();

    // Get all unique session numbers
    final allSessions =
        schedules
            .map((s) => int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0)
            .toSet()
            .toList()
          ..sort();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'JADWAL PELAJARAN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _getPrimaryColor(),
                ),
              ),
              SizedBox(height: 16),

              // Table
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: ColorUtils.slate300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Header Row 1 - Hari
                    Container(
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withValues(alpha: 0.1),
                        border: Border(
                          bottom: BorderSide(color: ColorUtils.slate300),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Empty cells for time and session
                          Container(
                            width: 80,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: ColorUtils.slate300),
                              ),
                            ),
                            child: Text(
                              'Jam Ke-',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: ColorUtils.slate300),
                              ),
                            ),
                            child: Text(
                              'Waktu',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),

                          // Hari headers
                          ...availableDays.expand((day) {
                            return [
                              Container(
                                width: 200 * classes.length.toDouble(),
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: availableDays.last == day
                                          ? Colors.transparent
                                          : ColorUtils.slate300,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  day,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _getDayColor(day),
                                  ),
                                ),
                              ),
                            ];
                          }),
                        ],
                      ),
                    ),

                    // Header Row 2 - Kelas
                    Container(
                      decoration: BoxDecoration(
                        color: _getPrimaryColor().withValues(alpha: 0.05),
                        border: Border(
                          bottom: BorderSide(color: ColorUtils.slate300),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Empty cells for time and session
                          Container(
                            width: 80,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: ColorUtils.slate300),
                              ),
                            ),
                          ),
                          Container(
                            width: 100,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(color: ColorUtils.slate300),
                              ),
                            ),
                          ),

                          // Kelas headers for each day
                          ...availableDays.expand((day) {
                            return classes.asMap().entries.map((classEntry) {
                              final isLastInDay =
                                  classEntry.key == classes.length - 1;
                              final isLastDay = availableDays.last == day;

                              return Container(
                                width: 200,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: (isLastInDay && !isLastDay)
                                          ? ColorUtils.slate300
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  classEntry.value,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: ColorUtils.slate600,
                                  ),
                                ),
                              );
                            }).toList();
                          }),
                        ],
                      ),
                    ),

                    // Data Rows
                    ...allSessions.map((session) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: session == allSessions.last
                                  ? Colors.transparent
                                  : ColorUtils.slate300,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Session Number
                            Container(
                              width: 80,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: ColorUtils.slate300),
                                ),
                              ),
                              child: Text(
                                session.toString(),
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            // Time
                            Container(
                              width: 100,
                              height: 60,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: ColorUtils.slate300),
                                ),
                              ),
                              child: _buildTimeForSession(session, schedules),
                            ),

                            // Schedule Data for each day and class
                            ...availableDays.expand((day) {
                              return classes.map((kelas) {
                                final scheduleForCell =
                                    _getScheduleForSessionAndDayAndClass(
                                      session,
                                      day,
                                      kelas,
                                      schedules,
                                    );

                                return Container(
                                  width: 200,
                                  height: 60,
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      right: BorderSide(
                                        color:
                                            classes.last == kelas &&
                                                availableDays.last != day
                                            ? ColorUtils.slate300
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                  child: scheduleForCell != null
                                      ? Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: _getDayColor(
                                              day,
                                            ).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: _getDayColor(
                                                day,
                                              ).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                scheduleForCell['mata_pelajaran_nama'] ??
                                                    '',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getDayColor(day),
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (scheduleForCell['guru_nama'] !=
                                                  null)
                                                Text(
                                                  scheduleForCell['guru_nama']!,
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: ColorUtils.slate500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        )
                                      : Container(),
                                );
                              }).toList();
                            }),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Legend
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ColorUtils.slate50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: ColorUtils.slate300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keterangan:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      children: availableDays.map((day) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getDayColor(day),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            SizedBox(width: 4),
                            Text(day, style: TextStyle(fontSize: 12)),
                          ],
                        );
                      }).toList(),
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

  // Helper method to get time for session
  Widget _buildTimeForSession(int session, List<dynamic> schedules) {
    final scheduleForSession = schedules.firstWhere(
      (s) => (int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0) == session,
      orElse: () => <String, dynamic>{},
    );

    if (scheduleForSession.isNotEmpty) {
      final startTime = _formatTime(scheduleForSession['jam_mulai']);
      final endTime = _formatTime(scheduleForSession['jam_selesai']);
      return Text(
        '$startTime\n$endTime',
        style: TextStyle(fontSize: 10),
        textAlign: TextAlign.center,
      );
    }

    return Text(
      '--:--\n--:--',
      style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
      textAlign: TextAlign.center,
    );
  }

  // Helper method to find schedule for specific session, day, and class
  Map<String, dynamic>? _getScheduleForSessionAndDayAndClass(
    int session,
    String day,
    String kelas,
    List<dynamic> schedules,
  ) {
    try {
      return schedules.firstWhere(
        (s) =>
            (int.tryParse(s['jam_ke']?.toString() ?? '') ?? 0) == session &&
            s['hari_nama']?.toString() == day &&
            s['kelas_nama']?.toString() == kelas,
        orElse: () => <String, dynamic>{},
      );
    } catch (e) {
      return null;
    }
  }

  // DIPINDAH: Method untuk card view (sebelumnya _buildJadwalCard)
  /// Builds the card view of schedule items grouped by day.
  /// Like a Vue `<ScheduleCardList>` component with `v-for` over days.
  Widget _buildCardView(
    LanguageProvider languageProvider,
    List<dynamic> schedules,
  ) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        return _buildJadwalCard(schedules[index], languageProvider, index);
      },
    );
  }

  Widget _buildJadwalCard(
    Map<String, dynamic> jadwal,
    LanguageProvider languageProvider,
    int index,
  ) {
    final daysIds = _extractDayIds(jadwal);

    String dayNames = daysIds
        .map((id) {
          final entry = _dayIdMap.entries.firstWhere(
            (e) => e.value.toString() == id,
            orElse: () => MapEntry('Unknown', ''),
          );
          return entry.key;
        })
        .where((n) => n != 'Unknown' && n.isNotEmpty)
        .join(', ');

    if (dayNames.isEmpty) {
      final rawDayName = (jadwal['hari_nama'] ?? jadwal['day_name'] ?? '')
          .toString();
      if (rawDayName.isNotEmpty) dayNames = _normalizeDayName(rawDayName);
    }

    final day = dayNames.isNotEmpty ? dayNames : 'Unknown';
    final firstDayName = daysIds.isNotEmpty
        ? _dayIdMap.entries
              .firstWhere(
                (e) => e.value.toString() == daysIds.first.toString(),
                orElse: () => MapEntry('Senin', ''),
              )
              .key
        : 'Senin';
    final dayColor = _getDayColor(firstDayName);
    final primary = _getPrimaryColor();

    return Container(
      key: index == 0 ? _firstScheduleKey : null,
      margin: EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PresencePage(
                  teacher: {'id': _teacherId, 'nama': _teacherNama},
                  initialDate: DateTime.now(),
                  initialSubjectId:
                      (jadwal['subject_id'] ??
                              jadwal['mata_pelajaran_id'] ??
                              jadwal['mata_pelajaran']?['id'])
                          ?.toString(),
                  initialSubjectName:
                      (jadwal['subject_name'] ??
                              jadwal['mata_pelajaran_nama'] ??
                              jadwal['mata_pelajaran']?['name'])
                          ?.toString(),
                  initialclassId:
                      (jadwal['class_id'] ??
                              jadwal['kelas_id'] ??
                              jadwal['class']?['id'])
                          ?.toString(),
                  initialClassName:
                      (jadwal['class_name'] ??
                              jadwal['kelas_nama'] ??
                              jadwal['class']?['name'])
                          ?.toString(),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: dayColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: dayColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: dayColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jadwal['mata_pelajaran_nama'] ??
                                languageProvider.getTranslatedText({
                                  'en': 'Subject',
                                  'id': 'Mata Pelajaran',
                                }),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3),
                          Text(
                            jadwal['tahun_ajaran_nama'] ??
                                _selectedAcademicYear,
                            style: TextStyle(
                              fontSize: 11,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: dayColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: dayColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        day,
                        style: TextStyle(
                          color: dayColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Divider(height: 1, color: ColorUtils.slate100),
                SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildScheduleInfoTag(
                      Icons.access_time_rounded,
                      '${_formatTime(jadwal["jam_mulai"])} – ${_formatTime(jadwal["jam_selesai"])}',
                      primary,
                    ),
                    _buildScheduleInfoTag(
                      Icons.class_rounded,
                      jadwal['kelas_nama'] ?? '-',
                      primary,
                    ),
                    _buildScheduleInfoTag(
                      Icons.format_list_numbered_rounded,
                      'Jam ke-${jadwal["jam_ke"] ?? "-"}',
                      dayColor,
                    ),
                    if (jadwal['semester_nama'] != null)
                      _buildScheduleInfoTag(
                        Icons.calendar_month_rounded,
                        jadwal['semester_nama'],
                        ColorUtils.slate500,
                      ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  key: index == 0 ? _actionButtonsKey : null,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MateriPage(
                                teacher: {
                                  'id': _teacherId,
                                  'nama': _teacherNama,
                                },
                                initialSubjectId:
                                    (jadwal['subject_id'] ??
                                            jadwal['mata_pelajaran_id'])
                                        ?.toString(),
                                initialSubjectName:
                                    (jadwal['subject_name'] ??
                                            jadwal['mata_pelajaran_nama'])
                                        ?.toString(),
                                initialClassId:
                                    (jadwal['class_id'] ?? jadwal['kelas_id'])
                                        ?.toString(),
                                initialClassName:
                                    (jadwal['class_name'] ??
                                            jadwal['kelas_nama'])
                                        ?.toString(),
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.library_books_rounded, size: 15),
                        label: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Material',
                            'id': 'Materi',
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(
                            color: primary.withValues(alpha: 0.6),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10),
                          backgroundColor: primary.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final now = DateTime.now();
                          final scheduleDay = _dayIdMap.entries
                              .firstWhere(
                                (entry) =>
                                    entry.value.toString() ==
                                    (jadwal['day_id'] ?? jadwal['hari_id'])
                                        ?.toString(),
                                orElse: () => MapEntry('Senin', '1'),
                              )
                              .key;
                          final scheduleDayIndex = _dayOptions.indexOf(
                            scheduleDay,
                          );
                          final todayIndex = now.weekday;
                          int daysUntilSchedule = scheduleDayIndex - todayIndex;
                          if (daysUntilSchedule < 0) daysUntilSchedule += 7;
                          final scheduleDate = now.add(
                            Duration(days: daysUntilSchedule),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClassActifityScreen(
                                initialDate: scheduleDate,
                                initialSubjectId:
                                    (jadwal['subject_id'] ??
                                            jadwal['mata_pelajaran_id'])
                                        ?.toString(),
                                initialSubjectName:
                                    (jadwal['subject_name'] ??
                                            jadwal['mata_pelajaran_nama'])
                                        ?.toString(),
                                initialClassId:
                                    (jadwal['class_id'] ?? jadwal['kelas_id'])
                                        ?.toString(),
                                initialClassName:
                                    (jadwal['class_name'] ??
                                            jadwal['kelas_nama'])
                                        ?.toString(),
                                autoShowActivityDialog: true,
                              ),
                            ),
                          );
                        },
                        icon: Icon(Icons.assignment_rounded, size: 15),
                        label: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Activity',
                            'id': 'Aktivitas',
                          }),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleInfoTag(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';

    // Handle various time formats
    final cleanedTime = time.replaceAll('.', ':');
    final timeParts = cleanedTime.split(':');

    if (timeParts.length >= 2) {
      final hour = timeParts[0].padLeft(2, '0');
      final minute = timeParts[1].padLeft(2, '0');
      return '$hour:$minute';
    }

    return time.length >= 5 ? time.substring(0, 5) : time;
  }
}
