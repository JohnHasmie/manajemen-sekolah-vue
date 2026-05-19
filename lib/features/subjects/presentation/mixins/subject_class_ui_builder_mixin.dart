// Widget builders for class cards and UI components.
//
// Migrated to use the shared `BrandListRow` so this screen's class list
// matches every other admin/parent list (Siswa, Guru, Kelas, parent
// Akademik feature cards). Each row shows:
//
//   • Tinted leading icon (44×44) — assigned = success green, available
//     = slate neutral.
//   • Bold title = class name (e.g. "7A").
//   • Inline meta = tingkat + wali kelas in topMeta line.
//   • Inline status row = green "Terdaftar" dot + label OR neutral
//     "Belum Terdaftar".
//   • Trailing CTA = "Tambah" or "Lepas" so the action is discoverable
//     without long-press menus.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_list_row.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

mixin SubjectClassUiBuilderMixin {
  /// Builds an individual class row using the shared `BrandListRow`.
  Widget buildClassCard(
    Map<String, dynamic> classItem,
    int index,
    bool isAssigned,
  ) {
    final model = Classroom.fromJson(classItem);

    final accent = isAssigned ? ColorUtils.success600 : ColorUtils.slate500;
    final ctaColor = isAssigned
        ? ColorUtils.error600
        : ColorUtils.getRoleColor('admin');

    final tingkat = (model.gradeLevel ?? '').trim();
    final wali = (model.homeroomTeacherName ?? '').trim();
    final topMetaParts = <String>[
      if (tingkat.isNotEmpty) 'Tingkat $tingkat',
      if (wali.isNotEmpty) 'Wali: $wali',
    ];
    final topMeta = topMetaParts.isEmpty ? null : topMetaParts.join(' · ');

    return BrandListRow(
      leading: _ClassLeadingIcon(color: accent),
      title: model.name.isEmpty ? 'Kelas' : model.name,
      topMeta: topMeta,
      status: isAssigned
          ? const BrandRowStatus.success('Terdaftar')
          : const BrandRowStatus.neutral('Belum terdaftar'),
      trailingActionLabel: isAssigned ? 'Lepas' : 'Tambah',
      trailingActionColor: ctaColor,
      showChevron: false,
      onTap: () => handleClassCardTap(classItem, isAssigned),
    );
  }

  /// Builds stat item in stats container (legacy — kept for back-compat
  /// with the mixin contract; the screen now uses `BrandKpiStrip`).
  Widget buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }

  /// Handles class card tap
  void handleClassCardTap(Map<String, dynamic> classItem, bool isAssigned);
}

/// Leading tile for the class row — 44×44 tinted square with a class
/// icon, mirroring the parent Akademik feature card leading style.
class _ClassLeadingIcon extends StatelessWidget {
  final Color color;

  const _ClassLeadingIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Icon(Icons.class_outlined, color: color, size: 22),
    );
  }
}
