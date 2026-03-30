// Parent view of student grades.
// Like `pages/parent/Grades.vue` in a Vue app.
//
// Read-only view of a child's grades with student selector,
// auto-marking grades as read when scrolled into view, and caching.
// In Laravel terms: `GradeController@parentIndex`.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer;
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/parent_grade_empty_state.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/parent_grade_header.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/parent_grade_list_view.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/parent_grade_student_selector.dart';

/// Parent's read-only view of student grades with read tracking.
///
/// Uses the same debounced visibility-based "mark as read" pattern.
/// Props: optional [academicYearId].
class ParentGradeScreen extends ConsumerStatefulWidget {
  final String? academicYearId;

  const ParentGradeScreen({super.key, this.academicYearId});

  @override
  ParentGradeScreenState createState() => ParentGradeScreenState();
}

/// State for [ParentGradeScreen].
///
/// Like a Vue page component with `data() { return {...} }`.
/// Key state: grade list, student selector, visibility-based read tracking.
class ParentGradeScreenState extends ConsumerState<ParentGradeScreen> {
  List<dynamic> _gradeList = [];
  List<dynamic> _studentList = [];
  String? _selectedStudentId;
  bool _isLoading = true;

  final GlobalKey _studentSelectorKey = GlobalKey();
  final GlobalKey _gradeListKey = GlobalKey();

  // Visibility Tracking
  final Set<String> _processedIds = {}; // IDs we've already handled/queued
  final Set<String> _pendingReadIds = {}; // IDs waiting to be sent to API
  Timer? _markReadDebounce;

  @override
  void dispose() {
    _markReadDebounce?.cancel(); // Cancel visibility debounce
    if (_pendingReadIds.isNotEmpty) {
      _flushMarkReadSilently(List.from(_pendingReadIds));
      _pendingReadIds.clear();
    }
    super.dispose();
  }

  Future<void> _flushMarkReadSilently(List<String> ids) async {
    try {
      await GradeService.markGradeAsRead(ids);
    } catch (e) {
      AppLogger.error('grades', e);
    }
  }

  void _onItemVisible(Map<String, dynamic> grade) {
    final id = grade['id'].toString();
    final isRead =
        grade['is_read'] == true ||
        grade['is_read'] == 1 ||
        grade['is_read'] == '1';

    if (!isRead && !_processedIds.contains(id)) {
      _processedIds.add(id);
      _pendingReadIds.add(id);
      _scheduleMarkRead();
    }
  }

  void _scheduleMarkRead() {
    if (_markReadDebounce?.isActive ?? false) return;

    _markReadDebounce = Timer(const Duration(seconds: 1), () {
      if (_pendingReadIds.isNotEmpty) {
        final idsToMark = _pendingReadIds.toList();
        _pendingReadIds.clear(); // Clear pending first to avoid duplicates
        _flushMarkRead(idsToMark);
      }
    });
  }

