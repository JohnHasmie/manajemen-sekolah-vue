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
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_book_header.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_book_content_widget.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_book_tour_mixin.dart';
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
        GradeBookTourMixin,
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
  void onDataLoaded() => checkAndShowTour();
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
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
            GradeBookHeader(
              primaryColor: pc,
              title: lp.getTranslatedText({
                'en': 'Grade Book',
                'id': 'Buku Nilai',
              }),
              subtitle:
                  '${Subject.fromJson(widget.subject).name} - ${Classroom.fromJson(widget.classData).name}',
              isCardView: _isCardView,
              onBack: () => widget.onBack != null
                  ? widget.onBack!()
                  : AppNavigator.pop(context),
              onExport: () => exportGrades(lp),
              onToggleView: () => setCardViewMode(!_isCardView),
            ),
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
              backgroundColor: pc,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            ),
    );
  }
}
