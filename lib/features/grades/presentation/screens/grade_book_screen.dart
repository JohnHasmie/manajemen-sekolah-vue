// Grade book table screen -- displays and edits student grades.
// Refactored with 5 mixins to keep main class under 400 lines.
import 'package:manajemensekolah/core/constants/grade_constants.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/controllers/grade_book_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_book_content_widget.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_book_data_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_score_formatter_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_book_dialogs_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_book_edit_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_book_navigation_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_book_export_mixin.dart';

/// Grade book page -- displays and edits student grades.
class GradeBookPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final Map<String, dynamic> classData;
  final VoidCallback? onBack;

  const GradeBookPage({
    super.key,
    required this.teacher,
    required this.subject,
    required this.classData,
    this.onBack,
  });

  @override
  GradeBookPageState createState() => GradeBookPageState();
}

/// State with 7 mixins: tour, data, formatter, dialogs, edit, navigation, export.
class GradeBookPageState extends ConsumerState<GradeBookPage>
    with
        GradeBookDataMixin,
        GradeScoreFormatterMixin,
        GradeBookDialogsMixin,
        GradeBookEditMixin,
        GradeBookNavigationMixin,
        GradeBookExportMixin {
  // State
  List<Student> _studentList = [];
  List<Student> _filteredStudentList = [];
  List<Map<String, dynamic>> _gradeList = [];
  final List<String> _allGradeTypeList = GradeConstants.allTypes;
  List<String> _filteredGradeTypeList = [];
  bool _isLoading = true;
  bool _isCardView = true;
  final Set<String> _expandedStudents = {};
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _gradeTypeFilter = GradeConstants.defaultFilter;
  Map<String, List<Map<String, dynamic>>> _assessmentHeaders = {};
  final ScrollController _horizontalScrollController = ScrollController();

  // Edit
  bool _isEditMode = false;
  String? _editGradeType;
  Map<String, dynamic>? _editHeader;
  final Map<String, TextEditingController> _editControllers = {};
  final Map<String, FocusNode> _editFocusNodes = {};
  final GlobalKey _addGradeKey = GlobalKey();
  @override
  List<Student> get studentList => _studentList;
  @override
  set studentList(List<Student> v) => _studentList = v;
  @override
  List<Student> get filteredStudentList => _filteredStudentList;
  @override
  set filteredStudentList(List<Student> v) => _filteredStudentList = v;
  @override
  List<Map<String, dynamic>> get gradeList => _gradeList;
  @override
  set gradeList(List<Map<String, dynamic>> v) => _gradeList = v;
  @override
  Map<String, List<Map<String, dynamic>>> get assessmentHeaders =>
      _assessmentHeaders;
  @override
  set assessmentHeaders(Map<String, List<Map<String, dynamic>>> v) =>
      _assessmentHeaders = v;
  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool v) => _isLoading = v;
  @override
  List<String> get allGradeTypeList => _allGradeTypeList;
  @override
  TextEditingController get searchController => _searchController;
  @override
  Map<String, dynamic> get teacher => widget.teacher;
  @override
  Map<String, dynamic> get subject => widget.subject;
  @override
  Map<String, dynamic> get classData => widget.classData;
  @override
  void onDataLoaded() {}
  @override
  GlobalKey get addGradeKey => _addGradeKey;
  @override
  bool get canEditGrades =>
      _canEdit && !ref.read(academicYearRiverpod).isReadOnly;
  @override
  bool get canEdit => _canEdit;
  @override
  bool get isReadOnly => _isReadOnly;
  @override
  bool get isEditMode => _isEditMode;
  @override
  set isEditMode(bool v) => _isEditMode = v;
  @override
  String? get editGradeType => _editGradeType;
  @override
  set editGradeType(String? v) => _editGradeType = v;
  @override
  Map<String, dynamic>? get editHeader => _editHeader;
  @override
  set editHeader(Map<String, dynamic>? v) => _editHeader = v;
  @override
  Map<String, TextEditingController> get editControllers => _editControllers;
  @override
  Map<String, FocusNode> get editFocusNodes => _editFocusNodes;
  @override
  Map<String, bool> get gradeTypeFilter => _gradeTypeFilter;
  @override
  List<String> get filteredGradeTypeList => _filteredGradeTypeList;
  @override
  set filteredGradeTypeList(List<String> v) => _filteredGradeTypeList = v;
  @override
  Future<void> onInlineSaved() => loadData(
    teacher: widget.teacher,
    subject: widget.subject,
    classData: widget.classData,
    useCache: false,
  );

  @override
  void showErrorSnackBar(String message) {
    if (mounted) {
      ref.read(gradeBookControllerProvider).showErrorSnackBar(context, message);
    }
  }

  @override
  void showSuccessSnackBar(String message) {
    if (mounted) {
      ref
          .read(gradeBookControllerProvider)
          .showSuccessSnackBar(context, message);
    }
  }

  @override
  Map<String, dynamic>? getGradeForStudentAndHeader(
    Student s,
    String t,
    Map<String, dynamic> h,
  ) => ref
      .read(gradeBookControllerProvider)
      .getGradeForStudentAndHeader(s, t, h, _gradeList);

  @override
  String formatDateDisplay(String d) =>
      ref.read(gradeBookControllerProvider).formatDateDisplay(d);

  @override
  String getGradeTypeLabel(String t, LanguageProvider lp) =>
      ref.read(gradeBookControllerProvider).getGradeTypeLabel(t, lp);

  @override
  Color getPrimaryColor(Map<String, dynamic> _) =>
      ref.read(gradeBookControllerProvider).getPrimaryColor(widget.teacher);

  @override
  Future<void> onAssessmentDeleted() => loadData(
    teacher: widget.teacher,
    subject: widget.subject,
    classData: widget.classData,
    useCache: false,
  );

  @override
  Future<void> onCellFocusLost(
    Student s,
    String t,
    Map<String, dynamic> h,
    String f,
    String v,
  ) async {
    final e = await ref
        .read(gradeBookControllerProvider)
        .saveInlineGrade(
          s,
          t,
          h,
          f,
          v,
          _gradeList,
          widget.teacher,
          widget.subject,
        );
    if (e != null) showErrorSnackBar(e);
    if (e == null) await onInlineSaved();
  }

  bool get _canEdit =>
      (widget.teacher['role']?.toString().toLowerCase() ?? '') == 'guru' ||
      (widget.teacher['role']?.toString().toLowerCase() ?? '') == 'teacher';

  bool get _isReadOnly => ref.read(academicYearRiverpod).isReadOnly;

  @override
  void setCardViewMode(bool isCardView) {
    setState(() => _isCardView = isCardView);
    LocalCacheService.save('buku_nilai_view_preference', {
      'is_card_view': isCardView,
    });
  }

  @override
  void initState() {
    super.initState();
    loadViewPreference();
    loadData(
      teacher: widget.teacher,
      subject: widget.subject,
      classData: widget.classData,
    );
    updateFilteredGradeTypes();
    _searchController.addListener(filterStudents);
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _searchController.dispose();
    disposeEditResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    final pc = getPrimaryColor(widget.teacher);
    // BrandPageHeader (cobalt teacher chrome) replaces the bespoke
    // `GradeBookHeader`. View toggle + export action icons live in
    // the header's `actionIcons`; the legacy "drag handle" handle bar
    // is dropped because this is a real page route now (was a 95%
    // modal sheet — see GradePage.openGradeBook for the route fix).
    final subjectName = Subject.fromJson(widget.subject).name;
    final className = Classroom.fromJson(widget.classData).name;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
            BrandPageHeader(
              role: 'guru',
              title: subjectName,
              subtitle: 'BUKU NILAI · ${className.toUpperCase()}',
              isRealtimeFresh: true,
              kpiOverlayHeight: 0,
              actionIcons: [
                BrandHeaderIconButton(
                  icon: _isCardView
                      ? Icons.table_chart_rounded
                      : Icons.view_agenda_rounded,
                  onTap: () => setCardViewMode(!_isCardView),
                ),
                BrandHeaderIconButton(
                  icon: Icons.file_download_rounded,
                  onTap: () => exportGrades(lp),
                ),
              ],
            ),
            // KPI strip — Siswa · Asesmen · Avg · <KKM. Sits flush
            // below the header (no overlap zone since the body has
            // its own internal scrolling tables).
            _buildKpiStrip(),
            Expanded(
              child: GradeBookContentWidget(
                isLoading: _isLoading,
                isEditMode: _isEditMode,
                editGradeType: _editGradeType,
                editHeader: _editHeader,
                filteredStudentList: _filteredStudentList,
                gradeList: _gradeList,
                expandedStudents: _expandedStudents,
                searchController: _searchController,
                allGradeTypeList: _allGradeTypeList,
                gradeTypeFilter: _gradeTypeFilter,
                filteredGradeTypeList: _filteredGradeTypeList,
                assessmentHeaders: _assessmentHeaders,
                horizontalScrollController: _horizontalScrollController,
                isCardView: _isCardView,
                primaryColor: pc,
                canEdit: _canEdit,
                isReadOnly: _isReadOnly,
                languageProvider: lp,
                editControllers: _editControllers,
                editFocusNodes: _editFocusNodes,
                onFilterChanged: updateFilteredGradeTypes,
                onCellTap: (s, t, h) => openInputForm(s, t, lp, header: h),
                onColumnTap: (t, h) => showColumnOptions(
                  t,
                  h,
                  lp,
                  () => showAssessmentDetail(t, h, lp),
                  () => enterEditMode(t, h),
                  () => confirmDeleteAssessment(
                    t,
                    h,
                    lp,
                    () => deleteAssessment(t, h),
                  ),
                ),
                onAddAssessment: (_) {},
                onInlineSave: (s, t, h, v) async {
                  final e = await ref
                      .read(gradeBookControllerProvider)
                      .saveInlineGrade(
                        s,
                        t,
                        h,
                        'score',
                        v,
                        _gradeList,
                        widget.teacher,
                        widget.subject,
                      );
                  if (e == null) await onInlineSaved();
                  return e;
                },
                onStudentCardTap: (s, h) =>
                    openInputForm(s, h['type'] ?? 'uh', lp, header: h),
                onStudentCardToggled: (id) {
                  setState(
                    () => _expandedStudents.contains(id)
                        ? _expandedStudents.remove(id)
                        : _expandedStudents.add(id),
                  );
                },
                onFinishEdit: finishEdit,
                scoreColor: scoreColor,
                shortTypeLabel: shortTypeLabel,
                formatScore: formatScore,
                getGradeTypeLabel: getGradeTypeLabel,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: (_isEditMode || !_canEdit || _isReadOnly)
          ? null
          : FloatingActionButton(
              key: _addGradeKey,
              onPressed: () => openNewInputForm(lp),
              // Teacher cobalt theme — was briefly violet to suggest
              // a "secondary action", but the FAB launches the same
              // grade-input flow as the cell-tap edit, not an AI
              // affordance. Cobalt matches the rest of the teacher
              // tools so the action feels native to the screen.
              backgroundColor: pc,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
    );
  }

  /// 4-cell KPI strip — Siswa count, Asesmen header count, Avg score,
  /// Below-KKM (<75) student count. Sits below the brand header as a
  /// pinned reference card while the teacher edits.
  Widget _buildKpiStrip() {
    final studentCount = _filteredStudentList.length;
    var assessmentCount = 0;
    for (final entry in _assessmentHeaders.entries) {
      assessmentCount += entry.value.length;
    }
    // Compute avg + below-KKM tally over the loaded grade list.
    var sum = 0.0;
    var count = 0;
    final perStudentSums = <String, _StudentScore>{};
    for (final g in _gradeList) {
      final s = g['score'];
      if (s is num) {
        sum += s.toDouble();
        count++;
        final sid = g['student_id']?.toString() ?? '';
        if (sid.isNotEmpty) {
          final acc = perStudentSums[sid] ?? const _StudentScore(0, 0);
          perStudentSums[sid] = _StudentScore(
            acc.sum + s.toDouble(),
            acc.count + 1,
          );
        }
      }
    }
    final avg = count == 0 ? null : sum / count;
    final belowKkm = perStudentSums.values
        .where((v) => v.count > 0 && (v.sum / v.count) < 75)
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _kpiCell(
            value: '$studentCount',
            label: 'SISWA',
            color: ColorUtils.success600,
          ),
          _kpiDivider(),
          _kpiCell(
            value: '$assessmentCount',
            label: 'ASESMEN',
            color: ColorUtils.getRoleColor('guru'),
          ),
          _kpiDivider(),
          _kpiCell(
            value: avg == null ? '—' : avg.toStringAsFixed(0),
            label: 'AVG',
            color: ColorUtils.info600,
          ),
          _kpiDivider(),
          _kpiCell(
            value: '$belowKkm',
            label: '< KKM',
            color: ColorUtils.error600,
          ),
        ],
      ),
    );
  }

  Widget _kpiCell({
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(width: 1, height: 24, color: ColorUtils.slate100);
  }
}

/// Internal helper for tallying per-student score sums.
class _StudentScore {
  final double sum;
  final int count;
  const _StudentScore(this.sum, this.count);
}
