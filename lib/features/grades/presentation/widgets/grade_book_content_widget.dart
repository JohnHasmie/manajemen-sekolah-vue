import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_edit_table_widget.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_table_widget.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/student_card_list_widget.dart';

/// Main content area of grade book (search, filters, table/cards, etc).
/// Extracted to reduce main screen state class.
class GradeBookContentWidget extends StatelessWidget {
  final bool isLoading;
  final bool isEditMode;
  final String? editGradeType;
  final Map<String, dynamic>? editHeader;
  final List<Student> filteredStudentList;
  final List<Map<String, dynamic>> gradeList;
  final Set<String> expandedStudents;
  final TextEditingController searchController;
  final List<String> allGradeTypeList;
  final Map<String, bool> gradeTypeFilter;
  final List<String> filteredGradeTypeList;
  final Map<String, List<Map<String, dynamic>>> assessmentHeaders;
  final ScrollController horizontalScrollController;
  final bool isCardView;
  final Color primaryColor;
  final bool canEdit;
  final bool isReadOnly;
  final LanguageProvider languageProvider;
  final Map<String, TextEditingController> editControllers;
  final Map<String, FocusNode> editFocusNodes;
  final VoidCallback onFilterChanged;
  final Function(Student, String, Map<String, dynamic>?) onCellTap;
  final Function(String, Map<String, dynamic>) onColumnTap;
  final Function(String) onAddAssessment;
  final Future<String?> Function(Student, String, Map<String, dynamic>, String)
  onInlineSave;
  final Function(Student, Map<String, dynamic>) onStudentCardTap;
  final Function(String) onStudentCardToggled;
  final Future<void> Function() onFinishEdit;
  final Color Function(double) scoreColor;
  final String Function(String) shortTypeLabel;
  final String Function(dynamic) formatScore;
  final String Function(String, LanguageProvider) getGradeTypeLabel;

  const GradeBookContentWidget({
    super.key,
    required this.isLoading,
    required this.isEditMode,
    required this.editGradeType,
    required this.editHeader,
    required this.filteredStudentList,
    required this.gradeList,
    required this.expandedStudents,
    required this.searchController,
    required this.allGradeTypeList,
    required this.gradeTypeFilter,
    required this.filteredGradeTypeList,
    required this.assessmentHeaders,
    required this.horizontalScrollController,
    required this.isCardView,
    required this.primaryColor,
    required this.canEdit,
    required this.isReadOnly,
    required this.languageProvider,
    required this.editControllers,
    required this.editFocusNodes,
    required this.onFilterChanged,
    required this.onCellTap,
    required this.onColumnTap,
    required this.onAddAssessment,
    required this.onInlineSave,
    required this.onStudentCardTap,
    required this.onStudentCardToggled,
    required this.onFinishEdit,
    required this.scoreColor,
    required this.shortTypeLabel,
    required this.formatScore,
    required this.getGradeTypeLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
      );
    }

    if (isEditMode && editGradeType != null && editHeader != null) {
      return GradeEditTableWidget(
        editGradeType: editGradeType!,
        editHeader: editHeader!,
        filteredStudentList: filteredStudentList,
        editControllers: editControllers,
        editFocusNodes: editFocusNodes,
        isReadOnly: isReadOnly,
        primaryColor: primaryColor,
        languageProvider: languageProvider,
        onSaveGrade: (student, field, value) =>
            onInlineSave(student, editGradeType!, editHeader!, value),
        onFinish: onFinishEdit,
      );
    }

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          color: ColorUtils.slate50,
          child: Column(
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ColorUtils.slate200),
                ),
                child: TextField(
                  controller: searchController,
                  style: TextStyle(color: ColorUtils.slate900, fontSize: 13),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    hintText: languageProvider.getTranslatedText({
                      'en': 'Search students...',
                      'id': 'Cari siswa...',
                    }),
                    hintStyle: TextStyle(
                      color: ColorUtils.slate400,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: ColorUtils.slate400,
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    isCollapsed: true,
                  ),
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                ),
              ),
              const SizedBox(height: 8),
              // Filter chips + student count
              Row(
                children: [
                  Text(
                    '${filteredStudentList.length} siswa',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: allGradeTypeList.map((type) {
                          final isActive = gradeTypeFilter[type] ?? true;
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: GestureDetector(
                              onTap: () {
                                gradeTypeFilter[type] = !isActive;
                                onFilterChanged();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? primaryColor.withValues(alpha: 0.1)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isActive
                                        ? primaryColor.withValues(alpha: 0.3)
                                        : ColorUtils.slate200,
                                  ),
                                ),
                                child: Text(
                                  getGradeTypeLabel(type, languageProvider),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isActive
                                        ? primaryColor
                                        : ColorUtils.slate400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Content with pull-to-refresh
        Expanded(
          child: AppRefreshIndicator(
            onRefresh: () async {
              // Trigger refresh in parent
            },
            role: 'guru',
            child: filteredStudentList.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 100),
                      EmptyState(
                        title: languageProvider.getTranslatedText({
                          'en': 'No students found',
                          'id': 'Tidak ada siswa',
                        }),
                        subtitle: searchController.text.isEmpty
                            ? languageProvider.getTranslatedText({
                                'en': 'No students in this class',
                                'id': 'Tidak ada siswa di kelas ini',
                              })
                            : languageProvider.getTranslatedText({
                                'en': 'No search results found',
                                'id': 'Tidak ditemukan hasil pencarian',
                              }),
                        icon: Icons.people_outline,
                      ),
                    ],
                  )
                : isCardView
                ? StudentCardListWidget(
                    filteredStudentList: filteredStudentList,
                    gradeList: gradeList,
                    expandedStudents: expandedStudents,
                    primaryColor: primaryColor,
                    languageProvider: languageProvider,
                    canEdit: canEdit,
                    isReadOnly: isReadOnly,
                    onStudentGradeTap: onStudentCardTap,
                    onStudentToggled: onStudentCardToggled,
                    scoreColor: scoreColor,
                    shortTypeLabel: shortTypeLabel,
                    formatScore: formatScore,
                    getGradeTypeLabel: getGradeTypeLabel,
                    assessmentHeaders: assessmentHeaders,
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      GradeTableWidget(
                        filteredStudentList: filteredStudentList,
                        filteredGradeTypeList: filteredGradeTypeList,
                        assessmentHeaders: assessmentHeaders,
                        gradeList: gradeList,
                        horizontalScrollController: horizontalScrollController,
                        canEdit: canEdit,
                        isReadOnly: isReadOnly,
                        primaryColor: primaryColor,
                        languageProvider: languageProvider,
                        onColumnTap: onColumnTap,
                        onCellTap: onCellTap,
                        onAddAssessment: onAddAssessment,
                        onInlineSave: onInlineSave,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
