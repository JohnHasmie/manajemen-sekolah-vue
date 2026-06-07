// Frame C · Class row quick-action sheet for the Mata Pelajaran
// detail screen. See `_design/admin_mapel_detail_redesign.html`.
//
// Triggered by long-press on an assigned class row. Shows the class
// identity + a small grid of metadata that we have on hand (tingkat,
// wali kelas) and three actions:
//
//   • Ganti wali kelas        → opens AssignWaliKelasSheet (Frame D)
//   • Tambah/Lepas (toggle)   → mirrors the row's primary CTA
//   • Tutup
//
// The mockup also lists "Lihat jadwal" and "Buka buku nilai" CTAs but
// those routes aren't reachable directly from this context (they
// expect the teacher+class+mapel triple, not just class+mapel), so
// they're omitted here. We can wire them later as a follow-up.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/assign_wali_kelas_sheet.dart';

class SubjectClassQuickActionSheet extends StatelessWidget {
  final Classroom model;
  final bool isAssigned;
  final VoidCallback onToggleAssignment;
  final VoidCallback onWaliReassigned;

  const SubjectClassQuickActionSheet({
    super.key,
    required this.model,
    required this.isAssigned,
    required this.onToggleAssignment,
    required this.onWaliReassigned,
  });

  /// Opens the sheet wrapped in [AppBottomSheet].
  static Future<void> show({
    required BuildContext context,
    required Classroom model,
    required bool isAssigned,
    required VoidCallback onToggleAssignment,
    required VoidCallback onWaliReassigned,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      title: '${kSubClassPrefix.tr}${model.name.isEmpty ? '—' : model.name}',
      subtitle: kSubQuickActions.tr,
      icon: Icons.class_outlined,
      primaryColor: ColorUtils.getRoleColor('admin'),
      content: SubjectClassQuickActionSheet(
        model: model,
        isAssigned: isAssigned,
        onToggleAssignment: onToggleAssignment,
        onWaliReassigned: onWaliReassigned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = ColorUtils.getRoleColor('admin');
    final tingkat = (model.gradeLevel ?? '').trim();
    final wali = (model.homeroomTeacherName ?? '').trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Metadata grid
        Row(
          children: [
            Expanded(
              child: _MetaCell(
                label: kSubGradeShort.tr,
                value: tingkat.isEmpty ? '—' : '${kSubGrade.tr}$tingkat',
                icon: Icons.layers_outlined,
                accent: primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetaCell(
                label: kSubWaliKelas.tr,
                value: wali.isEmpty ? kSubNotSet.tr : wali,
                icon: Icons.person_outline_rounded,
                accent: wali.isEmpty ? ColorUtils.warning600 : primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        _ActionTile(
          icon: Icons.person_outline_rounded,
          label: wali.isEmpty ? kSubSetWali.tr : kSubChangeWali.tr,
          tone: _ActionTone.cobalt,
          onTap: () async {
            AppNavigator.pop(context);
            final changed = await AssignWaliKelasSheet.show(
              context: context,
              classId: model.id,
              className: model.name.isEmpty ? kSubClassGeneric.tr : model.name,
            );
            if (changed == true) onWaliReassigned();
          },
        ),
        _ActionTile(
          icon: isAssigned
              ? Icons.remove_circle_outline_rounded
              : Icons.add_circle_outline_rounded,
          label: isAssigned
              ? kSubRemoveFromSubject.tr
              : kSubAddToSubject.tr,
          tone: isAssigned ? _ActionTone.red : _ActionTone.cobalt,
          onTap: () {
            AppNavigator.pop(context);
            onToggleAssignment();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _ActionTile(
          icon: Icons.close_rounded,
          label: kClose.tr,
          tone: _ActionTone.neutral,
          onTap: () => AppNavigator.pop(context),
        ),
      ],
    );
  }
}

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MetaCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        border: Border.all(color: ColorUtils.slate200),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: accent == ColorUtils.warning600
                  ? ColorUtils.warning600
                  : ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ActionTone { cobalt, red, neutral }

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final _ActionTone tone;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  ({Color bg, Color fg}) _palette() {
    final brand = ColorUtils.getRoleColor('admin');
    switch (tone) {
      case _ActionTone.cobalt:
        return (bg: brand.withValues(alpha: 0.08), fg: brand);
      case _ActionTone.red:
        return (
          bg: ColorUtils.error600.withValues(alpha: 0.08),
          fg: ColorUtils.error600,
        );
      case _ActionTone.neutral:
        return (bg: ColorUtils.slate100, fg: ColorUtils.slate700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _palette();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: palette.bg,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(icon, color: palette.fg, size: 18),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: palette.fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
