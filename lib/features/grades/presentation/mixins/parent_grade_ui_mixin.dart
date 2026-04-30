import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/brand_empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/parent_grade_header.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/parent_grade_list_view.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/parent_grade_student_selector.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';

/// Mixin for UI building and rendering.
///
/// Handles construction of UI components (header, selector, list).
mixin ParentGradeUiMixin on State<ParentGradeScreen> {
  // Expected from state
  List<dynamic> get gradeList;
  List<dynamic> get studentList;
  String? get selectedStudentId;
  bool get isLoading;

  GlobalKey get studentSelectorKey;
  GlobalKey get gradeListKey;

  Map<String, Color> get gradeTypeColorMap;

  Color Function() get getPrimaryColor;
  LinearGradient Function() get getCardGradient;
  void showGradeDetail(Map<String, dynamic> grade);
  void onItemVisible(Map<String, dynamic> grade);
  void Function(String?) get onStudentChanged;
  String formatDate(dynamic date);
  String Function(String) get getGradeTypeLabel;

  // Pagination from mixin
  ScrollController get paginationScrollController;
  bool get isLoadingMore;

  /// Build the top header with refresh button.
  Widget buildHeader() => ParentGradeHeader(
    gradient: getCardGradient(),
    primaryColor: getPrimaryColor(),
    onRefresh: onRefreshRequested,
  );

  /// Callback for refresh button.
  Future<void> onRefreshRequested();

  /// Build the student selector dropdown/menu.
  Widget buildStudentSelector() => ParentGradeStudentSelector(
    studentList: studentList,
    selectedStudentId: selectedStudentId,
    selectorKey: studentSelectorKey,
    onStudentChanged: onStudentChanged,
  );

  /// Build the empty state widget.
  Widget buildEmptyState(String message) => BrandEmptyState(
    icon: Icons.assignment_outlined,
    tone: BrandEmptyStateTone.info,
    kicker: 'Belum ada data',
    title: 'Belum ada nilai',
    message: message,
  );

  /// Build the loading skeleton.
  Widget buildLoadingState() {
    return SkeletonListLoading(
      itemCount: 6,
      infoTagCount: 2,
      shrinkWrap: true,
      baseColor: getPrimaryColor().withValues(alpha: 0.15),
      highlightColor: getPrimaryColor().withValues(alpha: 0.05),
    );
  }

  /// Get localized label for grade type.
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

  /// Build the main grade list.
  Widget buildGradeList() {
    final fallback = isLoading
        ? buildLoadingState()
        : buildEmptyState('Data penilaian tidak tersedia');

    return ParentGradeListView(
      gradeList: gradeList,
      selectedStudentId: selectedStudentId,
      loadingWidget: fallback,
      listKey: gradeListKey,
      gradeTypeColorMap: gradeTypeColorMap,
      formatDate: formatDate,
      getGradeTypeLabel: _getGradeTypeLabel,
      onItemVisible: onItemVisible,
      onGradeTap: showGradeDetail,
      controller: paginationScrollController,
      isLoadingMore: isLoadingMore,
    );
  }

  /// Build card gradient based on primary color.
  LinearGradient buildCardGradient(Color primaryColor) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }
}
