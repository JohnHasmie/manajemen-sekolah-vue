// Widget builders for class rows on the Mata Pelajaran detail screen.
//
// Each row mirrors the shared `BrandListRow` look (44×44 tinted icon,
// 15pt bold title, slate-500 meta, trailing CTA) but composes its own
// layout so the wali kelas chip can sit *inside* the row without
// fighting with `BrandListRow`'s internal Stack. The chip is tappable
// independently of the row — tapping the chip opens the Frame D wali
// assignment sheet; tapping anywhere else on the row toggles assign /
// unassign for the subject.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/classrooms/presentation/widgets/assign_wali_kelas_sheet.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_class_quick_action_sheet.dart';

mixin SubjectClassUiBuilderMixin {
  Set<String> get selectedIds;
  bool get bulkMode;
  void toggleSelection(String id);
  BuildContext get context;

  Widget buildClassCard(
    Map<String, dynamic> classItem,
    int index,
    bool isAssigned,
    bool isSelected,
  ) {
    final model = Classroom.fromJson(classItem);

    return _ClassRow(
      model: model,
      isAssigned: isAssigned,
      selected: isSelected,
      onTapRow: () {
        if (bulkMode) {
          if (isAssigned) {
            toggleSelection(model.id);
          }
        } else {
          // Tap 1x shows quick action sheet
          SubjectClassQuickActionSheet.show(
            context: context,
            model: model,
            isAssigned: isAssigned,
            onToggleAssignment: () => handleClassCardTap(classItem, isAssigned),
            onWaliReassigned: onWaliReassigned,
          );
        }
      },
      onLongPressRow: (context) {
        if (isAssigned) {
          toggleSelection(model.id);
        }
      },
      onWaliReassigned: onWaliReassigned,
    );
  }

  /// Legacy stat-item helper kept for back-compat with the mixin
  /// contract; the screen now uses `BrandKpiStrip` for KPIs.
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

  /// Handles a tap on the row (excluding the wali chip).
  void handleClassCardTap(Map<String, dynamic> classItem, bool isAssigned);

  /// Called after the wali kelas assignment changes so the screen can
  /// reload its data and refresh the inline wali chip.
  void onWaliReassigned();
}

/// Single class row used in the Mata Pelajaran detail list. Layout:
///
///   ┌──────────────────────────────────────────┐
///   │ ⬛  Tingkat 7                  Tambah →   │
///   │     7A                                    │
///   │     [● Terdaftar] [Wali: Ahmad Y.]       │   ← chip rows
///   └──────────────────────────────────────────┘
class _ClassRow extends StatelessWidget {
  final Classroom model;
  final bool isAssigned;
  final bool selected;
  final VoidCallback onTapRow;
  final void Function(BuildContext context) onLongPressRow;
  final VoidCallback onWaliReassigned;

  const _ClassRow({
    required this.model,
    required this.isAssigned,
    required this.selected,
    required this.onTapRow,
    required this.onLongPressRow,
    required this.onWaliReassigned,
  });

  Future<void> _openWaliSheet(BuildContext context) async {
    final changed = await AssignWaliKelasSheet.show(
      context: context,
      classId: model.id,
      className: model.name.isEmpty ? 'Kelas' : model.name,
    );
    if (changed == true) onWaliReassigned();
  }

  @override
  Widget build(BuildContext context) {
    final adminAccent = ColorUtils.getRoleColor('admin');
    final accent = isAssigned ? ColorUtils.success600 : ColorUtils.slate500;
    final ctaColor = isAssigned ? ColorUtils.error600 : adminAccent;
    final ctaLabel = isAssigned ? 'Lepas' : 'Tambah';

    final tingkat = (model.gradeLevel ?? '').trim();
    final waliName = (model.homeroomTeacherName ?? '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: onTapRow,
          onLongPress: () => onLongPressRow(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? adminAccent.withValues(alpha: 0.04)
                  : Colors.white,
              border: Border.all(
                color: selected ? adminAccent : ColorUtils.slate200,
                width: selected ? 1.4 : 0.75,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _LeadingIcon(color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tingkat.isNotEmpty) ...[
                        Text(
                          'Tingkat $tingkat',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: ColorUtils.slate500,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],
                      Text(
                        model.name.isEmpty ? 'Kelas' : model.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: ColorUtils.slate900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusPill(isAssigned: isAssigned),
                          if (isAssigned)
                            _WaliChip(
                              waliName: waliName,
                              onTap: () => _openWaliSheet(context),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selected)
                  Icon(Icons.check_circle_rounded, size: 22, color: adminAccent)
                else
                  Text(
                    '$ctaLabel →',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: ctaColor,
                      height: 1.0,
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

class _LeadingIcon extends StatelessWidget {
  final Color color;

  const _LeadingIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Icon(Icons.class_outlined, color: color, size: 22),
    );
  }
}

/// Inline status pill (dot + text) shown below the class name. Solid
/// green for Terdaftar, slate for Belum terdaftar.
class _StatusPill extends StatelessWidget {
  final bool isAssigned;

  const _StatusPill({required this.isAssigned});

  @override
  Widget build(BuildContext context) {
    final color = isAssigned ? ColorUtils.success600 : ColorUtils.slate500;
    final label = isAssigned ? 'Terdaftar' : 'Belum terdaftar';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

/// Tappable wali kelas chip. Indigo when set (2-letter initial in a
/// circle + name), amber with warning icon when missing.
class _WaliChip extends StatelessWidget {
  final String waliName;
  final VoidCallback onTap;

  const _WaliChip({required this.waliName, required this.onTap});

  bool get _hasWali => waliName.isNotEmpty;

  String get _initials {
    final t = waliName.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _hasWali
        ? const Color(0xFFE0EAFF) // indigo-50
        : const Color(0xFFFEF3C7); // amber-50
    final fg = _hasWali
        ? const Color(0xFF4F46E5) // indigo-600
        : const Color(0xFFB45309); // amber-700

    return Material(
      color: bg,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 3, 7, 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasWali) ...[
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: Text(
                    'Wali: $waliName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: fg,
                      height: 1.1,
                    ),
                  ),
                ),
              ] else ...[
                Icon(Icons.warning_amber_rounded, size: 13, color: fg),
                const SizedBox(width: 4),
                Text(
                  'Wali belum diset',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
