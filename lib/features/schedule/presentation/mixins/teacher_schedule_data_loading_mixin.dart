import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/schedule/presentation/controllers/teacher_schedule_controller.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';

/// Mixin for user data loading and homeroom class resolution.
mixin TeacherScheduleDataLoadingMixin on ConsumerState<TeachingScheduleScreen> {
  // Protected state properties
  List<dynamic> termListInternal = [];
  String teacherIdInternal = '';
  String teacherNamaInternal = '';
  String selectedTermInternal = '1';
  String selectedAcademicYearInternal = '2024/2025';
  List<dynamic> academicYearListInternal = [];
  List<dynamic> homeroomClassesListInternal = [];
  Map<String, dynamic>? selectedHomeroomClassInternal;
  bool isLoadingInternal = true;
  bool isHomeroomViewInternal = false;

  void onSyncTriggered() {}

  void setDefaultAcademicPeriod() {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    setState(() {
      selectedAcademicYearInternal = ctrl.getCurrentAcademicYear();
    });
  }

  Future<void> loadUserData() async {
    AppLogger.debug(
      'schedule',
      '===== TeachingScheduleScreen: loadUserData STARTED =====',
    );
    try {
      final teacherProvider = ref.read(teacherRiverpod);
      final prefs = PreferencesService();

      await _tryEarlyCache(prefs);

      if (teacherProvider.isLoaded && teacherProvider.teacherId != null) {
        _applyProviderData(teacherProvider);
        await _loadRefDataAndSchedule();
        return;
      }

      AppLogger.debug('schedule', 'TeacherProvider empty, falling back to API');
      await _loadUserDataFromApi(teacherProvider, prefs);
    } catch (e) {
      AppLogger.error('schedule', 'Error in loadUserData: $e');
      setState(() => isLoadingInternal = false);
    }
  }

  Future<void> _tryEarlyCache(PreferencesService prefs) async {
    // Early cache loading is now handled by TeacherScheduleCacheMixin
  }

  void _applyProviderData(dynamic teacherProvider) {
    AppLogger.debug(
      'schedule',
      'Using TeacherProvider cache (teacherId=${teacherProvider.teacherId})',
    );
    setState(() {
      teacherIdInternal = teacherProvider.teacherId!;
      teacherNamaInternal = teacherProvider.teacherName ?? 'Guru';
      homeroomClassesListInternal = teacherProvider.homeroomClasses
          .map((cls) => Map<String, dynamic>.from(cls))
          .toList();
      if (homeroomClassesListInternal.isNotEmpty &&
          selectedHomeroomClassInternal == null) {
        selectedHomeroomClassInternal = homeroomClassesListInternal.first;
      }
    });
  }

  Future<void> _loadUserDataFromApi(
    dynamic teacherProvider,
    PreferencesService prefs,
  ) async {
    final userDataStr = prefs.getString('user');
    final userData = json.decode(userDataStr ?? '{}');
    final userId = userData['id']?.toString() ?? '';

    setState(() {
      teacherIdInternal = userId;
      teacherNamaInternal = userData['nama']?.toString() ?? 'Guru';
    });

    if (userId.isEmpty) {
      setState(() => isLoadingInternal = false);
      return;
    }

    final resolvedId = await _resolveTeacherId(
      userData,
      userId,
      teacherProvider,
    );

    if (resolvedId != null) {
      AppLogger.info('schedule', 'Resolved Teacher ID: $resolvedId');
      setState(() => teacherIdInternal = resolvedId);
      await _resolveHomeroomClasses(teacherProvider, resolvedId);
    } else {
      AppLogger.error('schedule', 'Failed to resolve Teacher ID');
    }

    await _loadRefDataAndSchedule();
  }

  Future<String?> _resolveTeacherId(
    Map<String, dynamic> userData,
    String userId,
    dynamic teacherProvider,
  ) async {
    try {
      final looksLikeTeacher =
          userData.containsKey('employee_number') ||
          userData.containsKey('nip') ||
          userData.containsKey('user_id');

      if (looksLikeTeacher) {
        AppLogger.debug('schedule', 'Use ID from prefs directly: $userId');
        return userId;
      }

      final academicYearId = _readAcademicYearId();
      await teacherProvider.ensureLoaded(academicYearId: academicYearId);

      if (teacherProvider.teacherId != null) {
        return teacherProvider.teacherId;
      }

      final teacherData = await getIt<ApiTeacherService>().getTeacherByUserId(
        userId,
        academicYearId: academicYearId,
      );
      if (teacherData != null && teacherData['id'] != null) {
        return teacherData['id'].toString();
      }
    } catch (e) {
      AppLogger.error('schedule', 'Error resolving teacher ID: $e');
    }
    return null;
  }

  Future<void> _resolveHomeroomClasses(
    dynamic teacherProvider,
    String teacherId,
  ) async {
    if (teacherProvider.isLoaded) {
      setState(() {
        homeroomClassesListInternal = teacherProvider.homeroomClasses
            .map((cls) => Map<String, dynamic>.from(cls))
            .toList();
        if (homeroomClassesListInternal.isNotEmpty &&
            selectedHomeroomClassInternal == null) {
          selectedHomeroomClassInternal = homeroomClassesListInternal.first;
        }
      });
      return;
    }

    final academicYearId = _readAcademicYearId();
    final allClasses = await getIt<ApiTeacherService>().getTeacherClasses(
      teacherId,
      academicYearId: academicYearId,
    );

    final homeroom = <Map<String, dynamic>>[];
    for (final cls in allClasses) {
      final isHR =
          cls['is_homeroom'] == true ||
          cls['is_homeroom'] == 1 ||
          cls['is_homeroom'].toString().toLowerCase() == 'true' ||
          cls['is_homeroom'].toString() == '1';
      if (isHR) {
        homeroom.add(Map<String, dynamic>.from(cls));
      }
    }

    setState(() {
      homeroomClassesListInternal = homeroom;
      if (homeroomClassesListInternal.isNotEmpty &&
          selectedHomeroomClassInternal == null) {
        selectedHomeroomClassInternal = homeroomClassesListInternal.first;
      }
    });
  }

  String? _readAcademicYearId() {
    try {
      if (!mounted) return null;
      return ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadRefDataAndSchedule() async {
    await Future.wait([loadDayData(), loadTermData(), loadAcademicYearData()]);
    // Schedule loading called by caller
  }

  Future<void> loadDayData() async {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    await ctrl.loadDayData();
  }

  Future<void> loadTermData() async {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    final result = await ctrl.loadTermData();
    if (!mounted) return;
    setState(() {
      termListInternal = result.semesterList;
    });
    if (result.selectedSemester != null) {
      setState(() {
        selectedTermInternal = result.selectedSemester!;
      });
    }
  }

  Future<void> loadAcademicYearData() async {
    final ctrl = ref.read(teacherScheduleControllerProvider);
    final result = await ctrl.loadAcademicYearData();
    if (!mounted) return;
    setState(() {
      academicYearListInternal = result.academicYearList;
      if (result.selectedAcademicYear != null) {
        selectedAcademicYearInternal = result.selectedAcademicYear!;
      }
    });
  }

  // Getters for user data and reference data
  String get teacherId => teacherIdInternal;
  String get teacherNama => teacherNamaInternal;
  String get selectedTerm => selectedTermInternal;
  String get selectedAcademicYear => selectedAcademicYearInternal;
  List<dynamic> get termList => termListInternal;
  List<dynamic> get academicYearList => academicYearListInternal;
  List<dynamic> get homeroomClassesList => homeroomClassesListInternal;

  bool get isHomeroomView => isHomeroomViewInternal;
  set isHomeroomView(bool v) => isHomeroomViewInternal = v;

  Map<String, dynamic>? get selectedHomeroomClass =>
      selectedHomeroomClassInternal;
  set selectedHomeroomClass(Map<String, dynamic>? v) =>
      selectedHomeroomClassInternal = v;

  bool get isLoading => isLoadingInternal;
  set isLoading(bool v) => isLoadingInternal = v;
}
