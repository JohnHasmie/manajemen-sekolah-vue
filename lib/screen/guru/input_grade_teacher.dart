import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/components/empty_state.dart';
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/models/siswa.dart';
import 'package:manajemensekolah/providers/academic_year_provider.dart';
import 'package:manajemensekolah/providers/teacher_provider.dart';
import 'package:manajemensekolah/services/api_class_services.dart';
import 'package:manajemensekolah/services/api_schedule_services.dart';
import 'package:manajemensekolah/services/api_services.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/services/api_teacher_services.dart';
import 'package:manajemensekolah/services/api_tour_services.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class GradePage extends StatefulWidget {
  final Map<String, dynamic> teacher;

  const GradePage({super.key, required this.teacher});

  @override
  GradePageState createState() => GradePageState();
}

class GradePageState extends State<GradePage> {
  // Services
  final ApiSubjectService apiSubjectService = ApiSubjectService();
  final ApiTeacherService apiTeacherService = ApiTeacherService();

  // State
  int _currentStep = 0; // 0: Class List, 1: Subject List, 2: Grade Book

  // Data Lists
  List<dynamic> _classList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _todaySchedules = [];
  Map<String, String> _dayIdMap = {};
  String _currentDayIndo = '';

  // Selected Data
  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;

  // Filtering & Pagination
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool get _isReadOnly {
    return Provider.of<AcademicYearProvider>(context, listen: false).isReadOnly;
  }

  bool get _canEdit {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    bool canEditRole = role == 'guru' || role == 'teacher';

    // If viewing a subject, check if we have edit permission for it
    if (canEditRole &&
        _selectedSubject != null &&
        _selectedSubject!.containsKey('can_edit')) {
      return _selectedSubject!['can_edit'] == true;
    }

    return canEditRole;
  }

