// AdminScheduleCard — single schedule entry row in the admin list view
// (v3 — SS2 layout).
//
// Top row: meta (day · time) + "Detail →" CTA.
// Title:   bold subject name.
// Status:  inline info-dot teacher · class.
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_list_row.dart';
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

class AdminScheduleCard extends StatelessWidget {
  const AdminScheduleCard({
    super.key,
    required this.schedule,
    required this.index,
    required this.isReadOnly,
    required this.primaryColor,
    required this.dayLabel,
    required this.timeLabel,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onLongPress,
    this.selected = false,
  });

  final Map<String, dynamic> schedule;
  final int index;
  final bool isReadOnly;
  final Color primaryColor;
  final String dayLabel;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = ColorUtils.getRoleColor('admin');
    final model = Schedule.fromJson(schedule);
    final subjectName = (model.subjectName ?? '').isEmpty
        ? 'No Subject'
        : model.subjectName!;
    final teacherName = (model.teacherName ?? '').isEmpty
        ? '-'
        : model.teacherName!;
    final className = (model.className ?? '').isEmpty
        ? '-'
        : model.className!;

    final topMeta = '$dayLabel · $timeLabel';

    return BrandListRow(
      leading: InitialsAvatar(
        name: subjectName,
        size: 44,
        color: accent,
        borderRadius: 12,
      ),
      topMeta: topMeta,
      title: subjectName,
      status: BrandRowStatus.info('$teacherName · $className'),
      trailingActionLabel: selected ? null : 'Detail',
      trailingActionColor: accent,
      onTap: onTap,
      onLongPress: onLongPress ?? (isReadOnly ? null : onEdit),
      selected: selected,
    );
  }
}
