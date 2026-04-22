// Conflict resolution dialog for handling schedule conflicts.
//
// Like a Vue component `<ConflictResolverModal>` that appears when the
// backend returns a 409 Conflict response (similar to Laravel validation
// returning conflicting schedule errors). Lets the user pick which
// conflicting schedule to delete before retrying.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';

/// A dialog that shows conflicting schedules and lets the user select one to delete.
///
/// Like a Vue component `<ConflictResolutionDialog>` with props:
/// - [conflictingSchedules] - list of schedule maps that overlap (from API 409 response)
/// - [onDeleteConfirmed] - callback with the selected schedule ID to delete
/// - [onCancel] - callback when the user cancels
///
/// Uses radio buttons for single selection, similar to a Vue `<v-radio-group>`.
class ConflictResolutionDialog extends ConsumerStatefulWidget {
  final List<dynamic> conflictingSchedules;
  final Function(String) onDeleteConfirmed;
  final Function() onCancel;

  const ConflictResolutionDialog({
    super.key,
    required this.conflictingSchedules,
    required this.onDeleteConfirmed,
    required this.onCancel,
  });

  @override
  ConsumerState<ConflictResolutionDialog> createState() =>
      ConflictResolutionDialogState();
}

/// State for [ConflictResolutionDialog]. Tracks which schedule the user selected.
/// Like Vue's `data() { return { selectedId: null } }`.
class ConflictResolutionDialogState
    extends ConsumerState<ConflictResolutionDialog> {
  String? _selectedScheduleToDelete;

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    languageProvider.getTranslatedText({
                      'en': 'Schedule Conflict Detected',
                      'id': 'Terdeteksi Jadwal Bentrok',
                    }),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),

            // Description
            Text(
              languageProvider.getTranslatedText({
                'en':
                    'The following schedules conflict with each other. Please select one to delete:',
                'id':
                    'Jadwal berikut konflik satu sama lain. Pilih salah satu untuk dihapus:',
              }),
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),

            const SizedBox(height: AppSpacing.xl),

            // List of conflicting schedules
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: RadioGroup<String>(
                groupValue: _selectedScheduleToDelete,
                onChanged: (value) {
                  setState(() {
                    _selectedScheduleToDelete = value;
                  });
                },
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.conflictingSchedules.length,
                  itemBuilder: (context, index) {
                    final schedule = widget.conflictingSchedules[index];
                    return _buildScheduleItem(schedule, languageProvider);
                  },
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    child: Text(
                      AppLocalizations.cancel.tr,
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedScheduleToDelete != null
                        ? () => widget.onDeleteConfirmed(
                            _selectedScheduleToDelete!,
                          )
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedScheduleToDelete != null
                          ? Colors.red.shade600
                          : Colors.grey.shade400,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Delete Selected',
                        'id': 'Hapus yang Dipilih',
                      }),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single schedule radio item showing subject, teacher, class, and time.
  /// Like a `<ScheduleRadioItem>` Vue component inside a `v-for` loop.
  Widget _buildScheduleItem(
    dynamic schedule,
    LanguageProvider languageProvider,
  ) {
    final model = Schedule.fromJson(
      Map<String, dynamic>.from(schedule as Map),
    );
    final scheduleId = model.id;
    final isSelected = _selectedScheduleToDelete == scheduleId;
    final startTime = (model.startTime ?? '');
    final endTime = (model.endTime ?? '');
    final startDisplay = startTime.length >= 5
        ? startTime.substring(0, 5)
        : startTime;
    final endDisplay = endTime.length >= 5 ? endTime.substring(0, 5) : endTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? Colors.red.shade400 : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        color: isSelected ? Colors.red.shade50 : Colors.white,
      ),
      child: RadioListTile<String>(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (model.subjectName ?? '').isEmpty
                  ? 'No Subject'
                  : model.subjectName!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${languageProvider.getTranslatedText({'en': 'Teacher', 'id': 'Guru'})}: ${(model.teacherName ?? '').isEmpty ? 'No Teacher' : model.teacherName}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              '${languageProvider.getTranslatedText({'en': 'Class', 'id': 'Kelas'})}: ${(model.className ?? '').isEmpty ? 'No Class' : model.className}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              '${languageProvider.getTranslatedText({'en': 'Time', 'id': 'Waktu'})}: $startDisplay - $endDisplay',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        value: scheduleId,
        activeColor: Colors.red.shade600,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
