import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_screen.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_class_selector.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/report_card_student_list.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

/// Mixin for UI building and styling.
mixin TeacherReportCardUiMixin on ConsumerState<ReportCardScreen> {
  Color getPrimaryColor() {
    return ColorUtils.getRoleColor(getTeacherRole());
  }

  bool get isDialogMode => getInitialClassId() != null;

  Widget buildBody() {
    if (isLoading()) {
      return const SkeletonListLoading();
    }

    final errorMessage = getErrorMessage();
    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Terjadi kesalahan:\n$errorMessage',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: AppSpacing.xxl),
              ElevatedButton.icon(
                onPressed: onRetryLoading,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.tryAgain.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: getPrimaryColor(),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (!isDialogMode) buildClassSelector(),
        Expanded(
          child: isLoadingStudents()
              ? const SkeletonListLoading()
              : AppRefreshIndicator(
                  onRefresh: onRefresh,
                  role: 'guru',
                  child: buildStudentList(),
                ),
        ),
      ],
    );
  }

  Widget buildClassSelector() {
    return ReportCardClassSelector(
      selectorKey: getClassSelectorKey(),
      classes: getClasses(),
      selectedClass: getSelectedClass(),
      languageProvider: getLanguageProvider(),
      onClassChanged: (newValue) {
        onClassChanged(newValue);
        loadStudentsForClass();
      },
    );
  }

  Widget buildStudentList() {
    return ReportCardStudentList(
      students: getStudents(),
      selectedClass: getSelectedClass(),
      onDownloadPdf: downloadStudentPdf,
      onReturnFromDetail: loadStudentsForClass,
    );
  }

  // Abstract methods
  String getTeacherRole();
  String? getInitialClassId();
  bool isLoading();
  bool isLoadingStudents();
  String getErrorMessage();
  List<dynamic> getClasses();
  List<dynamic> getStudents();
  Map<String, dynamic>? getSelectedClass();
  LanguageProvider getLanguageProvider();
  GlobalKey getClassSelectorKey();

  Future<void> onRefresh();
  void onRetryLoading();
  void onClassChanged(Map<String, dynamic> newClass);
  Future<void> loadStudentsForClass({bool useCache = true});
  Future<void> downloadStudentPdf(Map<String, dynamic> student);
}
