// TeacherCard — single teacher row in the admin list (v3 — SS2 layout).
//
// Top row: meta (mapel · NIP) + "Detail →" CTA.
// Title:   bold teacher name.
// Status:  inline green-dot Aktif + optional Wali Kelas role chip.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_list_row.dart';
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

class TeacherCard extends ConsumerWidget {
  final Map<String, dynamic> teacher;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final bool selected;

  const TeacherCard({
    super.key,
    required this.teacher,
    required this.index,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.onLongPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.read(languageRiverpod);
    final isReadOnly = ref.read(academicYearRiverpod).isReadOnly;
    final model = Teacher.fromJson(teacher);
    final accent = ColorUtils.getRoleColor('admin');

    final displayName = model.name.isNotEmpty ? model.name : kTeaNoName.tr;
    final nip = (teacher['nip'] ?? teacher['nuptk'] ?? '').toString();
    final email = model.email.isNotEmpty ? model.email : '';

    final metaParts = <String>[];
    if (nip.isNotEmpty) metaParts.add('NIP $nip');
    if (email.isNotEmpty) metaParts.add(email);
    final topMeta = metaParts.isEmpty ? null : metaParts.join(' · ');

    final homeroomWord = lang.getTranslatedText(const {
      'en': 'Homeroom',
      'id': 'Wali',
    });
    final secondaryChip =
        model.isHomeroomTeacher && (model.homeroomClassName ?? '').isNotEmpty
        ? BrandRowChip.role('$homeroomWord ${model.homeroomClassName}')
        : null;

    return BrandListRow(
      leading: InitialsAvatar(
        name: displayName,
        size: 44,
        color: accent,
        borderRadius: 12,
      ),
      topMeta: topMeta,
      title: displayName,
      status: BrandRowStatus.success(
        lang.getTranslatedText(const {'en': 'Active', 'id': 'Aktif'}),
      ),
      secondaryChip: secondaryChip,
      trailingActionLabel: selected
          ? null
          : lang.getTranslatedText(const {'en': 'Detail', 'id': 'Detail'}),
      trailingActionColor: accent,
      onTap: onTap,
      onLongPress: onLongPress ?? (isReadOnly ? null : onEdit),
      selected: selected,
    );
  }
}
