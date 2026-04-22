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
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';

import 'package:manajemensekolah/features/recommendations/presentation/mixins/data_loading_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/generate_flow_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/tour_mixin.dart';
import 'package:manajemensekolah/features/recommendations/presentation/mixins/build_mixin.dart';
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

  /// Override generateForClass to handle full flow with proper error
  /// handling and user feedback.
  @override
  Future<void> generateForClass(String classId, String className) async {
    // Step 1: Pick scope (all students or only those who need)
    final includeOnTrack = await showScopePicker(className);
    if (includeOnTrack == null || !mounted) return;

    // Step 2: Pick subject
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

    Map<String, String>? selectedSubject;
    if (subjects.length == 1) {
      selectedSubject = subjects.first;
    } else {
      selectedSubject = await _showSubjectPicker(subjects, className);
    }

    if (selectedSubject == null || !mounted) return;

    // Step 3: Generate
    setState(() => generating[classId] = true);

    AppLogger.debug('recommendation', 'Generate Recommendation Params:');
    AppLogger.debug('recommendation', '   teacherId: $effectiveTeacherId');
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
        teacherId: effectiveTeacherId,
        classId: classId,
        subjectId: selectedSubject['id'] ?? '',
        includeOnTrack: includeOnTrack,
      );

      if (result['async'] == true) {
        final jobId = result['job_id']?.toString();
        if (jobId != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Sedang memproses...')),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rekomendasi berhasil dibuat!')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rekomendasi berhasil dibuat!')),
          );
        }
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

  /// Shows a bottom-sheet subject picker. Dismisses with the chosen
  /// subject Map, or `null` if the teacher backs out.
  Future<Map<String, String>?> _showSubjectPicker(
    List<Map<String, String>> subjects,
    String className,
  ) async {
    final primaryColor = getPrimaryColor();

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BottomSheetHeader(
              title: 'Pilih Mata Pelajaran',
              subtitle: 'Generate rekomendasi AI untuk $className',
              icon: Icons.menu_book_rounded,
              primaryColor: primaryColor,
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: subjects.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final subject = subjects[i];
                  final name = subject['name'] ?? 'Mata Pelajaran';
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, subject),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.04),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(
                            color: primaryColor.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: const BorderRadius.all(
                                    Radius.circular(10)),
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                size: 18,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: ColorUtils.slate800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: primaryColor.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: MediaQuery.of(ctx).padding.bottom + 8,
            ),
          ],
        ),
      ),
    );
  }
}
