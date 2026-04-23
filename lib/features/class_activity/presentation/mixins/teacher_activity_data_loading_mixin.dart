import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_metadata_helper.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityDataLoadingMixin
    on ConsumerState<TeacherClassActivityScreen> {
  late String _teacherId;
  late String _teacherName;

  String get teacherId => _teacherId;
  String get teacherName => _teacherName;

  Future<void> loadUserData() async {
    try {
      final teacherProvider = ref.read(teacherRiverpod);
      final prefs = PreferencesService();
      final userData = json.decode(prefs.getString('user') ?? '{}');
      final role = userData['role']?.toString().toLowerCase() ?? '';
      final isAdmin = role == 'admin' || role == 'super_admin';

      if (!isAdmin &&
          teacherProvider.isLoaded &&
          teacherProvider.teacherId != null) {
        setState(() {
          _teacherId = teacherProvider.teacherId!;
          _teacherName = teacherProvider.teacherName ?? 'Guru';
        });
        await loadInitialData(teacherProvider.teacherId!);
        return;
      }

      final userId = userData['id']?.toString() ?? '';
      setState(() {
        _teacherId = userId;
        _teacherName = userData['nama']?.toString() ?? 'Guru';
      });

      if (userId.isEmpty) {
        setState(() {});
        return;
      }

      if (isAdmin) {
        await loadInitialData(userId);
        return;
      }

      try {
        String? resolved;
        if (userData.containsKey('employee_number') ||
            userData.containsKey('nip') ||
            userData.containsKey('user_id')) {
          resolved = userId;
        } else {
          String? ayId;
          try {
            if (mounted) {
              ayId = ref
                  .read(academicYearRiverpod)
                  .selectedAcademicYear?['id']
                  ?.toString();
            }
          } catch (_) {}
          await teacherProvider.ensureLoaded(academicYearId: ayId);
          resolved = teacherProvider.teacherId;
          if (resolved == null) {
            final td = await getIt<ApiTeacherService>().getTeacherByUserId(
              userId,
              academicYearId: ayId,
            );
            resolved = td?['id']?.toString();
          }
        }
        if (resolved != null) {
          setState(() => _teacherId = resolved!);
          await loadInitialData(resolved);
        } else {
          setState(() {});
        }
      } catch (e) {
        AppLogger.error('class_activity', 'Error resolving teacher: $e');
        if (mounted) {
          SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
        }
        setState(() {});
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error in loadUserData: $e');
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
      setState(() {});
    }
  }

  /// Loads all initial data using cache-then-API pattern.
  /// Shows cached data instantly, then silently fetches fresh data from API.
  Future<void> loadInitialData(String teacherId) async {
    setLoading(true);
    final ayId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();

    try {
      // 1. Try cache for instant display
      final cacheKey = MetadataHelper.buildSummaryCacheKey(
        teacherId: teacherId,
        page: 1,
        includeContext: true,
      );
      bool hadCacheHit = false;

      if (cacheKey != null) {
        final cached = await MetadataHelper.loadCachedSummary(cacheKey);
        if (cached != null && mounted) {
          _applyLoadedData(cached);
          setLoading(false);
          _handleAutoOpen();
          hadCacheHit = true;
          // Don't return — continue fetching fresh data from API
        }
      }

      // 2. Always fetch fresh data from API
      final summaryResult =
          await getIt<ApiClassActivityService>().getTeacherActivitySummary(
        teacherId: teacherId,
        academicYearId: ayId,
        page: 1,
        perPage: 20,
        includeContext: true,
      );

      if (!mounted) return;

      // Silently update UI with fresh data
      _applyLoadedData(summaryResult);
      setLoading(false);

      // Only trigger auto-open if cache didn't already handle it
      if (!hadCacheHit) {
        _handleAutoOpen();
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error loading: $e');
      if (mounted) {
        setLoading(false);
        setActivityError(ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  /// Applies loaded data (from cache or API) to the UI state.
  void _applyLoadedData(Map<String, dynamic> summaryResult) {
    final classes = (summaryResult['class_list'] as List?) ?? [];
    final schedules = (summaryResult['schedules'] as List?) ?? [];
    final homeroomClasses =
        (summaryResult['homeroom_classes'] as List?) ?? [];

    setActivityError(null);
    onInitialDataLoaded(
      classes,
      schedules,
      summaryResult,
      homeroomClasses,
    );
  }

  /// Handles auto-open logic after data is first loaded.
  void _handleAutoOpen() {
    if (widget.initialClassId != null && widget.initialSubjectId != null) {
      openActivityList(
        classId: widget.initialClassId!,
        className: widget.initialClassName ?? '',
        subjectId: widget.initialSubjectId!,
        subjectName: widget.initialSubjectName ?? '',
      );
    } else if (widget.autoShowActivityDialog) {
      AppLogger.debug(
        'class_activity',
        'autoShowActivityDialog=true, calling autoOpenCurrentSchedule',
      );
      autoOpenCurrentSchedule();
    } else {
      AppLogger.debug(
        'class_activity',
        'autoShowActivityDialog=false, skipping auto-open',
      );
    }
  }

  /// Clears the cache and reloads initial data from the network.
  Future<void> refreshInitialData() async {
    await ApiClassActivityService.clearSummaryCache(teacherId);
    await loadInitialData(teacherId);
  }

  void onInitialDataLoaded(
    List classes,
    List schedules,
    Map<String, dynamic> summaryResult,
    List homerooms,
  );

  void openActivityList({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
  });

  void autoOpenCurrentSchedule();

  void setLoading(bool value);

  void setActivityError(String? message);
}
