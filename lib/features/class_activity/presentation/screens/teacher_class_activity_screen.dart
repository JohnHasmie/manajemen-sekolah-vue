// Class activity (journal) management screen for teachers.
//
// Single-page flat layout matching "Jadwal Mengajar":
// - Gradient header with role toggle + search + filter
// - Mengajar: shows teacher's own activities grouped by class+subject
// - Wali Kelas: shows ALL activities for the homeroom class (all teachers)
// - FAB to add activity from main screen
// - Filter dialog: class, subject (depends on class), date (hari ini/minggu ini/bulan ini)
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_type_bottom_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/add_activity_dialog.dart';

class ClassActivityScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;
  final String? initialChapterId;
  final String? initialSubChapterId;
  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;
  final bool autoShowActivityDialog;

  const ClassActivityScreen({
    super.key,
    this.initialDate,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
    this.initialChapterId,
    this.initialSubChapterId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.autoShowActivityDialog = false,
  });

  @override
  ClassActivityScreenState createState() => ClassActivityScreenState();
}

class ClassActivityScreenState extends ConsumerState<ClassActivityScreen> {
  String _teacherId = '';
  String _teacherName = '';
  bool _isLoading = true;

  // Role toggle
  bool _isHomeroomView = false;
  List<dynamic> _homeroomClassesList = [];
  Map<String, dynamic>? _selectedHomeroomClass;
  List<dynamic> _classList = [];

  // View toggle
  bool _isTimelineView = false;

  // Grouped data + pagination
  List<dynamic> _groupedActivities = [];
  List<dynamic> _schedules = [];
  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Timeline data + pagination
  List<dynamic> _timelineActivities = [];
  int _timelinePage = 1;
  bool _timelineHasMore = true;
  bool _timelineLoadingMore = false;
  final ScrollController _timelineScrollController = ScrollController();

  // Filter
  String? _filterClassId;
  String? _filterSubjectId;
  String? _filterDateOption; // today, week, month
  List<dynamic> _filterSubjectList = [];

  final TextEditingController _searchController = TextEditingController();

