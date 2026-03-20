// Parent view of class activities (teaching journal entries).
// Like `pages/parent/ClassActivity.vue` in a Vue app.
//
// Read-only view of class activities for the parent's children.
// Supports student selector (for parents with multiple kids),
// auto-marking activities as read when scrolled into view, and caching.
// In Laravel terms: `ClassActivityController@parentIndex`.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/components/skeleton_loading.dart';
import 'package:manajemensekolah/services/api_class_activity_services.dart';
import 'package:manajemensekolah/services/local_cache_service.dart';
import 'package:manajemensekolah/services/api_student_services.dart';
import 'package:manajemensekolah/services/api_tour_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/date_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:manajemensekolah/utils/language_utils.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Parent's read-only view of class activities with read tracking.
///
/// Uses the same debounced visibility-based "mark as read" pattern as
/// [AnnouncementScreen]. Props: optional [academicYearId].
class ParentClassActivityScreen extends StatefulWidget {
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
class ParentClassActivityScreenState extends State<ParentClassActivityScreen> {
  List<dynamic> _activityList = [];
  List<dynamic> _studentList = [];
  String? _selectedStudentId;
  String _parentName = '';
  bool _isLoading = true;
  bool _hasFreshData = false; // Only show unread dots after fresh API data arrives

  String? _tourId;
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
      await ApiClassActivityService.markAsRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error silent auto-marking read: $e");
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
      if (kDebugMode) {
        print(
          '📨 Auto-marking ${ids.length} visible class activities as read...',
        );
      }

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

