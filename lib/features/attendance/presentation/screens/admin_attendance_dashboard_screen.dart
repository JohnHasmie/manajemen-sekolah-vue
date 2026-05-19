// Admin Kehadiran dashboard — Mockup #11 applied as a standalone
// screen.
//
// Composes the AdminAttendanceDashboardHero with onTingkatTap wired
// to AdminTingkatHeatmapScreen (Mockup #12). This is the
// dashboard-style view the spec describes, kept separate from the
// older AdminAttendanceReportScreen so its 5-mixin tour/data/filter
// stack stays untouched. Future work can collapse the two; today
// admins reach this screen from the dashboard quick-actions.
//
// Converted from `ConsumerWidget` to `ConsumerStatefulWidget` so the
// shared `AdminAcademicYearReloadMixin` can attach. The mixin reloads
// the hero when the user flips the dashboard AY picker by remounting
// it via a `ValueKey` keyed on the current AY id — that resets the
// hero's internal State + re-triggers its `initState`-driven fetch
// without us having to thread a reload callback through.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/mixins/admin_academic_year_reload_mixin.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_tingkat_heatmap_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/admin_attendance_dashboard_hero.dart';

class AdminAttendanceDashboardScreen extends ConsumerStatefulWidget {
  const AdminAttendanceDashboardScreen({super.key});

  @override
  ConsumerState<AdminAttendanceDashboardScreen> createState() =>
      _AdminAttendanceDashboardScreenState();
}

class _AdminAttendanceDashboardScreenState
    extends ConsumerState<AdminAttendanceDashboardScreen>
    with AdminAcademicYearReloadMixin<AdminAttendanceDashboardScreen> {
  /// Bumped every time the dashboard AY picker flips. Folded into the
  /// hero's `ValueKey` so Flutter unmounts + remounts it, which
  /// reruns its initState-driven fetch under the new year.
  int _heroVersion = 0;

  @override
  void onAcademicYearChanged() {
    if (!mounted) return;
    setState(() => _heroVersion++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      // Hero is now backed by `BrandPageLayout` internally — it
      // owns the Stack overlay (header + KPI strip overlap + body
      // ListView with pull-to-refresh), so the screen just hosts
      // it directly without wrapping it in another ListView.
      body: AdminAttendanceDashboardHero(
        key: ValueKey('admin-attendance-hero-$_heroVersion'),
        onTingkatTap: (tingkat) {
          AppNavigator.push(
            context,
            AdminTingkatHeatmapScreen(tingkat: tingkat),
          );
        },
        onExportTap: () => SnackBarUtils.showInfo(
          context,
          'Ekspor laporan akan tersedia di rilis berikutnya.',
        ),
      ),
    );
  }
}
