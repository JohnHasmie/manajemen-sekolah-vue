// Teacher attendance management screen — redesigned
// to match the "Kegiatan Kelas" pattern: flat page
// with grouped cards, role toggle, and bottom sheets
// for detail/input flows.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';

import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_data_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_add_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_filter_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_shared_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_input_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_ui_embedded_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_ui_body_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_ui_builder_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_navigation_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_filter_chips_mixin.dart';

class AttendancePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialclassId;
  final String? initialClassName;
  final int? initialLessonHourNumber;

  /// Exact `lesson_hour_id` UUID of the schedule slot the user came
  /// from. Each (day, hour_number) tuple has its own UUID, so passing
  /// just the [initialLessonHourNumber] would let the hydration logic
  /// pick whatever day's hour_number matched first — typically not the
  /// one the user tapped — and lock the form to that other day's
  /// already-saved records, blocking new entry for the actual day.
  final String? initialLessonHourId;

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
    this.initialLessonHourId,
    this.initialStartTime,
    this.initialTabIndex = 0,
    this.embedded = false,
    this.scrollController,
  });

  @override
  AttendancePageState createState() => AttendancePageState();
}

class AttendancePageState extends ConsumerState<AttendancePage>
    with
        AttendanceDataMixin,
        AttendanceDialogSharedMixin,
        AttendanceDialogAddMixin,
        AttendanceDialogFilterMixin,
        AttendanceDialogMixin,
        AttendanceInputMixin,
        AttendanceUIEmbeddedMixin,
        AttendanceUIBodyMixin,
        AttendanceUIBuilderMixin,
        AttendanceNavigationMixin,
        AttendanceFilterChipsMixin {
  // ── Internal state fields ──
  List<dynamic> _groupedAttendance = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _isHomeroomView = false;
  List<dynamic> _homeroomClassesList = [];
  Map<String, dynamic>? _selectedHomeroomClass;
  String _teacherId = '';
  String _teacherNama = '';
  List<dynamic> _classList = [];
  List<dynamic> _subjectTeacher = [];
  bool _isTimelineView = false;
  List<dynamic> _timelineAttendance = [];
  bool _timelineHasMore = true;
  bool _timelineLoadingMore = false;
  final ScrollController _timelineSc = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  String? _filterClassId;
  String? _filterSubjectId;
  String? _filterDateOption;
  List<dynamic> _filterSubjectList = [];
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
  final TextEditingController _searchCtrlInput = TextEditingController();
  String? _selectedStatusFilter;
  bool _compactMode = false;
  final ScrollController _scrollController = ScrollController();

  @override
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  // ═════════════════════════════════════════
  // MIXIN BRIDGE — State accessors
  // ═════════════════════════════════════════

  @override
  String get teacherId => _teacherId;
  @override
  set teacherId(String v) => _teacherId = v;
  @override
  String get teacherNama => _teacherNama;
  @override
  set teacherNama(String v) => _teacherNama = v;
  @override
  List<dynamic> get classList => _classList;
  @override
  set classList(List<dynamic> v) => _classList = v;
  @override
  List<dynamic> get lessonHours => _lessonHours;
  @override
  set lessonHours(List<dynamic> v) => _lessonHours = v;
  @override
  List<dynamic> get homeroomClassesList => _homeroomClassesList;
  @override
  set homeroomClassesList(List<dynamic> v) => _homeroomClassesList = v;
  @override
  Map<String, dynamic>? get selectedHomeroomClass => _selectedHomeroomClass;
  @override
  set selectedHomeroomClass(Map<String, dynamic>? v) =>
      _selectedHomeroomClass = v;
  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool v) => _isLoading = v;
  @override
  bool get isLoadingMore => _isLoadingMore;
  @override
  set isLoadingMore(bool v) => _isLoadingMore = v;
  @override
  int get currentPage => _currentPage;
  @override
  set currentPage(int v) => _currentPage = v;
  @override
  bool get hasMoreData => _hasMoreData;
  @override
  set hasMoreData(bool v) => _hasMoreData = v;
  @override
  List<dynamic> get groupedAttendance => _groupedAttendance;
  @override
  set groupedAttendance(List<dynamic> v) => _groupedAttendance = v;
  @override
  bool get isHomeroomView => _isHomeroomView;
  @override
  set isHomeroomView(bool v) => _isHomeroomView = v;
  @override
  String? get filterClassId => _filterClassId;
  @override
  set filterClassId(String? v) => _filterClassId = v;
  @override
  String? get filterSubjectId => _filterSubjectId;
  @override
  set filterSubjectId(String? v) => _filterSubjectId = v;
  @override
  String? get filterDateOption => _filterDateOption;
  @override
  set filterDateOption(String? v) => _filterDateOption = v;
  @override
  List<dynamic> get filterSubjectList => _filterSubjectList;
  @override
  set filterSubjectList(List<dynamic> v) => _filterSubjectList = v;
  @override
  TextEditingController get searchController => _searchCtrl;
  @override
  List<dynamic> get timelineAttendance => _timelineAttendance;
  @override
  set timelineAttendance(List<dynamic> v) => _timelineAttendance = v;
  @override
  bool get timelineHasMore => _timelineHasMore;
  @override
  set timelineHasMore(bool v) => _timelineHasMore = v;
  @override
  bool get timelineLoadingMore => _timelineLoadingMore;
  @override
  set timelineLoadingMore(bool v) => _timelineLoadingMore = v;
  @override
  bool get isTimelineView => _isTimelineView;
  @override
  set isTimelineView(bool v) => _isTimelineView = v;
  @override
  List<Student> get studentList => _studentList;
  @override
  set studentList(List<Student> v) => _studentList = v;
  @override
  List<Student> get filteredStudentList => _filteredStudentList;
  @override
  set filteredStudentList(List<Student> v) => _filteredStudentList = v;
  @override
  Map<String, String> get attendanceStatus => _attendanceStatus;
  @override
  bool get isLoadingInput => _isLoadingInput;
  @override
  set isLoadingInput(bool v) => _isLoadingInput = v;
  @override
  DateTime get selectedDate => _selectedDate;
  @override
  String? get selectedSubjectId => _selectedSubjectId;
  @override
  String? get selectedClassId => _selectedClassId;
  @override
  String? get selectedLessonHourId => _selectedLessonHourId;
  @override
  String? get selectedStatusFilter => _selectedStatusFilter;
  @override
  bool get isSubmitting => _isSubmitting;
  @override
  bool get compactMode => _compactMode;
  @override
  TextEditingController get searchInputController => _searchCtrlInput;
  @override
  ScrollController get scrollController => _scrollController;
  @override
  ScrollController get timelineScrollController => _timelineSc;
  @override
  ScrollController? get embeddedScrollController => widget.scrollController;
  @override
  List<dynamic> get subjectTeacher => _subjectTeacher;
  @override
  bool get hasActiveFilter =>
      _filterClassId != null ||
      _filterSubjectId != null ||
      _filterDateOption != null;

  @override
  void setSelectedDate(DateTime v) => setState(() => _selectedDate = v);
  @override
  void setSelectedSubjectId(String? v) =>
      setState(() => _selectedSubjectId = v);
  @override
  void setSelectedClassId(String? v) => setState(() => _selectedClassId = v);
  @override
  void setSelectedLessonHourId(String? v) =>
      setState(() => _selectedLessonHourId = v);
  @override
  void setCompactMode(bool v) => setState(() => _compactMode = v);

  // Error state for inline error display with retry
  String? _attendanceErrorMessage;
  @override
  String? get attendanceErrorMessage => _attendanceErrorMessage;
  @override
  void setAttendanceError(String? message) {
    if (mounted) setState(() => _attendanceErrorMessage = message);
  }

  // ═════════════════════════════════════════
  // SHARED COMPONENT INTEGRATION
  // ═════════════════════════════════════════
  // Filter chips building moved to AttendanceFilterChipsMixin

  // Bridge methods for AttendanceInputMixin (public abstract declarations)
  @override
  DateTime getInputSelectedDate() => _selectedDate;
  @override
  String? getInputSelectedSubjectId() => _selectedSubjectId;
  @override
  String? getInputSelectedLessonHourId() => _selectedLessonHourId;
  @override
  void setInputSelectedLessonHourId(String? v) =>
      setState(() => _selectedLessonHourId = v);
  @override
  void setInputIsSubmitting(bool v) => setState(() => _isSubmitting = v);
  @override
  String? getInputSelectedStatusFilter() => _selectedStatusFilter;
  @override
  String getInputSearchText() => _searchCtrlInput.text;
  @override
  void setInputSubjectTeacher(List<dynamic> v) =>
      setState(() => _subjectTeacher = v);

  // ═════════════════════════════════════════
  // LIFECYCLE
  // ═════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _applyInitialParams();
    _attachScrollListeners();
    _loadViewPref();
    if (widget.embedded) {
      final model = Teacher.fromJson(widget.teacher);
      _teacherId = model.id;
      _teacherNama = model.name;
      loadEmbeddedData();
    } else {
      loadUserData();
    }
  }

  void _applyInitialParams() {
    if (widget.initialDate != null) _selectedDate = widget.initialDate!;
    if (widget.initialSubjectId != null) {
      _selectedSubjectId = widget.initialSubjectId;
    }
    if (widget.initialclassId != null) _selectedClassId = widget.initialclassId;
  }

  void _attachScrollListeners() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _hasMoreData) {
          loadMoreGroupedAttendance();
        }
      }
    });
  }

  Future<void> _loadViewPref() async {
    try {
      final c = await LocalCacheService.load('absensi_view_preference');
      if (c is Map && mounted) {
        setState(() => _isTimelineView = c['is_timeline'] ?? false);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchCtrlInput.dispose();
    _scrollController.dispose();
    _timelineSc.dispose();
    super.dispose();
  }

  // ═════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return widget.embedded ? buildEmbedded(lp) : buildMainScreen(lp);
  }
}
