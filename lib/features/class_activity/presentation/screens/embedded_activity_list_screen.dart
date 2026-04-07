// Standalone activity list screen for a single class + subject.
//
// Extracted from ClassActivityScreen (step 2) so that:
// - The schedule card bottom sheet opens this directly (no wizard overhead).
// - ClassActivityScreen reuses this for its step 2 body.
//
// Owns: activity list, pagination, search/filter, tabs, CRUD dialogs.
// Does NOT own: class selection, subject selection, teacher resolution.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_dialog.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_list_view.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_tab_switcher.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_type_bottom_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_dialog.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/class_activity_tour.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';

/// Lightweight activity list screen that only renders the activity list (step 2)
/// without class/subject wizard overhead.
///
/// Used by:
/// - `ScheduleCardItem._openClassActivity()` — opened in a bottom sheet
/// - `ClassActivityScreen` — embedded as step 2 body
class EmbeddedActivityListScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final bool canEdit;
  final DateTime? initialDate;
  final String? initialChapterId;
  final String? initialSubChapterId;
  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;
  final bool autoShowActivityDialog;

  /// When true, wraps itself in a Scaffold with an AppBar and close button.
  /// When false, returns just the body content (for embedding inside another Scaffold).
  final bool showScaffold;

  /// Called after an activity is added/edited/deleted so the parent can refresh.
  final VoidCallback? onActivityChanged;

  const EmbeddedActivityListScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    this.canEdit = true,
    this.initialDate,
    this.initialChapterId,
    this.initialSubChapterId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.autoShowActivityDialog = false,
    this.showScaffold = true,
    this.onActivityChanged,
  });

  @override
  EmbeddedActivityListScreenState createState() =>
      EmbeddedActivityListScreenState();
}

