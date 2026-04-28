// Parent view of student grades.
// Like `pages/parent/Grades.vue` in a Vue app.
//
// Read-only view of a child's grades with student selector,
// auto-marking grades as read when scrolled into view, and caching.
// In Laravel terms: `GradeController@parentIndex`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/mixins/pagination_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_read_tracking_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_data_loading_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_tour_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_detail_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_ui_mixin.dart';

/// Parent's read-only view of student grades.
///
/// Props: optional [academicYearId].
class ParentGradeScreen extends ConsumerStatefulWidget {
  final String? academicYearId;

  const ParentGradeScreen({super.key, this.academicYearId});

  @override
  ParentGradeScreenState createState() => ParentGradeScreenState();
}

/// State for [ParentGradeScreen].
///
/// Main state holder with all mixins for functionality.
class ParentGradeScreenState extends ConsumerState<ParentGradeScreen>
    with
        PaginationMixin<ParentGradeScreen>,
        ParentGradeReadTrackingMixin,
        ParentGradeDataLoadingMixin,
        ParentGradeTourMixin,
        ParentGradeDetailMixin,
        ParentGradeUiMixin {
  List<dynamic> _gradeList = [];
  List<dynamic> _studentList = [];
  String? _selectedStudentId;
  bool _isLoading = true;

  final GlobalKey _studentSelectorKey = GlobalKey();
  final GlobalKey _gradeListKey = GlobalKey();

  // Grade type color map
  final Map<String, Color> _gradeTypeColorMap = {
    'tugas': ColorUtils.corporateBlue600,
    'uh': ColorUtils.success600,
    'uts': ColorUtils.warning600,
    'uas': ColorUtils.error600,
  };

  @override
  void initState() {
    super.initState();
    initPagination();
    loadUserData();
  }

  @override
  void dispose() {
    disposePagination();
    disposeReadTracking();
    super.dispose();
  }

  // Mixin-required property getters for data
  @override
  List<dynamic> get gradeList => _gradeList;
  @override
  set gradeList(List<dynamic> value) {
    _gradeList = value;
  }

  @override
  List<dynamic> get studentList => _studentList;
  @override
  set studentList(List<dynamic> value) {
    _studentList = value;
  }

  @override
  String? get selectedStudentId => _selectedStudentId;
  @override
  set selectedStudentId(String? value) {
    _selectedStudentId = value;
  }

  @override
  bool get isLoading => _isLoading;
  @override
  set isLoading(bool value) {
    _isLoading = value;
  }

  @override
  String? get academicYearId => widget.academicYearId;

  @override
  GlobalKey get studentSelectorKey => _studentSelectorKey;

  @override
  GlobalKey get gradeListKey => _gradeListKey;

  @override
  Map<String, Color> get gradeTypeColorMap => _gradeTypeColorMap;

  @override
  Color Function() get getPrimaryColor =>
      () => ColorUtils.getRoleColor('wali');

  @override
  LinearGradient Function() get getCardGradient =>
      () => ColorUtils.brandGradient('wali');

  @override
  void Function(String?) get onStudentChanged => (value) {
    setState(() {
      _selectedStudentId = value;
      _gradeList = [];
    });
    loadGrades();
  };

  @override
  String Function(String) get getGradeTypeLabel => _getGradeTypeLabel;

  String _getGradeTypeLabel(String type) {
    switch (type) {
      case 'tugas':
        return 'Tugas';
      case 'uh':
        return 'UH';
      case 'uts':
        return 'UTS';
      case 'uas':
        return 'UAS';
      default:
        return type.toUpperCase();
    }
  }

  @override
  Future<void> onRefreshRequested() => forceRefresh();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          buildHeader(),
          buildStudentSelector(),
          Expanded(child: buildGradeList()),
        ],
      ),
    );
  }
}
