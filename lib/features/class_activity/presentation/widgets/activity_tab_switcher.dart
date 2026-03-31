// Tab switcher widget for the class activity screen (Step 2).
// Shows "All Students" / "Specific Student" tabs using the shared TabSwitcher.
// Replaces _buildTabSwitcher() from teacher_class_activity_screen.dart.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/tab_switcher.dart';

/// Renders the "Semua Siswa" / "Khusus Siswa" tab bar for the activity list step.
///
/// Wraps the shared [TabSwitcher] component with the two activity-audience tabs.
/// The [tabSwitcherKey] must remain in the parent State so the onboarding tour
/// can reference it (like a Vue `$refs` key staying on the parent component).
///
/// StatelessWidget is sufficient — no Riverpod reads needed here; all data
/// arrives via constructor parameters.
class ActivityTabSwitcher extends StatelessWidget {
  /// The GlobalKey used by the onboarding tour to highlight this widget.
  /// Must be created and owned by the parent State.
  final GlobalKey tabSwitcherKey;

  /// Owned by the parent State; drives tab animation and index.
  final TabController tabController;

  /// The brand/role color applied to the active tab indicator.
  final Color primaryColor;

  /// Translated labels come from the parent so this widget stays stateless.
  final String allStudentsLabel;
  final String specificStudentLabel;

  const ActivityTabSwitcher({
    super.key,
    required this.tabSwitcherKey,
    required this.tabController,
    required this.primaryColor,
    required this.allStudentsLabel,
    required this.specificStudentLabel,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      TabItem(label: allStudentsLabel, icon: Icons.group),
      TabItem(label: specificStudentLabel, icon: Icons.person),
    ];

    return Container(
      key: tabSwitcherKey,
      margin: const EdgeInsets.all(AppSpacing.lg),
      child: TabSwitcher(
        tabController: tabController,
        tabs: tabs,
        primaryColor: primaryColor,
      ),
    );
  }
}
