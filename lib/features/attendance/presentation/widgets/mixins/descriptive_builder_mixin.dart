import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/status_badge.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Descriptive mode builder for attendance student item.
///
/// Two-row layout: [# avatar name ── badge]
///                 [Hadir] [Terlambat] [Sakit] [Izin] [Alpha]
///
/// Requires:
/// - student: Student model
/// - currentStatus: Current attendance status
/// - onStatusChanged: Callback for status changes
/// - getStatusColor: Function to get status color
/// - getStatusText: Function to get status text
/// - getAvatarColor: Function to get avatar color
mixin DescriptiveBuilderMixin {
  Student get student;
  String get currentStatus;
  int get index;
  void Function(String studentId, String status) get onStatusChanged;

  Color getStatusColor(String status);
  String getStatusText(String status);
  Color getAvatarColor(String name);

  /// Builds descriptive two-row layout.
  Widget buildDescriptiveLayout() {
    final lowerStatus = currentStatus.toLowerCase();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        children: [
          _buildHeaderRow(),
          const SizedBox(height: 8),
          _buildButtonsRow(lowerStatus),
        ],
      ),
    );
  }

  Widget _buildHeaderRow() {
    final avatarColor = getAvatarColor(student.name);
    final statusColor = getStatusColor(currentStatus);
    final statusLabel = getStatusText(currentStatus);

    return Row(
      children: [
        _buildIndexNumber(),
        _buildAvatar(avatarColor),
        const SizedBox(width: 10),
        _buildStudentName(),
        const SizedBox(width: 8),
        _buildStatusBadge(statusColor, statusLabel),
      ],
    );
  }

  Widget _buildIndexNumber() {
    return SizedBox(
      width: 22,
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: ColorUtils.slate400,
        ),
      ),
    );
  }

  Widget _buildAvatar(Color avatarColor) {
    return CircleAvatar(
      radius: 15,
      backgroundColor: avatarColor.withValues(alpha: 0.15),
      child: Text(
        student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
        style: TextStyle(
          color: avatarColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildStudentName() {
    return Expanded(
      child: Text(
        student.name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: ColorUtils.slate800,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusBadge(Color statusColor, String statusLabel) {
    return StatusBadge(label: statusLabel, color: statusColor);
  }

  Widget _buildButtonsRow(String lowerStatus) {
    return Row(children: _labeledButtonList(lowerStatus));
  }

  List<Widget> _labeledButtonList(String lowerStatus) {
    return [
      _LabeledButton(
        label: getStatusText('hadir'),
        color: ColorUtils.success600,
        isSelected: lowerStatus == 'hadir',
        onTap: () => onStatusChanged(student.id, 'hadir'),
      ),
      const SizedBox(width: 5),
      _LabeledButton(
        label: getStatusText('terlambat'),
        color: ColorUtils.violet700,
        isSelected: lowerStatus == 'terlambat',
        onTap: () => onStatusChanged(student.id, 'terlambat'),
      ),
      const SizedBox(width: 5),
      _LabeledButton(
        label: getStatusText('sakit'),
        color: ColorUtils.warning600,
        isSelected: lowerStatus == 'sakit',
        onTap: () => onStatusChanged(student.id, 'sakit'),
      ),
      const SizedBox(width: 5),
      _LabeledButton(
        label: getStatusText('izin'),
        color: ColorUtils.info600,
        isSelected: lowerStatus == 'izin',
        onTap: () => onStatusChanged(student.id, 'izin'),
      ),
      const SizedBox(width: 5),
      _LabeledButton(
        label: getStatusText('alpha'),
        color: ColorUtils.error600,
        isSelected: lowerStatus == 'alpha',
        onTap: () => onStatusChanged(student.id, 'alpha'),
      ),
    ];
  }
}

/// Labeled button: Expanded, shows full text.
class _LabeledButton extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _LabeledButton({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          decoration: BoxDecoration(
            color: isSelected ? color : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : color.withValues(alpha: 0.25),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}
