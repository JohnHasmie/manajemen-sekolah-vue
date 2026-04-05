// Teacher attendance management screen — redesigned to match the
// "Kegiatan Kelas" pattern: flat page with grouped cards, role toggle,
// and bottom sheets for detail/input flows.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';

import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/date_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';

import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_quick_actions_sheet.dart';

import 'package:manajemensekolah/features/attendance/data/attendance_summary_item.dart';

import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_summary_card.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_input_form.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_input_mode.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';

import 'package:manajemensekolah/core/network/dio_client.dart';

part 'teacher_attendance_screen_helpers.dart';

class AttendancePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialclassId;
  final String? initialClassName;
  final int? initialLessonHourNumber;
  final String? initialStartTime;
  final int initialTabIndex;
  final ScrollController? scrollController;
  final bool embedded;

  const AttendancePage({
    super.key,
    required this.teacher,
    this.initialDate,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialclassId,
    this.initialClassName,
    this.initialLessonHourNumber,
    this.initialStartTime,
    this.initialTabIndex = 0,
    this.embedded = false,
    this.scrollController,
  });

  @override
  AttendancePageState createState() => AttendancePageState();
}

class AttendancePageState extends ConsumerState<AttendancePage> {
  // ── Grouped summary (main screen) ──
  List<dynamic> _groupedAttendance = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreData = true;

  // ── Role toggle ──
  bool _isHomeroomView = false;
  List<dynamic> _homeroomClassesList = [];
  Map<String, dynamic>? _selectedHomeroomClass;

  // ── Teacher / class data ──
  String _teacherId = '';
  String _teacherNama = '';
  List<dynamic> _classList = [];
  List<dynamic> _subjectTeacher = [];

  // ── View toggle ──
  bool _isTimelineView = false;

  // ── Timeline data ──
  List<dynamic> _timelineAttendance = [];
  bool _timelineHasMore = true;
  bool _timelineLoadingMore = false;
  final ScrollController _timelineScrollController = ScrollController();

  // ── Filters ──
  final TextEditingController _searchController = TextEditingController();
  String? _filterClassId;
  String? _filterSubjectId;
  String? _filterDateOption;
  List<dynamic> _filterSubjectList = [];
  bool get _hasActiveFilter => _filterClassId != null || _filterSubjectId != null || _filterDateOption != null;

  // ── Input mode state (reused for embedded + input sheet) ──
  DateTime _selectedDate = DateTime.now();
  String? _selectedSubjectId;
  String? _selectedClassId;
  List<Student> _studentList = [];
  List<Student> _filteredStudentList = [];
  final Map<String, String> _attendanceStatus = {};
  bool _isLoadingInput = true;
  bool _isSubmitting = false;
  List<dynamic> _lessonHours = [];
  String? _selectedLessonHourId;
  final TextEditingController _searchControllerInput = TextEditingController();
  String? _selectedStatusFilter;
  bool _compactMode = false;

  // ── Scroll ──
  final ScrollController _scrollController = ScrollController();

  // ── Tour ──
  final GlobalKey _searchFilterKey = GlobalKey();