  Color get _primaryColor => ColorUtils.getRoleColor('guru');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _timelineScrollController.addListener(_onTimelineScroll);
    _loadViewPref();
    _loadUserData();
  }

  Future<void> _loadViewPref() async {
    try {
      final c = await LocalCacheService.load('kegiatan_view_preference');
      if (c is Map && mounted) setState(() => _isTimelineView = c['is_timeline'] ?? false);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) _loadMoreGroupedActivities();
    }
  }

  void _onTimelineScroll() {
    if (_timelineScrollController.position.pixels >= _timelineScrollController.position.maxScrollExtent - 200) {
      if (!_timelineLoadingMore && _timelineHasMore) _loadMoreTimeline();
    }
  }

  // ── Data loading ──

  Future<void> _loadUserData() async {
    try {
      final teacherProvider = ref.read(teacherRiverpod);
      final prefs = PreferencesService();
      final userData = json.decode(prefs.getString('user') ?? '{}');
      final role = userData['role']?.toString().toLowerCase() ?? '';
      final isAdmin = role == 'admin' || role == 'super_admin';

      if (!isAdmin && teacherProvider.isLoaded && teacherProvider.teacherId != null) {
        setState(() {
          _teacherId = teacherProvider.teacherId!;
          _teacherName = teacherProvider.teacherName ?? 'Guru';
        });
        await _loadInitialData(teacherProvider.teacherId!);
        return;
      }

      final userId = userData['id']?.toString() ?? '';
      setState(() {
        _teacherId = userId;
        _teacherName = userData['nama']?.toString() ?? 'Guru';
      });

      if (userId.isEmpty) { setState(() => _isLoading = false); return; }

      if (isAdmin) { await _loadInitialData(userId); return; }

      try {
        String? resolved;
        if (userData.containsKey('employee_number') || userData.containsKey('nip') || userData.containsKey('user_id')) {
          resolved = userId;
        } else {
          String? ayId;
          try { if (mounted) ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString(); } catch (_) {}
          await teacherProvider.ensureLoaded(academicYearId: ayId);
          resolved = teacherProvider.teacherId;
          if (resolved == null) {
            final td = await getIt<ApiTeacherService>().getTeacherByUserId(userId, academicYearId: ayId);
            resolved = td?['id']?.toString();
          }
        }
        if (resolved != null) {
          setState(() => _teacherId = resolved!);
          await _loadInitialData(resolved);
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        AppLogger.error('class_activity', 'Error resolving teacher: $e');
        if (mounted) SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error in _loadUserData: $e');
      if (mounted) SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadInitialData(String teacherId) async {
    setState(() => _isLoading = true);
    final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();

    try {
      final results = await Future.wait([
        getIt<ApiTeacherService>().getTeacherClasses(teacherId, academicYearId: ayId),
        getIt<ApiScheduleService>().getScheduleByTeacher(teacherId: teacherId, academicYear: ayId),
        getIt<ApiClassActivityService>().getTeacherActivitySummary(teacherId: teacherId, academicYearId: ayId, page: 1, perPage: 20),
      ]);

      if (!mounted) return;
      final classes = results[0] as List;
      final summaryResult = results[2] as Map<String, dynamic>;
      final homerooms = classes.where((c) => c['is_homeroom'] == true).toList();

      setState(() {
        _classList = classes;
        _schedules = results[1] as List;
        _groupedActivities = (summaryResult['data'] as List?) ?? [];
        _hasMoreData = summaryResult['pagination']?['has_next_page'] == true;
        _homeroomClassesList = homerooms;
        if (homerooms.isNotEmpty) _selectedHomeroomClass = homerooms.first;
        _isLoading = false;
      });

      if (widget.initialClassId != null && widget.initialSubjectId != null) {
        _openActivityList(classId: widget.initialClassId!, className: widget.initialClassName ?? '', subjectId: widget.initialSubjectId!, subjectName: widget.initialSubjectName ?? '');
      } else {
        _autoOpenCurrentSchedule();
      }
    } catch (e) {
      AppLogger.error('class_activity', 'Error loading initial data: $e');
      if (mounted) { SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e)); setState(() => _isLoading = false); }
    }
  }

  void _autoOpenCurrentSchedule() {
    if (_schedules.isEmpty) return;
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    const wd = {1: 'senin', 2: 'selasa', 3: 'rabu', 4: 'kamis', 5: 'jumat', 6: 'sabtu'};
    final today = wd[now.weekday] ?? '';

    for (final s in _schedules) {
      final dn = (s['hari_nama'] ?? s['day_name'] ?? '').toString().toLowerCase();
      if (!dn.contains(today)) continue;
      final st = (s['jam_mulai'] ?? s['start_time'])?.toString();
      final et = (s['jam_selesai'] ?? s['end_time'])?.toString();
      if (st == null || et == null) continue;
      int toM(String t) { final p = t.replaceAll('.', ':').split(':'); return p.length < 2 ? 0 : (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0); }
      if (nowMin >= toM(st) && nowMin < toM(et)) {
        final cid = (s['class_id'] ?? s['kelas_id'])?.toString();
        final cn = (s['class_name'] ?? s['kelas_nama'])?.toString();
        final sid = (s['subject_id'] ?? s['mata_pelajaran_id'])?.toString();
        final sn = (s['subject_name'] ?? s['mata_pelajaran_nama'])?.toString();
        if (cid != null && sid != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openActivityList(classId: cid, className: cn ?? '', subjectId: sid, subjectName: sn ?? '');
          });
          return;
        }
      }
    }
  }

  // ── Refresh & Pagination ──

  Future<void> _refreshGroupedActivities() async {
    setState(() { _currentPage = 1; _hasMoreData = true; _groupedActivities.clear(); });
    await _fetchGroupedActivities();
  }

  Future<void> _loadMoreGroupedActivities() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() { _currentPage++; _isLoadingMore = true; });
    await _fetchGroupedActivities();
  }

  Future<void> _fetchGroupedActivities() async {
    final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
    try {
      final homeroomClassId = _selectedHomeroomClass?['id']?.toString();
      final result = await getIt<ApiClassActivityService>().getTeacherActivitySummary(
        teacherId: _isHomeroomView ? null : _teacherId,
        classId: _isHomeroomView ? homeroomClassId : _filterClassId,
        academicYearId: ayId,
        subjectId: _filterSubjectId,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        dateFilter: _filterDateOption,
        page: _currentPage,
        perPage: 20,
      );
      if (!mounted) return;
      final data = (result['data'] as List?) ?? [];
      final pagination = result['pagination'];
      setState(() {
        if (_currentPage == 1) {
          _groupedActivities = data;
        } else {
          final existingKeys = _groupedActivities.map((g) => '${g['class_id']}__${g['subject_id']}').toSet();
          for (final g in data) {
            final key = '${g['class_id']}__${g['subject_id']}';
            if (!existingKeys.contains(key)) _groupedActivities.add(g);
          }
        }
        _hasMoreData = pagination?['has_next_page'] == true;
        _isLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error fetching: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // ── Timeline fetch ──

  Future<void> _refreshTimeline() async {
    setState(() { _timelinePage = 1; _timelineHasMore = true; _timelineActivities.clear(); _isLoading = true; });
    await _fetchTimeline();
  }

  Future<void> _loadMoreTimeline() async {
    if (_timelineLoadingMore || !_timelineHasMore) return;
    setState(() { _timelinePage++; _timelineLoadingMore = true; });
    await _fetchTimeline();
  }

  Future<void> _fetchTimeline() async {
    final ayId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
    try {
      final homeroomClassId = _selectedHomeroomClass?['id']?.toString();
      final result = await getIt<ApiClassActivityService>().getClassActivityPaginated(
        page: _timelinePage,
        limit: 20,
        teacherId: _isHomeroomView ? null : _teacherId,
        classId: _isHomeroomView ? homeroomClassId : _filterClassId,
        subjectId: _filterSubjectId,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        academicYearId: ayId,
      );
      if (!mounted) return;
      final data = (result['data'] as List?) ?? [];
      final pagination = result['pagination'];
      setState(() {
        if (_timelinePage == 1) {
          _timelineActivities = data;
        } else {
          _timelineActivities.addAll(data);
        }
        _timelineHasMore = pagination?['has_next_page'] == true;
        _isLoading = false;
        _timelineLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error fetching timeline: $e');
      if (mounted) setState(() { _isLoading = false; _timelineLoadingMore = false; });
    }
  }

  void _toggleView() {
    setState(() => _isTimelineView = !_isTimelineView);
    LocalCacheService.save('kegiatan_view_preference', {'is_timeline': _isTimelineView});
    if (_isTimelineView && _timelineActivities.isEmpty) {
      _refreshTimeline();
    }
  }

  Future<void> _forceRefresh() async {
    if (_isTimelineView) {
      _refreshTimeline();
    } else {
      _refreshGroupedActivities();
    }
  }

  void _onSearch() { _isTimelineView ? _refreshTimeline() : _refreshGroupedActivities(); FocusScope.of(context).unfocus(); }

  // ── Navigation ──

  void _openActivityList({required String classId, required String className, required String subjectId, required String subjectName}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.96, expand: false,
        builder: (context, sc) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: EmbeddedActivityListScreen(
            teacherId: _teacherId, teacherName: _teacherName,
            classId: classId, className: className, subjectId: subjectId, subjectName: subjectName,
            canEdit: !_isHomeroomView, // Wali Kelas view is read-only for other teachers' activities
            initialDate: widget.initialDate, initialChapterId: widget.initialChapterId,
            initialSubChapterId: widget.initialSubChapterId,
            initialAdditionalMaterials: widget.initialAdditionalMaterials,
            materialsToMarkAsGenerated: widget.materialsToMarkAsGenerated,
            autoShowActivityDialog: widget.autoShowActivityDialog,
            showScaffold: true,
          ),
        ),
      ),
    ).then((_) => _forceRefresh());
  }

  // ── FAB: Add activity from main screen ──

  void _showAddActivityFlow(LanguageProvider lp) {
    String? pickClassId;
    String? pickClassName;
    String? pickSubjectId;
    String? pickSubjectName;
    List<dynamic> pickSubjectList = [];

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_primaryColor, _primaryColor.withValues(alpha: 0.85)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(lp.getTranslatedText({'en': 'New Activity', 'id': 'Kegiatan Baru'}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white)),
                  ]),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Select Class', 'id': 'Pilih Kelas'}), Icons.school_rounded),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: _classList.map((c) {
                        final cid = c['id']?.toString();
                        final cname = c['name'] ?? c['nama'] ?? '-';
                        return _buildSheetChip(cname, pickClassId == cid, () async {
                          setSS(() { pickClassId = cid; pickClassName = cname; pickSubjectId = null; pickSubjectName = null; pickSubjectList = []; });
                          if (cid != null) { try { final r = await dioClient.get('/class/$cid/subjects'); setSS(() => pickSubjectList = r.data is List ? r.data as List : []); } catch (_) {} }
                        });
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Select Subject', 'id': 'Pilih Mapel'}), Icons.menu_book_rounded),
                    if (pickSubjectList.isEmpty)
                      Text(
                        pickClassId == null ? lp.getTranslatedText({'en': 'Please select a class first', 'id': 'Pilih kelas terlebih dahulu'}) : lp.getTranslatedText({'en': 'No subjects available', 'id': 'Tidak ada mapel tersedia'}),
                        style: TextStyle(fontSize: 13, color: ColorUtils.slate500, fontStyle: FontStyle.italic),
                      )
                    else
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: pickSubjectList.map((s) {
                          final sid = s['id']?.toString();
                          final sname = s['name'] ?? s['nama'] ?? '-';
                          return _buildSheetChip(sname, pickSubjectId == sid, () {
                            setSS(() { pickSubjectId = sid; pickSubjectName = sname; });
                          });
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: ColorUtils.slate200),
                      ),
                      child: Text(lp.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColorUtils.slate600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: pickClassId != null && pickSubjectId != null ? () {
                        Navigator.pop(ctx);
                        _showActivityTypeSelector(pickClassId!, pickClassName ?? '', pickSubjectId!, pickSubjectName ?? '', lp);
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                        disabledBackgroundColor: ColorUtils.slate200,
                        disabledForegroundColor: ColorUtils.slate400,
                      ),
                      child: Text(lp.getTranslatedText({'en': 'Continue', 'id': 'Lanjutkan'}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showActivityTypeSelector(String classId, String className, String subjectId, String subjectName, LanguageProvider lp) {
    ActivityTypeBottomSheet.show(
      context: context,
      primaryColor: _primaryColor,
      languageProvider: lp,
      onActivityTypeSelected: (type) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AddActivityDialog(
            teacherId: _teacherId,
            teacherName: _teacherName,
            scheduleList: const [],
            subjectList: const [],
            chapterList: const [],
            subChapterList: const [],
            onSubjectSelected: (_) async {},
            onChapterSelected: (_) async {},
            onActivityAdded: _forceRefresh,
            initialTarget: 'umum',
            activityType: type,
            initialSubjectId: subjectId,
            initialSubjectName: subjectName,
            initialClassId: classId,
            initialClassName: className,
          ),
        );
      },
    );
  }

  // ── Filter dialog ──

  void _showFilterDialog(LanguageProvider lp) {
    String? tClassId = _filterClassId;
    String? tSubjectId = _filterSubjectId;
    String? tDateOption = _filterDateOption;
    List<dynamic> tSubjectList = List.from(_filterSubjectList);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [_primaryColor, _primaryColor.withValues(alpha: 0.85)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
                  ),
                  Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: Text(lp.getTranslatedText({'en': 'Filter Activity', 'id': 'Filter Kegiatan'}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                    TextButton(
                      onPressed: () => setSS(() { tClassId = null; tSubjectId = null; tDateOption = null; tSubjectList = []; }),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reset', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ],
              ),
            ),
            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Select Class', 'id': 'Pilih Kelas'}), Icons.school_rounded),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _buildSheetChip(lp.getTranslatedText({'en': 'All Classes', 'id': 'Semua Kelas'}), tClassId == null, () {
                          setSS(() { tClassId = null; tSubjectId = null; tSubjectList = []; });
                        }),
                        ..._classList.map((c) {
                          final cid = c['id']?.toString();
                          final cname = c['name'] ?? c['nama'] ?? '-';
                          return _buildSheetChip(cname, tClassId == cid, () async {
                            setSS(() { tClassId = cid; tSubjectId = null; tSubjectList = []; });
                            if (cid != null) { try { final r = await dioClient.get('/class/$cid/subjects'); setSS(() => tSubjectList = r.data is List ? r.data as List : []); } catch (_) {} }
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Select Subject', 'id': 'Pilih Mapel'}), Icons.menu_book_rounded),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _buildSheetChip(lp.getTranslatedText({'en': 'All Subjects', 'id': 'Semua Mapel'}), tSubjectId == null, () {
                          setSS(() { tSubjectId = null; });
                        }),
                        ...tSubjectList.map((s) {
                          final sid = s['id']?.toString();
                          final sname = s['name'] ?? s['nama'] ?? '-';
                          return _buildSheetChip(sname, tSubjectId == sid, () {
                            setSS(() { tSubjectId = sid; });
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Time Range', 'id': 'Rentang Waktu'}), Icons.calendar_today_rounded),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _buildSheetChip(lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}), tDateOption == 'today', () => setSS(() => tDateOption = tDateOption == 'today' ? null : 'today')),
                        _buildSheetChip(lp.getTranslatedText({'en': 'This Week', 'id': 'Minggu Ini'}), tDateOption == 'week', () => setSS(() => tDateOption = tDateOption == 'week' ? null : 'week')),
                        _buildSheetChip(lp.getTranslatedText({'en': 'This Month', 'id': 'Bulan Ini'}), tDateOption == 'month', () => setSS(() => tDateOption = tDateOption == 'month' ? null : 'month')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: ColorUtils.slate200),
                      ),
                      child: Text(lp.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColorUtils.slate600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() { _filterClassId = tClassId; _filterSubjectId = tSubjectId; _filterDateOption = tDateOption; _filterSubjectList = tSubjectList; });
                        Navigator.pop(ctx);
                        _forceRefresh();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(lp.getTranslatedText({'en': 'Apply', 'id': 'Terapkan'}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSheetSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: Icon(icon, size: 16, color: _primaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _primaryColor.withValues(alpha: 0.1) : ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(
            color: isSelected ? _primaryColor : ColorUtils.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? _primaryColor : ColorUtils.slate600,
          ),
        ),
      ),
    );
  }

  bool get _hasActiveFilter => _filterClassId != null || _filterSubjectId != null || _filterDateOption != null;

  String _dateFilterLabel(LanguageProvider lp) {
    switch (_filterDateOption) {
      case 'today': return lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'});
      case 'week': return lp.getTranslatedText({'en': 'This Week', 'id': 'Minggu Ini'});
      case 'month': return lp.getTranslatedText({'en': 'This Month', 'id': 'Bulan Ini'});
      default: return '';
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final lp = ref.read(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(children: [
        _buildHeader(lp),
        Expanded(child: _isTimelineView ? _buildTimelineBody(lp) : _buildBody(lp)),
      ]),
      floatingActionButton: !_isHomeroomView ? FloatingActionButton(
        onPressed: () => _showAddActivityFlow(lp),
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildHeader(LanguageProvider lp) {
    final p = _primaryColor;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + AppSpacing.lg, left: AppSpacing.lg, right: AppSpacing.lg, bottom: AppSpacing.lg),
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p, p.withValues(alpha: 0.8)])),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back, color: Colors.white, size: 20)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lp.getTranslatedText({'en': 'Class Activity', 'id': 'Kegiatan Kelas'}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(_isHomeroomView ? lp.getTranslatedText({'en': 'All activities in homeroom class', 'id': 'Semua kegiatan di kelas perwalian'}) : lp.getTranslatedText({'en': 'Manage your teaching activities', 'id': 'Kelola kegiatan mengajar Anda'}), style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
          ])),
          // View toggle (grouped ↔ timeline)
          GestureDetector(
            onTap: _toggleView,
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(_isTimelineView ? Icons.grid_view_rounded : Icons.view_list_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
        if (_homeroomClassesList.isNotEmpty) ...[const SizedBox(height: AppSpacing.md), _buildRoleToggle(lp)],
        const SizedBox(height: AppSpacing.md),
        // Search + filter
        Row(children: [
          Expanded(child: Container(
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _searchController, textAlignVertical: TextAlignVertical.center,
                style: TextStyle(color: ColorUtils.slate800, fontSize: 13),
                decoration: InputDecoration(isDense: true, hintText: lp.getTranslatedText({'en': 'Search activity...', 'id': 'Cari kegiatan...'}), hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                onSubmitted: (_) => _onSearch(),
              )),
              Container(margin: const EdgeInsets.only(right: 4), child: IconButton(icon: Icon(Icons.search, color: p, size: 20), onPressed: _onSearch)),
            ]),
          )),
          const SizedBox(width: AppSpacing.sm),
          Container(
            height: 48, width: 48,
            decoration: BoxDecoration(color: _hasActiveFilter ? Colors.white : Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
            child: Stack(alignment: Alignment.center, children: [
              IconButton(onPressed: () => _showFilterDialog(lp), icon: Icon(Icons.tune, color: _hasActiveFilter ? p : Colors.white, size: 20)),
              if (_hasActiveFilter) Positioned(right: 8, top: 8, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: ColorUtils.error600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)))),
            ]),
          ),
        ]),
        // Filter chips inside header
        if (_hasActiveFilter) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 32,
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      if (_filterClassId != null) ...[
                        _buildChip(_classList.firstWhere((c) => c['id']?.toString() == _filterClassId, orElse: () => {'name': '-'})['name'] ?? '-', () { setState(() { _filterClassId = null; _filterSubjectId = null; _filterSubjectList = []; }); _forceRefresh(); }),
                        const SizedBox(width: 6),
                      ],
                      if (_filterSubjectId != null) ...[
                        _buildChip(_filterSubjectList.firstWhere((s) => s['id']?.toString() == _filterSubjectId, orElse: () => {'name': '-'})['name'] ?? '-', () { setState(() => _filterSubjectId = null); _forceRefresh(); }),
                        const SizedBox(width: 6),
                      ],
                      if (_filterDateOption != null) ...[
                        _buildChip(_dateFilterLabel(lp), () { setState(() => _filterDateOption = null); _forceRefresh(); }),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: () { setState(() { _filterClassId = null; _filterSubjectId = null; _filterDateOption = null; _filterSubjectList = []; }); _forceRefresh(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      lp.getTranslatedText({'en': 'Clear All', 'id': 'Hapus Semua'}),
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildRoleToggle(LanguageProvider lp) {
    final p = _primaryColor;
    return Container(
      height: 46, padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.1))),
      child: Stack(alignment: Alignment.center, children: [
        AnimatedAlign(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut, alignment: _isHomeroomView ? Alignment.centerRight : Alignment.centerLeft, child: FractionallySizedBox(widthFactor: 0.5, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))])))),
        Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { if (_isHomeroomView) { setState(() { _isHomeroomView = false; _isLoading = true; }); _forceRefresh().then((_) { if (mounted) setState(() => _isLoading = false); }); } },
            child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.person_outline_rounded, size: 16, color: !_isHomeroomView ? p : Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: AppSpacing.xs),
              Text(lp.getTranslatedText({'en': 'Teaching', 'id': 'Mengajar'}), style: TextStyle(fontSize: 12, fontWeight: !_isHomeroomView ? FontWeight.w700 : FontWeight.w500, color: !_isHomeroomView ? p : Colors.white.withValues(alpha: 0.9))),
            ])))),
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { if (!_isHomeroomView) { setState(() { _isHomeroomView = true; _isLoading = true; }); _forceRefresh().then((_) { if (mounted) setState(() => _isLoading = false); }); } },
            child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.class_outlined, size: 16, color: _isHomeroomView ? p : Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: AppSpacing.xs),
              Flexible(child: Text(
                _isHomeroomView && _selectedHomeroomClass != null ? 'Kelas ${_selectedHomeroomClass!['name'] ?? _selectedHomeroomClass!['nama'] ?? ''}' : lp.getTranslatedText({'en': 'Homeroom', 'id': 'Wali Kelas'}),
                style: TextStyle(fontSize: 12, fontWeight: _isHomeroomView ? FontWeight.w700 : FontWeight.w500, color: _isHomeroomView ? p : Colors.white.withValues(alpha: 0.9)), maxLines: 1, overflow: TextOverflow.ellipsis,
              )),
            ])))),
        ]),
      ]),
    );
  }


  Widget _buildChip(String label, VoidCallback onRemove) {
    return GestureDetector(onTap: onRemove, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        const Icon(Icons.close, size: 14, color: Colors.white),
      ]),
    ));
  }

  Widget _buildBody(LanguageProvider lp) {
    if (_isLoading) return SkeletonListLoading(itemCount: 4, infoTagCount: 2);

    return RefreshIndicator(
      onRefresh: _forceRefresh,
      color: _primaryColor,
      child: _groupedActivities.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                Center(child: Column(children: [
                  Icon(Icons.event_note_outlined, size: 56, color: ColorUtils.slate300),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isNotEmpty || _hasActiveFilter
                        ? lp.getTranslatedText({'en': 'No activities match your filter', 'id': 'Tidak ada kegiatan sesuai filter'})
                        : lp.getTranslatedText({'en': 'No activities yet', 'id': 'Belum ada kegiatan'}),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColorUtils.slate600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lp.getTranslatedText({'en': 'Pull down to refresh', 'id': 'Tarik ke bawah untuk memuat ulang'}),
                    style: TextStyle(fontSize: 12, color: ColorUtils.slate400),
                  ),
                ])),
              ],
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: _groupedActivities.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _groupedActivities.length) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: _primaryColor)),
                  );
                }
                final g = _groupedActivities[index];
                return _ActivityGroupCard(group: g, primaryColor: _primaryColor, languageProvider: lp, onTap: () => _openActivityList(
                  classId: g['class_id']?.toString() ?? '', className: g['class_name']?.toString() ?? '',
                  subjectId: g['subject_id']?.toString() ?? '', subjectName: g['subject_name']?.toString() ?? '',
                ));
              },
            ),
    );
  }

  Widget _buildTimelineBody(LanguageProvider lp) {
    if (_isLoading) return SkeletonListLoading(itemCount: 5, infoTagCount: 1);

    return RefreshIndicator(
      onRefresh: () async => _refreshTimeline(),
      color: _primaryColor,
      child: _timelineActivities.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              Center(child: Column(children: [
                Icon(Icons.event_note_outlined, size: 56, color: ColorUtils.slate300),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isNotEmpty || _hasActiveFilter
                      ? lp.getTranslatedText({'en': 'No activities match your filter', 'id': 'Tidak ada kegiatan sesuai filter'})
                      : lp.getTranslatedText({'en': 'No activities yet', 'id': 'Belum ada kegiatan'}),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColorUtils.slate600), textAlign: TextAlign.center,
                ),
              ])),
            ])
          : ListView.builder(
              controller: _timelineScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: _timelineActivities.length + (_timelineLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _timelineActivities.length) {
                  return Padding(padding: const EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: _primaryColor)));
                }
                final a = _timelineActivities[index];
                return _ActivityTimelineCard(activity: a, primaryColor: _primaryColor, languageProvider: lp, onTap: () => _openActivityList(
                  classId: a['class_id']?.toString() ?? a['kelas_id']?.toString() ?? '',
                  className: a['class_name']?.toString() ?? a['kelas_nama']?.toString() ?? '',
                  subjectId: a['subject_id']?.toString() ?? a['mata_pelajaran_id']?.toString() ?? '',
                  subjectName: a['subject_name']?.toString() ?? a['mata_pelajaran_nama']?.toString() ?? '',
                ));
              },
            ),
    );
  }
}

