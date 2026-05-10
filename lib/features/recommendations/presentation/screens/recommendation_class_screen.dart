// Learning recommendation class selection screen for teachers.
// Like `pages/teacher/LearningRecommendation/ClassList.vue` in a Vue app.
//
// This is the entry point for the AI-powered learning recommendation flow.
// Teachers select a class, then drill down to individual students to view
// or generate personalized learning recommendations. The flow is:
// ClassScreen -> StudentScreen -> ResultScreen -> (optional) EditScreen.
// In Laravel terms, this is like `RecommendationController@classIndex`.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';

import 'package:manajemensekolah/features/recommendations/presentation/mixins/data_loading_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/generate_flow_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/tour_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/build_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_generate_sheet.dart';
import 'package:manajemensekolah/features/recommendations/data/recommendation_service.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Displays a list of classes with AI learning recommendation summaries.
///
/// This is a StatefulWidget -- like a Vue page component with local state.
/// Each class card shows a summary (total students, recommendations
/// generated) and can be expanded to show recommendation history grouped
/// by date.
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
/// Key state: summaries per class, recommendation history, teacher
/// schedules, expanded card toggles, and generation-in-progress flags.
///
/// `setState()` is like Vue's reactivity -- triggers a re-render when
/// data changes.
///
/// Uses mixins for organizing logic into concerns:
/// - [DataLoadingMixin] - data loading & caching
/// - [GenerateFlowMixin] - recommendation generation flow
/// - [TourMixin] - onboarding tour
/// - [BuildMixin] - UI construction
class _LearningRecommendationClassScreenState
    extends ConsumerState<LearningRecommendationClassScreen>
    with DataLoadingMixin, GenerateFlowMixin, TourMixin, BuildMixin {
  final GlobalKey _classListKey = GlobalKey();

  @override
  GlobalKey get classListKey => _classListKey;

  /// Whether the Wali Kelas scope is active. Defaults to `false` —
  /// teachers who only have a perwalian and no teaching classes land on
  /// Mengajar with an empty state and can flip to Wali Kelas themselves.
  /// Doing it this way keeps the default consistent with the other
  /// teacher screens (Rekap Nilai, Materi, Kegiatan Kelas) regardless
  /// of assignment shape.
  @override
  bool isHomeroomView = false;

  /// Like Vue's `mounted()` -- loads all data and schedules the
  /// onboarding tour.
  @override
  void initState() {
    super.initState();
    loadAllData();
    _ensureFreshClassCounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkAndShowTour();
    });
  }

  /// Handle role-toggle: clear the per-scope caches + reload so the
  /// new tab doesn't flash stale data from the other scope.
  @override
  Future<void> onRoleToggled(bool nowHomeroom) async {
    // Wipe in-memory caches so the UI doesn't briefly show the other
    // scope's numbers while the reload lands.
    setState(() {
      classSummaries.clear();
      classHistory.clear();
      loadingSummaries.clear();
      loadingHistory.clear();
      isInitialLoading = true;
    });
    // Disk cache for history is scope-segmented by key
    // (`_wali` vs `_mengajar`) so we don't need to clear it here — the
    // next loader will hit the correct bucket. Summary cache is class-id
    // only (scope-agnostic) and is fine to reuse.
    await loadAllData(useCache: true);
  }

  /// Dashboard hydrates [TeacherProvider] from `/dashboard/full`, whose
  /// classes payload doesn't always include `students_count`. Without
  /// that field, every card subtitle rendered "Siswa belum tersedia" on
  /// first open and only flipped to the correct number once the user
  /// pulled to refresh (which hits `/teacher/{id}/classes`, the endpoint
  /// that does populate `students_count`).
  ///
  /// We check against whichever roster the active scope is about to
  /// render so the common warm-start case pays nothing, while a teacher
  /// who lands directly on Wali Kelas still gets a freshened list.
  Future<void> _ensureFreshClassCounts() async {
    final provider = ref.read(teacherRiverpod);
    final classes = isHomeroomView
        ? provider.homeroomClasses
        : provider.allClasses;
    if (classes.isEmpty) return;
    final hasStudentCount = classes.any(
      (cls) =>
          cls['students_count'] != null ||
          cls['student_count'] != null ||
          cls['jumlah_siswa'] != null,
    );
    if (hasStudentCount) return;
    await provider.refresh();
  }

  /// Force refresh by clearing cache and reloading all data.
  ///
  /// Also refreshes the global [teacherRiverpod] so the class list picks up
  /// fresh `students_count` values from the backend. Without this, the card
  /// subtitle can get stuck on stale "Siswa belum tersedia" text because
  /// [TeacherProvider] holds the classes in memory behind an
  /// `_isLoaded` gate. The prefix `recommendation_` wipe covers both
  /// mengajar + wali kelas scopes, so a pull-to-refresh always puts the
  /// screen in a clean state regardless of which tab is active.
  @override
  Future<void> forceRefresh() async {
    await LocalCacheService.clearStartingWith('recommendation_');
    await LocalCacheService.clearStartingWith('tour_recommendation_class_');
    // Refetch /teacher/{id}/classes so students_count reflects backend state.
    await ref.read(teacherRiverpod).refresh();
    await loadAllData(useCache: false);
  }

  /// Helper: Get primary color for the teacher's role.
  @override
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor(Teacher.fromJson(widget.teacher).role);
  }

  /// Override generateForClass to use the unified Frame D Generate AI
  /// sheet (violet header + scope tiles + subject FilterChipGrid +
  /// periode chip + token estimate + violet Generate CTA). The sheet
  /// returns a single [GenerateConfig] that we then fan out into N
  /// API calls, one per selected subject.
  @override
  Future<void> generateForClass(String classId, String className) async {
    final subjects = getSubjectsForClass(classId);
    if (subjects.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada mata pelajaran ditemukan untuk kelas ini'),
          ),
        );
      }
      return;
    }

    final summary = classSummaries[classId];
    final studentCount = summary?['student_count'] is num
        ? (summary!['student_count'] as num).toInt()
        : (summary?['total_students'] is num
              ? (summary!['total_students'] as num).toInt()
              : 0);
    final atRiskCount = summary?['at_risk_count'] is num
        ? (summary!['at_risk_count'] as num).toInt()
        : (studentCount > 0 ? (studentCount * 0.3).round() : 0);

    final ayLabel =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['year']
            ?.toString() ??
        'Periode aktif';

    final config = await showRecommendationGenerateSheet(
      context: context,
      className: className,
      totalStudents: studentCount,
      atRiskCount: atRiskCount,
      subjects: subjects,
      periodeLabel: 'Tahun $ayLabel',
    );
    if (config == null || !mounted) return;

    setState(() => generating[classId] = true);
    AppLogger.debug('recommendation', 'Generate Recommendation Params:');
    AppLogger.debug('recommendation', '   teacherId: $effectiveTeacherId');
    AppLogger.debug('recommendation', '   classId: $classId');
    AppLogger.debug(
      'recommendation',
      '   subjectIds: ${config.subjectIds.join(", ")}',
    );
    AppLogger.debug('recommendation', '   scope: ${config.scope}');

    final includeOnTrack = config.scope == 'all';

    try {
      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      // Fan-out one call per selected subject. The generate API
      // accepts a single subject_id; running them in series keeps
      // the rate-limit math simple.
      var failures = 0;
      for (final subjectId in config.subjectIds) {
        try {
          final result = await getIt<ApiRecommendationService>()
              .generateForClass(
                teacherId: effectiveTeacherId,
                classId: classId,
                subjectId: subjectId,
                includeOnTrack: includeOnTrack,
                academicYearId: ayId,
              );
          if (result['async'] == true) {
            final jobId = result['job_id']?.toString();
            if (jobId != null) {
              await getIt<ApiRecommendationService>().pollJobUntilComplete(
                jobId,
              );
            }
          }
        } catch (e) {
          failures++;
          AppLogger.error(
            'recommendation',
            'Generate failed for subject $subjectId: $e',
          );
        }
      }

      if (mounted) {
        final ok = config.subjectIds.length - failures;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              failures == 0
                  ? 'Rekomendasi berhasil dibuat untuk $ok mapel.'
                  : '$ok berhasil, $failures gagal.',
            ),
          ),
        );
      }

      // Invalidate cache and refresh data
      await LocalCacheService.clearStartingWith(
        'recommendation_summary_$classId',
      );
      await LocalCacheService.clearStartingWith(
        'recommendation_history_$classId',
      );
      if (mounted) {
        await loadClassSummary(classId, useCache: false);
        await loadClassHistory(classId, useCache: false);
      }
    } on RateLimitException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => generating[classId] = false);
    }
  }
}
