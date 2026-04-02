// Student row for attendance input with two display modes:
// - compact:     single row  [# avatar name ── H T S I A]
// - descriptive: two rows    [# avatar name ── badge]
//                            [Hadir] [Terlambat] [Sakit] [Izin] [Alpha]
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class AttendanceStudentItem extends StatelessWidget {
  final Student student;
  final String currentStatus;
  final void Function(String studentId, String status) onStatusChanged;
  final LanguageProvider languageProvider;
  final int index;
  final bool compactMode;

  const AttendanceStudentItem({
    super.key,
    required this.student,
    required this.currentStatus,
    required this.onStatusChanged,
    required this.languageProvider,
    this.index = 0,
    this.compactMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return compactMode ? _buildCompact(context) : _buildDescriptive();
  }

  // ── Compact: single row ──────────────────────────────────────────────────

  Widget _buildCompact(BuildContext context) {
    final avatarColor = _avatarColor(student.name);
    final lowerStatus = currentStatus.toLowerCase();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate400,
              ),
            ),
          ),
          CircleAvatar(
            radius: 14,
            backgroundColor: avatarColor.withValues(alpha: 0.15),
            child: Text(
              student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: avatarColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tap name to show full name + NIS in a SnackBar
          Expanded(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${student.name} — NIS: ${student.studentNumber}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                );
              },
              child: Text(
                student.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Inline letter buttons
          _CompactButton(label: 'H', color: ColorUtils.success600, isSelected: lowerStatus == 'hadir', tooltip: attendanceStatusText('hadir', languageProvider), onTap: () => onStatusChanged(student.id, 'hadir')),
          const SizedBox(width: 4),
          _CompactButton(label: 'T', color: ColorUtils.violet700, isSelected: lowerStatus == 'terlambat', tooltip: attendanceStatusText('terlambat', languageProvider), onTap: () => onStatusChanged(student.id, 'terlambat')),
          const SizedBox(width: 4),
          _CompactButton(label: 'S', color: ColorUtils.warning600, isSelected: lowerStatus == 'sakit', tooltip: attendanceStatusText('sakit', languageProvider), onTap: () => onStatusChanged(student.id, 'sakit')),
          const SizedBox(width: 4),
          _CompactButton(label: 'I', color: ColorUtils.info600, isSelected: lowerStatus == 'izin', tooltip: attendanceStatusText('izin', languageProvider), onTap: () => onStatusChanged(student.id, 'izin')),
          const SizedBox(width: 4),
          _CompactButton(label: 'A', color: ColorUtils.error600, isSelected: lowerStatus == 'alpha', tooltip: attendanceStatusText('alpha', languageProvider), onTap: () => onStatusChanged(student.id, 'alpha')),
        ],
      ),
    );
  }

  // ── Descriptive: two rows with full labels ───────────────────────────────

  Widget _buildDescriptive() {
    final avatarColor = _avatarColor(student.name);
    final statusColor = attendanceStatusColor(currentStatus);
    final statusLabel = attendanceStatusText(currentStatus, languageProvider);
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
          // Row 1: Number + Avatar + Name + Status badge
          Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate400,
                  ),
                ),
              ),
              CircleAvatar(
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
              ),
              const SizedBox(width: 10),
              Expanded(
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
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Full-width labeled buttons
          Row(
            children: [
              _LabeledButton(label: attendanceStatusText('hadir', languageProvider), color: ColorUtils.success600, isSelected: lowerStatus == 'hadir', onTap: () => onStatusChanged(student.id, 'hadir')),
              const SizedBox(width: 5),
              _LabeledButton(label: attendanceStatusText('terlambat', languageProvider), color: ColorUtils.violet700, isSelected: lowerStatus == 'terlambat', onTap: () => onStatusChanged(student.id, 'terlambat')),
              const SizedBox(width: 5),
              _LabeledButton(label: attendanceStatusText('sakit', languageProvider), color: ColorUtils.warning600, isSelected: lowerStatus == 'sakit', onTap: () => onStatusChanged(student.id, 'sakit')),
              const SizedBox(width: 5),
              _LabeledButton(label: attendanceStatusText('izin', languageProvider), color: ColorUtils.info600, isSelected: lowerStatus == 'izin', onTap: () => onStatusChanged(student.id, 'izin')),
              const SizedBox(width: 5),
              _LabeledButton(label: attendanceStatusText('alpha', languageProvider), color: ColorUtils.error600, isSelected: lowerStatus == 'alpha', onTap: () => onStatusChanged(student.id, 'alpha')),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Compact button: 36px square with letter, 44px touch target ───────────

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

// ── Labeled button: Expanded, shows full text like "Hadir" ───────────────

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

// ---------------------------------------------------------------------------
// Pure helper functions
// ---------------------------------------------------------------------------

Color attendanceStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'hadir':
      return Colors.green;
    case 'sakit':
      return Colors.orange;
    case 'izin':
      return Colors.blue;
    case 'alpha':
      return Colors.red;
    case 'terlambat':
      return Colors.purple;
    default:
      return Colors.green;
  }
}

String attendanceStatusText(
  String status,
  LanguageProvider languageProvider,
) {
  switch (status.toLowerCase()) {
    case 'hadir':
      return languageProvider.getTranslatedText({
        'en': 'Present',
        'id': 'Hadir',
      });
    case 'sakit':
      return languageProvider.getTranslatedText({
        'en': 'Sick',
        'id': 'Sakit',
      });
    case 'izin':
      return languageProvider.getTranslatedText({
        'en': 'Permission',
        'id': 'Izin',
      });
    case 'alpha':
      return languageProvider.getTranslatedText({
        'en': 'Absent',
        'id': 'Alpha',
      });
    case 'terlambat':
      return languageProvider.getTranslatedText({
        'en': 'Late',
        'id': 'Terlambat',
      });
    default:
      return languageProvider.getTranslatedText({
        'en': 'Present',
        'id': 'Hadir',
      });
  }
}

Color _avatarColor(String name) {
  final index = name.isNotEmpty ? name.codeUnitAt(0) % 6 : 0;
  return ColorUtils.getColorForIndex(index);
}