  Color get _primaryColor => _getPrimaryColor();

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) _selectedDate = widget.initialDate!;
    if (widget.initialSubjectId != null) _selectedSubjectId = widget.initialSubjectId;
    if (widget.initialclassId != null) _selectedClassId = widget.initialclassId;

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMoreData) _loadMoreGroupedAttendance();
      }
    });
    _timelineScrollController.addListener(() {
      if (_timelineScrollController.position.pixels >= _timelineScrollController.position.maxScrollExtent - 200) {
        if (!_timelineLoadingMore && _timelineHasMore) _loadMoreTimeline();
      }
    });

    if (widget.embedded) {
      _teacherId = widget.teacher['id']?.toString() ?? '';
      _teacherNama = widget.teacher['nama']?.toString() ?? widget.teacher['name']?.toString() ?? '';
      _loadEmbeddedData();
    } else {
      _loadUserData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchControllerInput.dispose();
    _scrollController.dispose();
    _timelineScrollController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _loadUserData() async {
    final teacherProvider = ref.read(teacherRiverpod);
    String teacherId = '';
    String teacherNama = '';

    // 1. Try teacher prop
    teacherId = widget.teacher['id']?.toString() ?? '';
    teacherNama = widget.teacher['nama']?.toString() ?? widget.teacher['name']?.toString() ?? '';

    // 2. Try TeacherProvider
    if (teacherId.isEmpty && teacherProvider.isLoaded) {
      teacherId = teacherProvider.teacherId ?? '';
      teacherNama = teacherProvider.teacherName ?? '';
    }

    // 3. Try API lookup by user
    if (teacherId.isEmpty) {
      try {
        final prefs = await getIt<ApiTeacherService>().getTeacherByUserId(teacherId);
        teacherId = prefs?['id']?.toString() ?? '';
        teacherNama = prefs?['nama']?.toString() ?? prefs?['name']?.toString() ?? '';
      } catch (_) {}
    }

    if (teacherId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _teacherId = teacherId;
    _teacherNama = teacherNama;

    await _loadInitialData(teacherId);
  }

  Future<void> _loadInitialData(String teacherId) async {
    setState(() => _isLoading = true);
    try {
      final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();

      final results = await Future.wait([
        getIt<ApiTeacherService>().getTeacherClasses(teacherId, academicYearId: academicYearId),
        _loadWithCache(
          cacheKey: 'school_lesson_hour_data',
          ttl: const Duration(hours: 24),
          apiFetcher: () => getIt<ApiScheduleService>().getJamPelajaran(),
        ),
      ]);

      if (!mounted) return;

      final classList = results[0];
      final lessonHours = results[1];

      // Detect homeroom classes (same logic as kegiatan kelas)
      final homeroomClasses = classList.where((c) => c['is_homeroom'] == true).toList();

      setState(() {
        _classList = classList;
        _lessonHours = lessonHours;
        _homeroomClassesList = homeroomClasses;
        if (homeroomClasses.isNotEmpty) {
          _selectedHomeroomClass = homeroomClasses.first as Map<String, dynamic>;
        }
      });

      await _refreshGroupedAttendance();
    } catch (e) {
      AppLogger.error('attendance', 'Error loading initial data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmbeddedData() async {
    try {
      final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();

      final [studentList, lessonHours] = await Future.wait([
        _loadWithCache(
          cacheKey: 'class_student_data_${widget.initialclassId}_$academicYearId',
          ttl: const Duration(hours: 6),
          apiFetcher: () => getIt<ApiStudentService>().getStudentByClass(
            widget.initialclassId!,
            academicYearId: academicYearId,
          ),
        ),
        _loadWithCache(
          cacheKey: 'school_lesson_hour_data',
          ttl: const Duration(hours: 24),
          apiFetcher: () => getIt<ApiScheduleService>().getJamPelajaran(),
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _studentList = studentList.map((s) => Student.fromJson(s)).toList();
        _filteredStudentList = _studentList;
        final seen = <String>{};
        _lessonHours = lessonHours.where((lh) {
          final key = '${lh['hour_number'] ?? lh['name']}_${lh['start_time']}_${lh['end_time']}';
          return seen.add(key);
        }).toList();
        for (var student in _studentList) {
          _attendanceStatus[student.id] = 'hadir';
        }
        _isLoadingInput = false;
      });

      _detectCurrentLessonHour();
    } catch (e) {
      AppLogger.error('attendance', 'Error loading embedded data: $e');
      if (mounted) setState(() => _isLoadingInput = false);
    }
  }

  // ── Grouped attendance fetch ──

  Future<void> _refreshGroupedAttendance() async {
    setState(() { _currentPage = 1; _hasMoreData = true; _groupedAttendance.clear(); _isLoading = true; });
    await _fetchGroupedAttendance();
  }

  Future<void> _loadMoreGroupedAttendance() async {
    if (_isLoadingMore || !_hasMoreData) return;
    setState(() { _currentPage++; _isLoadingMore = true; });
    await _fetchGroupedAttendance();
  }

  Future<void> _fetchGroupedAttendance() async {
    final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
    try {
      final homeroomClassId = _selectedHomeroomClass?['id']?.toString();
      final result = await AttendanceService.getTeacherAttendanceSummary(
        teacherId: _isHomeroomView ? null : _teacherId,
        classId: _isHomeroomView ? homeroomClassId : _filterClassId,
        academicYearId: academicYearId,
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
          _groupedAttendance = data;
        } else {
          final existingKeys = _groupedAttendance.map((g) => '${g['class_id']}__${g['subject_id']}').toSet();
          for (final g in data) {
            final key = '${g['class_id']}__${g['subject_id']}';
            if (!existingKeys.contains(key)) _groupedAttendance.add(g);
          }
        }
        _hasMoreData = pagination?['has_next_page'] == true;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error fetching grouped attendance: $e');
      if (mounted) setState(() { _isLoading = false; _isLoadingMore = false; });
    }
  }

  Future<void> _forceRefresh() async {
    await LocalCacheService.clearStartingWith('presence_');
    if (_isTimelineView) {
      _refreshTimeline();
    } else {
      _refreshGroupedAttendance();
    }
  }

  // ── Timeline fetch ──

  Future<void> _refreshTimeline() async {
    setState(() { _timelineHasMore = false; _timelineAttendance.clear(); _isLoading = true; });
    await _fetchTimeline();
  }

  Future<void> _loadMoreTimeline() async {
    // Summary endpoint is not paginated — no-op
  }

  Future<void> _fetchTimeline() async {
    final academicYearId = ref.read(academicYearRiverpod).selectedAcademicYear?['id']?.toString();
    try {
      final homeroomClassId = _selectedHomeroomClass?['id']?.toString();
      final result = await AttendanceService.getAttendanceSummary(
        teacherId: _isHomeroomView ? null : _teacherId,
        classId: _isHomeroomView ? homeroomClassId : _filterClassId,
        subjectId: _filterSubjectId,
        academicYearId: academicYearId,
      );
      if (!mounted) return;
      setState(() {
        _timelineAttendance = result;
        _timelineHasMore = false; // summary endpoint is not paginated
        _isLoading = false;
        _timelineLoadingMore = false;
      });
    } catch (e) {
      AppLogger.error('attendance', 'Error fetching timeline: $e');
      if (mounted) setState(() { _isLoading = false; _timelineLoadingMore = false; });
    }
  }

  void _toggleView() {
    setState(() => _isTimelineView = !_isTimelineView);
    if (_isTimelineView && _timelineAttendance.isEmpty) {
      _refreshTimeline();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION & DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════

  void _openAttendanceDetail({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, sc) => _AttendanceDetailSheet(
          teacherId: _teacherId,
          teacherNama: _teacherNama,
          classId: classId,
          className: className,
          subjectId: subjectId,
          subjectName: subjectName,
          lessonHours: _lessonHours,
          classList: _classList,
          primaryColor: _primaryColor,
          languageProvider: ref.read(languageRiverpod),
          canEdit: !_isHomeroomView,
        ),
      ),
    ).then((_) => _refreshGroupedAttendance());
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
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate900),
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

  void _showAddAttendanceFlow(LanguageProvider lp) {
    String? pickClassId;
    String? pickClassName;
    String? pickSubjectId;
    String? pickSubjectName;
    List<dynamic> pickSubjectList = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSS) => Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primaryColor, _primaryColor.withValues(alpha: 0.85)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
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
                  Text(lp.getTranslatedText({'en': 'Take Attendance', 'id': 'Ambil Presensi'}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white)),
                ]),
              ]),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Select Class', 'id': 'Pilih Kelas'}), Icons.class_outlined),
                  Wrap(spacing: 8, runSpacing: 8, children: _classList.map((c) {
                    final isSelected = pickClassId == c['id']?.toString();
                    return _buildSheetChip(c['name'] ?? c['nama'] ?? '-', isSelected, () async {
                      setSS(() { pickClassId = isSelected ? null : c['id']?.toString(); pickClassName = isSelected ? null : c['name']?.toString(); pickSubjectId = null; pickSubjectName = null; pickSubjectList = []; });
                      if (pickClassId != null) { try { final r = await dioClient.get('/class/$pickClassId/subjects'); setSS(() => pickSubjectList = r.data is List ? r.data as List : []); } catch (_) {} }
                    });
                  }).toList()),
                  const SizedBox(height: 24),
                  
                  if (pickClassId != null) ...[
                    _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Select Subject', 'id': 'Pilih Mapel'}), Icons.book_outlined),
                    if (pickSubjectList.isEmpty)
                       Text(lp.getTranslatedText({'en': 'Loading subjects...', 'id': 'Memuat mapel...'}), style: TextStyle(color: ColorUtils.slate500, fontSize: 13))
                    else
                       Wrap(spacing: 8, runSpacing: 8, children: pickSubjectList.map((s) {
                         final isSelected = pickSubjectId == s['id']?.toString();
                         return _buildSheetChip(s['name'] ?? s['nama'] ?? '-', isSelected, () => setSS(() { pickSubjectId = isSelected ? null : s['id']?.toString(); pickSubjectName = isSelected ? null : s['name']?.toString(); }));
                       }).toList()),
                     const SizedBox(height: 24),
                   ],
                ]),
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: ColorUtils.slate200)),
                boxShadow: [BoxShadow(color: ColorUtils.slate900.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(lp.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}), style: TextStyle(fontWeight: FontWeight.w600, color: ColorUtils.slate700)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: pickClassId != null && pickSubjectId != null ? () {
                        Navigator.pop(ctx);
                        _openInputSheet(classId: pickClassId!, className: pickClassName ?? '', subjectId: pickSubjectId!, subjectName: pickSubjectName ?? '');
                      } : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0,
                        disabledBackgroundColor: ColorUtils.slate200,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(lp.getTranslatedText({'en': 'Continue', 'id': 'Lanjutkan'}), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _openInputSheet({required String classId, required String className, required String subjectId, required String subjectName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) => AttendancePage(
          teacher: {'id': _teacherId, 'nama': _teacherNama},
          initialDate: DateTime.now(),
          initialSubjectId: subjectId,
          initialSubjectName: subjectName,
          initialclassId: classId,
          initialClassName: className,
          initialTabIndex: 1,
          embedded: true,
          scrollController: scrollController,
        ),
      ),
    ).then((_) => _refreshGroupedAttendance());
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
          height: MediaQuery.of(ctx).size.height * 0.7,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // Header with gradient
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_primaryColor, _primaryColor.withValues(alpha: 0.85)]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
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
                  Expanded(
                    child: Text(lp.getTranslatedText({'en': 'Filter Attendance', 'id': 'Filter Presensi'}), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: () => setSS(() { tClassId = null; tSubjectId = null; tDateOption = null; tSubjectList = []; }),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(lp.getTranslatedText({'en': 'Reset', 'id': 'Reset'}), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ]),
              ]),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Class list
                  _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}), Icons.class_outlined),
                  Wrap(spacing: 8, runSpacing: 8, children: _classList.map((c) {
                    final isSelected = tClassId == c['id']?.toString();
                    return _buildSheetChip(c['name'] ?? c['nama'] ?? '-', isSelected, () async {
                      setSS(() { tClassId = isSelected ? null : c['id']?.toString(); tSubjectId = null; tSubjectList = []; });
                      if (tClassId != null) { try { final r = await dioClient.get('/class/$tClassId/subjects'); setSS(() => tSubjectList = r.data is List ? r.data as List : []); } catch (_) {} }
                    });
                  }).toList()),
                  const SizedBox(height: 24),
                  
                  // Subject list
                  if (tSubjectList.isNotEmpty || tClassId != null) ...[
                    _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Subject', 'id': 'Mapel'}), Icons.book_outlined),
                    if (tSubjectList.isEmpty)
                       Text(lp.getTranslatedText({'en': 'Loading subjects...', 'id': 'Memuat mapel...'}), style: TextStyle(color: ColorUtils.slate500, fontSize: 13))
                    else
                      Wrap(spacing: 8, runSpacing: 8, children: tSubjectList.map((s) {
                        final isSelected = tSubjectId == s['id']?.toString();
                        return _buildSheetChip(s['name'] ?? s['nama'] ?? '-', isSelected, () => setSS(() => tSubjectId = isSelected ? null : s['id']?.toString()));
                      }).toList()),
                    const SizedBox(height: 24),
                  ],
                  
                  // Date filter chips
                  _buildSheetSectionHeader(lp.getTranslatedText({'en': 'Time Range', 'id': 'Rentang Waktu'}), Icons.calendar_today_rounded),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _buildSheetChip(lp.getTranslatedText({'en': 'Today', 'id': 'Hari Ini'}), tDateOption == 'today', () => setSS(() => tDateOption = tDateOption == 'today' ? null : 'today')),
                    _buildSheetChip(lp.getTranslatedText({'en': 'This Week', 'id': 'Minggu Ini'}), tDateOption == 'week', () => setSS(() => tDateOption = tDateOption == 'week' ? null : 'week')),
                    _buildSheetChip(lp.getTranslatedText({'en': 'This Month', 'id': 'Bulan Ini'}), tDateOption == 'month', () => setSS(() => tDateOption = tDateOption == 'month' ? null : 'month')),
                  ]),
                  const SizedBox(height: 20),
                ]),
              ),
            ),

            // Apply button (Sticky footer)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: ColorUtils.slate200)),
                boxShadow: [BoxShadow(color: ColorUtils.slate900.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: SafeArea(
                top: false,
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => AppNavigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: ColorUtils.slate300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(lp.getTranslatedText({'en': 'Cancel', 'id': 'Batal'}), style: TextStyle(fontWeight: FontWeight.w600, color: ColorUtils.slate700)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() { _filterClassId = tClassId; _filterSubjectId = tSubjectId; _filterDateOption = tDateOption; _filterSubjectList = tSubjectList; });
                        Navigator.pop(ctx);
                        _forceRefresh();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _primaryColor, foregroundColor: Colors.white, elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(lp.getTranslatedText({'en': 'Apply Filter', 'id': 'Terapkan Filter'}), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INPUT MODE HELPERS (reused by embedded mode)
  // ═══════════════════════════════════════════════════════════════════════════

  void _detectCurrentLessonHour() {
    if (widget.initialLessonHourNumber != null) {
      for (var lh in _lessonHours) {
        final hourNum = lh['hour_number'] ?? lh['jam_ke'];
        if (hourNum?.toString() == widget.initialLessonHourNumber.toString()) {
          setState(() => _selectedLessonHourId = lh['id']?.toString());
          return;
        }
      }
    }
    // Auto-detect by current time
    for (var lh in _lessonHours) {
      final startTime = (lh['start_time'] ?? lh['jam_mulai'])?.toString() ?? '';
      final endTime = (lh['end_time'] ?? lh['jam_selesai'])?.toString() ?? '';
      if (_isWithinScheduleTime(startTime, endTime)) {
        setState(() => _selectedLessonHourId = lh['id']?.toString());
        return;
      }
    }
  }

  void _detectCurrentSchedule() {
    // Stub — auto-detect is handled by embedded params
  }

  void _filterStudentsByClass(String? classId) {
    setState(() { _selectedClassId = classId; _filterStudents(); });
  }

  void _filterStudents() {
    final searchTerm = _searchControllerInput.text.toLowerCase();
    setState(() {
      _filteredStudentList = _studentList.where((student) {
        final matchesSearch = searchTerm.isEmpty || student.name.toLowerCase().contains(searchTerm) || student.studentNumber.toLowerCase().contains(searchTerm);
        final matchesStatus = _selectedStatusFilter == null || (_attendanceStatus[student.id] ?? 'hadir') == _selectedStatusFilter;
        final matchesClass = _selectedClassId == null || student.classId == _selectedClassId;
        return matchesSearch && matchesStatus && matchesClass;
      }).toList();
    });
  }

  Future<void> _loadSubjectsByClass(String? classId) async {
    if (classId == null) return;
    try {
      final subjects = await _getSubjectByTeacher(_teacherId, classId: classId);
      if (mounted) setState(() => _subjectTeacher = subjects);
    } catch (_) {}
  }

  void _showQuickActionsSheet(LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => AttendanceQuickActionsSheet(
        languageProvider: languageProvider,
        onStatusSelected: (status) {
          setState(() { for (var student in _filteredStudentList) { _attendanceStatus[student.id] = status; } });
        },
      ),
    );
  }

  Future<void> _submitAttendance() async {
    final languageProvider = ref.read(languageRiverpod);
    final teacherId = widget.teacher['id'];
    if (teacherId == null) {
      SnackBarUtils.showError(context, languageProvider.getTranslatedText({'en': 'Invalid teacher data. Please login again.', 'id': 'Data guru tidak valid. Silakan login ulang.'}));
      return;
    }
    if (_selectedSubjectId == null) {
      SnackBarUtils.showError(context, languageProvider.getTranslatedText({'en': 'Please select a subject first', 'id': 'Pilih mata pelajaran terlebih dahulu'}));
      return;
    }
    if (_filteredStudentList.isEmpty) {
      SnackBarUtils.showError(context, languageProvider.getTranslatedText({'en': 'No students to save', 'id': 'Tidak ada siswa untuk disimpan'}));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final date = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final attendances = _filteredStudentList.map((student) {
        final status = _attendanceStatus[student.id] ?? 'hadir';
        return {'student_id': student.id, 'status': _mapStatusToBackend(status), 'notes': ''};
      }).toList();

      final result = await AttendanceService.createBulkAttendance(
        teacherId: teacherId.toString(), subjectId: _selectedSubjectId!,
        classId: _filteredStudentList.first.classId ?? _selectedClassId ?? '',
        date: date, lessonHourId: _selectedLessonHourId, attendances: attendances,
      );

      if (!mounted) return;
      final successCount = result['success'] ?? 0;
      final failedCount = result['failed'] ?? 0;

      if (failedCount == 0) {
        SnackBarUtils.showSuccess(context, languageProvider.getTranslatedText({'en': 'Attendance saved for $successCount students', 'id': 'Absensi disimpan untuk $successCount siswa'}));
        if (widget.embedded) { if (mounted) Navigator.of(context).pop(); return; }
      } else {
        SnackBarUtils.showWarning(context, languageProvider.getTranslatedText({'en': '$successCount saved, $failedCount failed', 'id': '$successCount berhasil, $failedCount gagal'}));
      }
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

    // ── Embedded mode (opened from schedule card) ──
    if (widget.embedded) {
      return GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          ),
          child: Column(children: [
            // Gradient header
            Container(
              decoration: BoxDecoration(
                gradient: _getCardGradient(),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(children: [
                Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                  child: Row(children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      languageProvider.getTranslatedText({'en': 'Take Attendance', 'id': 'Ambil Presensi'}),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    )),
                    // Compact/descriptive toggle
                    GestureDetector(
                      onTap: () => setState(() => _compactMode = !_compactMode),
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                        child: Icon(_compactMode ? Icons.view_agenda_outlined : Icons.density_small_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close, color: Colors.white, size: 18)),
                    ),
                  ]),
                ),
              ]),
            ),
            Expanded(child: _buildInputMode()),
          ]),
        ),
      );
    }

    // ── Main screen ──
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: ColorUtils.slate50,
        body: Column(children: [
          _buildHeader(languageProvider),
          Expanded(child: _isTimelineView ? _buildTimelineBody(languageProvider) : _buildBody(languageProvider)),
        ]),
        floatingActionButton: _isHomeroomView ? null : FloatingActionButton(
          onPressed: () => _showAddAttendanceFlow(languageProvider),
          backgroundColor: _primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lp) {
    final p = _primaryColor;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + AppSpacing.lg, left: AppSpacing.lg, right: AppSpacing.lg, bottom: AppSpacing.lg),
      decoration: BoxDecoration(gradient: _getCardGradient()),
      child: Column(children: [
        // Top row: back + title + toggle view
        Row(children: [
          GestureDetector(
            onTap: () => AppNavigator.pop(context),
            child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back, color: Colors.white, size: 20)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lp.getTranslatedText({'en': 'Attendance', 'id': 'Presensi'}), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(
              _isHomeroomView && _selectedHomeroomClass != null
                  ? lp.getTranslatedText({'en': 'Homeroom class attendance overview', 'id': 'Rekap presensi kelas perwalian'})
                  : lp.getTranslatedText({'en': 'Track and manage student attendance', 'id': 'Pantau dan kelola presensi siswa'}),
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ])),
          // Timeline toggle
          GestureDetector(
            onTap: _toggleView,
            child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Icon(_isTimelineView ? Icons.grid_view_rounded : Icons.view_list_rounded, color: Colors.white, size: 18)),
          ),
        ]),
        // Role toggle — only show when teacher has homeroom classes
        if (_homeroomClassesList.isNotEmpty) ...[const SizedBox(height: AppSpacing.md), _buildRoleToggle(lp)],
        const SizedBox(height: AppSpacing.md),
        // Search + filter row
        Row(children: [
          Expanded(child: Container(
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: TextField(
                key: _searchFilterKey,
                controller: _searchController, textAlignVertical: TextAlignVertical.center,
                style: TextStyle(color: ColorUtils.slate800, fontSize: 13),
                decoration: InputDecoration(isDense: true, hintText: lp.getTranslatedText({'en': 'Search class or subject...', 'id': 'Cari kelas atau mapel...'}), hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                onSubmitted: (_) { _refreshGroupedAttendance(); FocusScope.of(context).unfocus(); },
              )),
              Container(margin: const EdgeInsets.only(right: 4), child: IconButton(icon: Icon(Icons.search, color: p, size: 20), onPressed: () { _refreshGroupedAttendance(); FocusScope.of(context).unfocus(); })),
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
                        _buildChip(_classList.firstWhere((c) => c['id']?.toString() == _filterClassId, orElse: () => {'name': '-'})['name'] ?? '-', () { setState(() { _filterClassId = null; _filterSubjectId = null; _filterSubjectList = []; }); _refreshGroupedAttendance(); }),
                        const SizedBox(width: 6),
                      ],
                      if (_filterSubjectId != null) ...[
                        _buildChip(_filterSubjectList.firstWhere((s) => s['id']?.toString() == _filterSubjectId, orElse: () => {'name': '-'})['name'] ?? '-', () { setState(() { _filterSubjectId = null; }); _refreshGroupedAttendance(); }),
                        const SizedBox(width: 6),
                      ],
                      if (_filterDateOption != null) ...[
                        _buildChip(
                          _filterDateOption == 'today' ? lp.getTranslatedText({'en': 'Today', 'id': 'Hari ini'}) : _filterDateOption == 'week' ? lp.getTranslatedText({'en': 'This Week', 'id': 'Minggu ini'}) : lp.getTranslatedText({'en': 'This Month', 'id': 'Bulan ini'}),
                          () { setState(() { _filterDateOption = null; }); _refreshGroupedAttendance(); }),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                InkWell(
                  onTap: () { setState(() { _filterClassId = null; _filterSubjectId = null; _filterDateOption = null; _filterSubjectList = []; }); _refreshGroupedAttendance(); },
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
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { if (_isHomeroomView) { setState(() { _isHomeroomView = false; _isLoading = true; }); _forceRefresh(); } },
            child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.person_outline_rounded, size: 16, color: !_isHomeroomView ? p : Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: AppSpacing.xs),
              Text(lp.getTranslatedText({'en': 'Teaching', 'id': 'Mengajar'}), style: TextStyle(fontSize: 12, fontWeight: !_isHomeroomView ? FontWeight.w700 : FontWeight.w500, color: !_isHomeroomView ? p : Colors.white.withValues(alpha: 0.9))),
            ])))),
          Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () { if (!_isHomeroomView) { setState(() { _isHomeroomView = true; _isLoading = true; }); _forceRefresh(); } },
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
      child: _groupedAttendance.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              Center(child: Column(children: [
                Icon(Icons.fact_check_outlined, size: 56, color: ColorUtils.slate300),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isNotEmpty || _hasActiveFilter
                      ? lp.getTranslatedText({'en': 'No attendance matches your filter', 'id': 'Tidak ada presensi sesuai filter'})
                      : lp.getTranslatedText({'en': 'No attendance yet', 'id': 'Belum ada presensi'}),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColorUtils.slate600), textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(lp.getTranslatedText({'en': 'Pull down to refresh', 'id': 'Tarik ke bawah untuk memuat ulang'}), style: TextStyle(fontSize: 12, color: ColorUtils.slate400)),
              ])),
            ])
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: _groupedAttendance.length + (_isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _groupedAttendance.length) {
                  return Padding(padding: const EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: _primaryColor)));
                }
                final g = _groupedAttendance[index];
                return _AttendanceGroupCard(group: g, primaryColor: _primaryColor, languageProvider: lp, onTap: () => _openAttendanceDetail(
                  classId: g['class_id']?.toString() ?? '', className: g['class_name']?.toString() ?? '',
                  subjectId: g['subject_id']?.toString() ?? '', subjectName: g['subject_name']?.toString() ?? '',
                ));
              },
            ),
    );
  }

  Widget _buildInputMode() {
    final languageProvider = ref.watch(languageRiverpod);
    return AttendanceInputMode(
      isLoadingInput: _isLoadingInput,
      inputFormWidget: AttendanceInputForm(
        selectedDate: _selectedDate,
        selectedLessonHourId: _selectedLessonHourId,
        lessonHours: _lessonHours,
        selectedClassId: _selectedClassId,
        classList: _classList,
        selectedSubjectId: _selectedSubjectId,
        subjectTeacher: _subjectTeacher,
        primaryColor: _primaryColor,
        languageProvider: languageProvider,
        embedded: widget.embedded,
        initialClassName: widget.initialClassName,
        initialSubjectName: widget.initialSubjectName,
        initialLessonHourNumber: widget.initialLessonHourNumber,
        onDatePicked: (picked) { setState(() { _selectedDate = picked; _detectCurrentSchedule(); }); },
        onLessonHourChanged: (value) { setState(() => _selectedLessonHourId = value); },
        onClassChanged: (value) { setState(() { _selectedClassId = value; _filterStudentsByClass(value); }); _loadSubjectsByClass(value); },
        onSubjectChanged: (value) { setState(() => _selectedSubjectId = value); },
        onQuickActionsPressed: () => _showQuickActionsSheet(languageProvider),
      ),
      selectedSubjectId: _selectedSubjectId,
      filteredStudentList: _filteredStudentList,
      attendanceStatus: _attendanceStatus,
      isSubmitting: _isSubmitting,
      primaryColor: _primaryColor,
      searchController: _searchControllerInput,
      onSearchChanged: _filterStudents,
      onQuickActionsPressed: () => _showQuickActionsSheet(languageProvider),
      onStatusChanged: (studentId, status) { setState(() => _attendanceStatus[studentId] = status); },
      onSubmit: _submitAttendance,
      scrollController: widget.scrollController,
      compactMode: _compactMode,
    );
  }

  Widget _buildTimelineBody(LanguageProvider lp) {
    if (_isLoading) return SkeletonListLoading(itemCount: 5, infoTagCount: 1);

    return RefreshIndicator(
      onRefresh: _forceRefresh,
      color: _primaryColor,
      child: _timelineAttendance.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.25),
              Center(child: Column(children: [
                Icon(Icons.fact_check_outlined, size: 56, color: ColorUtils.slate300),
                const SizedBox(height: 16),
                Text(lp.getTranslatedText({'en': 'No attendance records', 'id': 'Belum ada data presensi'}), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ColorUtils.slate600)),
              ])),
            ])
          : ListView.builder(
              controller: _timelineScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: _timelineAttendance.length + (_timelineLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _timelineAttendance.length) {
                  return Padding(padding: const EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: _primaryColor)));
                }
                final r = _timelineAttendance[index];
                return _AttendanceTimelineCard(record: r, primaryColor: _primaryColor, languageProvider: lp, onTap: () => _openAttendanceDetail(
                  classId: (r['class_id'] ?? '').toString(), className: (r['class_name'] ?? r['subject_name'] ?? '').toString(),
                  subjectId: (r['subject_id'] ?? '').toString(), subjectName: (r['subject_name'] ?? '').toString(),
                ));
              },
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED DATE FORMATTER
// ═══════════════════════════════════════════════════════════════════════════════

