// Parent view of class activities (teaching journal entries).
// Like `pages/parent/ClassActivity.vue` in a Vue app.
//
// Read-only view of class activities for the parent's children.
// Supports student selector (for parents with multiple kids),
// auto-marking activities as read when scrolled into view, and caching.
// In Laravel terms: `ClassActivityController@parentIndex`.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer, ChangeNotifierProvider;
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_row.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_empty_state.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_info_tag.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/parent_class_activity_header.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/parent_student_selector.dart';

/// Parent's read-only view of class activities with read tracking.
///
/// Uses the same debounced visibility-based "mark as read" pattern as
/// [AnnouncementScreen]. Props: optional [academicYearId].
class ParentClassActivityScreen extends ConsumerStatefulWidget {
  final String? academicYearId;

  const ParentClassActivityScreen({super.key, this.academicYearId});

  @override
  ParentClassActivityScreenState createState() =>
      ParentClassActivityScreenState();
}

/// State for [ParentClassActivityScreen].
///
/// Like a Vue page component with `data() { return {...} }`.
/// Key state: activity list, student selector, visibility tracking for
/// auto-marking read items. Uses the same pattern as announcements.
class ParentClassActivityScreenState
    extends ConsumerState<ParentClassActivityScreen> {
  List<dynamic> _activityList = [];
  List<dynamic> _studentList = [];
  String? _selectedStudentId;
  String _parentName = '';
  bool _isLoading = true;
  bool _hasFreshData =
      false; // Only show unread dots after fresh API data arrives

  final GlobalKey _studentSelectorKey = GlobalKey();
  final GlobalKey _activityListKey = GlobalKey();

  // Visibility Tracking
  final Set<String> _processedIds = {}; // IDs we've already handled/queued
  final Set<String> _pendingReadIds = {}; // IDs waitng to be sent to API
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
      await getIt<ApiClassActivityService>().markAsRead(ids);
    } catch (e) {
      AppLogger.error('class_activity', "Error silent auto-marking read: $e");
    }
  }

  void _onItemVisible(Map<String, dynamic> activity) {
    if (!_hasFreshData) return; // Skip auto-marking from stale cache data

    final id = activity['id'].toString();
    final isRead =
        activity['is_read'] == true ||
        activity['is_read'] == 1 ||
        activity['is_read'] == '1';

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
        'class_activity',
        'Auto-marking ${ids.length} visible class activities as read...',
      );

      // Optimistic Update (update local list UI immediately)
      setState(() {
        for (var item in _activityList) {
          if (ids.contains(item['id'].toString())) {
            item['is_read'] = true;
          }
        }
      });

      // Update cache so next visit won't show stale unread dots
      final cacheKey = _buildActivitiesCacheKey();
      await LocalCacheService.save(cacheKey, _activityList);

      await getIt<ApiClassActivityService>().markAsRead(ids);
    } catch (e) {
      AppLogger.error('class_activity', "Error auto-marking read: $e");
    }
  }

  String get _studentsCacheKey =>
      'parent_activity_students_${widget.academicYearId ?? 'default'}';

  String _buildActivitiesCacheKey() {
    return 'parent_activity_list_${_selectedStudentId}_${widget.academicYearId ?? 'default'}';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('parent_activity_');
    await LocalCacheService.clearStartingWith('tour_parent_class_activity_');
    _loadUserData(useCache: false);
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData({bool useCache = true}) async {
    try {
      final prefs = PreferencesService();
      final userData = json.decode(prefs.getString('user') ?? '{}');

      setState(() {
        _parentName = userData['name']?.toString() ?? 'Wali Murid';
      });

      await _loadStudentsForParent(useCache: useCache);
    } catch (e) {
      AppLogger.error('class_activity', 'Error load user data: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadStudentsForParent({bool useCache = true}) async {
    // Try cache — return early
    if (useCache) {
      final cached = await LocalCacheService.load(_studentsCacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _studentList = cached;
          _isLoading = false;
        });
        // Auto-select if only 1 student
        if (_studentList.length == 1 && _selectedStudentId == null) {
          _selectedStudentId = _studentList[0]['id'];
          await _loadActivities(useCache: true);
        }
        AppLogger.debug(
          'class_activity',
          'ParentStudents: from cache (${cached.length})',
        );
        return;
      }
    }

    if (mounted) {
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

      await LocalCacheService.save(_studentsCacheKey, filteredStudents);

      setState(() {
        _studentList = filteredStudents;
      });

      if (_studentList.isNotEmpty) {
        if (_studentList.length == 1) {
          _selectedStudentId = _studentList[0]['id'];
          await _loadActivities(useCache: useCache);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error load students for parent: $e');
      if (!mounted) return;
      if (_studentList.isEmpty) {
        setState(() => _isLoading = false);
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadActivities({bool useCache = true}) async {
    if (_selectedStudentId == null) return;

    final cacheKey = _buildActivitiesCacheKey();

    // Try cache — return early (without unread indicators)
    if (useCache) {
      final cached = await LocalCacheService.load(cacheKey);
      if (cached != null && cached is List && cached.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _activityList = cached;
          _hasFreshData = false; // Don't show unread dots from stale cache
          _isLoading = false;
        });
        AppLogger.debug(
          'class_activity',
          'ParentActivities: from cache (${cached.length})',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _studentList.isNotEmpty) _checkAndShowTour();
        });
        return;
      }
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final selectedStudent = _studentList.firstWhere(
        (s) => s['id'] == _selectedStudentId,
        orElse: () => {},
      );

      final classId =
          selectedStudent['class_id'] ?? selectedStudent['class']?['id'];

      if (selectedStudent.isNotEmpty && classId != null) {
        final activities = await getIt<ApiClassActivityService>()
            .getActivityByClass(
              classId,
              studentId: _selectedStudentId,
              academicYearId: widget.academicYearId,
            );

        if (!mounted) return;

        await LocalCacheService.save(cacheKey, activities);

        setState(() {
          _activityList = activities;
          _hasFreshData = true; // Now safe to show unread dots
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _activityList = [];
          _hasFreshData = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error load activities: $e');
      if (!mounted) return;
      if (_activityList.isEmpty) {
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
      'parent_class_activity_screen',
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
      AppLogger.error('class_activity', 'Error checking tour status: $e');
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
          name: 'parent_class_activity_screen_tour',
          role: 'wali',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('parent_class_activity_screen', 'wali'),
          {'should_show': false},
        );
      },
      onSkip: () {
        getIt<ApiTourService>().completeTour(
          name: 'parent_class_activity_screen_tour',
          role: 'wali',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('parent_class_activity_screen', 'wali'),
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
                        'en':
                            'Select your child to view their class activities.',
                        'id':
                            'Pilih anak Anda untuk melihat aktivitas kelas mereka.',
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
        identify: "ActivityList",
        keyTarget: _activityListKey,
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
                      'en': 'Activity List',
                      'id': 'Daftar Aktivitas',
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
                            'Here you can see the latest assignments and materials for your child.',
                        'id':
                            'Di sini Anda dapat melihat tugas dan materi terbaru untuk anak Anda.',
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

  void _showActivityDetail(Map<String, dynamic> activity) {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = _getPrimaryColor();
    final isAssignment = activity['jenis'] == 'tugas';

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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isAssignment
                          ? Icons.assignment_rounded
                          : Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAssignment
                              ? languageProvider.getTranslatedText({
                                  'en': 'Assignment',
                                  'id': 'Tugas',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'Material',
                                  'id': 'Materi',
                                }),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          activity['title'] ??
                              activity['judul'] ??
                              AppLocalizations.activityTitle.tr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ActivityDetailRow(
                      icon: Icons.person_rounded,
                      label: languageProvider.getTranslatedText({
                        'en': 'Teacher',
                        'id': 'Guru Pengajar',
                      }),
                      value: activity['teacher_name'] ??
                          activity['guru_nama'] ??
                          AppLocalizations.unknown.tr,
                      primaryColor: _getPrimaryColor(),
                    ),
                    ActivityDetailRow(
                      icon: Icons.menu_book_rounded,
                      label: languageProvider.getTranslatedText({
                        'en': 'Subject',
                        'id': 'Mata Pelajaran',
                      }),
                      value: activity['subject_name'] ??
                          activity['mata_pelajaran_nama'] ??
                          '-',
                      primaryColor: _getPrimaryColor(),
                    ),
                    ActivityDetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: languageProvider.getTranslatedText({
                        'en': 'Date',
                        'id': 'Tanggal',
                      }),
                      value:
                          '${activity['day'] ?? activity['hari'] ?? '-'} • ${_formatDate(activity['date'] ?? activity['tanggal'])}',
                      primaryColor: _getPrimaryColor(),
                    ),
                    if (isAssignment &&
                        (activity['deadline'] ?? activity['batas_waktu']) !=
                            null)
                      ActivityDetailRow(
                        icon: Icons.access_time_rounded,
                        label: AppLocalizations.deadline.tr,
                        value: _formatDate(
                          activity['deadline'] ?? activity['batas_waktu'],
                        ),
                        primaryColor: _getPrimaryColor(),
                        iconColor: ColorUtils.error600,
                      ),
                    if (activity['deskripsi'] != null &&
                        activity['deskripsi'].toString().isNotEmpty &&
                        activity['deskripsi'] != 'null')
                      ActivityDetailRow(
                        icon: Icons.description_rounded,
                        label: AppLocalizations.description.tr,
                        value: activity['deskripsi'].toString(),
                        primaryColor: _getPrimaryColor(),
                      ),
                    if (activity['judul_bab'] != null)
                      ActivityDetailRow(
                        icon: Icons.auto_stories_rounded,
                        label: languageProvider.getTranslatedText({
                          'en': 'Chapter',
                          'id': 'Materi',
                        }),
                        value:
                            '${activity['judul_bab']}${activity['judul_sub_bab'] != null ? '\n• ${activity['judul_sub_bab']}' : ''}',
                        primaryColor: _getPrimaryColor(),
                      ),
                    if (activity['additional_material'] != null &&
                        activity['additional_material'] is List &&
                        (activity['additional_material'] as List).isNotEmpty)
                      ...(activity['additional_material'] as List).map<Widget>((
                        item,
                      ) {
                        return ActivityDetailRow(
                          icon: Icons.bookmark_add_rounded,
                          label: AppLocalizations.additionalSubChapter.tr,
                          value: item['sub_chapter_title'] ??
                              AppLocalizations.unknown.tr,
                          primaryColor: _getPrimaryColor(),
                        );
                      }),
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

  Widget _buildActivityList() {
    final languageProvider = ref.read(languageRiverpod);

    if (_selectedStudentId == null) {
      return ActivityEmptyState(
        message: AppLocalizations.selectChildToViewActivity.tr,
      );
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_activityList.isEmpty) {
      return ActivityEmptyState(
        message: AppLocalizations.noActivityForChild.tr,
      );
    }

    return ListView.builder(
      key: _activityListKey,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _activityList.length,
      itemBuilder: (context, index) {
        final activity = _activityList[index];
        final isAssignment = activity['jenis'] == 'tugas';
        final isSpecificTarget = activity['target'] == 'khusus';
        final isForThisStudent = activity['untuk_siswa_ini'] == true;
        // Only show unread dots when we have fresh API data, not stale cache
        final isRead =
            !_hasFreshData ||
            activity['is_read'] == true ||
            activity['is_read'] == 1 ||
            activity['is_read'] == '1';

        final accentColor = isAssignment
            ? ColorUtils.warning600
            : ColorUtils.success600;

        return Builder(
          builder: (context) {
            _onItemVisible(activity);
            return Container(
              margin: EdgeInsets.symmetric(vertical: 5),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showActivityDetail(activity),
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
                        // Icon container
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            isAssignment
                                ? Icons.assignment_outlined
                                : Icons.menu_book_outlined,
                            color: accentColor,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: AppSpacing.md),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      activity['judul'] ??
                                          AppLocalizations.activityTitle.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        color: ColorUtils.slate900,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Unread dot
                                  if (!isRead) ...[
                                    SizedBox(width: AppSpacing.sm),
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
                              SizedBox(height: 3),
                              Text(
                                '${activity['mata_pelajaran_nama'] ?? '-'} • ${activity['kelas_nama'] ?? '-'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: ColorUtils.slate600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Description preview
                              if (activity['deskripsi'] != null &&
                                  activity['deskripsi'].toString().isNotEmpty &&
                                  activity['deskripsi'] != 'null') ...[
                                SizedBox(height: 6),
                                Text(
                                  activity['deskripsi'].toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ColorUtils.slate500,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

                              // Chapter info
                              if (activity['judul_bab'] != null) ...[
                                SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.auto_stories_rounded,
                                      size: 12,
                                      color: ColorUtils.info600,
                                    ),
                                    SizedBox(width: AppSpacing.xs),
                                    Expanded(
                                      child: Text(
                                        '${activity['judul_bab']}${activity['judul_sub_bab'] != null ? ' • ${activity['judul_sub_bab']}' : ''}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: ColorUtils.slate600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              SizedBox(height: AppSpacing.sm),

                              // Info tags
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  ActivityInfoTag(
                                    icon: isAssignment
                                        ? Icons.assignment_outlined
                                        : Icons.menu_book_outlined,
                                    label: isAssignment
                                        ? AppLocalizations.assignment.tr
                                        : AppLocalizations.material.tr,
                                    tagColor: accentColor,
                                  ),
                                  ActivityInfoTag(
                                    icon: Icons.calendar_today_outlined,
                                    label:
                                        '${activity['hari'] ?? '-'} • ${_formatDate(activity['tanggal'])}',
                                  ),
                                  ActivityInfoTag(
                                    icon: isSpecificTarget
                                        ? Icons.person_outlined
                                        : Icons.group_outlined,
                                    label: isSpecificTarget
                                        ? languageProvider.getTranslatedText({
                                            'en': 'Specific',
                                            'id': 'Khusus',
                                          })
                                        : languageProvider.getTranslatedText({
                                            'en': 'All Students',
                                            'id': 'Semua',
                                          }),
                                    tagColor: isSpecificTarget
                                        ? ColorUtils.info600
                                        : ColorUtils.success600,
                                  ),
                                  if (isAssignment &&
                                      activity['batas_waktu'] != null)
                                    ActivityInfoTag(
                                      icon: Icons.access_time_rounded,
                                      label:
                                          '${languageProvider.getTranslatedText({'en': 'Due', 'id': 'Batas'})}: ${_formatDate(activity['batas_waktu'])}',
                                      tagColor: ColorUtils.error600,
                                    ),
                                  if (isSpecificTarget && isForThisStudent)
                                    ActivityInfoTag(
                                      icon: Icons.star_outline_rounded,
                                      label: languageProvider.getTranslatedText(
                                        {
                                          'en': 'For this child',
                                          'id': 'Untuk anak ini',
                                        },
                                      ),
                                      tagColor: ColorUtils.corporateBlue600,
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

  Widget _buildLoadingState() {
    return SkeletonListLoading(
      itemCount: 6,
      infoTagCount: 3,
      baseColor: _getPrimaryColor().withValues(alpha: 0.15),
      highlightColor: _getPrimaryColor().withValues(alpha: 0.05),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ParentClassActivityHeader(
            parentName: _parentName,
            studentCount: _studentList.length,
            gradient: _getCardGradient(),
            primaryColor: _getPrimaryColor(),
            onRefresh: _forceRefresh,
          ),

          // Student Selector
          ParentStudentSelector(
            studentList: _studentList,
            selectedStudentId: _selectedStudentId,
            selectorKey: _studentSelectorKey,
            onStudentChanged: (value) {
              setState(() {
                _selectedStudentId = value;
                _activityList = [];
                _hasFreshData = false;
              });
              _loadActivities();
            },
          ),

          // Activities List
          Expanded(child: _buildActivityList()),
        ],
      ),
    );
  }
}