// ── Group card ──────────────────────────────────────────────────────────────

class _ActivityGroupCard extends StatelessWidget {
  final dynamic group;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onTap;

  const _ActivityGroupCard({required this.group, required this.primaryColor, required this.languageProvider, required this.onTap});

  String _fmt(String? d) {
    if (d == null) return '-';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cn = group['class_name']?.toString() ?? '-';
    final sn = group['subject_name']?.toString() ?? '-';
    final total = group['total_count'] ?? 0;
    final latest = (group['latest_activities'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ColorUtils.slate200), boxShadow: ColorUtils.corporateShadow(elevation: 1.0)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.school_outlined, color: primaryColor, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kelas: $cn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColorUtils.slate900), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(sn, style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w600)),
            ])),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryColor)),
              const SizedBox(width: 3),
              Text(languageProvider.getTranslatedText({'en': 'act', 'id': 'kegiatan'}), style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.w500)),
            ])),
          ]),
          if (latest.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ColorUtils.slate50, borderRadius: BorderRadius.circular(10)), child: Column(children: latest.asMap().entries.map((e) {
              final a = e.value;
              final isA = a['type'] == 'assignment' || a['type'] == 'tugas';
              return Padding(padding: EdgeInsets.only(top: e.key > 0 ? 6 : 0), child: Row(children: [
                Icon(isA ? Icons.assignment_outlined : Icons.menu_book_outlined, size: 14, color: isA ? ColorUtils.warning600 : ColorUtils.success600),
                const SizedBox(width: 8),
                Expanded(child: Text(a['title']?.toString() ?? '-', style: TextStyle(fontSize: 12, color: ColorUtils.slate700, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                Text(_fmt(a['date']?.toString()), style: TextStyle(fontSize: 10, color: ColorUtils.slate400)),
              ]));
            }).toList())),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.update_rounded, size: 14, color: ColorUtils.slate400),
            const SizedBox(width: 4),
            Text('${languageProvider.getTranslatedText({'en': 'Latest', 'id': 'Terbaru'})}: ${_fmt(group['latest_date']?.toString())}', style: TextStyle(fontSize: 11, color: ColorUtils.slate400)),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(languageProvider.getTranslatedText({'en': 'View All', 'id': 'Lihat Semua'}), style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.w600)),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 14, color: primaryColor),
            ])),
          ]),
        ]),
      ))),
    );
  }
}