String _fmtFullDate(String? d) {
  if (d == null) return '-';
  final dt = DateTime.tryParse(d);
  if (dt == null) return d;
  return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);
}

// ═══════════════════════════════════════════════════════════════════════════════
// GROUP CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _AttendanceGroupCard extends StatelessWidget {
  final dynamic group;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onTap;

  const _AttendanceGroupCard({required this.group, required this.primaryColor, required this.languageProvider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cn = group['class_name']?.toString() ?? '-';
    final sn = group['subject_name']?.toString() ?? '-';
    final totalSessions = group['total_sessions'] ?? 0;
    final avgPct = (group['avg_present_pct'] ?? 0).toDouble();
    final latest = (group['latest_records'] as List?) ?? [];
    final pctColor = avgPct >= 80 ? ColorUtils.success600 : (avgPct >= 60 ? ColorUtils.warning600 : ColorUtils.error600);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: ColorUtils.slate200), boxShadow: ColorUtils.corporateShadow(elevation: 1.0)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row: icon + class/subject + percentage ring + count
          Row(children: [
            // Circular percentage indicator
            SizedBox(
              width: 44, height: 44,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(width: 44, height: 44, child: CircularProgressIndicator(
                  value: avgPct / 100, strokeWidth: 4, backgroundColor: ColorUtils.slate100,
                  color: pctColor,
                )),
                Text('${avgPct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: pctColor)),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Kelas: $cn', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ColorUtils.slate900), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(sn, style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w600)),
            ])),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$totalSessions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primaryColor)),
              Text(languageProvider.getTranslatedText({'en': 'meets', 'id': 'pertemuan'}), style: TextStyle(fontSize: 8, color: primaryColor, fontWeight: FontWeight.w500)),
            ])),
          ]),
          // Latest sessions preview
          if (latest.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: ColorUtils.slate50, borderRadius: BorderRadius.circular(10)), child: Column(children: latest.asMap().entries.map((e) {
              final r = e.value;
              final present = r['present'] ?? 0;
              final total = r['total'] ?? 0;
              return Padding(padding: EdgeInsets.only(top: e.key > 0 ? 6 : 0), child: Row(children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: ColorUtils.slate400),
                const SizedBox(width: 6),
                Expanded(child: Text(_fmtFullDate(r['date']?.toString()), style: TextStyle(fontSize: 11, color: ColorUtils.slate600, fontWeight: FontWeight.w500))),
                const SizedBox(width: 8),
                Text('$present/$total', style: TextStyle(fontSize: 12, color: present == total ? ColorUtils.success600 : ColorUtils.warning600, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Text(languageProvider.getTranslatedText({'en': 'present', 'id': 'hadir'}), style: TextStyle(fontSize: 10, color: ColorUtils.slate400)),
              ]));
            }).toList())),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.update_rounded, size: 14, color: ColorUtils.slate400),
            const SizedBox(width: 4),
            Expanded(child: Text('${languageProvider.getTranslatedText({'en': 'Latest', 'id': 'Terbaru'})}: ${_fmtFullDate(group['latest_date']?.toString())}', style: TextStyle(fontSize: 11, color: ColorUtils.slate400), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
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

// ═══════════════════════════════════════════════════════════════════════════════
// TIMELINE CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _AttendanceTimelineCard extends StatelessWidget {
  final dynamic record;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onTap;

  const _AttendanceTimelineCard({required this.record, required this.primaryColor, required this.languageProvider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cn = record['class_name']?.toString() ?? '-';
    final sn = record['subject_name']?.toString() ?? record['mata_pelajaran_nama']?.toString() ?? '-';
    final dateStr = _fmtFullDate(record['date']?.toString());
    final present = int.tryParse(record['present']?.toString() ?? record['present_count']?.toString() ?? '0') ?? 0;
    final total = int.tryParse(record['total_students']?.toString() ?? '0') ?? 0;
    final lhName = record['lesson_hour_name']?.toString();
    final pctColor = total > 0 && present / total >= 0.8 ? ColorUtils.success600 : (total > 0 && present / total >= 0.6 ? ColorUtils.warning600 : ColorUtils.error600);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12), child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: ColorUtils.slate200)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Percentage ring
          SizedBox(
            width: 40, height: 40,
            child: Stack(alignment: Alignment.center, children: [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(
                value: total > 0 ? present / total : 0, strokeWidth: 3.5, backgroundColor: ColorUtils.slate100, color: pctColor,
              )),
              Text(total > 0 ? '${(present / total * 100).toStringAsFixed(0)}%' : '-', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: pctColor)),
            ]),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(dateStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ColorUtils.slate800), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text('$present/$total', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: pctColor)),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)),
                child: Text('$cn · $sn', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: primaryColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (lhName != null && lhName.isNotEmpty) ...[
                const SizedBox(width: 6),
                Icon(Icons.access_time_rounded, size: 10, color: ColorUtils.slate400),
                const SizedBox(width: 2),
                Text(lhName, style: TextStyle(fontSize: 10, color: ColorUtils.slate500)),
              ],
            ]),
          ])),
        ]),
      ))),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DETAIL SHEET (session list for a class+subject)
