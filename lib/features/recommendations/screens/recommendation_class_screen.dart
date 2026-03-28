// Learning recommendation class selection screen for teachers.
// Like `pages/teacher/LearningRecommendation/ClassList.vue` in a Vue app.
//
// This is the entry point for the AI-powered learning recommendation flow.
// Teachers select a class, then drill down to individual students to view
// or generate personalized learning recommendations. The flow is:
// ClassScreen -> StudentScreen -> ResultScreen -> (optional) EditScreen.
// In Laravel terms, this is like `RecommendationController@classIndex`.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:manajemensekolah/features/recommendations/screens/recommendation_student_screen.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Displays a list of classes with AI learning recommendation summaries.
///
/// This is a StatefulWidget -- like a Vue page component with local state.
/// Each class card shows a summary (total students, recommendations generated)
/// and can be expanded to show recommendation history grouped by date.
///
/// Props (like Vue props):
/// - [teacher] -- current teacher info
/// - [classes] -- list of classes assigned to this teacher
class LearningRecommendationClassScreen extends ConsumerStatefulWidget {
  final Map<String, String> teacher;
  final List<dynamic> classes;

  const LearningRecommendationClassScreen({
    super.key,
    required this.teacher,
    required this.classes,
  });

  @override
  ConsumerState<LearningRecommendationClassScreen> createState() =>
      _LearningRecommendationClassScreenState();
}

