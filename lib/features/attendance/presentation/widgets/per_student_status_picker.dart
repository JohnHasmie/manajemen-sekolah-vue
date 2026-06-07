// Per-student status picker — Frame E from
// `_design/teacher_attendance_detail_mockup.html`.
//
// Opens when the teacher taps a saved-status pill in the attendance
// detail screen. Renders five status tiles (Hadir / Telat / Sakit /
// Izin / Alpa) plus an optional notes field, then dispatches an
// `(status, note)` callback when the teacher taps Terapkan.
//
// Caller wires the callback to the existing
// `TeacherAttendanceController.updateStatus` + `saveChanges` chain so
// the change persists through the same path the bulk-edit FAB uses.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Public entrypoint for the picker — keep the private state class
/// out of imports so callers always go through this helper.
Future<void> showPerStudentStatusPicker({
  required BuildContext context,
  required Student student,
  required String className,
  required String initialStatus,
  String? initialNote,
  required Future<void> Function(String status, String? note) onApply,
}) {
  return AppBottomSheet.show<void>(
    context: context,
    title: student.name,
    subtitle:
        '$className · NIS ${student.studentNumber} · '
        '${kAttTapStatusToChange.tr}',
    icon: Icons.edit_note_rounded,
    primaryColor: ColorUtils.getRoleColor('guru'),
    contentPadding: EdgeInsets.zero,
    content: _PerStudentStatusPickerBody(
      initialStatus: initialStatus,
      initialNote: initialNote,
      onApply: onApply,
    ),
  );
}

class _PerStudentStatusPickerBody extends StatefulWidget {
  final String initialStatus;
  final String? initialNote;
  final Future<void> Function(String status, String? note) onApply;

  const _PerStudentStatusPickerBody({
    required this.initialStatus,
    required this.initialNote,
    required this.onApply,
  });

  @override
  State<_PerStudentStatusPickerBody> createState() =>
      _PerStudentStatusPickerBodyState();
}

class _PerStudentStatusPickerBodyState
    extends State<_PerStudentStatusPickerBody> {
  late String _selected;
  late final TextEditingController _noteCtrl;
  bool _saving = false;

  // Frame E mockup uses 4 tiles; drop Telat from the picker. A row
  // already saved with status='terlambat' will normalise to 'hadir'
  // on open, so the teacher can explicitly switch to Sakit/Izin/Alpa
  // if desired. Re-add Telat here if a future mockup brings it back.
  static const _statuses = <_StatusOption>[
    _StatusOption(
      key: 'hadir',
      label: 'Hadir',
      icon: Icons.check_rounded,
      colorRef: _StatusColor.success,
    ),
    _StatusOption(
      key: 'sakit',
      label: 'Sakit',
      icon: Icons.medication_outlined,
      colorRef: _StatusColor.warning,
    ),
    _StatusOption(
      key: 'izin',
      label: 'Izin',
      icon: Icons.assignment_turned_in_outlined,
      colorRef: _StatusColor.info,
    ),
    _StatusOption(
      key: 'alpha',
      label: 'Alpa',
      icon: Icons.close_rounded,
      colorRef: _StatusColor.error,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selected = _normalize(widget.initialStatus);
    _noteCtrl = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  String _normalize(String s) {
    final l = s.toLowerCase();
    if (l == 'present') return 'hadir';
    if (l == 'late') return 'terlambat';
    if (l == 'sick') return 'sakit';
    if (l == 'permission' || l == 'excused') return 'izin';
    if (l == 'absent') return 'alpha';
    return l;
  }

  Color _resolve(_StatusColor c) {
    switch (c) {
      case _StatusColor.success:
        return ColorUtils.success600;
      case _StatusColor.violet:
        return ColorUtils.violet700;
      case _StatusColor.warning:
        return ColorUtils.warning600;
      case _StatusColor.info:
        return ColorUtils.info600;
      case _StatusColor.error:
        return ColorUtils.error600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = ColorUtils.getRoleColor('guru');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _statuses
                .map(
                  (opt) => _StatusTile(
                    label: opt.label,
                    icon: opt.icon,
                    color: _resolve(opt.colorRef),
                    isSelected: _selected == opt.key,
                    onTap: _saving
                        ? null
                        : () => setState(() => _selected = opt.key),
                  ),
                )
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kAttNotesOptional.tr,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _noteCtrl,
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                style: TextStyle(
                  fontSize: 12,
                  color: ColorUtils.slate800,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: kAttNotesPlaceholder.tr,
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate400,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ColorUtils.slate200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        BottomSheetFooter(
          primaryLabel: _saving ? kAttSaving.tr : kAttApply.tr,
          primaryColor: primary,
          primaryEnabled: !_saving,
          onPrimary: _onApply,
          onSecondary: _saving ? () {} : () => AppNavigator.pop(context),
        ),
      ],
    );
  }

  Future<void> _onApply() async {
    if (_saving) return;
    setState(() => _saving = true);
    final note = _noteCtrl.text.trim();
    try {
      await widget.onApply(_selected, note.isEmpty ? null : note);
      if (mounted) AppNavigator.pop(context);
    } catch (_) {
      // Errors are surfaced by the caller (controller logs + snackbar
      // in the existing save path); we just unblock the sheet.
      if (mounted) setState(() => _saving = false);
    }
  }
}

enum _StatusColor { success, violet, warning, info, error }

class _StatusOption {
  final String key;
  final String label;
  final IconData icon;
  final _StatusColor colorRef;
  const _StatusOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.colorRef,
  });
}

class _StatusTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const _StatusTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 5 tiles share the row width; on a 360dp phone with 16dp side
    // padding and 8dp gaps the available width is ~288dp → 56dp/tile.
    // We give a small minimum and a large flex so they fill on wider
    // screens too.
    return SizedBox(
      width: _tileWidth(MediaQuery.of(context).size.width),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 76,
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : ColorUtils.slate200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? color : ColorUtils.slate500,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? color : ColorUtils.slate700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _tileWidth(double screenWidth) {
    // Total side padding 32 + 4 gaps × 8 = 64 reserved; divide by 5.
    final available = (screenWidth - 32 - 32) / 5;
    return available.clamp(48.0, 80.0);
  }
}
