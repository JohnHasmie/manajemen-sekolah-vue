// Bottom sheet for bulk-setting all students to a single attendance status.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

typedef OnStatusSelected = void Function(String status);

class AttendanceQuickActionsSheet extends StatelessWidget {
  final LanguageProvider languageProvider;
  final OnStatusSelected onStatusSelected;

  const AttendanceQuickActionsSheet({
    super.key,
    required this.languageProvider,
    required this.onStatusSelected,
  });

  String _tr(Map<String, String> map) =>
      languageProvider.getTranslatedText(map);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ColorUtils.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            _tr({
              'en': 'Mark All Students As',
              'id': 'Tandai Semua Siswa Sebagai',
            }),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _tr({
              'en': 'Tap a status to apply to all students',
              'id': 'Ketuk status untuk diterapkan ke semua siswa',
            }),
            style: TextStyle(fontSize: 12, color: ColorUtils.slate400),
          ),
          const SizedBox(height: 16),
          // Status options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatusOption(
                  status: 'hadir',
                  label: _tr({'en': 'Present', 'id': 'Hadir'}),
                  icon: Icons.check_circle_outline,
                  color: ColorUtils.success600,
                  onTap: () => _select(context, 'hadir'),
                ),
                const SizedBox(width: 8),
                _StatusOption(
                  status: 'terlambat',
                  label: _tr({'en': 'Late', 'id': 'Terlambat'}),
                  icon: Icons.watch_later_outlined,
                  color: ColorUtils.violet700,
                  onTap: () => _select(context, 'terlambat'),
                ),
                const SizedBox(width: 8),
                _StatusOption(
                  status: 'sakit',
                  label: _tr({'en': 'Sick', 'id': 'Sakit'}),
                  icon: Icons.local_hospital_outlined,
                  color: ColorUtils.warning600,
                  onTap: () => _select(context, 'sakit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _StatusOption(
                  status: 'izin',
                  label: _tr({'en': 'Permission', 'id': 'Izin'}),
                  icon: Icons.assignment_turned_in_outlined,
                  color: ColorUtils.info600,
                  onTap: () => _select(context, 'izin'),
                ),
                const SizedBox(width: 8),
                _StatusOption(
                  status: 'alpha',
                  label: _tr({'en': 'Absent', 'id': 'Alpha'}),
                  icon: Icons.cancel_outlined,
                  color: ColorUtils.error600,
                  onTap: () => _select(context, 'alpha'),
                ),
                const SizedBox(width: 8),
                // Empty spacer to keep 3-column grid
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  void _select(BuildContext context, String status) {
    onStatusSelected(status);
    Navigator.of(context).pop();
  }
}

/// Card-style status option with icon, label, and tap animation.
class _StatusOption extends StatelessWidget {
  final String status;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
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