/// State for [LearningRecommendationClassScreen].
///
/// This is like a Vue page component with `data() { return {...} }`.
/// Key state: summaries per class, recommendation history, teacher schedules,
/// expanded card toggles, and generation-in-progress flags.
///
/// `setState()` is like Vue's reactivity -- triggers a re-render when data changes.
class _LearningRecommendationClassScreenState
    extends ConsumerState<LearningRecommendationClassScreen> {
  final GlobalKey _classListKey = GlobalKey();

  // Summary data per class ID
  final Map<String, Map<String, dynamic>> _classSummaries = {};
  final Map<String, bool> _loadingSummaries = {};

  // Recommendation history per class (grouped by date)
  final Map<String, List<Map<String, dynamic>>> _classHistory = {};
  final Map<String, bool> _loadingHistory = {};

  // Subjects per class (from teaching schedule)
  List<dynamic> _teacherSchedules = [];
  bool _schedulesLoaded = false;

  // Teacher profile ID (resolved from user_id)
  String? _teacherProfileId;

  // Generate state
  final Map<String, bool> _generating = {};

  // Expanded class cards
  final Map<String, bool> _expandedClass = {};

  /// Like Vue's `mounted()` -- loads all data and schedules the onboarding tour.
  @override
  void initState() {
    super.initState();
    _loadAllData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkAndShowTour();
    });
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('recommendation_');
    await LocalCacheService.clearStartingWith('tour_recommendation_class_');
    _loadAllData(useCache: false);
  }

  /// Loads all data in parallel: teacher profile, schedules, and per-class
  /// summaries + histories. Like Vue `mounted()` calling multiple `axios.get()`
  /// in `Promise.all()`.
  Future<void> _loadAllData({bool useCache = true}) async {
    await _resolveTeacherProfileId(useCache: useCache);
    _loadTeacherSchedules(useCache: useCache);
    for (final cls in widget.classes) {
      final classId = cls['id']?.toString();
      if (classId == null) continue;
      _loadClassSummary(classId, useCache: useCache);
      _loadClassHistory(classId, useCache: useCache);
    }
  }

  Future<void> _resolveTeacherProfileId({bool useCache = true}) async {
    final userId = widget.teacher['id'] ?? '';
    if (userId.isEmpty) return;
    final cacheKey = 'recommendation_teacher_profile_$userId';

    // Try cache
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is String && cached.isNotEmpty) {
        _teacherProfileId = cached;
        return;
      }
    }

    try {
      final apiTeacherService = getIt<ApiTeacherService>();
      final profileData = await apiTeacherService.getTeacherById(userId);
      if (profileData != null) {
        _teacherProfileId = profileData['id']?.toString();
        if (_teacherProfileId != null) {
          await LocalCacheService.save(cacheKey, _teacherProfileId);
        }
      }
    } catch (e) {
      AppLogger.debug(
        'recommendation',
        'Could not resolve teacher profile ID: $e',
      );
    }
  }

  /// Get the effective teacher ID for API calls
  String get _effectiveTeacherId =>
      _teacherProfileId ?? widget.teacher['id'] ?? '';

  Future<void> _loadClassSummary(String classId, {bool useCache = true}) async {
    if (!mounted) return;
    final cacheKey = 'recommendation_summary_$classId';

    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is Map) {
        if (mounted) {
          setState(() {
            _classSummaries[classId] = Map<String, dynamic>.from(cached);
            _loadingSummaries[classId] = false;
          });
        }
        AppLogger.debug('recommendation', 'ClassSummary $classId: from cache');
        return;
      }
    }

    if (mounted) {
      setState(() => _loadingSummaries[classId] = true);
    }

    try {
      final summary = await getIt<ApiRecommendationService>().getClassSummary(
        classId,
      );
      if (mounted) {
        setState(() {
          _classSummaries[classId] = summary['data'] ?? {};
          _loadingSummaries[classId] = false;
        });
      }
      await LocalCacheService.save(cacheKey, summary['data'] ?? {});
    } catch (e) {
      AppLogger.error('recommendation', e);
      if (mounted) {
        setState(() => _loadingSummaries[classId] = false);
      }
    }
  }

  Future<void> _loadClassHistory(String classId, {bool useCache = true}) async {
    if (!mounted) return;
    final cacheKey = 'recommendation_history_${classId}_$_effectiveTeacherId';

    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _classHistory[classId] = List<Map<String, dynamic>>.from(
              cached.map((e) => Map<String, dynamic>.from(e)),
            );
            _loadingHistory[classId] = false;
          });
        }
        AppLogger.debug('recommendation', 'ClassHistory $classId: from cache');
        return;
      }
    }

    if (mounted) {
      setState(() => _loadingHistory[classId] = true);
    }

    try {
      final result = await getIt<ApiRecommendationService>().getRecommendations(
        teacherId: _effectiveTeacherId,
        classId: classId,
        perPage: 50,
      );

      if (!mounted) return;

      final recommendations = (result['data'] as List?) ?? [];
      final grouped = <String, Map<String, dynamic>>{};

      for (final rec in recommendations) {
        final createdAt = rec['created_at']?.toString() ?? '';
        if (createdAt.isEmpty) continue;

        final dateKey = createdAt.length >= 10
            ? createdAt.substring(0, 10)
            : createdAt;
        final triggerSource = rec['trigger_source']?.toString() ?? 'on_demand';
        final groupKey = '${dateKey}_$triggerSource';

        if (!grouped.containsKey(groupKey)) {
          grouped[groupKey] = {
            'date': dateKey,
            'trigger_source': triggerSource,
            'count': 0,
            'by_status': <String, int>{},
            'by_priority': <String, int>{},
            'by_category': <String, int>{},
          };
        }

        final group = grouped[groupKey]!;
        group['count'] = (group['count'] as int) + 1;

        final status = rec['status']?.toString() ?? 'pending';
        final statusMap = group['by_status'] as Map<String, int>;
        statusMap[status] = (statusMap[status] ?? 0) + 1;

        final priority = rec['priority']?.toString() ?? 'medium';
        final priorityMap = group['by_priority'] as Map<String, int>;
        priorityMap[priority] = (priorityMap[priority] ?? 0) + 1;

        final category = rec['category']?.toString() ?? '';
        if (category.isNotEmpty) {
          final catMap = group['by_category'] as Map<String, int>;
          catMap[category] = (catMap[category] ?? 0) + 1;
        }
      }

      final history = grouped.values.toList()
        ..sort((a, b) {
          final dateCompare = (b['date'] as String).compareTo(
            a['date'] as String,
          );
          if (dateCompare != 0) return dateCompare;
          return (a['trigger_source'] as String).compareTo(
            b['trigger_source'] as String,
          );
        });

      setState(() {
        _classHistory[classId] = history;
        _loadingHistory[classId] = false;
      });

      // Save grouped history to cache
      await LocalCacheService.save(cacheKey, history);
    } catch (e) {
      AppLogger.error('recommendation', e);
      if (mounted && !_classHistory.containsKey(classId)) {
        setState(() {
          _classHistory[classId] = [];
          _loadingHistory[classId] = false;
        });
      }
    }
  }

  Future<void> _loadTeacherSchedules({bool useCache = true}) async {
    final teacherIdForSchedule = widget.teacher['id'] ?? '';
    if (teacherIdForSchedule.isEmpty) return;
    final cacheKey = 'recommendation_schedules_$teacherIdForSchedule';

    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _teacherSchedules = List<dynamic>.from(cached);
            _schedulesLoaded = true;
          });
        }
        AppLogger.debug('recommendation', 'TeacherSchedules: from cache');
        return;
      }
    }

    try {
      final schedules = await getIt<ApiScheduleService>().getScheduleByTeacher(
        teacherId: teacherIdForSchedule,
      );
      if (mounted) {
        setState(() {
          _teacherSchedules = schedules;
          _schedulesLoaded = true;
        });
      }
      await LocalCacheService.save(cacheKey, schedules);
    } catch (e) {
      AppLogger.error('recommendation', e);
      if (mounted) setState(() => _schedulesLoaded = true);
    }
  }

  List<Map<String, String>> _getSubjectsForClass(String classId) {
    final seen = <String>{};
    final subjects = <Map<String, String>>[];

    for (final schedule in _teacherSchedules) {
      final scheduleClassId =
          schedule['class_id']?.toString() ??
          schedule['class']?['id']?.toString();
      if (scheduleClassId != classId) continue;

      final subjectId =
          schedule['subject_id']?.toString() ??
          schedule['subject']?['id']?.toString();
      final subjectName =
          schedule['subject']?['name']?.toString() ??
          schedule['subject_name']?.toString() ??
          'Mata Pelajaran';

      if (subjectId != null && seen.add(subjectId)) {
        subjects.add({'id': subjectId, 'name': subjectName});
      }
    }

    return subjects;
  }

  // ==================== GENERATE FLOW ====================

  Future<void> _generateForClass(String classId, String className) async {
    // Step 1: Pick scope (all students or only those who need recommendations)
    final includeOnTrack = await _showScopePicker(className);
    if (includeOnTrack == null || !mounted) return;

    // Step 2: Pick subject
    final subjects = _getSubjectsForClass(classId);
    if (subjects.isEmpty) {
      if (mounted) {
        SnackBarUtils.showInfo(
          context,
          'Tidak ada mata pelajaran ditemukan untuk kelas ini',
        );
      }
      return;
    }

    Map<String, String>? selectedSubject;
    if (subjects.length == 1) {
      selectedSubject = subjects.first;
    } else {
      selectedSubject = await showModalBottomSheet<Map<String, String>>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => _SubjectPickerSheet(
          subjects: subjects,
          className: className,
          primaryColor: _getPrimaryColor(),
        ),
      );
    }

    if (selectedSubject == null || !mounted) return;

    // Step 3: Generate
    setState(() => _generating[classId] = true);

    AppLogger.debug('recommendation', 'Generate Recommendation Params:');
    AppLogger.debug('recommendation', '   teacherId: $_effectiveTeacherId');
    AppLogger.debug('recommendation', '   classId: $classId');
    AppLogger.debug('recommendation', '   subjectId: ${selectedSubject['id']}');
    AppLogger.debug(
      'recommendation',
      '   subjectName: ${selectedSubject['name']}',
    );
    AppLogger.debug('recommendation', '   includeOnTrack: $includeOnTrack');
    AppLogger.debug('recommendation', '   className: $className');

    try {
      final result = await getIt<ApiRecommendationService>().generateForClass(
        teacherId: _effectiveTeacherId,
        classId: classId,
        subjectId: selectedSubject['id'] ?? '',
        includeOnTrack: includeOnTrack,
      );

      if (result['async'] == true) {
        final jobId = result['job_id']?.toString();
        if (jobId != null && mounted) {
          SnackBarUtils.showInfo(
            context,
            result['message'] ?? 'Sedang memproses...',
          );

          try {
            await getIt<ApiRecommendationService>().pollJobUntilComplete(
              jobId,
              onProgress: (status, attempt) {
                AppLogger.debug(
                  'recommendation',
                  'Job $jobId: $status (attempt $attempt)',
                );
              },
            );
            if (mounted) {
              SnackBarUtils.showSuccess(
                context,
                'Rekomendasi berhasil dibuat!',
              );
            }
          } catch (e) {
            if (mounted) {
              SnackBarUtils.showError(context, 'Gagal: $e');
            }
          }
        }
      } else {
        if (mounted) {
          SnackBarUtils.showSuccess(context, 'Rekomendasi berhasil dibuat!');
        }
      }

      // Invalidate cache and refresh data
      await LocalCacheService.clearStartingWith(
        'recommendation_summary_$classId',
      );
      await LocalCacheService.clearStartingWith(
        'recommendation_history_$classId',
      );
      _loadClassSummary(classId, useCache: false);
      _loadClassHistory(classId, useCache: false);
    } on RateLimitException catch (e) {
      if (mounted) {
        SnackBarUtils.showWarning(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _generating[classId] = false);
    }
  }

  Future<bool?> _showScopePicker(String className) async {
    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ColorUtils.slate300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Pilih Cakupan Siswa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ColorUtils.slate900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Generate rekomendasi AI untuk $className',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildScopeOption(
              ctx: ctx,
              value: true,
              icon: Icons.groups_rounded,
              title: 'Semua Siswa',
              subtitle:
                  'Generate rekomendasi untuk semua siswa termasuk yang sudah baik',
              color: ColorUtils.corporateBlue500,
            ),
            _buildScopeOption(
              ctx: ctx,
              value: false,
              icon: Icons.person_search_rounded,
              title: 'Siswa yang Perlu Saja',
              subtitle:
                  'Hanya siswa yang membutuhkan rekomendasi berdasarkan data performa',
              color: ColorUtils.amber500,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeOption({
    required BuildContext ctx,
    required bool value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => AppNavigator.pop(ctx, value),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: ColorUtils.slate200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: ColorUtils.slate400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== TOUR ====================

  Future<void> _checkAndShowTour() async {
    final tourCacheKey = CacheKeyBuilder.tourStatus(
      'recommendation_class_screen',
      'guru',
    );
    try {
      // Cache-only: tour status pre-fetched from dashboard
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
      AppLogger.error('recommendation', e);
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: languageProvider.getTranslatedText({
        'en': 'SKIP',
        'id': 'LEWATI',
      }),
      alignSkip: Alignment.topRight,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'learning_recommendation_class_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('recommendation_class_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'learning_recommendation_class_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('recommendation_class_screen', 'guru'),
          {'should_show': false},
        );
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "ClassList",
        keyTarget: _classListKey,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Class List',
                        'id': 'Daftar Kelas',
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
                              'Choose one of your classes to see student learning recommendations.',
                          'id':
                              'Pilih salah satu kelas Anda untuk melihat rekomendasi belajar siswa.',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return targets;
  }

  // ==================== HELPERS ====================

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _getRelativeDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(date.year, date.month, date.day);
      final diff = today.difference(target).inDays;

      if (diff == 0) return 'Hari ini';
      if (diff == 1) return 'Kemarin';
      if (diff < 7) return '$diff hari lalu';
      return _formatDate(dateStr);
    } catch (_) {
      return dateStr;
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header
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
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
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
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekomendasi Belajar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Pilih kelas untuk melihat rekomendasi siswa',
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
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'refresh') _forceRefresh();
                  },
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
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
                          const SizedBox(width: AppSpacing.sm),
                          const Text('Perbarui Data'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadAllData();
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: widget.classes.length,
                itemBuilder: (context, index) {
                  final cls = widget.classes[index];
                  final classId = cls['id']?.toString() ?? '';
                  final className = cls['name'] ?? cls['nama'] ?? 'Kelas';
                  final summary = _classSummaries[classId];
                  final isLoading = _loadingSummaries[classId] == true;
                  final isGenerating = _generating[classId] == true;
                  final history = _classHistory[classId] ?? [];
                  final isLoadingHistory = _loadingHistory[classId] == true;
                  final isExpanded = _expandedClass[classId] == true;

                  return Padding(
                    key: index == 0 ? _classListKey : null,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildClassCard(
                      className: className,
                      classId: classId,
                      classData: cls,
                      summary: summary,
                      isLoading: isLoading,
                      isGenerating: isGenerating,
                      history: history,
                      isLoadingHistory: isLoadingHistory,
                      isExpanded: isExpanded,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard({
    required String className,
    required String classId,
    required Map<String, dynamic> classData,
    Map<String, dynamic>? summary,
    bool isLoading = false,
    bool isGenerating = false,
    List<Map<String, dynamic>> history = const [],
    bool isLoadingHistory = false,
    bool isExpanded = false,
  }) {
    final byStatus = _toCountMap(summary?['by_status']);
    final totalRec = byStatus.values.fold<int>(0, (sum, v) => sum + v);
    final primaryColor = _getPrimaryColor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200, width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row - tap to expand
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _expandedClass[classId] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(16),
                bottom: isExpanded ? Radius.zero : const Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: primaryColor.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Icon(
                        Icons.class_outlined,
                        size: 24,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            className,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (isLoading)
                            Text(
                              'Memuat...',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate400,
                              ),
                            )
                          else if (totalRec > 0)
                            Text(
                              '$totalRec rekomendasi  •  ${history.length} sesi',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate500,
                              ),
                            )
                          else
                            Text(
                              'Belum ada rekomendasi',
                              style: TextStyle(
                                fontSize: 12,
                                color: ColorUtils.slate400,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: ColorUtils.slate400,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Expanded content
          if (isExpanded) ...[
            Divider(height: 1, color: ColorUtils.slate200),

            // History list
            if (isLoadingHistory)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                ),
              )
            else if (history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 32,
                      color: ColorUtils.slate300,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Belum ada riwayat rekomendasi',
                      style: TextStyle(
                        fontSize: 13,
                        color: ColorUtils.slate500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tekan tombol Generate untuk membuat rekomendasi AI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: ColorUtils.slate400,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: history.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final entry = history[index];
                  return _buildHistoryItem(
                    entry: entry,
                    classData: classData,
                    classId: classId,
                  );
                },
              ),

            // Generate button
            if (_schedulesLoaded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isGenerating
                        ? null
                        : () => _generateForClass(classId, className),
                    icon: isGenerating
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryColor,
                            ),
                          )
                        : Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: primaryColor,
                          ),
                    label: Text(
                      isGenerating ? 'Memproses...' : 'Generate Rekomendasi AI',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isGenerating
                            ? ColorUtils.slate400
                            : primaryColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isGenerating
                            ? ColorUtils.slate300
                            : primaryColor.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryItem({
    required Map<String, dynamic> entry,
    required Map<String, dynamic> classData,
    required String classId,
  }) {
    final date = entry['date'] as String;
    final count = entry['count'] is int
        ? entry['count'] as int
        : int.tryParse(entry['count'].toString()) ?? 0;
    final triggerSource = entry['trigger_source']?.toString() ?? 'on_demand';
    final byStatus = _toCountMap(entry['by_status']);
    final byPriority = _toCountMap(entry['by_priority']);
    final highCount = byPriority['high'] ?? 0;
    final pendingCount = byStatus['pending'] ?? 0;
    final completedCount = byStatus['completed'] ?? 0;

    final periodInfo = _getPeriodInfo(triggerSource);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Pass resolved teacher_id so student/result screens can query correctly
          final teacherWithProfileId = Map<String, String>.from(widget.teacher);
          if (_teacherProfileId != null) {
            teacherWithProfileId['teacher_id'] = _teacherProfileId!;
          }

          AppNavigator.push(
            context,
            LearningRecommendationStudentScreen(
              teacher: teacherWithProfileId,
              classData: classData,
            ),
          ).then((_) {
            _loadClassSummary(classId);
            _loadClassHistory(classId);
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            children: [
              // Period icon with color
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: periodInfo.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: periodInfo.color.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(periodInfo.icon, size: 18, color: periodInfo.color),
              ),
              const SizedBox(width: AppSpacing.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getRelativeDate(date),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ),
                        // Period badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: periodInfo.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: periodInfo.color.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            periodInfo.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: periodInfo.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildMiniTag(
                          '$count rekomendasi',
                          ColorUtils.slate600,
                        ),
                        if (highCount > 0)
                          _buildMiniTag(
                            '$highCount prioritas tinggi',
                            ColorUtils.red500,
                          ),
                        if (pendingCount > 0)
                          _buildMiniTag(
                            '$pendingCount pending',
                            ColorUtils.amber500,
                          ),
                        if (completedCount > 0)
                          _buildMiniTag(
                            '$completedCount selesai',
                            ColorUtils.emerald500,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Map trigger_source back to period display info
  ({Color color, String label, IconData icon}) _getPeriodInfo(
    String triggerSource,
  ) {
    switch (triggerSource) {
      case 'weekly_review':
        return (
          color: ColorUtils.corporateBlue500,
          label: 'Pekanan',
          icon: Icons.date_range_rounded,
        );
      case 'post_exam':
        return (
          color: ColorUtils.violet500,
          label: 'Bulanan/UTS',
          icon: Icons.calendar_month_rounded,
        );
      case 'attendance_alert':
        return (
          color: ColorUtils.red500,
          label: 'Kehadiran',
          icon: Icons.warning_amber_rounded,
        );
      case 'on_demand':
      default:
        return (
          color: ColorUtils.amber500,
          label: 'Semester',
          icon: Icons.emoji_events_rounded,
        );
    }
  }

  Map<String, int> _toCountMap(dynamic data) {
    if (data is Map) {
      return data.map(
        (k, v) => MapEntry(
          k.toString(),
          v is int ? v : int.tryParse(v.toString()) ?? 0,
        ),
      );
    }
    if (data is List) {
      final map = <String, int>{};
      for (final item in data) {
        if (item is Map) {
          final key =
              (item['status'] ?? item['priority'] ?? item['category'] ?? '')
                  .toString();
          final count = item['count'] is int
              ? item['count']
              : int.tryParse(item['count'].toString()) ?? 0;
          if (key.isNotEmpty) map[key] = count;
        }
      }
      return map;
    }
    return {};
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Bottom sheet for picking a subject
class _SubjectPickerSheet extends StatelessWidget {
  final List<Map<String, String>> subjects;
  final String className;
  final Color primaryColor;

  const _SubjectPickerSheet({
    required this.subjects,
    required this.className,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ColorUtils.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Pilih Mata Pelajaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Generate rekomendasi AI untuk $className',
            style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
          ),
          const SizedBox(height: AppSpacing.lg),
          ...subjects.map(
            (subject) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => AppNavigator.pop(context, subject),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: ColorUtils.slate200, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.menu_book_outlined,
                            size: 18,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            subject['name'] ?? 'Mata Pelajaran',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ),
                        Icon(Icons.auto_awesome, size: 18, color: primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