// ═══════════════════════════════════════════════════════════════════════════════

class _AttendanceDetailSheet extends StatefulWidget {
  final String teacherId;
  final String teacherNama;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final List<dynamic> lessonHours;
  final List<dynamic> classList;
  final Color primaryColor;
  final bool canEdit;
  final LanguageProvider languageProvider;

  const _AttendanceDetailSheet({
    required this.teacherId, required this.teacherNama,
    required this.classId, required this.className,
    required this.subjectId, required this.subjectName,
    required this.lessonHours, required this.classList,
    required this.primaryColor, required this.languageProvider,
    this.canEdit = true,
  });

  @override
  State<_AttendanceDetailSheet> createState() => _AttendanceDetailSheetState();
}

class _AttendanceDetailSheetState extends State<_AttendanceDetailSheet> {
  List<AttendanceSummaryItem> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final data = await AttendanceService.getAttendanceSummary(
        teacherId: widget.teacherId,
        classId: widget.classId,
        subjectId: widget.subjectId,
      );
      if (!mounted) return;
      final sessions = data.map((record) {
        return AttendanceSummaryItem(
          subjectId: (record['subject_id'] ?? '').toString(),
          subjectName: record['subject_name'] ?? widget.subjectName,
          date: AppDateUtils.parseApiDate(record['date']?.toString() ?? '') ?? DateTime.now(),
          totalStudent: int.tryParse(record['total_students']?.toString() ?? '0') ?? 0,
          present: int.tryParse(record['present']?.toString() ?? '0') ?? 0,
          absent: int.tryParse(record['absent']?.toString() ?? '0') ?? 0,
          classId: (record['class_id'] ?? '').toString(),
          className: record['class_name'] ?? widget.className,
          lessonHourId: (record['lesson_hour_id'] ?? '').toString(),
          lessonHourName: record['lesson_hour_name'] ?? '',
        );
      }).toList()..sort((a, b) => b.date.compareTo(a.date));
      setState(() { _sessions = sessions; _isLoading = false; });
    } catch (e) {
      AppLogger.error('attendance', 'Error loading sessions: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        // Header
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [widget.primaryColor, widget.primaryColor.withValues(alpha: 0.85)]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
              child: Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.fact_check_outlined, color: Colors.white, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Kelas: ${widget.className}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(widget.subjectName, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                ])),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.close, color: Colors.white, size: 18)),
                ),
              ]),
            ),
          ]),
        ),
        // Session list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _sessions.isEmpty
                  ? Center(child: Text('No attendance records', style: TextStyle(color: ColorUtils.slate400)))
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      color: widget.primaryColor,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final s = _sessions[index];
                          return AttendanceSummaryCard(
                            summary: s,
                            primaryColor: widget.primaryColor,
                            languageProvider: widget.languageProvider,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherAttendanceDetailPage(
                              subjectId: s.subjectId, subjectName: s.subjectName,
                              date: s.date, classId: s.classId ?? '', className: s.className ?? '',
                              teacher: {'id': widget.teacherId, 'nama': widget.teacherNama},
                              lessonHourId: s.lessonHourId, lessonHourName: s.lessonHourName,
                            ))),
                            onDelete: () async {
                              if (!widget.canEdit) return;
                              try {
                                await AttendanceService.deleteAttendanceSummary(
                                  teacherId: widget.teacherId, subjectId: s.subjectId,
                                  date: DateFormat('yyyy-MM-dd').format(s.date),
                                  classId: s.classId, lessonHourId: s.lessonHourId,
                                );
                                _loadSessions();
                              } catch (e) {
                                if (context.mounted) SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
                              }
                            },
                          );
                        },
                      ),
                    ),
        ),
        // FAB-like button for taking attendance
        if (widget.canEdit)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => DraggableScrollableSheet(
                        initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.96, expand: false,
                        builder: (ctx, sc) => AttendancePage(
                          teacher: {'id': widget.teacherId, 'nama': widget.teacherNama},
                          initialDate: DateTime.now(),
                          initialSubjectId: widget.subjectId,
                          initialSubjectName: widget.subjectName,
                          initialclassId: widget.classId,
                          initialClassName: widget.className,
                          initialTabIndex: 1,
                          embedded: true,
                          scrollController: sc,
                        ),
                      ),
                    ).then((_) => _loadSessions());
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Ambil Presensi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: widget.primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
