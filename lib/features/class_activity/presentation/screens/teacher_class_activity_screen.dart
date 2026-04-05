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

  // Grouped data + pagination
  List<dynamic> _groupedActivities = [];
  List<dynamic> _schedules = [];
  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

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
    _loadUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) _loadMoreGroupedActivities();
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

  Future<void> _forceRefresh() async => _refreshGroupedActivities();

  void _onSearch() { _refreshGroupedActivities(); FocusScope.of(context).unfocus(); }

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
    ).then((_) => _refreshGroupedActivities());
  }

  // ── FAB: Add activity from main screen ──

  void _showAddActivityFlow(LanguageProvider lp) {
    // Step 1: Pick class
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: ColorUtils.slate300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.add_rounded, size: 18, color: _primaryColor)),
                const SizedBox(width: 12),
                Text(lp.getTranslatedText({'en': 'New Activity', 'id': 'Kegiatan Baru'}), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColorUtils.slate800)),
              ]),
            ),
            const SizedBox(height: 16),
            // Class dropdown
            _buildFilterDropdown(ctx, setSS, lp.getTranslatedText({'en': 'Select Class', 'id': 'Pilih Kelas'}), pickClassId, _classList.map((c) => DropdownMenuItem<String>(value: c['id']?.toString(), child: Text(c['name'] ?? c['nama'] ?? '-'))).toList(), (v) async {
              setSS(() { pickClassId = v; pickClassName = _classList.firstWhere((c) => c['id']?.toString() == v, orElse: () => {})['name']?.toString(); pickSubjectId = null; pickSubjectName = null; pickSubjectList = []; });
              if (v != null) { try { final r = await dioClient.get('/class/$v/subjects'); setSS(() => pickSubjectList = r.data is List ? r.data as List : []); } catch (_) {} }
            }),
            const SizedBox(height: 12),
            // Subject dropdown
            _buildFilterDropdown(ctx, setSS, lp.getTranslatedText({'en': 'Select Subject', 'id': 'Pilih Mapel'}), pickSubjectId, pickSubjectList.map((s) => DropdownMenuItem<String>(value: s['id']?.toString(), child: Text(s['name'] ?? s['nama'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(), (v) {
              setSS(() { pickSubjectId = v; pickSubjectName = pickSubjectList.firstWhere((s) => s['id']?.toString() == v, orElse: () => {})['name']?.toString(); });
            }),
            const SizedBox(height: 20),
            // Continue button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: pickClassId != null && pickSubjectId != null ? () {
                  Navigator.pop(ctx);
                  _showActivityTypeSelector(pickClassId!, pickClassName ?? '', pickSubjectId!, pickSubjectName ?? '', lp);
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, disabledBackgroundColor: ColorUtils.slate200),
                child: Text(lp.getTranslatedText({'en': 'Continue', 'id': 'Lanjutkan'}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              )),
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
            onActivityAdded: _refreshGroupedActivities,
            initialTarget: 'umum',
            activityType: type,
            initialSubjectId: subjectId,
            initialClassId: classId,
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: ColorUtils.slate300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.tune_rounded, size: 18, color: _primaryColor)),
                const SizedBox(width: 12),
                Expanded(child: Text(lp.getTranslatedText({'en': 'Filter Activity', 'id': 'Filter Kegiatan'}), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ColorUtils.slate800))),
                if (tClassId != null || tSubjectId != null || tDateOption != null)
                  TextButton(onPressed: () => setSS(() { tClassId = null; tSubjectId = null; tDateOption = null; tSubjectList = []; }), child: Text('Reset', style: TextStyle(color: _primaryColor, fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 16),
            // Class dropdown
            _buildFilterDropdown(ctx, setSS, lp.getTranslatedText({'en': 'All Classes', 'id': 'Semua Kelas'}), tClassId, _classList.map((c) => DropdownMenuItem<String>(value: c['id']?.toString(), child: Text(c['name'] ?? c['nama'] ?? '-'))).toList(), (v) async {
              setSS(() { tClassId = v; tSubjectId = null; tSubjectList = []; });
              if (v != null) { try { final r = await dioClient.get('/class/$v/subjects'); setSS(() => tSubjectList = r.data is List ? r.data as List : []); } catch (_) {} }
            }),
            const SizedBox(height: 12),
            // Subject dropdown
            _buildFilterDropdown(ctx, setSS, lp.getTranslatedText({'en': 'All Subjects', 'id': 'Semua Mapel'}), tSubjectId, tSubjectList.map((s) => DropdownMenuItem<String>(value: s['id']?.toString(), child: Text(s['name'] ?? s['nama'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(), (v) => setSS(() => tSubjectId = v)),
            const SizedBox(height: 16),
            // Date filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lp.getTranslatedText({'en': 'Time Range', 'id': 'Rentang Waktu'}), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate700)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  _dateChip(lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}), 'today', tDateOption, (v) => setSS(() => tDateOption = v)),
                  _dateChip(lp.getTranslatedText({'en': 'This Week', 'id': 'Minggu Ini'}), 'week', tDateOption, (v) => setSS(() => tDateOption = v)),
                  _dateChip(lp.getTranslatedText({'en': 'This Month', 'id': 'Bulan Ini'}), 'month', tDateOption, (v) => setSS(() => tDateOption = v)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),
            // Apply
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(width: double.infinity, height: 48, child: ElevatedButton(
                onPressed: () {
                  setState(() { _filterClassId = tClassId; _filterSubjectId = tSubjectId; _filterDateOption = tDateOption; _filterSubjectList = tSubjectList; });
                  Navigator.pop(ctx);
                  _refreshGroupedActivities();
                },
                style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                child: Text(lp.getTranslatedText({'en': 'Apply Filter', 'id': 'Terapkan Filter'}), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              )),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(BuildContext ctx, StateSetter setSS, String hint, String? value, List<DropdownMenuItem<String>> items, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: ColorUtils.slate50, borderRadius: BorderRadius.circular(12), border: Border.all(color: ColorUtils.slate200)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value, isExpanded: true,
            hint: Text(hint, style: TextStyle(fontSize: 13, color: ColorUtils.slate500)),
            icon: Icon(Icons.arrow_drop_down, color: ColorUtils.slate600),
            style: TextStyle(fontSize: 13, color: ColorUtils.slate800),
            items: [DropdownMenuItem<String>(value: null, child: Text(hint, style: TextStyle(color: ColorUtils.slate500))), ...items],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _dateChip(String label, String value, String? selected, void Function(String?) onTap) {
    final isActive = selected == value;
    return GestureDetector(
      onTap: () => onTap(isActive ? null : value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? _primaryColor.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? _primaryColor : ColorUtils.slate300, width: isActive ? 1.5 : 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: isActive ? _primaryColor : ColorUtils.slate600, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
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
        if (_hasActiveFilter) _buildFilterChips(lp),
        Expanded(child: _buildBody(lp)),
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
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { if (_isHomeroomView) { setState(() { _isHomeroomView = false; _isLoading = true; }); _refreshGroupedActivities().then((_) { if (mounted) setState(() => _isLoading = false); }); } },
            child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.person_outline_rounded, size: 16, color: !_isHomeroomView ? p : Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: AppSpacing.xs),
              Text(lp.getTranslatedText({'en': 'Teaching', 'id': 'Mengajar'}), style: TextStyle(fontSize: 12, fontWeight: !_isHomeroomView ? FontWeight.w700 : FontWeight.w500, color: !_isHomeroomView ? p : Colors.white.withValues(alpha: 0.9))),
            ])))),
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { if (!_isHomeroomView) { setState(() { _isHomeroomView = true; _isLoading = true; }); _refreshGroupedActivities().then((_) { if (mounted) setState(() => _isLoading = false); }); } },
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

  Widget _buildFilterChips(LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        if (_filterClassId != null) ...[
          _buildChip(_classList.firstWhere((c) => c['id']?.toString() == _filterClassId, orElse: () => {'name': '-'})['name'] ?? '-', () { setState(() { _filterClassId = null; _filterSubjectId = null; _filterSubjectList = []; }); _refreshGroupedActivities(); }),
          const SizedBox(width: 6),
        ],
        if (_filterSubjectId != null) ...[
          _buildChip(_filterSubjectList.firstWhere((s) => s['id']?.toString() == _filterSubjectId, orElse: () => {'name': '-'})['name'] ?? '-', () { setState(() => _filterSubjectId = null); _refreshGroupedActivities(); }),
          const SizedBox(width: 6),
        ],
        if (_filterDateOption != null) ...[
          _buildChip(_dateFilterLabel(lp), () { setState(() => _filterDateOption = null); _refreshGroupedActivities(); }),
          const SizedBox(width: 6),
        ],
        GestureDetector(
          onTap: () { setState(() { _filterClassId = null; _filterSubjectId = null; _filterDateOption = null; _filterSubjectList = []; }); _refreshGroupedActivities(); },
          child: Text(lp.getTranslatedText({'en': 'Clear All', 'id': 'Hapus Semua'}), style: TextStyle(fontSize: 12, color: ColorUtils.error600, fontWeight: FontWeight.w500)),
        ),
      ])),
    );
  }

  Widget _buildChip(String label, VoidCallback onRemove) {
    return GestureDetector(onTap: onRemove, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: _primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _primaryColor.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 12, color: _primaryColor, fontWeight: FontWeight.w500)),
        const SizedBox(width: 4),
        Icon(Icons.close, size: 14, color: _primaryColor),
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
