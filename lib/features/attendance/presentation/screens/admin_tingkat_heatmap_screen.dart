// Admin Kehadiran detail — per-student heatmap (Mockup #12).
//
// Drilled in from the AdminAttendanceDashboardHero TrendSparkRow tap.
// Shows a navy hero with the tingkat label + range chips + the H/I/S/A
// legend, then a vertical list of student cards: each card is a
// [StudentRowHeader] above a [CalendarHeatmap].
//
// The cell-correction inline sheet referenced in the mockup spec is
// scaffolded as a future TODO — a tap currently surfaces a snackbar
// since the per-cell update endpoint is a separate slice. Adding it
// later means: open a [CellDetailSheet] and POST to a new
// `attendance/{id}` PATCH endpoint that records an audit_logs row.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_attendance_components.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_dashboard_service.dart';

class AdminTingkatHeatmapScreen extends ConsumerStatefulWidget {
  /// Tingkat to scope the heatmap to (e.g. 9 for Tingkat 9). One of
  /// [tingkat] or [classId] should be set; if both are null the
  /// backend returns the school-wide list capped at 60.
  final int? tingkat;
  final String? classId;
  final String? title;

  const AdminTingkatHeatmapScreen({
    super.key,
    this.tingkat,
    this.classId,
    this.title,
  });

  @override
  ConsumerState<AdminTingkatHeatmapScreen> createState() =>
      _AdminTingkatHeatmapScreenState();
}

class _AdminTingkatHeatmapScreenState
    extends ConsumerState<AdminTingkatHeatmapScreen> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    final scope = HeatmapScope(
      tingkat: widget.tingkat,
      classId: widget.classId,
      days: _days,
    );
    final async = ref.watch(studentHeatmapProvider(scope));

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(
            navy: navy,
            title:
                widget.title ??
                (widget.tingkat != null
                    ? 'Tingkat ${widget.tingkat}'
                    : 'Kehadiran detail'),
            studentCountText: async.maybeWhen(
              data: (r) => '${r.students.length} siswa',
              orElse: () => '—',
            ),
            days: _days,
            onDaysChange: (d) => setState(() => _days = d),
          ),
          const SizedBox(height: AppSpacing.md),
          async.when(
            data: (r) => _StudentList(result: r),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Gagal memuat: $e',
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
          ),
          SizedBox(
            height: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Color navy;
  final String title;
  final String studentCountText;
  final int days;
  final ValueChanged<int> onDaysChange;

  const _Hero({
    required this.navy,
    required this.title,
    required this.studentCountText,
    required this.days,
    required this.onDaysChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: ColorUtils.brandGradient('admin')),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => AppNavigator.pop(context),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kehadiran detail',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          studentCountText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Days range chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _DaysChip(
                    label: '30 hari',
                    active: days == 30,
                    onTap: () => onDaysChange(30),
                  ),
                  const SizedBox(width: 8),
                  _DaysChip(
                    label: '60 hari',
                    active: days == 60,
                    onTap: () => onDaysChange(60),
                  ),
                  const SizedBox(width: 8),
                  _DaysChip(
                    label: '90 hari',
                    active: days == 90,
                    onTap: () => onDaysChange(90),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Legend strip
            const _LegendStrip(),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _DaysChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _DaysChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navy = ColorUtils.getRoleColor('admin');
    return Material(
      color: active ? Colors.white : Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? navy : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendStrip extends StatelessWidget {
  const _LegendStrip();

  @override
  Widget build(BuildContext context) {
    Widget legendItem(Color c, String label) => Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        children: [
          legendItem(AttendancePalette.present, 'Hadir'),
          legendItem(AttendancePalette.excused, 'Izin'),
          legendItem(AttendancePalette.sick, 'Sakit'),
          legendItem(AttendancePalette.alpha, 'Alpa'),
          legendItem(AttendancePalette.holiday.withValues(alpha: 0.4), 'Libur'),
        ],
      ),
    );
  }
}

class _StudentList extends StatelessWidget {
  final StudentHeatmapResult result;
  const _StudentList({required this.result});

  Color _avatarColor(int i) {
    const palette = [
      Color(0xFF3B82F6),
      Color(0xFFEC4899),
      Color(0xFF22C55E),
      Color(0xFFA855F7),
      Color(0xFFF59E0B),
      Color(0xFF14B8A6),
      Color(0xFF6366F1),
    ];
    return palette[i % palette.length];
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (result.students.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Text(
            'Belum ada siswa di rentang ini',
            style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < result.students.length; i++) ...[
          _StudentCard(
            entry: result.students[i],
            avatarColor: _avatarColor(i),
            initials: _initials(result.students[i].name),
          ),
          if (i < result.students.length - 1)
            const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentHeatmapEntry entry;
  final Color avatarColor;
  final String initials;

  const _StudentCard({
    required this.entry,
    required this.avatarColor,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: entry.alert
              ? Border.all(color: const Color(0xFFFEE2E2), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 6),
              blurRadius: 14,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StudentRowHeader(
              avatarInitials: initials,
              avatarColor: avatarColor,
              name: entry.name,
              classRoll: entry.studentNumber == null
                  ? '—'
                  : 'No. absen ${entry.studentNumber}',
              monthlyPct: entry.monthlyPct,
              presentDays: entry.presentDays,
              totalDays: entry.totalDays,
              alert: entry.alert,
              alertCopy: entry.alertCopy,
            ),
            const SizedBox(height: AppSpacing.md),
            CalendarHeatmap(
              cells: entry.cells,
              onCellTap: (i) {
                SnackBarUtils.showInfo(
                  context,
                  'Koreksi cell akan tersedia di rilis berikutnya.',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
