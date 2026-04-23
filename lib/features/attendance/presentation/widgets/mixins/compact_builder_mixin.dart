import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Compact mode builder for attendance student item.
///
/// Single row layout: [# avatar name ── H T S I A]
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        children: [
          _buildIndexNumber(),
          const SizedBox(width: 6),
          _buildStudentName(),
          const SizedBox(width: 4),
          _buildCompactButtons(lowerStatus),
        ],
      ),
    );
  }

  Widget _buildIndexNumber() {
    return SizedBox(
      width: 18,
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: ColorUtils.slate400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStudentName() {
    return Expanded(
      child: Text(
        student.name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ColorUtils.slate800,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildCompactButtons(String lowerStatus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: _compactButtonList(lowerStatus),
    );
  }

  List<Widget> _compactButtonList(String lowerStatus) {
    return [
      _CompactButton(
        label: 'H',
        color: ColorUtils.success600,
        isSelected: lowerStatus == 'hadir',
        tooltip: getStatusText('hadir'),
        onTap: () => onStatusChanged(student.id, 'hadir'),
      ),
      const SizedBox(width: 3),
      _CompactButton(
        label: 'T',
        color: ColorUtils.violet700,
        isSelected: lowerStatus == 'terlambat',
        tooltip: getStatusText('terlambat'),
        onTap: () => onStatusChanged(student.id, 'terlambat'),
      ),
      const SizedBox(width: 3),
      _CompactButton(
        label: 'S',
        color: ColorUtils.warning600,
        isSelected: lowerStatus == 'sakit',
        tooltip: getStatusText('sakit'),
        onTap: () => onStatusChanged(student.id, 'sakit'),
      ),
      const SizedBox(width: 3),
      _CompactButton(
        label: 'I',
        color: ColorUtils.info600,
        isSelected: lowerStatus == 'izin',
        tooltip: getStatusText('izin'),
        onTap: () => onStatusChanged(student.id, 'izin'),
      ),
      const SizedBox(width: 3),
      _CompactButton(
        label: 'A',
        color: ColorUtils.error600,
        isSelected: lowerStatus == 'alpha',
        tooltip: getStatusText('alpha'),
        onTap: () => onStatusChanged(student.id, 'alpha'),
      ),
    ];
  }
}

/// Compact button widget: 36px square with letter.
class _CompactButton extends StatelessWidget {
  final String label;
  final String tooltip;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactButton({
    required this.label,
    required this.tooltip,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
