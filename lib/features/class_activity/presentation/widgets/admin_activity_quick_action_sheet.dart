// Quick-action sheet for the admin Kegiatan Kelas hub (Frame D).
//
// Triggered by the kebab on each activity card. Lets admin pivot the
// hub to a teacher's / subject's / class's slice in one tap — the
// recovery for the old drill-down's intent without the cost of
// descending the tree.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/class_activity/domain/models/admin_activity_summary.dart';

class AdminActivityQuickActionSheet {
  static Future<void> show({
    required BuildContext context,
    required AdminActivitySummary activity,
    required VoidCallback onViewDetail,
    required VoidCallback onFilterByTeacher,
    required VoidCallback onFilterBySubject,
    required VoidCallback onFilterByClass,
  }) {
    final primary = ColorUtils.getRoleColor('admin');
    return AppBottomSheet.show(
      context: context,
      title: activity.title ?? 'Kegiatan',
      subtitle:
          '${activity.type.labelId} · ${activity.subjectName ?? '—'} · ${activity.className ?? '—'} · ${activity.teacherName ?? '—'}',
      icon: Icons.event_note_rounded,
      primaryColor: primary,
      content: _Body(
        activity: activity,
        onViewDetail: onViewDetail,
        onFilterByTeacher: onFilterByTeacher,
        onFilterBySubject: onFilterBySubject,
        onFilterByClass: onFilterByClass,
      ),
      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.activity,
    required this.onViewDetail,
    required this.onFilterByTeacher,
    required this.onFilterBySubject,
    required this.onFilterByClass,
  });

  final AdminActivitySummary activity;
  final VoidCallback onViewDetail;
  final VoidCallback onFilterByTeacher;
  final VoidCallback onFilterBySubject;
  final VoidCallback onFilterByClass;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Row(
          icon: Icons.visibility_outlined,
          iconBg: const Color(0xFFEDE9FE),
          iconFg: const Color(0xFF7C3AED),
          title: 'Lihat Detail',
          desc: 'Buka informasi lengkap, daftar siswa, & statistik',
          onTap: () {
            AppNavigator.pop(context);
            onViewDetail();
          },
        ),
        if ((activity.teacherId ?? '').isNotEmpty)
          _Row(
            icon: Icons.person_outline_rounded,
            iconBg: const Color(0xFFCCFBF1),
            iconFg: const Color(0xFF0D9488),
            title: 'Filter pakai Guru ini',
            desc:
                'Tampilkan semua kegiatan oleh ${activity.teacherName ?? '—'}',
            onTap: () {
              AppNavigator.pop(context);
              onFilterByTeacher();
            },
          ),
        if ((activity.subjectId ?? '').isNotEmpty)
          _Row(
            icon: Icons.menu_book_outlined,
            iconBg: const Color(0xFFDBEAFE),
            iconFg: const Color(0xFF1D4ED8),
            title: 'Filter pakai Mapel ini',
            desc: 'Tampilkan semua kegiatan ${activity.subjectName ?? '—'}',
            onTap: () {
              AppNavigator.pop(context);
              onFilterBySubject();
            },
          ),
        if ((activity.classId ?? '').isNotEmpty)
          _Row(
            icon: Icons.class_outlined,
            iconBg: const Color(0xFFFEF3C7),
            iconFg: const Color(0xFFB45309),
            title: 'Filter pakai Kelas ini',
            desc: 'Tampilkan semua kegiatan kelas ${activity.className ?? '—'}',
            onTap: () {
              AppNavigator.pop(context);
              onFilterByClass();
            },
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: iconFg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.brandDarkBlue,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: ColorUtils.slate500,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: ColorUtils.slate400,
            ),
          ],
        ),
      ),
    );
  }
}
