import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_tab_switcher.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Helpers and public API for parent.
mixin EmbeddedActivityHelpersMixin
    on ConsumerState<EmbeddedActivityListScreen> {
  // Abstract declarations for fields from state class
  GlobalKey get tabSwitcherKey;
  GlobalKey get searchFilterKey;
  GlobalKey get fabKey;

  TabController get tabController;

  // Abstract methods
  void resetAndLoadActivities();
  void showActivityTypeDialog();

  Color get primaryColor => ColorUtils.getRoleColor('guru');

  String resolveActivityType(dynamic activity) {
    final type = activity['type']?.toString() ?? activity['jenis']?.toString();
    if (type == 'assignment' || type == 'tugas') return 'tugas';
    if (type == 'material' || type == 'materi') return 'materi';
    return 'tugas';
  }

  Widget buildTabSwitcher(LanguageProvider languageProvider) {
    return ActivityTabSwitcher(
      tabSwitcherKey: tabSwitcherKey,
      tabController: tabController,
      primaryColor: primaryColor,
      allStudentsLabel: languageProvider.getTranslatedText({
        'en': 'All Students',
        'id': 'Semua Siswa',
      }),
      specificStudentLabel: languageProvider.getTranslatedText({
        'en': 'Specific Student',
        'id': 'Khusus Siswa',
      }),
    );
  }

  void forceRefresh() => resetAndLoadActivities();

  Widget? buildFab() {
    if (!widget.canEdit) return null;
    return FloatingActionButton(
      key: fabKey,
      onPressed: showActivityTypeDialog,
      backgroundColor: primaryColor,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}
