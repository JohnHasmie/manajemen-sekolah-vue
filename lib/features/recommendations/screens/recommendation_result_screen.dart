// Displays AI-generated learning recommendations for a specific student.
// Like `pages/teacher/LearningRecommendation/Result.vue` in a Vue app.
//
// Shows the recommendation cards with HTML content (rendered via
// flutter_widget_from_html) and allows navigation to the edit screen.
// In Laravel terms, this is like `RecommendationController@show`.
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/recommendations/screens/recommendation_edit_screen.dart';
import 'package:manajemensekolah/features/recommendations/services/recommendation_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Shows AI-generated learning recommendations for a student in a class.
///
/// Fetches recommendations from the API (with caching) and renders them
/// as expandable cards with HTML content. Teachers can navigate to the
/// edit screen to modify recommendations.
///
/// Props (like Vue props): [teacher], [student], [classData].
class LearningRecommendationResultScreen extends ConsumerStatefulWidget {
  final Map<String, String> teacher;
  final Map<String, dynamic> student;
  final Map<String, dynamic> classData;

  const LearningRecommendationResultScreen({
    super.key,
    required this.teacher,
    required this.student,
    required this.classData,
  });

  @override
  ConsumerState<LearningRecommendationResultScreen> createState() =>
      _LearningRecommendationResultScreenState();
}

