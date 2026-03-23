// Parent view of student grades.
// Like `pages/parent/Grades.vue` in a Vue app.
//
// Read-only view of a child's grades with student selector,
// auto-marking grades as read when scrolled into view, and caching.
// In Laravel terms: `GradeController@parentIndex`.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/students/services/student_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Parent's read-only view of student grades with read tracking.
///
/// Uses the same debounced visibility-based "mark as read" pattern.
/// Props: optional [academicYearId].
class ParentGradeScreen extends StatefulWidget {
  final String? academicYearId;

  const ParentGradeScreen({super.key, this.academicYearId});

  @override
  ParentGradeScreenState createState() => ParentGradeScreenState();
}

/// State for [ParentGradeScreen].
///
/// Like a Vue page component with `data() { return {...} }`.
/// Key state: grade list, student selector, visibility-based read tracking.
class ParentGradeScreenState extends State<ParentGradeScreen> {
  List<dynamic> _gradeList = [];
  List<dynamic> _studentList = [];
  String? _selectedStudentId;
  bool _isLoading = true;

  String? _tourId;
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
      await ApiService.markGradeAsRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error silent auto-marking read: $e");
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
      if (kDebugMode) {
        print('📨 Auto-marking ${ids.length} visible grades as read...');
      }

      // Optimistic Update (update local list UI immediately)
      setState(() {
        for (var item in _gradeList) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      await ApiService.markGradeAsRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error auto-marking read: $e");
    }
  }

  final Map<String, Color> _gradeTypeColorMap = {
    'tugas': ColorUtils.corporateBlue600,
    'uh': ColorUtils.success600,
    'uts': ColorUtils.warning600,
    'uas': ColorUtils.error600,
  };

  String get _studentsCacheKey => 'parent_grade_students_${widget.academicYearId ?? 'default'}';

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
      if (kDebugMode) {
        print('Error load user data: $e');
      }
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _loadStudentsForParent({bool useCache = true}) async {
    // Try cache — return early if hit
    if (useCache) {
      final cached = await LocalCacheService.load(_studentsCacheKey, ttl: const Duration(hours: 6));
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
        if (kDebugMode) print('📦 ParentGradeStudents: from cache (${cached.length})');
        return;
      }
    }

    // No cache — fetch from API
    if (_studentList.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = json.decode(prefs.getString('user') ?? '{}');
      final userId = userData['id']?.toString() ?? '';
      final guardianEmail = userData['email']?.toString();

      final allStudents = await ApiStudentService.getStudent(
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
      if (kDebugMode) print('Error load students for parent grade: $e');
      if (!mounted) return;
      if (_studentList.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
      }
    }
  }