class EmbeddedActivityListScreenState
    extends ConsumerState<EmbeddedActivityListScreen>
    with TickerProviderStateMixin {
  // Activity data
  List<dynamic> _activityList = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  // Pagination
  int _currentPage = 1;
  final int _perPage = 10;
  bool _hasMoreData = true;

  // Search & filter
  final TextEditingController _searchController = TextEditingController();
  String? _selectedDateFilter;
  bool _hasActiveFilter = false;

  // Scroll
  final ScrollController _scrollController = ScrollController();

  // Tabs (umum / khusus)
  late TabController _tabController;
  String _currentTarget = 'umum';

  // Material data (for add/edit dialog)
  List<dynamic> _chapterList = [];
  List<dynamic> _subChapterList = [];

  // Tour keys
  final GlobalKey _searchFilterKey = GlobalKey();
  final GlobalKey _tabSwitcherKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _scrollController.addListener(_onScroll);
    _loadActivities();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Tab / Scroll handlers ──

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentTarget = _tabController.index == 0 ? 'umum' : 'khusus';
    });
    _resetAndLoadActivities();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreActivities();
      }
    }
  }

  // ── Data loading ──

  void _resetAndLoadActivities() {
    setState(() {
      _currentPage = 1;
      _activityList.clear();
      _hasMoreData = true;
      _isLoading = true;
    });
    _loadActivities();
  }

  Future<void> _loadMoreActivities() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() {
      _currentPage++;
      _isLoadingMore = true;
    });
    await _loadActivities();
  }

  Future<void> _loadActivities() async {
    if (_isLoadingMore && _currentPage == 1) return;

    try {
      setState(() {
        if (_currentPage == 1) _isLoading = true;
      });

      final academicYearId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      final response = await getIt<ApiClassActivityService>()
          .getClassActivityPaginated(
            page: _currentPage,
            limit: _perPage,
            teacherId: widget.teacherId,
            classId: widget.classId,
            subjectId: widget.subjectId,
            target: _currentTarget,
            search: _searchController.text.isNotEmpty
                ? _searchController.text
                : null,
            date: _selectedDateFilter,
            academicYearId: academicYearId,
          );

      setState(() {
        if (_currentPage == 1) {
          _activityList = response['data'] ?? [];
        } else {
          _activityList.addAll(response['data'] ?? []);
        }
        _hasMoreData = response['pagination']?['has_next_page'] ?? false;
        _isLoading = false;
        _isLoadingMore = false;
      });

      if (_currentPage == 1 && !widget.autoShowActivityDialog) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _checkAndShowTour();
        });
      }

      if (widget.autoShowActivityDialog && _currentPage == 1) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _showActivityTypeDialog();
        });
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error load activities: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasMoreData = false;
        });
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _loadMaterials(String subjectId) async {
    try {
      final materials = await getIt<ApiSubjectService>().getMaterials();
      setState(() {
        _chapterList = materials;
        _subChapterList = [];
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error load materials: $e');
    }
  }

  Future<void> _loadSubChapterContent(String chapterId) async {
    try {
      final subMaterials = await getIt<ApiSubjectService>()
          .getSubChapterMaterials(chapterId: chapterId);
      setState(() {
        _subChapterList = subMaterials;
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error load sub chapter materials: $e');
    }
  }

  // ── CRUD dialogs ──

  void _showActivityTypeDialog() {
    ActivityTypeBottomSheet.show(
      context: context,
      primaryColor: _primaryColor,
      languageProvider: ref.read(languageRiverpod),
      onActivityTypeSelected: _showAddActivityDialog,
    );
  }

  void _showAddActivityDialog(String activityType) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddActivityDialog(
        teacherId: widget.teacherId,
        teacherName: widget.teacherName,
        scheduleList: const [],
        subjectList: const [],
        chapterList: _chapterList,
        subChapterList: _subChapterList,
        onSubjectSelected: _loadMaterials,
        onChapterSelected: _loadSubChapterContent,
        onActivityAdded: _onActivityChanged,
        initialTarget: _currentTarget,
        activityType: activityType,
        initialDate: widget.initialDate,
        initialSubjectId: widget.subjectId,
        initialSubjectName: widget.subjectName,
        initialClassId: widget.classId,
        initialClassName: widget.className,
        initialChapterId: widget.initialChapterId,
        initialSubChapterId: widget.initialSubChapterId,
        initialAdditionalMaterials: widget.initialAdditionalMaterials,
        materialsToMarkAsGenerated: widget.materialsToMarkAsGenerated,
      ),
    );
  }

  void _showEditActivityDialog(dynamic activity) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddActivityDialog(
        teacherId: widget.teacherId,
        teacherName: widget.teacherName,
        scheduleList: const [],
        subjectList: const [],
        chapterList: _chapterList,
        subChapterList: _subChapterList,
        onSubjectSelected: _loadMaterials,
        onChapterSelected: _loadSubChapterContent,
        onActivityAdded: _onActivityChanged,
        initialTarget: activity['target_role'] ?? 'umum',
        activityType: _resolveActivityType(activity),
        isEditMode: true,
        activityData: activity,
        initialDate: activity['date'] != null
            ? DateTime.tryParse(activity['date'].toString())
            : null,
        initialSubjectId: activity['subject_id']?.toString(),
        initialClassId: activity['class_id']?.toString(),
        initialChapterId: activity['chapter_id']?.toString(),
        initialSubChapterId: activity['sub_chapter_id']?.toString(),
        initialAdditionalMaterials: activity['additional_material'] is List
            ? (activity['additional_material'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList()
            : [],
      ),
    );
  }

  void _onActivityChanged() {
    _loadActivities();
    widget.onActivityChanged?.call();
  }

  Future<void> _deleteActivity(
    dynamic activity,
    LanguageProvider languageProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          languageProvider.getTranslatedText({
            'en': 'Delete Activity',
            'id': 'Hapus Kegiatan',
          }),
        ),
        content: Text(
          languageProvider.getTranslatedText({
            'en':
                'Are you sure you want to delete "${activity['title']}"? This action cannot be undone.',
            'id':
                'Apakah Anda yakin ingin menghapus "${activity['title']}"? Tindakan ini tidak dapat dibatalkan.',
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context, false),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Cancel',
                'id': 'Batal',
              }),
            ),
          ),
          ElevatedButton(
            onPressed: () => AppNavigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorUtils.error600,
              foregroundColor: Colors.white,
            ),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Delete',
                'id': 'Hapus',
              }),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await getIt<ApiClassActivityService>().deleteActivity(
        activity['id'].toString(),
      );

      if (!mounted) return;

      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'Activity deleted successfully',
          'id': 'Kegiatan berhasil dihapus',
        }),
      );

      _onActivityChanged();
      await _autoUncheckMaterials(activity);
    } catch (e) {
      AppLogger.error('class_activity', 'Delete activity error: $e');
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        '${languageProvider.getTranslatedText({'en': 'Failed to delete activity: ', 'id': 'Gagal menghapus kegiatan: '})}${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  /// Auto-uncheck material progress when an activity is deleted.
  Future<void> _autoUncheckMaterials(dynamic activity) async {
    if (activity['chapter_id'] == null) return;

    final List<Map<String, dynamic>> progressItems = [];

    Future<bool> isMaterialUsed(String chapterId, String? subChapterId) async {
      try {
        final response = await getIt<ApiClassActivityService>()
            .getClassActivityPaginated(
              page: 1,
              limit: 1,
              teacherId: widget.teacherId,
              subjectId: activity['subject_id'] ?? activity['mata_pelajaran_id'],
              chapterId: chapterId,
              subChapterId: subChapterId,
            );
        return (response['pagination']?['total_items'] ?? 0) > 0;
      } catch (e) {
        AppLogger.error('class_activity', 'Error checking material usage: $e');
        return true;
      }
    }

    try {
      if (activity['sub_chapter_id'] != null) {
        final inUse = await isMaterialUsed(
          activity['chapter_id'].toString(),
          activity['sub_chapter_id'].toString(),
        );
        if (!inUse) {
          progressItems.add({
            'bab_id': activity['chapter_id'],
            'sub_bab_id': activity['sub_chapter_id'],
            'is_checked': false,
          });
        }
      } else {
        final subChapters = await getIt<ApiSubjectService>()
            .getSubChapterMaterials(
              chapterId: activity['chapter_id'].toString(),
            );

        for (var sub in subChapters) {
          final subId = sub['id'].toString();
          final isSpecificUsed = await isMaterialUsed(
            activity['chapter_id'].toString(),
            subId,
          );
          final isGenericUsed = await isMaterialUsed(
            activity['chapter_id'].toString(),
            'null',
          );
          if (!isSpecificUsed && !isGenericUsed) {
            progressItems.add({
              'bab_id': activity['chapter_id'],
              'sub_bab_id': subId,
              'is_checked': false,
            });
          }
        }
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error unchecking primary material: $e');
    }

    // Additional materials
    if (activity['additional_material'] != null) {
      try {
        List<dynamic> additionalMaterials = [];
        if (activity['additional_material'] is String) {
          additionalMaterials = json.decode(activity['additional_material']);
        } else if (activity['additional_material'] is List) {
          additionalMaterials = activity['additional_material'];
        }

        for (var item in additionalMaterials) {
          if (item['chapter_id'] != null && item['sub_chapter_id'] != null) {
            final subId = item['sub_chapter_id'].toString();
            final chapId = item['chapter_id'].toString();
            final isSpecificUsed = await isMaterialUsed(chapId, subId);
            final isGenericUsed = await isMaterialUsed(chapId, 'null');
            if (!isSpecificUsed && !isGenericUsed) {
              progressItems.add({
                'bab_id': chapId,
                'sub_bab_id': subId,
                'is_checked': false,
              });
            }
          }
        }
      } catch (e) {
        AppLogger.error('class_activity', 'Error parsing additional materials: $e');
      }
    }

    if (progressItems.isNotEmpty) {
      try {
        await getIt<ApiSubjectService>().batchSaveMateriProgress({
          'guru_id': widget.teacherId,
          'mata_pelajaran_id':
              activity['subject_id'] ?? activity['mata_pelajaran_id'],
          'progress_items': progressItems,
        });
        AppLogger.debug(
          'class_activity',
          'Auto-unchecked ${progressItems.length} materials.',
        );
      } catch (e) {
        AppLogger.error('class_activity', 'Error auto-unchecking materials: $e');
      }
    }
  }

  // ── Filter / Detail ──

  void _showFilterSheet() {
    FilterBottomSheet.show(
      context: context,
      primaryColor: _primaryColor,
      languageProvider: ref.read(languageRiverpod),
      initialDateFilter: _selectedDateFilter,
      onApply: (dateFilter) {
        setState(() {
          _selectedDateFilter = dateFilter;
          _hasActiveFilter = _selectedDateFilter != null;
        });
        _resetAndLoadActivities();
      },
    );
  }

  void _showActivityDetail(dynamic activity) {
    ActivityDetailDialog.show(
      context: context,
      activity: activity,
      primaryColor: _primaryColor,
      languageProvider: ref.read(languageRiverpod),
      canEdit: widget.canEdit,
      selectedClassName: widget.className,
      selectedSubjectName: widget.subjectName,
      onEditPressed: () => _showEditActivityDialog(activity),
    );
  }

  // ── Tour ──

  Future<void> _checkAndShowTour() async {
    try {
      final tourCacheKey = CacheKeyBuilder.tourStatus(
        'class_activity_screen',
        'guru',
      );
      final cached = await LocalCacheService.load(
        tourCacheKey,
        ttl: const Duration(hours: 24),
      );
      if (cached != null && cached is Map && cached['should_show'] == true) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _showTour();
          });
        }
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error checking tour status: $e');
    }
  }

  void _showTour() {
    showClassActivityTour(
      context: context,
      targets: buildClassActivityTourTargets(
        tabSwitcherKey: _tabSwitcherKey,
        searchFilterKey: _searchFilterKey,
        fabKey: _fabKey,
        selectedSubjectCanEdit: widget.canEdit,
      ),
    );
  }

  // ── Helpers ──

  Color get _primaryColor => ColorUtils.getRoleColor('guru');

  /// Maps API `type` field (material/assignment) back to the Indonesian
  /// value the add/edit dialog expects (materi/tugas).
  String _resolveActivityType(dynamic activity) {
    final type = activity['type']?.toString() ?? activity['jenis']?.toString();
    if (type == 'assignment' || type == 'tugas') return 'tugas';
    if (type == 'material' || type == 'materi') return 'materi';
    return 'tugas';
  }

  // ── Public API for parent (ClassActivityScreen) ──

  /// The tab switcher widget that the parent's header can display.
  Widget buildTabSwitcher(LanguageProvider languageProvider) {
    return ActivityTabSwitcher(
      tabSwitcherKey: _tabSwitcherKey,
      tabController: _tabController,
      primaryColor: _primaryColor,
      allStudentsLabel: languageProvider.getTranslatedText({
        'en': 'All Students',
        'id': 'Semua Siswa',
      }),
      specificStudentLabel: languageProvider.getTranslatedText({
        'en': 'Specific Student',
        'id': 'Khusus Siswa',
      }),
    );
  }

  /// Force-refresh activities from the API.
  void forceRefresh() => _resetAndLoadActivities();

  /// The FAB for adding activities (used when parent owns the Scaffold).
  Widget? buildFab() {
    if (!widget.canEdit) return null;
    return FloatingActionButton(
      key: _fabKey,
      onPressed: _showActivityTypeDialog,
      backgroundColor: _primaryColor,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final body = ActivityListView(
      isLoading: _isLoading,
      isLoadingMore: _isLoadingMore,
      activityList: _activityList,
      hasActiveFilter: _hasActiveFilter,
      selectedDateFilter: _selectedDateFilter,
      searchController: _searchController,
      scrollController: _scrollController,
      searchFilterKey: _searchFilterKey,
      primaryColor: _primaryColor,
      canEdit: widget.canEdit,
      selectedSubjectName: widget.subjectName,
      selectedClassName: widget.className,
      onSearchSubmitted: _resetAndLoadActivities,
      onFilterPressed: _showFilterSheet,
      onRemoveDateFilter: () {
        setState(() {
          _selectedDateFilter = null;
          _hasActiveFilter = false;
        });
        _resetAndLoadActivities();
      },
      onActivityTap: _showActivityDetail,
      onActivityEdit: _showEditActivityDialog,
      onActivityDelete: (activity) =>
          _deleteActivity(activity, ref.read(languageRiverpod)),
    );

    if (!widget.showScaffold) return body;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Gradient header with drag handle
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primaryColor, _primaryColor.withValues(alpha: 0.85)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_outlined, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kelas: ${widget.className}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.subjectName,
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: buildFab(),
    );
  }
}
