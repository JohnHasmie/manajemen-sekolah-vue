// StudentCard — single student row in the admin list (v3 — SS2 layout).
//
// Top row: meta (class · NIS) + "Detail →" CTA.
// Title:   bold student name.
// Status:  inline green-dot Aktif (no bg pill).
import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_list_row.dart';
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final int index;
  final bool isReadOnly;
  final Color primaryColor;
  final String genderText;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final bool selected;

  const StudentCard({
    super.key,
    required this.student,
    required this.index,
    required this.isReadOnly,
    required this.primaryColor,
    required this.genderText,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final model = Student.fromJson(student);
    final accent = ColorUtils.getRoleColor('admin');
    final className = model.className.isNotEmpty ? model.className : '-';
    // Canonical NIS field is `student_number` (matches the backend
    // column and the form). Fall back to legacy `nis` / `nisn` only
    // when the canonical key is missing so older API responses still
    // surface a NIS rather than going blank.
    final nis =
        (student['student_number'] ?? student['nis'] ?? student['nisn'] ?? '')
            .toString();

    final topMeta = nis.isNotEmpty ? '$className · NIS $nis' : className;

    return BrandListRow(
      leading: InitialsAvatar(
        name: model.name.isNotEmpty ? model.name : '?',
        size: 44,
        color: accent,
        borderRadius: 12,
      ),
      topMeta: topMeta,
      title: model.name.isNotEmpty ? model.name : kStuNoName.tr,
      status: BrandRowStatus.success(kStuActive.tr),
      trailingActionLabel: selected ? null : 'Detail',
      trailingActionColor: accent,
      onTap: onTap,
      onLongPress: onLongPress ?? (isReadOnly ? null : onEdit),
      selected: selected,
    );
  }
}
