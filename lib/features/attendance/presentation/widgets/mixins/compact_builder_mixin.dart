import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Compact mode builder for attendance student item.
///
/// Single-row layout (Frame A from `_design/teacher_attendance_detail_mockup.html`):
///
///   `[ name + NIS ── Hadir | Telat | Sakit | Izin | Alpa ]`
///
/// The avatar and order number are intentionally dropped so the row can
/// fit five full-word status buttons on a single line at ≈40dp tall —
/// thumb-friendly while still scannable.
///
/// Requires:
/// - student: Student model
/// - currentStatus: Current attendance status
/// - onStatusChanged: Callback for status changes
/// - getStatusColor: Function to get status color
/// - getStatusText: Function to get status text
mixin CompactBuilderMixin {
  Student get student;
  String get currentStatus;
  int get index;
  void Function(String studentId, String status) get onStatusChanged;

  Color getStatusColor(String status);
  String getStatusText(String status);

  /// Builds compact single-row layout.
  Widget buildCompactLayout(BuildContext context) {
    final lowerStatus = currentStatus.toLowerCase();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          _buildStudentBlock(),
          const SizedBox(width: 8),
          _buildWordButtons(lowerStatus),
        ],
      ),
    );
  }

  Widget _buildStudentBlock() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            student.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate900,
              height: 1.15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            'NIS ${student.studentNumber}',
            style: TextStyle(
              fontSize: 10,
              color: ColorUtils.slate500,
              fontWeight: FontWeight.w500,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWordButtons(String lowerStatus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WordButton(
          label: 'Hadir',
          color: ColorUtils.success600,
          isSelected: lowerStatus == 'hadir',
          onTap: () => onStatusChanged(student.id, 'hadir'),
        ),
        const SizedBox(width: 4),
        _WordButton(
          label: 'Telat',
          color: ColorUtils.violet700,
          isSelected: lowerStatus == 'terlambat',
          onTap: () => onStatusChanged(student.id, 'terlambat'),
        ),
        const SizedBox(width: 4),
        _WordButton(
          label: 'Sakit',
          color: ColorUtils.warning600,
          isSelected: lowerStatus == 'sakit',
          onTap: () => onStatusChanged(student.id, 'sakit'),
        ),
        const SizedBox(width: 4),
        _WordButton(
          label: 'Izin',
          color: ColorUtils.info600,
          isSelected: lowerStatus == 'izin',
          onTap: () => onStatusChanged(student.id, 'izin'),
        ),
        const SizedBox(width: 4),
        _WordButton(
          label: 'Alpa',
          color: ColorUtils.error600,
          isSelected: lowerStatus == 'alpha',
          onTap: () => onStatusChanged(student.id, 'alpha'),
        ),
      ],
    );
  }
}

/// Word button: ~42dp wide × 40dp tall, full-word label.
///
/// Active state fills with the status colour and bumps the border weight.
/// Inactive sits on a light tint of the colour so the row still reads as
/// a coloured palette at a glance.
class _WordButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _WordButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Match Frame A mockup styling exactly:
    //   selected   → color-50 fill + color-600 text + color-600 border
    //   unselected → slate-100 fill + slate-500 text + no border
    // Neutral unselected state means only the active status pops out
    // visually — the row reads as a single colored chip surrounded by
    // four "available" greys, instead of five competing pastel chips.
    final bgColor = isSelected
        ? Color.alphaBlend(color.withValues(alpha: 0.10), Colors.white)
        : ColorUtils.slate100;
    final fgColor = isSelected ? color : ColorUtils.slate500;
    final borderColor = isSelected ? color : Colors.transparent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 42,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 0),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fgColor,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
