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
            lang.getTranslatedText(const {'en': 'Inactive', 'id': 'Nonaktif'}),
          );

    // BrandListRow + a small popup menu overlay so admins have a
    // visible Edit / Hapus affordance (long-press → edit still works
    // as a secondary shortcut). Read-only AY hides the menu so the
    // mutation actions don't tease an action that can't fire.
    return Stack(
      children: [
        BrandListRow(
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
              : lang.getTranslatedText(const {'en': 'Detail', 'id': 'Detail'}),
          trailingActionColor: accent,
          onTap: onTap,
          onLongPress: onLongPress ?? (isReadOnly ? null : onEdit),
          selected: selected,
        ),
        if (!selected && !isReadOnly)
          Positioned(
            top: 6,
            right: 6,
            child: _SubjectRowMenu(
              onEdit: onEdit,
              onDelete: onDelete,
              editLabel: lang.getTranslatedText(const {
                'en': 'Edit',
                'id': 'Edit',
              }),
              deleteLabel: lang.getTranslatedText(const {
                'en': 'Delete',
                'id': 'Hapus',
              }),
            ),
          ),
      ],
    );
  }
}

/// Small kebab menu button — sits over the top-right of the card and
/// exposes Edit + Hapus actions. Replaces the long-press-only edit
/// flow so admins can find the action without the hidden gesture.
class _SubjectRowMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String editLabel;
  final String deleteLabel;

  const _SubjectRowMenu({
    required this.onEdit,
    required this.onDelete,
    required this.editLabel,
    required this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<String>(
        tooltip: editLabel,
        icon: Icon(
          Icons.more_vert_rounded,
          size: 18,
          color: ColorUtils.slate500,
        ),
        padding: EdgeInsets.zero,
        offset: const Offset(0, 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
        itemBuilder: (_) => [
          PopupMenuItem<String>(
            value: 'edit',
            height: 40,
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 16, color: ColorUtils.slate700),
                const SizedBox(width: 10),
                Text(editLabel, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            height: 40,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: ColorUtils.error600,
                ),
                const SizedBox(width: 10),
                Text(
                  deleteLabel,
                  style: TextStyle(
                    fontSize: 13,
                    color: ColorUtils.error600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