// ── Timeline card ─────────────────────────────────────────────────────────

class _ActivityTimelineCard extends StatelessWidget {
  final dynamic activity;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onTap;

  const _ActivityTimelineCard({required this.activity, required this.primaryColor, required this.languageProvider, required this.onTap});

  String _fmtDate(String? d) {
    if (d == null) return '-';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = activity['title']?.toString() ?? '-';
    final cn = activity['class_name']?.toString() ?? activity['kelas_nama']?.toString() ?? '-';
    final sn = activity['subject_name']?.toString() ?? activity['mata_pelajaran_nama']?.toString() ?? '-';
    final type = activity['type']?.toString() ?? activity['jenis']?.toString() ?? '';
    final isAssignment = type == 'assignment' || type == 'tugas';
    final dateStr = _fmtDate(activity['date']?.toString());
    final description = (activity['deskripsi'] ?? activity['description'])?.toString();
    final hasDesc = description != null && description.isNotEmpty;
    final accentColor = isAssignment ? ColorUtils.warning600 : ColorUtils.success600;
    final typeLabel = isAssignment
        ? languageProvider.getTranslatedText({'en': 'Task', 'id': 'Tugas'})
        : languageProvider.getTranslatedText({'en': 'Material', 'id': 'Materi'});

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ColorUtils.slate200)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Type accent bar
          Container(width: 4, height: 48, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          // Content
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Title
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ColorUtils.slate900), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            // Meta row: class badge + date + type badge
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                child: Text('$cn · $sn', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: primaryColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Icon(Icons.calendar_today_rounded, size: 10, color: ColorUtils.slate400),
              const SizedBox(width: 3),
              Text(dateStr, style: TextStyle(fontSize: 10, color: ColorUtils.slate500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(typeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accentColor)),
              ),
            ]),
            // Description preview
            if (hasDesc) ...[
              const SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: 11, color: ColorUtils.slate500, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ])),
        ]),
      ))),
    );
  }
}
