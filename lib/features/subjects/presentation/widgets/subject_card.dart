// SubjectCard — single subject (mata pelajaran) row in the admin list
// (v3 — SS2 layout).
//
// Top row: meta (kode · N kelas) + "Detail →" CTA.
// Title:   bold subject name.
// Status:  inline green-dot Aktif / red-dot Nonaktif.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_list_row.dart';
import 'package:manajemensekolah/core/widgets/initials_avatar.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

class SubjectCard extends ConsumerWidget {
  final Map<String, dynamic> subject;
  final int index;
  final Color primaryColor;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onLongPress;
  final bool selected;

  const SubjectCard({
    super.key,
    required this.subject,
    required this.index,
    required this.primaryColor,
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
    final model = Subject.fromJson(subject);
    final accent = ColorUtils.getRoleColor('admin');
    final code = (model.code ?? '').isNotEmpty ? model.code! : '-';

    final topMeta =
        '$code · ${model.classCount} ${lang.getTranslatedText(const {'en': 'classes', 'id': 'kelas'})}';

    final status = model.isActive
        ? BrandRowStatus.success(
            lang.getTranslatedText(const {'en': 'Active', 'id': 'Aktif'}),
          )
        : BrandRowStatus.danger(
            lang.getTranslatedText(const {
              'en': 'Inactive',
              'id': 'Nonaktif',
            }),
          );

    return BrandListRow(
      leading: InitialsAvatar(
        name: model.name.isNotEmpty ? model.name : '?',
        size: 44,
        color: accent,
        borderRadius: 12,
      ),
      topMeta: topMeta,
      title: model.name.isNotEmpty ? model.name : 'No Name',
      status: status,
      trailingActionLabel: selected
          ? null
          : lang.getTranslatedText(const {
              'en': 'Detail',
              'id': 'Detail',
            }),
      trailingActionColor: accent,
      onTap: onTap,
      onLongPress: onLongPress ?? (isReadOnly ? null : onEdit),
      selected: selected,
    );
  }
}
