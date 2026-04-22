import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_detail_dialog.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/filter_bottom_sheet.dart';

/// Handles filtering and activity detail display.
mixin EmbeddedActivityFilterMixin on ConsumerState<EmbeddedActivityListScreen> {
  // Abstract declarations for fields from state class
  Color get primaryColor;

  String? get selectedDateFilter;
  set selectedDateFilter(String? value);

  bool get hasActiveFilter;
  set hasActiveFilter(bool value);

  // Abstract methods
  void resetAndLoadActivities();
  void showEditActivityDialog(dynamic activity);

  void showFilterSheet() {
    FilterBottomSheet.show(
      context: context,
      primaryColor: primaryColor,
      languageProvider: ref.read(languageRiverpod),
      initialDateFilter: selectedDateFilter,
      onApply: (dateFilter) {
        setState(() {
          selectedDateFilter = dateFilter;
          hasActiveFilter = selectedDateFilter != null;
        });
        resetAndLoadActivities();
      },
    );
  }

  void showActivityDetail(dynamic activity) {
    ActivityDetailDialog.show(
      context: context,
      activity: activity,
      primaryColor: primaryColor,
      languageProvider: ref.read(languageRiverpod),
      canEdit: widget.canEdit,
      selectedClassName: widget.className,
      selectedSubjectName: widget.subjectName,
      onEditPressed: () => showEditActivityDialog(activity),
    );
  }
}
