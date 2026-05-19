// Activity card rendered on the admin Kegiatan Kelas hub (Frame A).
//
// Layout:
//   ┌───────────────────────────────────────────────────────┐
//   │  📘 Tugas   Matematika   7A                       ⋯  │
//   │  Latihan Bab 3 — Persamaan Linear                    │
//   │  Selesaikan 10 soal pada halaman 45 buku paket…      │
//   │  👤 Pak Adi   ⏰ 2 hari lagi                         │
//   │  ──────────────────────────────────────────────────  │
//   │  ▓▓▓▓▓▓▓▓▓░░░  18 / 25 submit · 72%                 │
//   └───────────────────────────────────────────────────────┘
//
// Replaces the legacy drill-down "third-level" card. Tap → opens the
// detail screen. Kebab → opens the quick-action sheet with "Filter
// pakai Guru / Mapel / Kelas / Lihat Detail". The submission progress
// bar is only rendered when the activity has tracked submissions
// (announcements / materials hide it).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/class_activity/domain/models/admin_activity_summary.dart';

class AdminActivityCard extends StatelessWidget {
  const AdminActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.onKebabTap,
  });

  final AdminActivitySummary activity;
  final VoidCallback? onTap;
  final VoidCallback? onKebabTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ColorUtils.slate200),
          ),
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPillRow(),
              if ((activity.title ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  activity.title!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.brandDarkBlue,
                    height: 1.25,
                  ),
                ),
              ],
              if ((activity.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  activity.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ColorUtils.slate600,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _buildMetaRow(),
              if (activity.submissions.hasTracking) ...[
                const SizedBox(height: 8),
                const _DashedDivider(),
                const SizedBox(height: 8),
                _buildSubmissionProgress(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillRow() {
    return Row(
      children: [
        _TypePill(type: activity.type),
        const SizedBox(width: 6),
        if ((activity.subjectName ?? '').isNotEmpty) ...[
          _MetaPill(
            label: activity.subjectName!,
            bg: const Color(0xFFEDE9FE),
            fg: const Color(0xFF7C3AED),
          ),
          const SizedBox(width: 6),
        ],
        if ((activity.className ?? '').isNotEmpty)
          _MetaPill(
            label: activity.className!,
            bg: const Color(0xFFCCFBF1),
            fg: const Color(0xFF0D9488),
          ),
        const Spacer(),
        if (onKebabTap != null)
          InkResponse(
            onTap: onKebabTap,
            radius: 16,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: ColorUtils.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.more_horiz_rounded,
                size: 14,
                color: ColorUtils.slate500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetaRow() {
    final children = <Widget>[];
    if ((activity.teacherName ?? '').isNotEmpty) {
      children.add(
        _MetaItem(
          icon: Icons.person_outline_rounded,
          label: activity.teacherName!,
        ),
      );
    }
    if ((activity.time ?? '').isNotEmpty) {
      children.add(
        _MetaItem(icon: Icons.access_time_rounded, label: activity.time!),
      );
    }
    final dateLabel = _formatRelativeDate(activity.date);
    if (dateLabel != null) {
      children.add(_MetaItem(icon: Icons.event_rounded, label: dateLabel));
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 12, runSpacing: 6, children: children);
  }

  Widget _buildSubmissionProgress() {
    final s = activity.submissions;
    final percent = (s.progress * 100).round();
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 5,
            decoration: BoxDecoration(
              color: ColorUtils.slate100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              widthFactor: s.progress.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ColorUtils.brandCobalt,
                      const Color(0xFF21AFE6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '${s.submitted + s.late} / ${s.totalStudents} · $percent%',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate700,
          ),
        ),
        if (s.avgScore != null) ...[
          const SizedBox(width: 6),
          Text(
            '· ⭐ ${s.avgScore!.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ColorUtils.brandDarkBlue,
            ),
          ),
        ],
      ],
    );
  }

  /// Returns a short Indonesian relative label like "Hari ini",
  /// "Kemarin", "3 hari lagi", "Lewat 2 hari".
  String? _formatRelativeDate(DateTime? date) {
    if (date == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final delta = target.difference(today).inDays;
    if (delta == 0) return 'Hari ini';
    if (delta == 1) return 'Besok';
    if (delta == -1) return 'Kemarin';
    if (delta > 1) return '$delta hari lagi';
    return 'Lewat ${-delta} hari';
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});
  final AdminActivityType type;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = _styleFor(type);
    return _MetaPill(label: label, bg: bg, fg: fg, icon: icon);
  }

  (Color, Color, String, IconData) _styleFor(AdminActivityType type) {
    return switch (type) {
      AdminActivityType.tugas => (
        const Color(0xFFDBEAFE),
        const Color(0xFF1D4ED8),
        'Tugas',
        Icons.assignment_outlined,
      ),
      AdminActivityType.pr => (
        const Color(0xFFFEF3C7),
        const Color(0xFFB45309),
        'PR',
        Icons.home_work_outlined,
      ),
      AdminActivityType.ulangan => (
        const Color(0xFFFEE2E2),
        const Color(0xFFB91C1C),
        'Ulangan',
        Icons.fact_check_outlined,
      ),
      AdminActivityType.lainnya => (
        const Color(0xFFEDE9FE),
        const Color(0xFF7C3AED),
        'Lainnya',
        Icons.bookmark_outline_rounded,
      ),
    };
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
  });

  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: ColorUtils.slate400),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
      ],
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const dashWidth = 3.0;
        const gap = 3.0;
        final count = (c.maxWidth / (dashWidth + gap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Container(
              width: dashWidth,
              height: 1,
              margin: const EdgeInsets.only(right: gap),
              color: ColorUtils.slate200,
            ),
          ),
        );
      },
    );
  }
}
