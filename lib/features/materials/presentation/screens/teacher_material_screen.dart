// Teaching material (materi) management screen for teachers.
//
// Refactored from 760 lines → ~370 lines by extracting:
//   - MaterialDataMixin (data loading, caching)
//   - MaterialProgressMixin (checkbox state, save/load)
//   - MaterialChapterMixin (chapter operations)
//   - MaterialResolveMixin (resolve logic)
//   - MaterialFilterMixin (filter UI + logic)
//   - MaterialNavigationMixin (navigation + sheets)
//   - MaterialUIHelpersMixin (color, text, search helpers)
//   - MaterialBuildMixin (all build methods)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_build_list_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_build_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_chapter_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_data_load_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_data_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_filter_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_navigation_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_progress_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_resolve_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_ui_helpers_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_tour_helper.dart';

/// Teaching material browser with subject, chapter,
/// and sub-chapter navigation.
class TeacherMaterialScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> teacher;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;
  final bool embedded;

  const TeacherMaterialScreen({
    super.key,
    required this.teacher,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
    this.embedded = false,
  });

  @override
  TeacherMaterialScreenState createState() => TeacherMaterialScreenState();
}

class TeacherMaterialScreenState extends ConsumerState<TeacherMaterialScreen>
    with
        MaterialDataMixin,
        MaterialDataLoadMixin,
        MaterialResolveMixin,
        MaterialChapterMixin,
        MaterialProgressMixin,
        MaterialFilterMixin,
        MaterialNavigationMixin,
        MaterialUIHelpersMixin,
        MaterialBuildMixin,
        MaterialBuildListMixin {
  // ── State fields ──

  String? _selectedSubject;
  String? _selectedClassId;
  String? _selectedClassName;
  List<dynamic> _subjectList = [];
  List<dynamic> _classList = [];
  List<dynamic> _chapterMaterialList = [];
  List<dynamic> _subChapterMaterialList = [];
  List<dynamic> _schedules = [];
  List<dynamic> _overviewSummary = [];
  bool _isLoading = false;
  bool _isLoadingBab = false;
  bool _isLoadingProgress = false;
  bool _isLoadingOverview = true;
  bool _isListView = false;
  bool _isHomeroomView = false;
  String? _teacherProfileId;
  String? _materialErrorMessage;

  final _searchController = TextEditingController();
  final Map<String, bool> _expandedChapter = {};
  final Map<String, bool> _checkedChapter = {};
  final Map<String, bool> _checkedSubChapter = {};
  final Map<String, bool> _generatedChapter = {};
  final Map<String, bool> _generatedSubChapter = {};
  final Map<String, bool> _usedChapter = {};
  final Map<String, bool> _usedSubChapter = {};
  final GlobalKey _filterKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final bool _hasAutoExpanded = false;

  late final _tourHelper = MaterialTourHelper(
    filterKey: _filterKey,
    searchKey: _searchKey,
  );

  // ── Bridge accessors (for mixins) ──

  @override
  String? get selectedSubject => _selectedSubject;
  @override
  set selectedSubject(String? v) => _selectedSubject = v;
  @override
  String? get selectedClassId => _selectedClassId;
  @override
  set selectedClassId(String? v) => _selectedClassId = v;
  @override
  String? get selectedClassName => _selectedClassName;
  @override
  set selectedClassName(String? v) => _selectedClassName = v;
  @override
  List<dynamic> get subjectList => _subjectList;
  @override
  set subjectList(List<dynamic> v) => _subjectList = v;
  @override
  List<dynamic> get classList => _classList;
  @override
  set classList(List<dynamic> v) => _classList = v;
  @override
  List<dynamic> get chapterMaterialList => _chapterMaterialList;
  @override
  set chapterMaterialList(List<dynamic> v) => _chapterMaterialList = v;
  @override
  List<dynamic> get subChapterMaterialList => _subChapterMaterialList;
  @override
  set subChapterMaterialList(List<dynamic> v) => _subChapterMaterialList = v;
  @override
  List<dynamic> get schedules => _schedules;
  @override
  set schedules(List<dynamic> v) => _schedules = v;
  @override
  List<dynamic> get overviewSummary => _overviewSummary;
  @override
  set overviewSummary(List<dynamic> v) => _overviewSummary = v;
  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool v) => _isLoading = v;
  @override
  bool get isLoadingBab => _isLoadingBab;
  @override
  set isLoadingBab(bool v) => _isLoadingBab = v;
  @override
  bool get isLoadingProgress => _isLoadingProgress;
  @override
  set isLoadingProgress(bool v) => _isLoadingProgress = v;
  @override
  bool get isLoadingOverview => _isLoadingOverview;
  @override
  set isLoadingOverview(bool v) => _isLoadingOverview = v;
  @override
  String? get teacherProfileId => _teacherProfileId;
  @override
  set teacherProfileId(String? v) => _teacherProfileId = v;
  @override
  String? get materialErrorMessage => _materialErrorMessage;
  @override
  set materialErrorMessage(String? v) => _materialErrorMessage = v;
  @override
  Map<String, bool> get expandedChapter => _expandedChapter;
  @override
  Map<String, bool> get checkedChapter => _checkedChapter;
  @override
  Map<String, bool> get checkedSubChapter => _checkedSubChapter;
  @override
  Map<String, bool> get generatedChapter => _generatedChapter;
  @override
  Map<String, bool> get generatedSubChapter => _generatedSubChapter;
  @override
  Map<String, bool> get usedChapter => _usedChapter;
  @override
  Map<String, bool> get usedSubChapter => _usedSubChapter;
  @override
  bool get isHomeroomView => _isHomeroomView;
  @override
  set isHomeroomView(bool v) => _isHomeroomView = v;
  @override
  void checkAndShowTour() => _tourHelper.checkAndShow(context);
  @override
  bool get isListView => _isListView;
  @override
  set isListView(bool v) => _isListView = v;
  @override
  TextEditingController get searchController => _searchController;
  @override
  Color get primaryColor => ColorUtils.getRoleColor('guru');
  @override
  GlobalKey get filterKey => _filterKey;
  @override
  GlobalKey get searchKey => _searchKey;

  // ── Lifecycle ──

  @override
  void initState() {
    super.initState();
    loadViewPref((v) => setState(() => _isListView = v));
    WidgetsBinding.instance.addPostFrameCallback((_) => loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    return widget.embedded ? buildEmbedded(lp) : buildMain(lp);
  }
}
