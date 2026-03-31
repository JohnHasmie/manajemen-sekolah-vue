// Bottom sheet widget for bulk-setting all students to a single attendance status.
// Extracted from TeacherAttendanceScreen._showQuickActionsSheet.
//
// Think of this like a Vue <AttendanceQuickActions> component that emits
// an event when the teacher picks a status to apply to everyone.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Callback signature: receives the raw status string
/// (e.g. 'hadir', 'terlambat', 'izin', 'sakit', 'alpha').
typedef OnStatusSelected = void Function(String status);

/// Content widget shown inside a modal bottom sheet.
/// Displays five attendance statuses the teacher can tap to apply to all students.
///
/// Usage:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   backgroundColor: Colors.transparent,
///   builder: (_) => AttendanceQuickActionsSheet(
///     languageProvider: languageProvider,
///     onStatusSelected: (status) { ... },
///   ),
/// );
/// ```
class AttendanceQuickActionsSheet extends StatelessWidget {
  final LanguageProvider languageProvider;
  final OnStatusSelected onStatusSelected;

  const AttendanceQuickActionsSheet({
    super.key,
    required this.languageProvider,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            languageProvider.getTranslatedText({
              'en': 'Set All Students To',
              'id': 'Atur Semua Siswa Menjadi',
            }),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildOption(context, 'hadir'),
          _buildOption(context, 'terlambat'),
          _buildOption(context, 'izin'),
          _buildOption(context, 'sakit'),
          _buildOption(context, 'alpha'),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String status) {
    return ListTile(
      leading: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
      title: Text(_getStatusText(status)),
      onTap: () {
        onStatusSelected(status);
        Navigator.of(context).pop();
      },
    );
  }

  // ---- Status helpers (duplicated from the screen so the widget is self-contained) ----

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'hadir':
        return Icons.check_circle;
      case 'terlambat':
        return Icons.watch_later;
      case 'izin':
        return Icons.assignment_turned_in;
      case 'sakit':
        return Icons.local_hospital;
      case 'alpha':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  Color _getStatusColor(String status) {
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

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return languageProvider.getTranslatedText({'en': 'Present', 'id': 'Hadir'});
      case 'sakit':
        return languageProvider.getTranslatedText({'en': 'Sick', 'id': 'Sakit'});
      case 'izin':
        return languageProvider.getTranslatedText({'en': 'Permission', 'id': 'Izin'});
      case 'alpha':
        return languageProvider.getTranslatedText({'en': 'Absent', 'id': 'Alpha'});
      case 'terlambat':
        return languageProvider.getTranslatedText({'en': 'Late', 'id': 'Terlambat'});
      default:
        return languageProvider.getTranslatedText({'en': 'Present', 'id': 'Hadir'});
    }
  }
}