  Future<void> _flushMarkRead(List<String> ids) async {
    try {
      AppLogger.debug(
        'grades',
        'Auto-marking ${ids.length} visible grades as read...',
      );

      // Optimistic Update (update local list UI immediately)
      setState(() {
        for (var item in _gradeList) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await GradeService.markGradeAsRead(ids);
    } catch (e) {
      AppLogger.error('grades', e);
    }
  }

  final Map<String, Color> _gradeTypeColorMap = {
    'tugas': ColorUtils.corporateBlue600,
    'uh': ColorUtils.success600,
    'uts': ColorUtils.warning600,
    'uas': ColorUtils.error600,
  };

  String get _studentsCacheKey =>
      'parent_grade_students_${widget.academicYearId ?? 'default'}';

  String _buildGradesCacheKey() {
    return 'parent_grade_list_${_selectedStudentId}_${widget.academicYearId ?? 'default'}';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('parent_grade_');
    await LocalCacheService.clearStartingWith('tour_parent_grade_');
    _loadUserData(useCache: false);
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData({bool useCache = true}) async {
    try {
      await _loadStudentsForParent(useCache: useCache);
    } catch (e) {
      AppLogger.error('grades', e);
      setState(() => _isLoading = false);
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadStudentsForParent({bool useCache = true}) async {
    // Try cache — return early if hit
    if (useCache) {
      final cached = await LocalCacheService.load(
        _studentsCacheKey,
        ttl: const Duration(hours: 6),
      );
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _studentList = cached;
          _isLoading = false;
        });
        if (_studentList.length == 1 && _selectedStudentId == null) {
          _selectedStudentId = _studentList[0]['id'];
          await _loadGrades(useCache: true);
        }
        AppLogger.debug(
          'grades',
          'ParentGradeStudents: from cache (${cached.length})',
        );
        return;
      }
    }

    // No cache — fetch from API
    if (_studentList.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = PreferencesService();
      final userData = json.decode(prefs.getString('user') ?? '{}');
      final userId = userData['id']?.toString() ?? '';
      final guardianEmail = userData['email']?.toString();

      final allStudents = await getIt<ApiStudentService>().getStudent(
        academicYearId: widget.academicYearId,
        userId: userId,
        guardianEmail: guardianEmail,
      );

      final filteredStudents = allStudents.where((student) {
        return student['guardian_email'] == userData['email'] ||
            student['guardian_name'] == userData['name'] ||
            student['user_id'].toString() == userId ||
            student['parent_id'].toString() == userId ||
            student['wali_id'].toString() == userId ||
            (userData['student_id'] != null &&
                student['id'] == userData['student_id']) ||
            (userData['siswa_id'] != null &&
                student['id'] == userData['siswa_id']);
      }).toList();

      if (!mounted) return;

      LocalCacheService.save(_studentsCacheKey, filteredStudents);

      setState(() {
        _studentList = filteredStudents;
      });

      if (_studentList.isNotEmpty) {
        if (_studentList.length == 1) {
          _selectedStudentId = _studentList[0]['id'];
          await _loadGrades(useCache: useCache);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('grades', e);
      if (!mounted) return;
      if (_studentList.isEmpty) {
        setState(() => _isLoading = false);
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadGrades({bool useCache = true}) async {
    if (_selectedStudentId == null) return;

    final cacheKey = _buildGradesCacheKey();

    // Try cache — return early if hit (don't use for grades with is_read tracking)
    if (useCache) {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _gradeList = cached;
          _isLoading = false;
        });
        AppLogger.debug(
          'grades',
          'ParentGrades: from cache (${cached.length})',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _studentList.isNotEmpty) _checkAndShowTour();
        });
        return;
      }
    }

    // No cache — fetch from API
    if (_gradeList.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final grades = await GradeService.getGrades(
        studentId: _selectedStudentId,
        academicYearId: widget.academicYearId,
      );

      if (!mounted) return;

      LocalCacheService.save(cacheKey, grades);

      setState(() {
        _gradeList = grades;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.error('grades', e);
      if (!mounted) return;
      if (_gradeList.isEmpty) {
        setState(() => _isLoading = false);
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _studentList.isNotEmpty) _checkAndShowTour();
      });
    }
  }

  Future<void> _checkAndShowTour() async {
    final tourCacheKey = CacheKeyBuilder.tourStatus(
      'parent_grade_screen',
      'wali',
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
      AppLogger.error('grades', e);
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
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        getIt<ApiTourService>().completeTour(
          name: 'parent_grade_screen_tour',
          role: 'wali',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('parent_grade_screen', 'wali'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'parent_grade_screen_tour',
          role: 'wali',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('parent_grade_screen', 'wali'),
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
        identify: "StudentSelector",
        keyTarget: _studentSelectorKey,
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
                    languageProvider.getTranslatedText({
                      'en': 'Select Child',
                      'id': 'Pilih Anak',
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
                        'en': 'Select your child to view their grades.',
                        'id': 'Pilih anak Anda untuk melihat nilai mereka.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
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
        identify: "GradeList",
        keyTarget: _gradeListKey,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Grade List',
                      'id': 'Daftar Nilai',
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
                            'Here you can see the scores and details of your child\'s assessments.',
                        'id':
                            'Di sini Anda dapat melihat skor dan detail dari penilaian anak Anda.',
                      }),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('wali');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  Widget _buildStudentSelector() => ParentGradeStudentSelector(
        studentList: _studentList,
        selectedStudentId: _selectedStudentId,
        selectorKey: _studentSelectorKey,
        onStudentChanged: (value) {
          setState(() {
            _selectedStudentId = value;
            _gradeList = [];
          });
          _loadGrades();
        },
      );

  void _showGradeDetail(Map<String, dynamic> grade) {
    final primaryColor = _getPrimaryColor();
    final type = grade['type']?.toString().toLowerCase() ?? 'tugas';
    final typeColor = _gradeTypeColorMap[type] ?? ColorUtils.corporateBlue600;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gradient header
            Container(
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.75)],
                ),
              ),
              child: Row(
                children: [
                  // Score badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        grade['score']?.toString() ?? '0',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          grade['subject_name'] ??
                              grade['mata_pelajaran'] ??
                              AppLocalizations.subject.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (grade['title'] != null &&
                            grade['title'].toString().isNotEmpty) ...[
                          SizedBox(height: 2),
                          Text(
                            grade['title'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 350),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      Icons.person_rounded,
                      AppLocalizations.teacher.tr,
                      grade['teacher_name'] ?? AppLocalizations.unknown.tr,
                    ),
                    _buildDetailRow(
                      Icons.calendar_today_rounded,
                      AppLocalizations.assessmentDate.tr,
                      _formatDate(grade['date']),
                    ),
                    _buildDetailRow(
                      Icons.category_rounded,
                      AppLocalizations.grades.tr,
                      type.toUpperCase(),
                      iconColor: typeColor,
                    ),
                    if (grade['notes'] != null &&
                        grade['notes'].toString().isNotEmpty &&
                        grade['notes'] != 'null')
                      _buildDetailRow(
                        Icons.notes_rounded,
                        AppLocalizations.teacherNotes.tr,
                        grade['notes'].toString(),
                      ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: ColorUtils.slate100)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => AppNavigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: ColorUtils.slate300),
                    foregroundColor: ColorUtils.slate700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.close.tr,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    Color? iconColor,
  }) {
    final c = iconColor ?? _getPrimaryColor();
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: c),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final dt = AppDateUtils.parseApiDate(date);
      if (dt == null) return date.toString();
      // Use intl package if available, or simple string formatting
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildEmptyState(String message) =>
      ParentGradeEmptyState(message: message);

  Widget _buildLoadingState() {
    return SkeletonListLoading(
      itemCount: 6,
      infoTagCount: 2,
      baseColor: _getPrimaryColor().withValues(alpha: 0.15),
      highlightColor: _getPrimaryColor().withValues(alpha: 0.05),
    );
  }

  String _getGradeTypeLabel(String type) {
    switch (type) {
      case 'tugas':
        return AppLocalizations.assignment.tr;
      case 'uh':
        return 'UH';
      case 'uts':
        return 'UTS';
      case 'uas':
        return 'UAS';
      default:
        return type.toUpperCase();
    }
  }

  Widget _buildGradeList() {
    // Determine what to show when the list is empty: skeleton or empty-state.
    // This is passed to ParentGradeListView as `loadingWidget` so the widget
    // stays stateless — like passing a v-slot to a Vue component.
    final fallback = _isLoading
        ? _buildLoadingState()
        : _buildEmptyState(AppLocalizations.noGradesData.tr);

    return ParentGradeListView(
      gradeList: _gradeList,
      selectedStudentId: _selectedStudentId,
      loadingWidget: fallback,
      listKey: _gradeListKey,
      gradeTypeColorMap: _gradeTypeColorMap,
      formatDate: _formatDate,
      getGradeTypeLabel: _getGradeTypeLabel,
      onItemVisible: _onItemVisible,
      onGradeTap: _showGradeDetail,
    );
  }

  Widget _buildHeader() => ParentGradeHeader(
        gradient: _getCardGradient(),
        primaryColor: _getPrimaryColor(),
        onRefresh: _forceRefresh,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(),
          _buildStudentSelector(),
          Expanded(child: _buildGradeList()),
        ],
      ),
    );
  }
}