      await ApiClassActivityService.markAsRead(ids);
    } catch (e) {
      if (kDebugMode) print("Error auto-marking read: $e");
    }
  }

  String get _studentsCacheKey => 'parent_activity_students_${widget.academicYearId ?? 'default'}';

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
      final prefs = await SharedPreferences.getInstance();
      final userData = json.decode(prefs.getString('user') ?? '{}');

      setState(() {
        _parentName =
            userData['name']?.toString() ?? 'Wali Murid';
      });

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
        if (kDebugMode) print('📦 ParentStudents: from cache (${cached.length})');
        return;
      }
    }

    if (mounted) {
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
      if (kDebugMode) {
        print('Error load students for parent: $e');
      }
      if (!mounted) return;
      if (_studentList.isEmpty) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.getFriendlyMessage(e))),
        );
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
        if (kDebugMode) print('📦 ParentActivities: from cache (${cached.length})');
        Future.delayed(const Duration(milliseconds: 1000), () {
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
        final activities = await ApiClassActivityService.getKegiatanByKelas(
          classId,
          siswaId: _selectedStudentId,
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
      if (kDebugMode) {
        print('Error load activities: $e');
      }
      if (!mounted) return;
      if (_activityList.isEmpty) {
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
    const tourCacheKey = 'tour_parent_class_activity_screen_wali';
    try {
      // Check cache first
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
        name: 'parent_class_activity_screen_tour',
      );

      await LocalCacheService.save(tourCacheKey, status);

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
          LocalCacheService.save('tour_parent_class_activity_screen_wali', {'should_show': false});
        }
      },
      onSkip: () {
        if (_tourId != null) {
          ApiTourService.completeTour(tourId: _tourId!, platform: 'mobile');
          LocalCacheService.save('tour_parent_class_activity_screen_wali', {'should_show': false});
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
                  _activityList = [];
                  _hasFreshData = false;
                });
                _loadActivities();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showActivityDetail(Map<String, dynamic> activity) {
    final languageProvider = context.read<LanguageProvider>();
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
                  SizedBox(width: 12),
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
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      Icons.person_rounded,
                      languageProvider.getTranslatedText({
                        'en': 'Teacher',
                        'id': 'Guru Pengajar',
                      }),
                      activity['teacher_name'] ??
                          activity['guru_nama'] ??
                          AppLocalizations.unknown.tr,
                    ),
                    _buildDetailRow(
                      Icons.menu_book_rounded,
                      languageProvider.getTranslatedText({
                        'en': 'Subject',
                        'id': 'Mata Pelajaran',
                      }),
                      activity['subject_name'] ??
                          activity['mata_pelajaran_nama'] ??
                          '-',
                    ),
                    _buildDetailRow(
                      Icons.calendar_today_rounded,
                      languageProvider.getTranslatedText({
                        'en': 'Date',
                        'id': 'Tanggal',
                      }),
                      '${activity['day'] ?? activity['hari'] ?? '-'} • ${_formatDate(activity['date'] ?? activity['tanggal'])}',
                    ),
                    if (isAssignment &&
                        (activity['deadline'] ?? activity['batas_waktu']) !=
                            null)
                      _buildDetailRow(
                        Icons.access_time_rounded,
                        AppLocalizations.deadline.tr,
                        _formatDate(
                          activity['deadline'] ?? activity['batas_waktu'],
                        ),
                        iconColor: ColorUtils.error600,
                      ),
                    if (activity['deskripsi'] != null &&
                        activity['deskripsi'].toString().isNotEmpty &&
                        activity['deskripsi'] != 'null')
                      _buildDetailRow(
                        Icons.description_rounded,
                        AppLocalizations.description.tr,
                        activity['deskripsi'].toString(),
                      ),
                    if (activity['judul_bab'] != null)
                      _buildDetailRow(
                        Icons.auto_stories_rounded,
                        languageProvider.getTranslatedText({
                          'en': 'Chapter',
                          'id': 'Materi',
                        }),
                        '${activity['judul_bab']}${activity['judul_sub_bab'] != null ? '\n• ${activity['judul_sub_bab']}' : ''}',
                      ),
                    if (activity['additional_material'] != null &&
                        activity['additional_material'] is List &&
                        (activity['additional_material'] as List).isNotEmpty)
                      ...(activity['additional_material'] as List).map<Widget>((
                        item,
                      ) {
                        return _buildDetailRow(
                          Icons.bookmark_add_rounded,
                          AppLocalizations.additionalSubChapter.tr,
                          item['sub_chapter_title'] ??
                              AppLocalizations.unknown.tr,
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

  Widget _buildActivityList() {
    final languageProvider = context.read<LanguageProvider>();

    if (_selectedStudentId == null) {
      return _buildEmptyState(AppLocalizations.selectChildToViewActivity.tr);
    }

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_activityList.isEmpty) {
      return _buildEmptyState(AppLocalizations.noActivityForChild.tr);
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
        final isRead = !_hasFreshData ||
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
                                    SizedBox(width: 4),
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

                              SizedBox(height: 8),

                              // Info tags
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildInfoTag(
                                    isAssignment
                                        ? Icons.assignment_outlined
                                        : Icons.menu_book_outlined,
                                    isAssignment
                                        ? AppLocalizations.assignment.tr
                                        : AppLocalizations.material.tr,
                                    tagColor: accentColor,
                                  ),
                                  _buildInfoTag(
                                    Icons.calendar_today_outlined,
                                    '${activity['hari'] ?? '-'} • ${_formatDate(activity['tanggal'])}',
                                  ),
                                  _buildInfoTag(
                                    isSpecificTarget
                                        ? Icons.person_outlined
                                        : Icons.group_outlined,
                                    isSpecificTarget
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
                                    _buildInfoTag(
                                      Icons.access_time_rounded,
                                      '${languageProvider.getTranslatedText({'en': 'Due', 'id': 'Batas'})}: ${_formatDate(activity['batas_waktu'])}',
                                      tagColor: ColorUtils.error600,
                                    ),
                                  if (isSpecificTarget && isForThisStudent)
                                    _buildInfoTag(
                                      Icons.star_outline_rounded,
                                      languageProvider.getTranslatedText({
                                        'en': 'For this child',
                                        'id': 'Untuk anak ini',
                                      }),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
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
                Icons.event_note_outlined,
                size: 36,
                color: ColorUtils.slate400,
              ),
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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

  Widget _buildHeader() {
    final languageProvider = context.read<LanguageProvider>();
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
                      AppLocalizations.childClassActivity.tr,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      AppLocalizations.monitorChildActivity.tr,
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
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.family_restroom,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _parentName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${_studentList.length} ${languageProvider.getTranslatedText({'en': 'Children', 'id': 'Anak'})}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

          // Student Selector
          _buildStudentSelector(),

          // Activities List
          Expanded(child: _buildActivityList()),
        ],
      ),
    );
  }
}