/// State for [LearningRecommendationResultScreen].
///
/// Like a Vue component with `data() { return { isLoading, recommendations, errorMessage } }`.
/// Uses cache-first strategy then falls back to API.
class _LearningRecommendationResultScreenState
    extends ConsumerState<LearningRecommendationResultScreen> {
  bool _isLoading = true;
  List<dynamic> _recommendations = [];
  String _errorMessage = '';
  final GlobalKey _recommendationListKey = GlobalKey();
  final GlobalKey _editButtonKey = GlobalKey();
  String? _tourId;

  /// Like Vue's `mounted()` -- fetches recommendations on screen load.
  @override
  void initState() {
    super.initState();
    _fetchRecommendations();
  }

  String _buildRecommendationsCacheKey() {
    final teacherId = widget.teacher['teacher_id'] ?? widget.teacher['id'] ?? '';
    final classId = widget.classData['id']?.toString() ?? '';
    final studentId = widget.student['student_id']?.toString() ??
        widget.student['id']?.toString() ?? '';
    return 'recommendation_result_${teacherId}_${classId}_$studentId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.invalidate(_buildRecommendationsCacheKey());
    await LocalCacheService.clearStartingWith('tour_recommendation_result_');
    _fetchRecommendations(useCache: false);
  }

  /// Fetches learning recommendations from API with cache-first strategy.
  /// Like `axios.get('/api/recommendations')` in Vue with localStorage caching.
  /// Handles rate limiting errors gracefully.
  Future<void> _fetchRecommendations({bool useCache = true}) async {
    final cacheKey = _buildRecommendationsCacheKey();

    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _recommendations = cached;
          _isLoading = false;
          _errorMessage = '';
        });
        AppLogger.debug('recommendation', 'RecommendationResult: from cache (${cached.length})');
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
      final teacherId = widget.teacher['teacher_id'] ?? widget.teacher['id'] ?? '';
      final classId = widget.classData['id']?.toString() ?? '';
      final studentId = widget.student['student_id']?.toString() ??
          widget.student['id']?.toString() ?? '';

      AppLogger.debug('recommendation', 'Fetching recommendations: teacherId=$teacherId, classId=$classId, studentId=$studentId');

      final response = await getIt<ApiRecommendationService>().getRecommendations(
        teacherId: teacherId,
        classId: classId,
        studentId: studentId,
      );

      if (response['success'] == true) {
        final data = response['data'];
        final List recommendations;
        if (data is List) {
          recommendations = data;
        } else if (data is Map && data['data'] is List) {
          recommendations = data['data'];
        } else {
          recommendations = [];
        }

        AppLogger.debug('recommendation', 'Recommendations count: ${recommendations.length}');

        await LocalCacheService.save(cacheKey, recommendations);

        if (!mounted) return;
        setState(() {
          _recommendations = recommendations;
          _isLoading = false;
          _errorMessage = '';
        });

        if (recommendations.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _checkAndShowTour();
          });
        }
      } else {
        if (!mounted) return;
        if (_recommendations.isEmpty) {
          setState(() {
            _errorMessage = response['message'] ?? 'Gagal mengambil rekomendasi.';
            _isLoading = false;
          });
        }
      }
    } on RateLimitException catch (e) {
      if (mounted && _recommendations.isEmpty) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _recommendations.isEmpty) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkAndShowTour() async {
    final tourCacheKey = CacheKeyBuilder.tourStatus('recommendation_result_screen', 'guru');
    try {
      // Cache-only: tour status pre-fetched from dashboard
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
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
      alignSkip: Alignment.topRight,
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save(CacheKeyBuilder.tourStatus('recommendation_result_screen', 'guru'), {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          getIt<ApiTourService>().completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save(CacheKeyBuilder.tourStatus('recommendation_result_screen', 'guru'), {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "RecommendationList",
        keyTarget: _recommendationListKey,
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
                        'en': 'Learning Recommendations',
                        'id': 'Rekomendasi Belajar',
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
                              'These are AI-generated recommendations tailored to the student\'s performance.',
                          'id':
                              'Ini adalah rekomendasi berbasis AI yang disesuaikan dengan performa siswa.',
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

    targets.add(
      TargetFocus(
        identify: "EditButton",
        keyTarget: _editButtonKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
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
                        'en': 'Edit Results',
                        'id': 'Ubah Hasil',
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
                              'Tap here to manually adjust or regenerate the recommendations.',
                          'id':
                              'Ketuk di sini untuk menyesuaikan secara manual atau membuat ulang rekomendasi.',
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

  void _navigateToEdit() async {
    final result = await AppNavigator.push(context, LearningRecommendationEditScreen(
          teacher: widget.teacher,
          student: widget.student,
          recommendations: _recommendations,
        ));

    if (result == true) {
      await LocalCacheService.invalidate(_buildRecommendationsCacheKey());
      _fetchRecommendations(useCache: false); // Refresh if data was saved
    }
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
                        'Siswa: ${widget.student['nama'] ?? widget.student['name'] ?? 'Siswa'}',
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
                    if (value == 'edit') _navigateToEdit();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20, color: ColorUtils.info600),
                          const SizedBox(width: AppSpacing.sm),
                          const Text('Perbarui Data'),
                        ],
                      ),
                    ),
                    if (!_isLoading && _recommendations.isNotEmpty)
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_note, size: 20, color: ColorUtils.slate600),
                            const SizedBox(width: AppSpacing.sm),
                            const Text('Edit Hasil'),
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
                : _recommendations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxxl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 48,
                            color: ColorUtils.slate300,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'Belum ada rekomendasi untuk siswa ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: ColorUtils.slate500,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Generate rekomendasi dari halaman kelas terlebih dahulu.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: ColorUtils.slate400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: _recommendations.length,
                    itemBuilder: (context, index) {
                      final rec = _recommendations[index];
                      return _buildRecommendationCard(rec, isFirst: index == 0);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: (!_isLoading && _recommendations.isNotEmpty)
          ? FloatingActionButton.extended(
              key: _editButtonKey,
              onPressed: _navigateToEdit,
              backgroundColor: _getPrimaryColor(),
              icon: const Icon(Icons.edit, color: Colors.white, size: 20),
              label: const Text(
                'Edit Hasil',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildRecommendationCard(
    Map<String, dynamic> rec, {
    bool isFirst = false,
  }) {
    final priority = rec['priority']?.toString().toLowerCase() ?? 'low';
    final type = rec['type']?.toString().toLowerCase() ?? 'other';

    Color priorityColor;
    if (priority == 'high') {
      priorityColor = Colors.red;
    } else if (priority == 'medium') {
      priorityColor = Colors.orange;
    } else {
      priorityColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: ColorUtils.corporateShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header with Badge
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: ColorUtils.slate600,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Icon(Icons.more_horiz, color: ColorUtils.slate300),
              ],
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              key: isFirst ? _recommendationListKey : null,
              rec['title'] ?? 'Rekomendasi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: ColorUtils.slate800,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Description (HTML render)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REKOMENDASI:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: ColorUtils.slate400,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                HtmlWidget(
                  rec['description'] ?? '',
                  textStyle: TextStyle(
                    fontSize: 15,
                    color: ColorUtils.slate700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          // AI Reasoning
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ColorUtils.primary.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: ColorUtils.primary.withValues(alpha: 0.1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: ColorUtils.primary,
                      size: 16,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'BERDASARKAN ANALISIS AI:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: ColorUtils.primary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  rec['ai_reasoning'] ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate700,
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          // Materials
          if (rec['materials'] != null &&
              (rec['materials'] as List).isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: 12,
              ),
              child: Text(
                'MATERI & AKTIVITAS:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: ColorUtils.slate400,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...(rec['materials'] as List).map((mat) => _buildMaterialItem(mat)),
          ],

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildMaterialItem(Map<String, dynamic> mat) {
    IconData iconData;
    Color iconColor;

    final type = mat['type']?.toString().toLowerCase() ?? 'other';
    if (type == 'video') {
      iconData = Icons.play_circle_filled_rounded;
      iconColor = Colors.red.shade600;
    } else if (type == 'exercise') {
      iconData = Icons.task_alt_rounded;
      iconColor = Colors.orange.shade700;
    } else if (type == 'reading') {
      iconData = Icons.auto_stories_rounded;
      iconColor = Colors.blue.shade700;
    } else {
      iconData = Icons.extension_rounded;
      iconColor = ColorUtils.slate400;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mat['title'] ?? 'Materi',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                HtmlWidget(
                  mat['content'] ?? '',
                  textStyle: TextStyle(
                    fontSize: 14,
                    color: ColorUtils.slate600,
                    height: 1.4,
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
