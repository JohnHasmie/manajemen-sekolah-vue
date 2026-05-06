// Admin Kehadiran dashboard — Mockup #11 applied as a standalone
// screen.
//
// Composes the AdminAttendanceDashboardHero with onTingkatTap wired
// to AdminTingkatHeatmapScreen (Mockup #12). This is the
// dashboard-style view the spec describes, kept separate from the
// older AdminAttendanceReportScreen so its 5-mixin tour/data/filter
// stack stays untouched. Future work can collapse the two; today
// admins reach this screen from the dashboard quick-actions.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_tingkat_heatmap_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/admin_attendance_dashboard_hero.dart';

class AdminAttendanceDashboardScreen extends ConsumerWidget {
  const AdminAttendanceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      // Hero is now backed by `BrandPageLayout` internally — it
      // owns the Stack overlay (header + KPI strip overlap + body
      // ListView with pull-to-refresh), so the screen just hosts
      // it directly without wrapping it in another ListView.
      body: AdminAttendanceDashboardHero(
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
