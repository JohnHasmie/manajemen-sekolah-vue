// Student selection screen for learning recommendations.
// Like `pages/teacher/LearningRecommendation/StudentList.vue` in a Vue app.
//
// Displays students in a selected class. Tapping a student navigates to
// the recommendation result screen. Part of the recommendation flow:
// ClassScreen -> StudentScreen (this) -> ResultScreen.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/classrooms/data/classroom_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

import 'package:manajemensekolah/features/recommendations/screens/recommendation_result_screen.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Lists students in a class for the learning recommendation flow.
///
/// Props (like Vue props): [teacher], [classData].
/// Navigates to [LearningRecommendationResultScreen] on student tap.
class LearningRecommendationStudentScreen extends ConsumerStatefulWidget {
  final Map<String, String> teacher;
  final Map<String, dynamic> classData;

  const LearningRecommendationStudentScreen({
    super.key,
    required this.teacher,
    required this.classData,
  });

  @override
  ConsumerState<LearningRecommendationStudentScreen> createState() =>
      _LearningRecommendationStudentScreenState();
}

/// State for [LearningRecommendationStudentScreen].
///
/// Like a Vue component with `data() { return { isLoading, students, errorMessage } }`.
class _LearningRecommendationStudentScreenState
    extends ConsumerState<LearningRecommendationStudentScreen> {
  bool _isLoading = true;
  List<dynamic> _students = [];
  String _errorMessage = '';
  final GlobalKey _studentListKey = GlobalKey();

  /// Like Vue's `mounted()` -- loads the student list on screen mount.
  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  String _buildStudentsCacheKey() {
    final classId = widget.classData['id']?.toString() ?? '';
    return 'recommendation_students_$classId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.invalidate(_buildStudentsCacheKey());
    await LocalCacheService.clearStartingWith('tour_recommendation_student_');
    _loadStudents(useCache: false);
  }

  /// Fetches students for the class with cache-first strategy.
  /// Like `axios.get('/api/classes/{id}/students')` in Vue.
  Future<void> _loadStudents({bool useCache = true}) async {
    final cacheKey = _buildStudentsCacheKey();

    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _students = cached;
          _isLoading = false;
          _errorMessage = '';
        });
        AppLogger.debug(
          'recommendation',
          'RecommendationStudents: from cache (${cached.length})',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkAndShowTour();
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final students = await getIt<ApiClassService>().getStudentsByClassId(
        widget.classData['id'].toString(),
      );
      if (!mounted) return;

      await LocalCacheService.save(cacheKey, students);

      setState(() {
        _students = students;
        _isLoading = false;
        _errorMessage = '';
      });

      if (students.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkAndShowTour();
        });
      }
    } catch (e) {
      if (!mounted) return;
      if (_students.isEmpty) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkAndShowTour() async {
    final tourCacheKey = CacheKeyBuilder.tourStatus(
      'recommendation_student_screen',
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
          name: 'learning_recommendation_student_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('recommendation_student_screen', 'guru'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'learning_recommendation_student_tour',
          role: 'guru',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('recommendation_student_screen', 'guru'),
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
        identify: "StudentList",
        keyTarget: _studentListKey,
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
                        'en': 'Student List',
                        'id': 'Daftar Siswa',
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
                              'Choose a student to view their AI-generated learning recommendations.',
                          'id':
                              'Pilih siswa untuk melihat rekomendasi belajar berbasis AI.',
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

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(widget.teacher['role'] ?? 'guru');
  }

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
                      Text(
                        widget.classData['name'] ??
                            widget.classData['nama'] ??
                            'Daftar Siswa',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Pilih siswa untuk melihat rekomendasi belajar',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'refresh') _forceRefresh();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(
                            Icons.refresh,
                            size: 20,
                            color: ColorUtils.info600,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(AppLocalizations.updateData.tr),
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
            child: _isLoading
                ? const SkeletonListLoading()
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _students.isEmpty
                ? const Center(child: Text('Tidak ada data siswa'))
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _students.length,
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      return Container(
                        key: index == 0 ? _studentListKey : null,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: ColorUtils.corporateShadow(),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ColorUtils.slate50,
                            child: Text(
                              (student['nama'] ?? student['name'] ?? '?')[0]
                                  .toUpperCase(),
                              style: TextStyle(
                                color: ColorUtils.slate600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            student['nama'] ??
                                student['name'] ??
                                'Siswa Tanpa Nama',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate800,
                            ),
                          ),
                          subtitle: Text(
                            'NIS: ${student['nis'] ?? student['nisn'] ?? '-'}',
                            style: TextStyle(
                              color: ColorUtils.slate500,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: ColorUtils.slate400,
                          ),
                          onTap: () {
                            AppNavigator.push(
                              context,
                              LearningRecommendationResultScreen(
                                teacher: widget.teacher,
                                student: student,
                                classData: widget.classData,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
