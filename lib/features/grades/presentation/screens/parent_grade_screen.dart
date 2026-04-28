// Parent view of student grades — Phase 3 brand-aligned redesign.
//
// Read-only view of a child's grades with multi-anak chip selector,
// auto-marking grades as read when scrolled into view, and caching.
// In Laravel terms: `GradeController@parentIndex`.
//
// The data layer (5 mixins: read tracking / data loading / tour /
// detail / UI builder) is unchanged; only the screen's build()
// composition moved over to the canonical Phase-3 stack
// (BrandPageHeader + ChildSelectorChipRow + RefreshIndicator).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/core/mixins/pagination_mixin.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_realtime_pill.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_data_loading_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_detail_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_read_tracking_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_tour_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_ui_mixin.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

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

  // Drives the realtime pill — bumped after every successful refresh.
  DateTime _lastSync = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: RefreshIndicator(
        color: ColorUtils.brandAzureDeep,
        onRefresh: () async {
          await onRefreshRequested();
          if (mounted) setState(() => _lastSync = DateTime.now());
        },
        // Single outer ListView so the gradient hero scrolls with
        // the grade list — matches the dashboard / Kehadiran hero
        // idiom (not pinned).
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            _buildHeader(lang),
            buildGradeList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lang) {
    final summaries = _studentList.map<ChildSummary>((raw) {
      final model = Student.fromJson(raw as Map<String, dynamic>);
      return ChildSummary(
        id: model.id,
        shortName: model.name.isEmpty ? '?' : model.name,
        klass: model.className.isEmpty
            ? '-'
            : 'Kelas ${model.className}',
      );
    }).toList(growable: false);

    return BrandPageHeader(
      role: 'wali',
      subtitle: lang.getTranslatedText({
        'en': 'Academic · Child',
        'id': 'Akademik · Anak',
      }),
      title: lang.getTranslatedText({
        'en': 'Grades',
        'id': 'Nilai',
      }),
      realtimeIndicator: BrandRealtimePill(
        isFresh: !isLoading,
        lastSync: _lastSync,
      ),
      childSelector: summaries.length < 2
          ? null
          : ChildSelectorChipRow(
              key: _studentSelectorKey,
              children: summaries,
              selectedChildId: _selectedStudentId ?? summaries.first.id,
              onSelected: onStudentChanged,
              accentColor: ColorUtils.brandAzureDeep,
            ),
    );
  }
}