  // Pagination State
  int _currentPage = 1;
  final int _perPage = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTodaySchedules();
      _loadClasses();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && !_isLoading) {
        if (_currentStep == 0) {
          _loadMoreClasses();
        } else if (_currentStep == 1) {
          _loadMoreSubjects();
        }
      }
    }
  }

  void _onSearchChanged() {
    // Manual search triggered by button/enter
  }

  void _handleSearch() {
    setState(() {
      _currentPage = 1;
    });
    if (_currentStep == 0) {
      _loadClasses();
    } else if (_currentStep == 1) {
      setState(() {}); // Local filtering
    }
  }

  // ==================== CACHE KEYS ====================

  String? _buildClassCacheKey() {
    if (_currentPage != 1) return null;
    if (_searchController.text.trim().isNotEmpty) return null;

    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    final yearId = academicYearProvider.selectedAcademicYear?['id']?.toString() ?? 'default';
    final teacherId = widget.teacher['id']?.toString() ?? 'unknown';
    return 'grade_classes_${teacherId}_$yearId';
  }

  String? _buildSubjectCacheKey() {
    if (_selectedClass == null) return null;

    final academicYearProvider = Provider.of<AcademicYearProvider>(
      context,
      listen: false,
    );
    final yearId = academicYearProvider.selectedAcademicYear?['id']?.toString() ?? 'default';
    final teacherId = widget.teacher['id']?.toString() ?? 'unknown';
    final classId = _selectedClass!['id']?.toString() ?? 'unknown';
    return 'grade_subjects_${teacherId}_${classId}_$yearId';
  }

  // ==================== LOAD LOGIC ====================

  Future<void> _loadClasses({bool resetPage = true, bool useCache = true}) async {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    final isGuru = _canEdit && role.contains('guru');

    if (resetPage) {
      _currentPage = 1;
      _hasMoreData = true;

      // ─── Step 1: Try TeacherProvider (populated by Dashboard) ───
      if (isGuru && useCache) {
        final teacherProvider = Provider.of<TeacherProvider>(context, listen: false);
        if (teacherProvider.isLoaded && teacherProvider.allClasses.isNotEmpty) {
          List<dynamic> providerClasses = List.from(teacherProvider.allClasses);
          _sortClassesByTodaySchedule(providerClasses);
          setState(() {
            _classList = providerClasses;
            _hasMoreData = false;
            _isLoading = false;
          });
          if (kDebugMode) print('⚡ Grade classes from TeacherProvider (${providerClasses.length})');
          return; // ✅ Provider hit — no API needed
        }
      }

      // ─── Step 2: Try loading from cache → return early ───
      if (useCache) {
        final cacheKey = _buildClassCacheKey();
        if (cacheKey != null) {
          try {
            final cached = await LocalCacheService.load(
              cacheKey,
              ttl: const Duration(hours: 3),
            );
            if (cached != null && mounted) {
              final cachedData = Map<String, dynamic>.from(cached);
              final cachedClasses = List<dynamic>.from(cachedData['classes'] ?? []);
              if (cachedClasses.isNotEmpty) {
                setState(() {
                  _classList = cachedClasses;
                  _hasMoreData = cachedData['hasMoreData'] ?? false;
                  _isLoading = false;
                });
                if (kDebugMode) print('⚡ Grade classes loaded from cache');
                return; // ✅ Cache hit — no API needed
              }
            }
          } catch (e) {
            if (kDebugMode) print('⚠️ Grade class cache load failed: $e');
          }
        }
      }

      // Show skeleton only if no data yet
      if (_classList.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
        });
      }
    }

    // ─── Step 3: No cache — fetch fresh from API ───
    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      List<dynamic> loadedClasses = [];

      if (isGuru) {
        final response = await ApiTeacherService.getTeacherClasses(
          widget.teacher['id'],
          academicYearId: academicYearId,
        );
        loadedClasses = response;
        _hasMoreData = false;
      } else {
        // Admin: Load ALL classes
        final response = await ApiClassService.getClassPaginated(
          page: _currentPage,
          limit: _perPage,
          academicYearId: academicYearId,
          search: _searchController.text,
        );
        loadedClasses = response['data'] ?? [];
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
      }

      // Sort: Today's classes first
      _sortClassesByTodaySchedule(loadedClasses);

      if (mounted) {
        setState(() {
          if (resetPage) {
            _classList = loadedClasses;
          } else {
            _classList.addAll(loadedClasses);
          }
          _isLoading = false;
        });
      }

      // ─── Step 4: Save to cache ───
      if (resetPage) {
        final cacheKey = _buildClassCacheKey();
        if (cacheKey != null) {
          LocalCacheService.save(cacheKey, {
            'classes': loadedClasses,
            'hasMoreData': _hasMoreData,
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading classes: $e');
      if (mounted) {
        if (_classList.isEmpty) {
          setState(() => _isLoading = false);
        }
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  /// Sort classes so today's scheduled classes appear first
  void _sortClassesByTodaySchedule(List<dynamic> classes) {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    if (role.contains('guru') && _todaySchedules.isNotEmpty) {
      final todayClassIds = _todaySchedules
          .map((s) => (s['class_id'] ?? s['kelas_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      classes.sort((a, b) {
        final idA = a['id'].toString();
        final idB = b['id'].toString();
        final isTodayA = todayClassIds.contains(idA);
        final isTodayB = todayClassIds.contains(idB);

        if (isTodayA && !isTodayB) return -1;
        if (!isTodayA && isTodayB) return 1;
        return 0;
      });
    }
  }

  Future<void> _loadMoreClasses() async {
    if (widget.teacher['role'] == 'guru') return;
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;
    await _loadClasses(resetPage: false);
    setState(() => _isLoadingMore = false);
  }

  Future<void> _loadSubjects({bool useCache = true}) async {
    // ─── Step 1: Try loading from cache → return early ───
    if (useCache) {
      final cacheKey = _buildSubjectCacheKey();
      if (cacheKey != null) {
        try {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 3),
          );
          if (cached != null && mounted) {
            final cachedData = Map<String, dynamic>.from(cached);
            final cachedSubjects = List<dynamic>.from(cachedData['subjects'] ?? []);
            if (cachedSubjects.isNotEmpty) {
              setState(() {
                _subjectList = cachedSubjects;
                _isLoading = false;
              });
              if (kDebugMode) print('⚡ Grade subjects loaded from cache — skipping API');
              return; // ✅ Cache hit — no API needed
            }
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Grade subject cache load failed: $e');
        }
      }
    }

    // Show skeleton only if no data yet
    if (_subjectList.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // ─── Step 2: No cache — fetch fresh from API ───
    try {
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']
          ?.toString();

      List<dynamic> subjects = [];

      final isHomeroom = _selectedClass?['is_homeroom'] == true;
      final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
      final isGuru = role.contains('guru') || role.contains('teacher');
      final isAdmin =
          !isGuru; // Assuming non-guru is admin/staff with higher privs

      // 1. Fetch subjects taught by THIS teacher in this class
      final mySchedules = await ApiScheduleService.getSchedulesPaginated(
        limit: 100,
        guruId: widget.teacher['id'],
        classId: _selectedClass!['id'].toString(),
        tahunAjaran: academicYearId,
      );
      final myData = mySchedules['data'] ?? [];
      final mySubjectIds = <String>{};
      for (var item in myData) {
        final subject = item['subject'] ?? item['mata_pelajaran'];
        if (subject != null) {
          mySubjectIds.add(subject['id'].toString());
        }
      }

      if (isHomeroom || isAdmin) {
        // 2. Homeroom or Admin: Get ALL subjects assigned to this class
        final response = await http.get(
          Uri.parse(
            '${ApiService.baseUrl}/class/${_selectedClass!['id']}/subjects',
          ),
          headers: await ApiService.getHeaders(),
        );

        if (response.statusCode == 200) {
          final allSubjects = json.decode(response.body) as List;
          final uniqueSubjects = <String, Map<String, dynamic>>{};

          for (var subject in allSubjects) {
            final subjectId = subject['id'].toString();
            var s = Map<String, dynamic>.from(subject);
            // Editable if Admin OR if I teach it
            s['can_edit'] = isAdmin || mySubjectIds.contains(subjectId);
            uniqueSubjects[subjectId] = s;
          }
          subjects = uniqueSubjects.values.toList();
        }
      } else {
        // 3. Regular Teacher (Non-Homeroom): Only SHOW what I teach
        final uniqueSubjects = <String, Map<String, dynamic>>{};
        for (var item in myData) {
          final subject = item['subject'] ?? item['mata_pelajaran'];
          if (subject != null) {
            final subjectId = subject['id'].toString();
            var s = Map<String, dynamic>.from(subject);
            s['can_edit'] = true;
            uniqueSubjects[subjectId] = s;
          }
        }
        subjects = uniqueSubjects.values.toList();
      }

      // Sort subjects: Today's subjects for THIS teacher and THIS class first
      if (_todaySchedules.isNotEmpty && _selectedClass != null) {
        final selectedClassId = _selectedClass!['id'].toString();
        final todaySubjectIds = _todaySchedules
            .where(
              (s) =>
                  (s['class_id'] ?? s['kelas_id'] ?? '').toString() ==
                  selectedClassId,
            )
            .map(
              (s) =>
                  (s['subject_id'] ?? s['mata_pelajaran_id'] ?? '').toString(),
            )
            .where((id) => id.isNotEmpty)
            .toSet();

        subjects.sort((a, b) {
          final idA = a['id'].toString();
          final idB = b['id'].toString();
          final isTodayA = todaySubjectIds.contains(idA);
          final isTodayB = todaySubjectIds.contains(idB);

          if (isTodayA && !isTodayB) return -1;
          if (!isTodayA && isTodayB) return 1;
          return 0;
        });
      }

      if (mounted) {
        setState(() {
          _subjectList = subjects;
          _isLoading = false;
        });
      }

      // ─── Step 3: Save to cache ───
      final cacheKey = _buildSubjectCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'subjects': subjects,
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading subjects: $e');
      if (mounted) {
        if (_subjectList.isEmpty) {
          setState(() => _isLoading = false);
        }
        _showErrorSnackBar(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadMoreSubjects() async {}

  // ==================== PRIORITY LOGIC ====================

  Future<void> _loadTodaySchedules() async {
    try {
      // 1. Load Days — try cache first (shared with teaching_schedule)
      List<dynamic> days = [];
      try {
        final cachedDays = await LocalCacheService.load('school_day_data', ttl: const Duration(hours: 24));
        if (cachedDays != null) {
          days = List<dynamic>.from(cachedDays);
          if (kDebugMode) print('⚡ Grade: days from cache');
        }
      } catch (_) {}
      if (days.isEmpty) {
        days = await ApiScheduleService.getHari();
        if (days.isNotEmpty) LocalCacheService.save('school_day_data', days);
      }

      final Map<String, String> dayIdMap = {};
      for (var day in days) {
        dayIdMap[day['nama'] ?? day['name'] ?? ''] = day['id'].toString();
      }

      // 2. Determine Today
      final now = DateTime.now();
      final dayNamesISO = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      final currentDayISO = dayNamesISO[now.weekday - 1];
      final currentDayIndo = _normalizeDayName(currentDayISO);

      String? currentDayId;
      dayIdMap.forEach((key, value) {
        if (_normalizeDayName(key) == currentDayIndo) {
          currentDayId = value;
        }
      });

      // 3. Load Teacher Schedules — try teaching_schedule's cache first
      final academicYearProvider = Provider.of<AcademicYearProvider>(
        context,
        listen: false,
      );
      final academicYearId = academicYearProvider.selectedAcademicYear?['id']?.toString();
      final semesterProvider = academicYearProvider.selectedAcademicYear;
      final semester = semesterProvider?['semester']?.toString() ?? '1';
      final teacherId = widget.teacher['id']?.toString() ?? '';

      List<dynamic> allSchedules = [];

      // Try teaching_schedule's cached data
      final scheduleCacheKey = 'schedule_teacher_${teacherId}_${semester}_$academicYearId';
      try {
        final cached = await LocalCacheService.load(scheduleCacheKey, ttl: const Duration(hours: 3));
        if (cached != null) {
          final cachedData = Map<String, dynamic>.from(cached);
          allSchedules = List<dynamic>.from(cachedData['jadwal'] ?? []);
          if (kDebugMode) print('⚡ Grade: schedules from teaching_schedule cache (${allSchedules.length})');
        }
      } catch (_) {}

      // Fallback to API
      if (allSchedules.isEmpty) {
        final schedules = await ApiScheduleService.getSchedulesPaginated(
          limit: 100,
          guruId: widget.teacher['id'],
          tahunAjaran: academicYearId,
        );
        allSchedules = schedules['data'] ?? [];
      }

      if (mounted) {
        setState(() {
          _dayIdMap = dayIdMap;
          _currentDayIndo = currentDayIndo;
          _todaySchedules = allSchedules.where((s) {
            final ids = _extractDayIds(s);
            // Tier 1: Match by ID
            if (currentDayId != null && ids.contains(currentDayId)) return true;
            // Tier 2: Match by Name mapping
            return ids.any((id) {
              final entry = _dayIdMap.entries.firstWhere(
                (e) => e.value == id,
                orElse: () => const MapEntry('', ''),
              );
              return entry.key.isNotEmpty &&
                  _normalizeDayName(entry.key) == currentDayIndo;
            });
          }).toList();
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error loading today schedules: $e');
    }
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
    if (schedule == null) return [];
    final rawIds = schedule['days_ids'] ?? schedule['day_id'];
    if (rawIds == null) return [];

    if (rawIds is List) {
      return rawIds.map((e) => e.toString()).toList();
    }
    if (rawIds is String) {
      if (rawIds.contains('[')) {
        try {
          final parsed = json.decode(rawIds);
          if (parsed is List) return parsed.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return rawIds
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [rawIds.toString()];
  }

  // ==================== HELPER METHODS ====================

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

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
    );
  }

  // ==================== BUILDERS ====================

  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStep0ClassList(LanguageProvider languageProvider) {
    // Filter locally if needed
    final searchTerm = _searchController.text.toLowerCase();
    final filtered = _classList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '')
          .toString()
          .toLowerCase();
      final level = (item['grade_level'] ?? item['tingkat'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(searchTerm) || level.contains(searchTerm);
    }).toList();

    if (_isLoading) {
      return SkeletonListLoading(padding: EdgeInsets.only(top: 8, bottom: 80));
    }

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.class_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Classes Found',
          'id': 'Tidak Ada Kelas',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'Try adjusting your search filters',
          'id': 'Coba sesuaikan filter pencarian anda',
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadClasses(),
      child: ListView.builder(
        padding: EdgeInsets.only(top: 8, bottom: 80),
        itemCount: filtered.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == filtered.length) {
            return Container(
              padding: EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_getPrimaryColor()),
              ),
            );
          }
          final classData = filtered[index];
          final isHomeroom = classData['is_homeroom'] == true;
          final accentColor = isHomeroom
              ? ColorUtils.primary
              : _getPrimaryColor();
          final isToday = _todaySchedules.any(
            (s) =>
                (s['class_id'] ?? s['kelas_id'] ?? '').toString() ==
                classData['id'].toString(),
          );
          final gradeLevel = classData['grade_level'] ?? classData['tingkat'];
          final homeroomTeacher = classData['homeroom_teacher_name'];

          return Container(
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedClass = classData;
                    _currentStep = 1;
                    _searchController.clear();
                  });
                  _loadSubjects();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ColorUtils.slate200, width: 1),
                    boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          isHomeroom
                              ? Icons.home_work_outlined
                              : Icons.class_outlined,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              classData['nama'] ?? classData['name'] ?? '-',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (gradeLevel != null &&
                                    gradeLevel.toString().isNotEmpty)
                                  _buildInfoTag(
                                    Icons.school_outlined,
                                    gradeLevel.toString(),
                                  ),
                                if (isHomeroom)
                                  _buildInfoTag(
                                    Icons.home_outlined,
                                    'Wali Kelas',
                                  ),
                                if (homeroomTeacher != null)
                                  _buildInfoTag(
                                    Icons.person_outlined,
                                    homeroomTeacher.toString(),
                                  ),
                                if (isToday)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.success600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: ColorUtils.success600.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.today,
                                          size: 11,
                                          color: ColorUtils.success600,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Today',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.success600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: ColorUtils.slate400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStep1SubjectList(LanguageProvider languageProvider) {
    final searchTerm = _searchController.text.toLowerCase();
    final filtered = _subjectList.where((item) {
      final name = (item['nama'] ?? item['name'] ?? '')
          .toString()
          .toLowerCase();
      final code = (item['kode'] ?? item['code'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(searchTerm) || code.contains(searchTerm);
    }).toList();

    if (_isLoading) {
      return SkeletonListLoading(padding: EdgeInsets.only(top: 8, bottom: 80));
    }

    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Subjects Found',
          'id': 'Tidak Ada Mata Pelajaran',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'No subjects found for this class',
          'id': 'Tidak ada mata pelajaran untuk kelas ini',
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSubjects(),
      child: ListView.builder(
        padding: EdgeInsets.only(top: 8, bottom: 80),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final subject = filtered[index];
          final subjectCode = subject['kode'] ?? subject['code'];
          final canEdit = subject['can_edit'] != false;
          final isToday = _todaySchedules.any(
            (s) =>
                (s['class_id'] ?? s['kelas_id'] ?? '').toString() ==
                    _selectedClass!['id'].toString() &&
                (s['subject_id'] ?? s['mata_pelajaran_id'] ?? '').toString() ==
                    subject['id'].toString(),
          );
          final accentColor = ColorUtils.warning600;

          return Container(
            margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedSubject = subject;
                    _currentStep = 2;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ColorUtils.slate200, width: 1),
                    boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          Icons.book_outlined,
                          color: accentColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject['nama'] ?? subject['name'] ?? '-',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (subjectCode != null &&
                                    subjectCode.toString().isNotEmpty)
                                  _buildInfoTag(
                                    Icons.tag,
                                    subjectCode.toString(),
                                  ),
                                if (isToday)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.success600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: ColorUtils.success600.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.today,
                                          size: 11,
                                          color: ColorUtils.success600,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'Today',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.success600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (!canEdit)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.warning600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: ColorUtils.warning600.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.lock_outline,
                                          size: 11,
                                          color: ColorUtils.warning600,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          languageProvider.getTranslatedText({
                                            'en': 'Read Only',
                                            'id': 'Hanya Lihat',
                                          }),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: ColorUtils.warning600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: ColorUtils.slate400,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        if (_currentStep == 0) {
          _selectedClass = null;
          _selectedSubject = null;
          _searchController.clear();
        } else if (_currentStep == 1) {
          _selectedSubject = null;
        }
      });
      return false;
    }
    return true;
  }

  Widget _buildHeader(BuildContext context, LanguageProvider languageProvider) {
    String title = '';
    String subtitle = '';

    if (_currentStep == 0) {
      title = languageProvider.getTranslatedText({
        'en': 'Input Grades',
        'id': 'Input Nilai',
      });
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select Class',
        'id': 'Pilih Kelas',
      });
    } else if (_currentStep == 1) {
      title = _selectedClass?['nama'] ?? _selectedClass?['name'] ?? 'Class';
      subtitle = languageProvider.getTranslatedText({
        'en': 'Select Subject',
        'id': 'Pilih Mata Pelajaran',
      });
    } else {
      return SizedBox.shrink();
    }

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
                onTap: () async {
                  final shouldPop = await _handleWillPop();
                  if (shouldPop && mounted) Navigator.pop(context);
                },
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
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_currentDayIndo.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Jadwal Hari Ini: $_currentDayIndo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          // Search Bar matched to StudentManagement
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: Colors.black87),
                    decoration: InputDecoration(
                      hintText: _currentStep == 0
                          ? languageProvider.getTranslatedText({
                              'en': 'Search class...',
                              'id': 'Cari kelas...',
                            })
                          : languageProvider.getTranslatedText({
                              'en': 'Search subject...',
                              'id': 'Cari mata pelajaran...',
                            }),
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _handleSearch(),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(right: 4),
                  child: IconButton(
                    icon: Icon(Icons.search, color: _getPrimaryColor()),
                    onPressed: _handleSearch,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        // If Step 2, we show GradeBookPage which handles its own scaffold/body
        if (_currentStep == 2) {
          return WillPopScope(
            onWillPop: _handleWillPop,
            child: GradeBookPage(
              teacher: widget.teacher,
              subject: _selectedSubject!,
              classData: _selectedClass!,
              onBack: () {
                setState(() {
                  _currentStep = 1;
                  _selectedSubject = null;
                });
              },
            ),
          );
        }

        return WillPopScope(
          onWillPop: _handleWillPop,
          child: Scaffold(
            backgroundColor: ColorUtils.slate50,
            body: Column(
              children: [
                _buildHeader(context, languageProvider),

                // Search Bar has been moved to Header
                Expanded(
                  child: _currentStep == 0
                      ? _buildStep0ClassList(languageProvider)
                      : _buildStep1SubjectList(languageProvider),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Halaman Grade Book/Tabel Nilai
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

class GradeBookPageState extends State<GradeBookPage> {
  List<Siswa> _siswaList = [];
  List<Siswa> _filteredSiswaList = [];
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

  @override
  void initState() {
    super.initState();
    _loadData();
    _updateFilteredJenisNilai();
    _searchController.addListener(_filterSiswa);
  }

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
                  siswa.nis.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  /// Process raw grade items and apply to state (used by both cache and fresh load)
  void _processAndApplyGradeData(List<dynamic> siswaData, List<dynamic> rawNilaiItems) {
    _siswaList = siswaData.map((s) => Siswa.fromJson(s)).toList();
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
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted) _checkAndShowTour();
              });
              if (kDebugMode) print('⚡ Grade book loaded from cache — skipping API');
              return; // ✅ Cache hit — no API needed
            }
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Grade book cache load failed: $e');
        }
      }

      // Show skeleton only if no data yet
      if (_siswaList.isEmpty && mounted) {
        if (showLoading) setState(() => _isLoading = true);
      }

      // ─── Step 2: No cache — fetch fresh from API ───
      // 1. Load siswa berdasarkan kelas
      final siswaData = await ApiStudentService.getStudentByClass(
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

      if (kDebugMode) print('DEBUG: Loading grades from $url');

      final response = await ApiService().get(url);

      // Handle paginated response (Map with 'data' key) or direct List
      List<dynamic> rawNilaiItems = [];
      if (response is Map<String, dynamic> && response.containsKey('data')) {
        rawNilaiItems = response['data'] as List<dynamic>;
      } else if (response is List) {
        rawNilaiItems = response;
      }

      if (kDebugMode) {
        print('DEBUG: Received ${rawNilaiItems.length} grade items');
      }

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
      Future.delayed(Duration(milliseconds: 1000), () {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    } catch (e) {
      if (kDebugMode) print('Error loading grade data: $e');
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
    Siswa siswa,
    String jenis,
    Map<String, dynamic> header,
  ) {
    try {
      final siswaId = siswa.id.toString();
      final studentClassId = siswa.studentClassId?.toString();

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
    Siswa siswa,
    String jenisNilai,
    LanguageProvider languageProvider, {
    Map<String, dynamic>? header,
  }) {
    final existingNilai = header != null
        ? _getNilaiForSiswaAndHeader(siswa, jenisNilai, header)
        : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GradeInputForm(
          teacher: widget.teacher,
          subject: widget.subject,
          siswa: siswa,
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

  Future<void> _saveInlineGrade(
    Siswa siswa,
    String jenis,
    Map<String, dynamic> header,
    String field,
    String value, {
    bool reload = true,
  }) async {
    // Check if value changed
    final currentData = _getNilaiForSiswaAndHeader(siswa, jenis, header);
    final currentValue = currentData?[field]?.toString() ?? '';

    // If value is empty and was empty, do nothing
    if (value.isEmpty && currentValue.isEmpty) return;

    // If value hasn't changed, do nothing
    if (value == currentValue) return;

    try {
      final data = {
        'student_id': siswa.id,
        'student_class_id': siswa.studentClassId,
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
      if (kDebugMode) print('Error saving inline grade: $e');
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
                    if (kDebugMode) print('Finish edit error: $e');
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
                                    siswa.nis,
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
      if (kDebugMode) print('Delete assessment error: $e');
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
      if (kDebugMode) print('Export error: $e');
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
                    '${languageProvider.getTranslatedText({'en': 'NIS', 'id': 'NIS'})}: ${siswa.nis}',
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
      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'guru',
        name: 'input_grade_tour',
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
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
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

// Form Input Nilai Individual
class GradeInputForm extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final Siswa siswa;
  final String jenisNilai;
  final Map<String, dynamic>? existingNilai;
  final dynamic assessmentId; // Added assessmentId
  final DateTime? initialDate;
  final String? initialTitle;

  const GradeInputForm({
    super.key,
    required this.teacher,
    required this.subject,
    required this.siswa,
    required this.jenisNilai,
    this.existingNilai,
    this.assessmentId, // Added assessmentId
    this.initialDate,
    this.initialTitle,
  });

  @override
  GradeInputFormState createState() => GradeInputFormState();
}

class GradeInputFormState extends State<GradeInputForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nilaiController = TextEditingController();
  final TextEditingController _deskripsiController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool get _canEdit {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    return role == 'guru' || role == 'teacher';
  }

  bool get _isReadOnly {
    return Provider.of<AcademicYearProvider>(context, listen: false).isReadOnly;
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill data jika edit
    if (widget.existingNilai != null) {
      _nilaiController.text = widget.existingNilai!['nilai'].toString();
      _deskripsiController.text =
          widget.existingNilai!['deskripsi']?.toString() ?? '';
      _titleController.text = widget.existingNilai!['title']?.toString() ?? '';

      if (widget.existingNilai!['tanggal'] != null) {
        _selectedDate = DateTime.parse(widget.existingNilai!['tanggal']);
      }
    } else {
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
      }
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
    }
  }

  @override
  void dispose() {
    _nilaiController.dispose();
    _deskripsiController.dispose();
    _titleController.dispose();
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

  Future<void> _submitNilai() async {
    if (_isReadOnly) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<LanguageProvider>(
              context,
              listen: false,
            ).getTranslatedText({
              'en': 'Cannot submit grades for inactive academic year',
              'id':
                  'Tidak dapat menyimpan nilai untuk tahun ajaran yang tidak aktif',
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      try {
        final data = {
          'student_id': widget.siswa.id,
          'student_class_id':
              widget.siswa.studentClassId, // Added for completeness
          'teacher_id': widget.teacher['id'],
          'subject_id': widget.subject['id'],
          'type': widget.jenisNilai,
          'assessment_id':
              widget.assessmentId ??
              widget
                  .existingNilai?['assessment_id'], // Priority on assessmentId
          'score': int.parse(_nilaiController.text),
          'notes': _deskripsiController.text,
          'title': _titleController.text.isNotEmpty
              ? _titleController.text
              : null,
          'date':
              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
        };

        if (widget.existingNilai != null) {
          // Update nilai yang sudah ada
          await ApiService().put(
            '/grades/${widget.existingNilai!['id']}',
            data,
          );
        } else {
          // Tambah nilai baru
          await ApiService().post('/grades', data);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<LanguageProvider>().getTranslatedText({
                'en': widget.existingNilai != null
                    ? 'Grade successfully updated'
                    : 'Grade successfully saved',
                'id': widget.existingNilai != null
                    ? 'Nilai berhasil diupdate'
                    : 'Nilai berhasil disimpan',
              }),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        if (kDebugMode) print('Submit grade error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: ColorUtils.corporateBlue600),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
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
                      onTap: () => Navigator.of(context).pop(),
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
                              'en': 'Input Grade',
                              'id': 'Input Nilai',
                            }),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.siswa.name,
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
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        // Info card - Pattern #10 detail items style
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ColorUtils.slate200),
                            boxShadow: ColorUtils.corporateShadow(
                              elevation: 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailItem(
                                Icons.person_outline,
                                languageProvider.getTranslatedText({
                                  'en': 'Student',
                                  'id': 'Siswa',
                                }),
                                widget.siswa.name,
                              ),
                              _buildDetailItem(
                                Icons.badge_outlined,
                                languageProvider.getTranslatedText({
                                  'en': 'NIS',
                                  'id': 'NIS',
                                }),
                                widget.siswa.nis,
                              ),
                              _buildDetailItem(
                                Icons.menu_book_outlined,
                                languageProvider.getTranslatedText({
                                  'en': 'Subject',
                                  'id': 'Mata Pelajaran',
                                }),
                                widget.subject['nama'] ??
                                    widget.subject['name'] ??
                                    '-',
                              ),
                              _buildDetailItem(
                                Icons.assignment_outlined,
                                languageProvider.getTranslatedText({
                                  'en': 'Type',
                                  'id': 'Jenis',
                                }),
                                _getJenisNilaiLabel(
                                  widget.jenisNilai,
                                  languageProvider,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Input Title - Pattern #9 styled field
                        Container(
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorUtils.slate200),
                          ),
                          child: TextFormField(
                            controller: _titleController,
                            style: TextStyle(color: ColorUtils.slate900),
                            decoration: InputDecoration(
                              labelText: languageProvider.getTranslatedText({
                                'en': 'Assessment Title (Optional)',
                                'id': 'Judul Penilaian (Opsional)',
                              }),
                              labelStyle: TextStyle(color: ColorUtils.slate500),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.title,
                                color: _getPrimaryColor(),
                              ),
                              helperText: languageProvider.getTranslatedText({
                                'en': 'E.g., Quiz 1, Project A',
                                'id': 'Contoh: Kuis 1, Proyek A',
                              }),
                              helperStyle: TextStyle(
                                color: ColorUtils.slate400,
                                fontSize: 11,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _getPrimaryColor(),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Input Nilai - Pattern #9 styled field
                        Container(
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorUtils.slate200),
                          ),
                          child: TextFormField(
                            controller: _nilaiController,
                            style: TextStyle(color: ColorUtils.slate900),
                            decoration: InputDecoration(
                              labelText: languageProvider.getTranslatedText({
                                'en': 'Grade',
                                'id': 'Nilai',
                              }),
                              labelStyle: TextStyle(color: ColorUtils.slate500),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.score,
                                color: _getPrimaryColor(),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _getPrimaryColor(),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return languageProvider.getTranslatedText({
                                  'en': 'Please enter grade',
                                  'id': 'Masukkan nilai',
                                });
                              }
                              if (int.tryParse(value) == null) {
                                return languageProvider.getTranslatedText({
                                  'en': 'Please enter valid integer',
                                  'id': 'Masukkan angka bulat yang valid',
                                });
                              }
                              final nilai = int.parse(value);
                              if (nilai < 0 || nilai > 100) {
                                return languageProvider.getTranslatedText({
                                  'en': 'Grade must be between 0-100',
                                  'id': 'Nilai harus antara 0-100',
                                });
                              }
                              return null;
                            },
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Input Deskripsi - Pattern #9 styled field
                        Container(
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorUtils.slate200),
                          ),
                          child: TextFormField(
                            controller: _deskripsiController,
                            style: TextStyle(color: ColorUtils.slate900),
                            decoration: InputDecoration(
                              labelText: languageProvider.getTranslatedText({
                                'en': 'Description',
                                'id': 'Deskripsi',
                              }),
                              labelStyle: TextStyle(color: ColorUtils.slate500),
                              border: InputBorder.none,
                              prefixIcon: Icon(
                                Icons.description,
                                color: _getPrimaryColor(),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _getPrimaryColor(),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            maxLines: 3,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Date picker - Pattern #9 field container style
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ColorUtils.slate200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: _getPrimaryColor(),
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                languageProvider.getTranslatedText({
                                  'en': 'Date:',
                                  'id': 'Tanggal:',
                                }),
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: ColorUtils.slate600,
                                ),
                              ),
                              Spacer(),
                              TextButton(
                                onPressed: () => _selectDate(context),
                                child: Text(
                                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: _getPrimaryColor(),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitNilai,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _getPrimaryColor(),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              widget.existingNilai != null
                                  ? languageProvider.getTranslatedText({
                                      'en': 'Update Grade',
                                      'id': 'Update Nilai',
                                    })
                                  : languageProvider.getTranslatedText({
                                      'en': 'Save Grade',
                                      'id': 'Simpan Nilai',
                                    }),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
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

// Form Input Nilai Baru untuk Multiple Siswa
class GradeInputFormNew extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final List<Siswa> siswaList;

  const GradeInputFormNew({
    super.key,
    required this.teacher,
    required this.subject,
    required this.siswaList,
  });

  @override
  GradeInputFormNewState createState() => GradeInputFormNewState();
}

class GradeInputFormNewState extends State<GradeInputFormNew> {
  final _formKey = GlobalKey<FormState>();
  DateTime _selectedDate = DateTime.now();

  bool get _canEdit {
    final role = widget.teacher['role']?.toString().toLowerCase() ?? '';
    return role == 'guru' || role == 'teacher';
  }

  bool get _isReadOnly {
    return Provider.of<AcademicYearProvider>(context, listen: false).isReadOnly;
  }

  // Variabel untuk state
  String? _selectedJenisNilai;
  final List<String> _jenisNilaiList = [
    'uh',
    'tugas',
    'uts',
    'uas',
    'pts',
    'pas',
  ];

  // Map untuk menyimpan nilai per siswa
  final Map<String, Map<String, dynamic>> _nilaiSiswaMap = {};

  // Text controllers untuk tabel input
  final Map<String, TextEditingController> _tableControllers = {};
  final Map<String, FocusNode> _tableFocusNodes = {};

  // State untuk tracking apakah jenis nilai dan tanggal sudah di-set
  bool _isConfigurationSet = false;
  String? _confirmedJenisNilai;
  DateTime? _confirmedDate;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize map dengan nilai default untuk setiap siswa
    for (var siswa in widget.siswaList) {
      _nilaiSiswaMap[siswa.id] = {'nilai': '', 'deskripsi': ''};
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

  Future<void> _submitNilai() async {
    final languageProvider = context.read<LanguageProvider>();

    if (_formKey.currentState!.validate()) {
      if (_selectedJenisNilai == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Please select grade type first',
                'id': 'Pilih jenis nilai terlebih dahulu',
              }),
            ),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Cek apakah ada setidaknya satu siswa yang memiliki nilai
      bool hasData = false;
      for (var siswa in widget.siswaList) {
        final nilaiData = _nilaiSiswaMap[siswa.id];
        if (nilaiData?['nilai']?.isNotEmpty == true) {
          hasData = true;
          break;
        }
      }

      if (!hasData) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Enter grade for at least one student',
                'id': 'Masukkan nilai untuk setidaknya satu siswa',
              }),
            ),
            backgroundColor: Colors.orange.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      try {
        int successCount = 0;

        for (var siswa in widget.siswaList) {
          final nilaiData = _nilaiSiswaMap[siswa.id];
          final nilai = nilaiData?['nilai']?.toString().trim();

          // Skip jika tidak ada nilai yang diinput
          if (nilai == null || nilai.isEmpty) {
            continue;
          }

          // Perbaikan: Kirim Student Class ID jika ada, fallback ke ID siswa (untuk kompatibilitas)
          final studentIdToSend = siswa.studentClassId ?? siswa.id;

          // ... (inside _submitNilai)
          final data = {
            'student_id': siswa.id, // For legacy/history
            'student_class_id':
                studentIdToSend, // New field required by backend
            'teacher_id': widget.teacher['id'],
            'subject_id': widget.subject['id'],
            'type': _selectedJenisNilai,
            'score': int.parse(nilaiData!['nilai']),
            'notes': nilaiData['deskripsi'] ?? '',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': '$successCount grades successfully saved',
                'id': '$successCount nilai berhasil disimpan',
              }),
            ),
            backgroundColor: Colors.green.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        if (kDebugMode) print('Submit grades batch error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Validation failed - show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en':
                  'Please check your input. Grades must be integers between 0-100.',
              'id':
                  'Periksa input Anda. Nilai harus berupa angka bulat antara 0-100.',
            }),
          ),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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

  Widget _buildInputTable(LanguageProvider languageProvider) {
    // Calculate width
    double tableWidth = 150.0; // Name column
    tableWidth += 100.0; // Nilai column
    tableWidth += 200.0; // Deskripsi column

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: MediaQuery.of(context).size.width > 600
              ? MediaQuery.of(context).size.width
              : tableWidth,
          child: Column(
            children: [
              // Header (Sticky-like appearance)
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: ColorUtils.corporateBlue600.withValues(alpha: 0.05),
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
              // Rows - scrollable
              ...widget.siswaList.map((siswa) {
                final nilaiKey = "${siswa.id}_nilai";
                final deskripsiKey = "${siswa.id}_deskripsi";

                // Initialize controllers if not exists
                if (!_tableControllers.containsKey(nilaiKey)) {
                  _tableControllers[nilaiKey] = TextEditingController();
                  _tableFocusNodes[nilaiKey] = FocusNode();
                }
                if (!_tableControllers.containsKey(deskripsiKey)) {
                  _tableControllers[deskripsiKey] = TextEditingController();
                  _tableFocusNodes[deskripsiKey] = FocusNode();
                }

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
                              siswa.nis,
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
                          controller: _tableControllers[nilaiKey],
                          focusNode: _tableFocusNodes[nilaiKey],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ColorUtils.slate900),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            hintText: '-',
                            hintStyle: TextStyle(color: ColorUtils.slate400),
                            errorStyle: TextStyle(fontSize: 10),
                          ),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (int.tryParse(value) == null) {
                                return languageProvider.getTranslatedText({
                                  'en': 'Integer only',
                                  'id': 'Hanya angka bulat',
                                });
                              }
                              final numValue = int.parse(value);
                              if (numValue < 0 || numValue > 100) {
                                return languageProvider.getTranslatedText({
                                  'en': '0-100',
                                  'id': '0-100',
                                });
                              }
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _nilaiSiswaMap[siswa.id]?['nilai'] = value;
                            });
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
                            controller: _tableControllers[deskripsiKey],
                            focusNode: _tableFocusNodes[deskripsiKey],
                            style: TextStyle(color: ColorUtils.slate900),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: languageProvider.getTranslatedText({
                                'en': 'Add description...',
                                'id': 'Tambah deskripsi...',
                              }),
                              hintStyle: TextStyle(
                                color: ColorUtils.slate400,
                                fontSize: 12,
                              ),
                            ),
                            onChanged: (value) {
                              _nilaiSiswaMap[siswa.id]?['deskripsi'] = value;
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
    );
  }

  // Build header for add mode after configured (similar to edit mode)
  Widget _buildAddHeader(LanguageProvider languageProvider) {
    return Container(
      padding: EdgeInsets.all(16),
      color: ColorUtils.warning600.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Jenis Nilai with edit icon
          GestureDetector(
            onTap: () {
              setState(() {
                _isConfigurationSet = false;
              });
            },
            child: Row(
              children: [
                Text(
                  _getJenisNilaiLabel(
                    _confirmedJenisNilai ?? '',
                    languageProvider,
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ColorUtils.warning600,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.edit, size: 16, color: ColorUtils.warning600),
              ],
            ),
          ),
          // Right side: Date in Indonesian format
          Text(
            _formatDateIndonesian(_confirmedDate!),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: ColorUtils.slate700,
            ),
          ),
        ],
      ),
    );
  }

  // Format date to Indonesian format (e.g., "05 Januari 2025")
  String _formatDateIndonesian(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString();

    return '$day $month $year';
  }

  // Build configuration panel (selection stage)
  Widget _buildConfigurationPanel(LanguageProvider languageProvider) {
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: ColorUtils.slate200, width: 1),
          ),
        ),
        child: Column(
          children: [
            // Subject Info
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getPrimaryColor().withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_outlined,
                      color: _getPrimaryColor(),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject['nama'] ??
                              widget.subject['name'] ??
                              '-',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        if (widget.subject['code'] != null ||
                            widget.subject['kode'] != null)
                          Text(
                            '${languageProvider.getTranslatedText({'en': 'Code', 'id': 'Kode'})}: ${widget.subject['code'] ?? widget.subject['kode']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Pilih Jenis Nilai - Pattern #9 style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedJenisNilai,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(
                    Icons.assignment_outlined,
                    color: _getPrimaryColor(),
                  ),
                  hintText: languageProvider.getTranslatedText({
                    'en': 'Select grade type',
                    'id': 'Pilih jenis nilai',
                  }),
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: TextStyle(color: ColorUtils.slate900),
                items: _jenisNilaiList.map((String jenis) {
                  return DropdownMenuItem<String>(
                    value: jenis,
                    child: Text(_getJenisNilaiLabel(jenis, languageProvider)),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedJenisNilai = newValue;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return languageProvider.getTranslatedText({
                      'en': 'Please select grade type',
                      'id': 'Pilih jenis nilai terlebih dahulu',
                    });
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 12),
            // Pilih Tanggal - Pattern #9 style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: _getPrimaryColor(),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Date:',
                      'id': 'Tanggal:',
                    }),
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: ColorUtils.slate600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _selectDate(context),
                    child: Text(
                      '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                      style: TextStyle(
                        fontSize: 15,
                        color: _getPrimaryColor(),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Title field - Pattern #9 style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: TextFormField(
                controller: _titleController,
                style: TextStyle(color: ColorUtils.slate900),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.title, color: _getPrimaryColor()),
                  hintText: languageProvider.getTranslatedText({
                    'en': 'Assessment Title (Optional)',
                    'id': 'Judul Penilaian (Opsional)',
                  }),
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                  helperText: languageProvider.getTranslatedText({
                    'en': 'E.g., Quiz 1, Chapter 5 Test',
                    'id': 'Contoh: Kuis 1, Ulangan Bab 5',
                  }),
                  helperStyle: TextStyle(
                    color: ColorUtils.slate400,
                    fontSize: 11,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Set button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_selectedJenisNilai != null && !_isReadOnly)
                    ? () {
                        setState(() {
                          _isConfigurationSet = true;
                          _confirmedJenisNilai = _selectedJenisNilai;
                          _confirmedDate = _selectedDate;
                        });
                      }
                    : null,
                icon: Icon(Icons.check),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Set',
                    'id': 'Tetapkan',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getPrimaryColor(),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  disabledBackgroundColor: ColorUtils.slate200,
                  disabledForegroundColor: ColorUtils.slate500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        final siswaWithNilaiCount = widget.siswaList.where((siswa) {
          final nilaiData = _nilaiSiswaMap[siswa.id];
          return nilaiData?['nilai']?.isNotEmpty == true;
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
                      onTap: () => Navigator.of(context).pop(),
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
                            widget.subject['nama'] ??
                                widget.subject['name'] ??
                                '',
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
                        _buildConfigurationPanel(languageProvider)
                      else
                        _buildAddHeader(languageProvider),

                      // Student List Section - only show after configuration is set
                      if (_isConfigurationSet) ...[
                        const SizedBox(height: 12),
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
                                  color: siswaWithNilaiCount > 0
                                      ? ColorUtils.success600.withValues(
                                          alpha: 0.08,
                                        )
                                      : ColorUtils.slate100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: siswaWithNilaiCount > 0
                                        ? ColorUtils.success600.withValues(
                                            alpha: 0.3,
                                          )
                                        : ColorUtils.slate200,
                                  ),
                                ),
                                child: Text(
                                  '$siswaWithNilaiCount/${widget.siswaList.length} ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
                                  style: TextStyle(
                                    color: siswaWithNilaiCount > 0
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
                              'en':
                                  'Edit grade and description for each student',
                              'id':
                                  'Edit nilai dan deskripsi untuk setiap siswa',
                            }),
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _buildInputTable(languageProvider)),
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
                          padding: const EdgeInsets.all(16),
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
                                onPressed: _submitNilai,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _getPrimaryColor(),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
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
      },
    );
  }
}