  Future<void> _loadGrades({bool useCache = true}) async {
    if (_selectedStudentId == null) return;

    final cacheKey = _buildGradesCacheKey();

    // Try cache — return early if hit (don't use for grades with is_read tracking)
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey, ttl: const Duration(hours: 3));
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _gradeList = cached;
          _isLoading = false;
        });
        if (kDebugMode) print('📦 ParentGrades: from cache (${cached.length})');
        Future.delayed(const Duration(milliseconds: 500), () {
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
      final grades = await ApiService.getNilai(
        siswaId: _selectedStudentId,
        academicYearId: widget.academicYearId,
      );

      if (!mounted) return;

      LocalCacheService.save(cacheKey, grades);

      setState(() {
        _gradeList = grades;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) print('Error load grades: $e');
      if (!mounted) return;
      if (_gradeList.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted && _studentList.isNotEmpty) _checkAndShowTour();
      });
    }
  }

  Future<void> _checkAndShowTour() async {
    const tourCacheKey = 'tour_parent_grade_screen_wali';
    try {
      // Try cache first
      final cached = await LocalCacheService.load(tourCacheKey, ttl: const Duration(hours: 24));
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true && cached['tour'] != null) {
          _tourId = cached['tour']['id']?.toString();
          if (!mounted) return;
          _showTour();
        }
        return;
      }

      final status = await ApiTourService.getTourStatus(
        platform: 'mobile',
        role: 'wali',
        name: 'parent_grade_screen_tour',
      );

      LocalCacheService.save(tourCacheKey, status);

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

    final languageProvider = context.read<LanguageProvider>();

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
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_parent_grade_screen_wali', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_parent_grade_screen_wali', {'should_show': false});
        }
        return true;
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    List<TargetFocus> targets = [];
    final languageProvider = context.read<LanguageProvider>();

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

  Widget _buildStudentSelector() {
    if (_studentList.isEmpty) {
      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ColorUtils.warning600.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ColorUtils.warning600.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: ColorUtils.warning600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: ColorUtils.warning600,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                AppLocalizations.noChildrenLinked.tr,
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: _studentSelectorKey,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              AppLocalizations.selectChild.tr,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: ColorUtils.slate700,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButton<String>(
              value: _selectedStudentId,
              isExpanded: true,
              underline: SizedBox(),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: ColorUtils.slate500,
              ),
              items: _studentList.map((student) {
                return DropdownMenuItem<String>(
                  value: student['id'],
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          student['name'] ??
                              AppLocalizations.nameNotAvailable.tr,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: ColorUtils.slate900,
                          ),
                        ),
                        Text(
                          '${AppLocalizations.classString.tr}: ${student['kelas_nama'] ?? student['class']?['name'] ?? '-'} • NIS: ${student['student_number'] ?? '-'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStudentId = value;
                  _gradeList = [];
                });
                _loadGrades();
              },
            ),
          ),
        ],
      ),
    );
  }

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
              padding: EdgeInsets.all(20),
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
                padding: EdgeInsets.all(20),
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
                  onPressed: () => Navigator.pop(context),
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
          SizedBox(width: 12),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 36,
              color: ColorUtils.slate400,
            ),
          ),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: ColorUtils.slate500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SkeletonListLoading(
      itemCount: 6,
      infoTagCount: 2,
      baseColor: _getPrimaryColor().withValues(alpha: 0.15),
      highlightColor: _getPrimaryColor().withValues(alpha: 0.05),
    );
  }

  // Pattern #8 info tag chip
  Widget _buildInfoTag(IconData icon, String text, {Color? tagColor}) {
    final c = tagColor ?? ColorUtils.slate600;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor != null
            ? tagColor.withValues(alpha: 0.08)
            : ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tagColor != null
              ? tagColor.withValues(alpha: 0.3)
              : ColorUtils.slate200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
    if (_selectedStudentId == null) {
      return _buildEmptyState(AppLocalizations.selectChildToViewGrades.tr);
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_gradeList.isEmpty) {
      return _buildEmptyState(AppLocalizations.noGradesData.tr);
    }

    return ListView.builder(
      key: _gradeListKey,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _gradeList.length,
      itemBuilder: (context, index) {
        final grade = _gradeList[index];
        final type = grade['type']?.toString().toLowerCase() ?? 'tugas';
        final typeColor =
            _gradeTypeColorMap[type] ?? ColorUtils.corporateBlue600;
        final score = double.tryParse(grade['score']?.toString() ?? '0') ?? 0;
        final assessmentTitle = grade['title']?.toString();
        final isRead =
            grade['is_read'] == true ||
            grade['is_read'] == 1 ||
            grade['is_read'] == '1';

        return Builder(
          builder: (context) {
            _onItemVisible(grade);
            return Container(
              margin: EdgeInsets.symmetric(vertical: 5),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showGradeDetail(grade),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ColorUtils.slate200),
                      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Score container
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                score.toStringAsFixed(0) == score.toString()
                                    ? score.toStringAsFixed(0)
                                    : score.toString(),
                                style: TextStyle(
                                  color: typeColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 12),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      grade['subject_name'] ??
                                          grade['mata_pelajaran'] ??
                                          AppLocalizations.subject.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: ColorUtils.slate900,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Unread dot
                                  if (!isRead) ...[
                                    SizedBox(width: 8),
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: ColorUtils.error600,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (assessmentTitle != null &&
                                  assessmentTitle.isNotEmpty) ...[
                                SizedBox(height: 3),
                                Text(
                                  assessmentTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ColorUtils.slate600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              SizedBox(height: 8),
                              // Info tags
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildInfoTag(
                                    Icons.category_outlined,
                                    _getGradeTypeLabel(type),
                                    tagColor: typeColor,
                                  ),
                                  _buildInfoTag(
                                    Icons.calendar_today_outlined,
                                    _formatDate(grade['date']),
                                  ),
                                  if (grade['teacher_name'] != null)
                                    _buildInfoTag(
                                      Icons.person_outlined,
                                      grade['teacher_name'],
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
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
                onTap: () => Navigator.pop(context),
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
                      AppLocalizations.childAcademicGrades.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      AppLocalizations.monitorChildGrades.tr,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'refresh') _forceRefresh();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
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
              ),
            ],
          ),
        ],
      ),
    );
  }

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
