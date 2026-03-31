// Admin class activity monitoring screen.
//
// Like `pages/admin/class-activities.vue` - allows admins to view class activities
// (assignments, homework, exams) created by teachers. Uses a drill-down navigation:
// Teacher list -> Subject list -> Activity list.
//
// In Laravel terms, this consumes ClassActivityController with teacher/subject filtering.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/services/tour_service.dart';
import 'package:manajemensekolah/features/class_activity/exports/class_activity_export_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_teacher_card.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_subject_card.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_activity_card.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/admin_activity_detail_item.dart';

/// Admin screen to monitor class activities (assignments, exams) per teacher/subject.
///
/// This is a [StatefulWidget] with drill-down navigation:
/// 1. Shows teacher list -> 2. Shows subjects for that teacher -> 3. Shows activities.
/// Like a Vue page with nested views controlled by local state flags.
class AdminClassActivityScreen extends ConsumerStatefulWidget {
  const AdminClassActivityScreen({super.key});

  @override
  AdminClassActivityScreenState createState() =>
      AdminClassActivityScreenState();
}

/// Mutable state for [AdminClassActivityScreen].
///
/// Key state (like Vue `data()`):
/// - [_showTeacherList] / [_showSubjectList] - flags controlling which drill-down view is shown
/// - [_teacherList] / [_subjectList] / [_activityList] - data lists from API
/// - [_selectedTeacherId] / [_selectedSubjectId] - current drill-down selections
///
/// Uses cache-first pattern with [LocalCacheService] for instant display.
/// setState() triggers re-render, like Vue's reactivity system.
class AdminClassActivityScreenState
    extends ConsumerState<AdminClassActivityScreen> {
  List<dynamic> _teacherList = [];
  List<dynamic> _subjectList = [];
  List<dynamic> _activityList = [];
  bool _isLoading = true;
  String? _selectedTeacherId;
  String? _selectedTeacherName;
  String? _selectedSubjectId;
  String? _selectedSubjectName;
  bool _showTeacherList = true;
  bool _showSubjectList = false;
  String? _errorMessage;
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _infoKey = GlobalKey();
  bool _isTourShowing = false;

  // Search
  final TextEditingController _searchController = TextEditingController();

  /// Like Vue's `mounted()` - loads the initial teacher list on screen open.
  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  /// Like Vue's `beforeUnmount()` - cleans up the search controller.
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _buildTeacherCacheKey() {
    if (_searchController.text.trim().isNotEmpty) return null;
    return 'class_activity_teachers';
  }

  String? _buildSubjectCacheKey() {
    if (_selectedTeacherId == null) return null;
    if (_searchController.text.trim().isNotEmpty) return null;
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'class_activity_subjects_${_selectedTeacherId}_$yearId';
  }

  String? _buildActivityCacheKey() {
    if (_selectedTeacherId == null || _selectedSubjectId == null) return null;
    if (_searchController.text.trim().isNotEmpty) return null;
    final yearId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    return 'class_activity_list_${_selectedTeacherId}_${_selectedSubjectId}_$yearId';
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('tour_class_activity_');
    if (_showTeacherList) {
      final cacheKey = _buildTeacherCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      _loadTeachers(useCache: false);
    } else if (_showSubjectList) {
      final cacheKey = _buildSubjectCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      _loadSubjectsByTeacher(
        _selectedTeacherId!,
        _selectedTeacherName!,
        useCache: false,
      );
    } else {
      final cacheKey = _buildActivityCacheKey();
      if (cacheKey != null) await LocalCacheService.invalidate(cacheKey);
      _loadActivitiesBySubject(
        _selectedSubjectId!,
        _selectedSubjectName!,
        useCache: false,
      );
    }
  }

  /// Loads the teacher list (first drill-down level).
  /// Uses cache-first pattern: shows cached data instantly, then fetches fresh from API.
  /// Like a Vue method calling `GET /api/teachers` with localStorage caching.
  Future<void> _loadTeachers({bool useCache = true}) async {
    try {
      _errorMessage = null;

      // Step 1: Try cache for instant display
      if (useCache) {
        final cacheKey = _buildTeacherCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                _teacherList = cachedList;
                _isLoading = false;
              });
              AppLogger.info(
                'class_activity',
                'Class activity teachers loaded from cache',
              );
              // Cache hit → return early
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _checkAndShowTour();
              });
              return;
            }
          }
        }
      }

      // Show skeleton only if list is empty
      if (_teacherList.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Step 2: Fetch fresh from API
      final apiTeacherService = getIt<ApiTeacherService>();
      final teachers = await apiTeacherService.getTeacher();

      if (!mounted) return;

      setState(() {
        _teacherList = teachers;
        _isLoading = false;
      });

      // Step 3: Save to cache (non-blocking)
      final cacheKey = _buildTeacherCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {'data': teachers});
      }

      // Trigger tour after teachers are loaded
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndShowTour();
        }
      });
    } catch (e) {
      if (mounted) {
        if (_teacherList.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = ErrorUtils.getFriendlyMessage(e);
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
        _showErrorSnackBar(
          '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  // Method to export data
  Future<void> exportActivities() async {
    if (_activityList.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        AppLocalizations.noDataToExport.tr,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ExcelClassActivityService.exportClassActivitiesToExcel(
        activities: _activityList,
        context: context,
      );
    } catch (e) {
      AppLogger.error('class_activity', e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubjectsByTeacher(
    String teacherId,
    String teacherName, {
    bool useCache = true,
  }) async {
    try {
      _errorMessage = null;
      _selectedTeacherId = teacherId;
      _selectedTeacherName = teacherName;
      _showTeacherList = false;
      _showSubjectList = true;

      // Step 1: Try cache for instant display
      if (useCache) {
        final cacheKey = _buildSubjectCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                _subjectList = cachedList;
                _isLoading = false;
              });
              AppLogger.info(
                'class_activity',
                'Class activity subjects loaded from cache',
              );
              return;
            }
          }
        }
      }

      // Show skeleton only if list is empty
      if (_subjectList.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Step 2: Fetch fresh from API
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiTeacherService>()
          .getSubjectsByTeacherPaginated(
            teacherId: teacherId,
            academicYearId: academicYearId,
          );

      if (!mounted) return;

      setState(() {
        _subjectList = response['data'] ?? [];
        _isLoading = false;
      });

      // Step 3: Save to cache (non-blocking)
      final cacheKey = _buildSubjectCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {'data': response['data'] ?? []});
      }
    } catch (e) {
      if (mounted) {
        if (_subjectList.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = ErrorUtils.getFriendlyMessage(e);
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
        _showErrorSnackBar(
          '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  Future<void> _loadActivitiesBySubject(
    String subjectId,
    String subjectName, {
    bool useCache = true,
  }) async {
    try {
      _errorMessage = null;
      _selectedSubjectId = subjectId;
      _selectedSubjectName = subjectName;
      _showSubjectList = false;

      // Step 1: Try cache for instant display
      if (useCache) {
        final cacheKey = _buildActivityCacheKey();
        if (cacheKey != null) {
          final cached = await LocalCacheService.load(cacheKey);
          if (cached != null && cached['data'] != null && mounted) {
            final cachedList = cached['data'] as List<dynamic>;
            if (cachedList.isNotEmpty) {
              setState(() {
                _activityList = cachedList;
                _isLoading = false;
              });
              AppLogger.info(
                'class_activity',
                'Class activities loaded from cache',
              );
              return;
            }
          }
        }
      }

      // Show skeleton only if list is empty
      if (_activityList.isEmpty && mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      // Step 2: Fetch fresh from API
      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiClassActivityService>()
          .getClassActivityPaginated(
            teacherId: _selectedTeacherId,
            subjectId: subjectId,
            academicYearId: academicYearId,
          );

      if (!mounted) return;

      setState(() {
        _activityList = response['data'] ?? [];
        _isLoading = false;
      });

      // Step 3: Save to cache (non-blocking)
      final cacheKey = _buildActivityCacheKey();
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {'data': response['data'] ?? []});
      }
    } catch (e) {
      if (mounted) {
        if (_activityList.isEmpty) {
          setState(() {
            _isLoading = false;
            _errorMessage = ErrorUtils.getFriendlyMessage(e);
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
        _showErrorSnackBar(
          '${AppLocalizations.failedToLoad.tr}: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  void _showErrorSnackBar(String message) {
    SnackBarUtils.showError(context, message);
  }

  void _backToTeacherList() {
    setState(() {
      _showTeacherList = true;
      _showSubjectList = false;
      _selectedTeacherId = null;
      _selectedTeacherName = null;
      _selectedSubjectId = null;
      _selectedSubjectName = null;
      _searchController.clear();
    });
  }

  void _backToSubjectList() {
    setState(() {
      _showTeacherList = false;
      _showSubjectList = true;
      _selectedSubjectId = null;
      _selectedSubjectName = null;
      _searchController.clear();
    });
  }

  List<dynamic> _getFilteredTeachers() {
    final searchTerm = _searchController.text.toLowerCase();
    return _teacherList.where((teacher) {
      final teacherName = teacher['name']?.toString().toLowerCase() ?? '';
      final teacherEmail = teacher['email']?.toString().toLowerCase() ?? '';
      final teacherSubject =
          teacher['subject_name']?.toString().toLowerCase() ?? '';

      return searchTerm.isEmpty ||
          teacherName.contains(searchTerm) ||
          teacherEmail.contains(searchTerm) ||
          teacherSubject.contains(searchTerm);
    }).toList();
  }

  List<dynamic> _getFilteredSubjects() {
    final searchTerm = _searchController.text.toLowerCase();
    return _subjectList.where((subject) {
      final name = subject['name']?.toString().toLowerCase() ?? '';
      return searchTerm.isEmpty || name.contains(searchTerm);
    }).toList();
  }

  List<dynamic> _getFilteredActivities() {
    final searchTerm = _searchController.text.toLowerCase();
    return _activityList.where((activity) {
      final title = activity['title']?.toString().toLowerCase() ?? '';
      final subject = activity['subject_name']?.toString().toLowerCase() ?? '';
      final className = activity['class_name']?.toString().toLowerCase() ?? '';
      final description =
          activity['description']?.toString().toLowerCase() ?? '';

      return searchTerm.isEmpty ||
          title.contains(searchTerm) ||
          subject.contains(searchTerm) ||
          className.contains(searchTerm) ||
          description.contains(searchTerm);
    }).toList();
  }

  // ─── Pattern #8: Teacher Card ──────────────────────────────────────────────
  Widget _buildTeacherCard(Map<String, dynamic> teacher, int index) {
    return AdminTeacherCard(
      teacher: teacher,
      index: index,
      onTap: () =>
          _loadSubjectsByTeacher(teacher['id'].toString(), teacher['name']?.toString() ?? ''),
    );
  }

  // ─── Pattern #8: Subject Card ──────────────────────────────────────────────
  Widget _buildSubjectCard(Map<String, dynamic> subject, int index) {
    return AdminSubjectCard(
      subject: subject,
      index: index,
      onTap: () => _loadActivitiesBySubject(
        subject['id'].toString(),
        subject['name']?.toString() ?? '',
      ),
    );
  }

  // ─── Pattern #8: Activity Card ─────────────────────────────────────────────
  Widget _buildActivityCard(Map<String, dynamic> activity, int index) {
    return AdminActivityCard(
      activity: activity,
      onTap: () => _showActivityDetail(activity),
    );
  }

  // ─── Pattern #10: Activity Detail Dialog ──────────────────────────────────
  void _showActivityDetail(Map<String, dynamic> activity) {
    final languageProvider = ref.read(languageRiverpod);
    final isAssignment = activity['jenis'] == 'tugas';
    final isSpecificTarget = activity['target'] == 'khusus';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: const BorderRadius.all(Radius.circular(20))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gradient header (Pattern #10)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  gradient: _getCardGradient(),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Icon(
                        isAssignment ? Icons.assignment : Icons.menu_book,
                        size: 22,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity['judul'] ?? 'Judul Kegiatan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${activity['mata_pelajaran_nama'] ?? ''} • ${activity['kelas_nama'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdminActivityDetailItem(
                      icon: Icons.person,
                      label: 'Guru Pengajar',
                      value: activity['guru_nama'] ?? 'Tidak Diketahui',
                      primaryColor: _getPrimaryColor(),
                    ),
                    AdminActivityDetailItem(
                      icon: Icons.calendar_today,
                      label: 'Hari',
                      value: activity['hari'] ?? '-',
                      primaryColor: _getPrimaryColor(),
                    ),
                    AdminActivityDetailItem(
                      icon: Icons.date_range,
                      label: 'Tanggal',
                      value: _formatDate(activity['tanggal']),
                      primaryColor: _getPrimaryColor(),
                    ),
                    if (isAssignment)
                      AdminActivityDetailItem(
                        icon: Icons.access_time,
                        label: 'Batas Waktu',
                        value: _formatDate(activity['batas_waktu']),
                        primaryColor: _getPrimaryColor(),
                      ),
                    AdminActivityDetailItem(
                      icon: Icons.category,
                      label: 'Jenis Kegiatan',
                      value: isAssignment ? 'Tugas' : 'Materi',
                      primaryColor: _getPrimaryColor(),
                    ),
                    AdminActivityDetailItem(
                      icon: Icons.group,
                      label: 'Target Siswa',
                      value: isSpecificTarget ? 'Khusus Siswa' : 'Semua Siswa',
                      primaryColor: _getPrimaryColor(),
                    ),

                    if (activity['deskripsi'] != null &&
                        activity['deskripsi'].isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Deskripsi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: ColorUtils.slate50,
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                          border: Border.all(color: ColorUtils.slate200),
                        ),
                        child: Text(
                          activity['deskripsi'],
                          style: TextStyle(
                            fontSize: 14,
                            color: ColorUtils.slate700,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],

                    if (activity['judul_bab'] != null ||
                        activity['judul_sub_bab'] != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Informasi Bab',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (activity['judul_bab'] != null)
                        AdminActivityDetailItem(
                          icon: Icons.menu_book,
                          label: 'Bab',
                          value: activity['judul_bab']!,
                          primaryColor: _getPrimaryColor(),
                        ),
                      if (activity['judul_sub_bab'] != null)
                        AdminActivityDetailItem(
                          icon: Icons.bookmark,
                          label: 'Sub Bab (Utama)',
                          value: activity['judul_sub_bab']!,
                          primaryColor: _getPrimaryColor(),
                        ),
                      if (activity['additional_material'] != null &&
                          activity['additional_material'] is List &&
                          (activity['additional_material'] as List)
                              .isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        ...(activity['additional_material'] as List)
                            .map<Widget>((item) {
                              return AdminActivityDetailItem(
                                icon: Icons.bookmark_add,
                                label: 'Sub Bab (Tambahan)',
                                value: item['sub_chapter_title'] ?? 'Unknown',
                                primaryColor: _getPrimaryColor(),
                              );
                            }),
                      ],
                    ],

                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => AppNavigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: const BorderRadius.all(Radius.circular(12)),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                            ),
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Close',
                                'id': 'Tutup',
                              }),
                              style: TextStyle(
                                color: ColorUtils.slate700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
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
    );
  }

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  String _formatDate(String? date) {
    if (date == null) return '-';
    return AppDateUtils.formatDateString(date, format: 'dd/MM/yyyy');
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    if (_errorMessage != null) {
      return ErrorScreen(
        errorMessage: _errorMessage!,
        onRetry: _showTeacherList
            ? _loadTeachers
            : (_showSubjectList
                  ? () => _loadSubjectsByTeacher(
                      _selectedTeacherId!,
                      _selectedTeacherName!,
                    )
                  : () => _loadActivitiesBySubject(
                      _selectedSubjectId!,
                      _selectedSubjectName!,
                    )),
      );
    }

    final filteredItems = _showTeacherList
        ? _getFilteredTeachers()
        : (_showSubjectList
              ? _getFilteredSubjects()
              : _getFilteredActivities());

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // ─── Pattern #7 Gradient Header ──────────────────────────────
          Container(
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
                    // Back button (40x40 semi-transparent)
                    GestureDetector(
                      onTap: _showTeacherList
                          ? () => AppNavigator.pop(context)
                          : (_showSubjectList
                                ? _backToTeacherList
                                : _backToSubjectList),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Title + subtitle
                    Expanded(
                      child: Column(
                        key: _infoKey,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _showTeacherList
                                ? languageProvider.getTranslatedText({
                                    'en': 'Class Activities',
                                    'id': 'Kegiatan Kelas',
                                  })
                                : (_showSubjectList
                                      ? languageProvider.getTranslatedText({
                                          'en':
                                              'Subjects - $_selectedTeacherName',
                                          'id':
                                              'Mata Pelajaran - $_selectedTeacherName',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en':
                                              'Activities - $_selectedSubjectName',
                                          'id':
                                              'Kegiatan - $_selectedSubjectName',
                                        })),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _showTeacherList
                                ? languageProvider.getTranslatedText({
                                    'en': 'View all teacher activities',
                                    'id': 'Lihat semua kegiatan guru',
                                  })
                                : (_showSubjectList
                                      ? languageProvider.getTranslatedText({
                                          'en':
                                              'Select subject to view activities',
                                          'id':
                                              'Pilih mata pelajaran untuk melihat kegiatan',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en':
                                              'Viewing activities for $_selectedSubjectName',
                                          'id':
                                              'Melihat kegiatan untuk $_selectedSubjectName',
                                        })),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menu button
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'refresh') {
                          _forceRefresh();
                        }
                      },
                      icon: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: const BorderRadius.all(Radius.circular(10)),
                        ),
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      itemBuilder: (context) => [
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
                              Text(AppLocalizations.updateData.tr),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),

                // Search Bar
                Container(
                  key: _searchKey,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(color: ColorUtils.slate800),
                          decoration: InputDecoration(
                            hintText: _showTeacherList
                                ? languageProvider.getTranslatedText({
                                    'en': 'Search teachers...',
                                    'id': 'Cari guru...',
                                  })
                                : (_showSubjectList
                                      ? languageProvider.getTranslatedText({
                                          'en': 'Search subjects...',
                                          'id': 'Cari mata pelajaran...',
                                        })
                                      : languageProvider.getTranslatedText({
                                          'en': 'Search activities...',
                                          'id': 'Cari kegiatan...',
                                        })),
                            hintStyle: TextStyle(color: ColorUtils.slate400),
                            prefixIcon: Icon(
                              Icons.search,
                              color: ColorUtils.slate400,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => setState(() {}),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.search, color: _getPrimaryColor()),
                          onPressed: () => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ─── Content ─────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? SkeletonListLoading(
                    itemCount: 8,
                    infoTagCount: _showTeacherList ? 1 : 2,
                    showActions: false,
                  )
                : filteredItems.isEmpty
                ? EmptyState(
                    title: _showTeacherList
                        ? languageProvider.getTranslatedText({
                            'en': 'No teachers',
                            'id': 'Tidak ada guru',
                          })
                        : (_showSubjectList
                              ? languageProvider.getTranslatedText({
                                  'en': 'No subjects',
                                  'id': 'Tidak ada mata pelajaran',
                                })
                              : languageProvider.getTranslatedText({
                                  'en': 'No activities',
                                  'id': 'Tidak ada kegiatan',
                                })),
                    subtitle: _searchController.text.isEmpty
                        ? _showTeacherList
                              ? languageProvider.getTranslatedText({
                                  'en': 'No teacher data available',
                                  'id': 'Data guru tidak tersedia',
                                })
                              : (_showSubjectList
                                    ? languageProvider.getTranslatedText({
                                        'en':
                                            'Teacher $_selectedTeacherName has no subjects',
                                        'id':
                                            'Guru $_selectedTeacherName tidak memiliki mata pelajaran',
                                      })
                                    : languageProvider.getTranslatedText({
                                        'en':
                                            'Subject $_selectedSubjectName has no class activities',
                                        'id':
                                            'Mata pelajaran $_selectedSubjectName belum memiliki kegiatan kelas',
                                      }))
                        : languageProvider.getTranslatedText({
                            'en': 'No search results found',
                            'id': 'Tidak ditemukan hasil pencarian',
                          }),
                    icon: _showTeacherList
                        ? Icons.people_outline
                        : (_showSubjectList
                              ? Icons.menu_book
                              : Icons.event_note),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _showTeacherList
                          ? _buildTeacherCard(item, index)
                          : (_showSubjectList
                                ? _buildSubjectCard(item, index)
                                : _buildActivityCard(item, index));
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndShowTour() async {
    if (_isTourShowing) return;
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'class_activity',
        'admin',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map) {
        if (cached['should_show'] == true) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_isTourShowing) _showTour();
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('class_activity', e);
    }
  }

  void _showTour() {
    final List<TargetFocus> targets = _createTourTargets();
    if (targets.isEmpty) return;

    final languageProvider = ref.read(languageRiverpod);

    setState(() {
      _isTourShowing = true;
    });

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
        setState(() {
          _isTourShowing = false;
        });
        getIt<ApiTourService>().completeTour(
          name: 'admin_class_activity_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('class_activity', 'admin'),
          {'should_show': false},
        );
      },
      onSkip: () {
        setState(() {
          _isTourShowing = false;
        });
        getIt<ApiTourService>().completeTour(
          name: 'admin_class_activity_tour',
          role: 'admin',
          platform: 'mobile',
        );
        LocalCacheService.save(
          CacheKeyBuilder.tourStatus('class_activity', 'admin'),
          {'should_show': false},
        );
        return true;
      },
      onClickOverlay: (target) {
        // Optional handle
      },
    ).show(context: context);
  }

  List<TargetFocus> _createTourTargets() {
    final List<TargetFocus> targets = [];
    final languageProvider = ref.read(languageRiverpod);

    targets.add(
      TargetFocus(
        identify: "ClassActivityInfo",
        keyTarget: _infoKey,
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
                      'en': 'Class Activities',
                      'id': 'Kegiatan Kelas',
                    }),
                    style: TextStyle(
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
                            'Monitor and view teaching activities conducted by all teachers.',
                        'id':
                            'Pantau dan lihat kegiatan mengajar yang dilakukan oleh semua guru.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
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
        identify: "ClassActivitySearch",
        keyTarget: _searchKey,
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
                      'en': 'Search Activities',
                      'id': 'Cari Kegiatan',
                    }),
                    style: TextStyle(
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
                            'Quickly find teachers, subjects, or specific activities.',
                        'id':
                            'Cari guru, mata pelajaran, atau kegiatan tertentu dengan cepat.',
                      }),
                      style: TextStyle(color: Colors.white, fontSize: 14.0),
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
}
