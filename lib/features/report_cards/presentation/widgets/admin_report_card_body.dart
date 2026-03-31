// Body widget for AdminReportCardScreen — class selector dropdown and student list.
// Replaces _buildBody() from admin_report_card_screen.dart.
// Like a Vue <template> section extracted into its own component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Stateless body for the admin report card screen.
///
/// Receives all state as constructor params — like Vue props — and fires
/// callbacks upward instead of calling setState directly (like Vue `$emit`).
class AdminReportCardBody extends StatelessWidget {
  /// All currently available classes (from API / cache).
  final List<dynamic> classes;

  /// The currently selected class, or null if none chosen yet.
  final Map<String, dynamic>? selectedClass;

  /// Students in [selectedClass] with their raport status.
  final List<dynamic> students;

  /// True while students are being fetched for the selected class.
  final bool isLoadingStudents;

  /// Primary brand colour for avatars and accents.
  final Color primaryColor;

  /// GlobalKey forwarded from the screen so the tour overlay can target it.
  final GlobalKey selectClassKey;

  /// GlobalKey forwarded from the screen so the tour overlay can target it.
  final GlobalKey studentListKey;

  /// Called when the user picks a class from the dropdown.
  /// Parent clears [students] and starts loading via setState + _loadStudents.
  final void Function(Map<String, dynamic>? cls) onClassChanged;

  /// Called when a student row is tapped — navigates to the detail screen.
  final void Function(Map<String, dynamic> student) onViewDetail;

  /// Called when the PDF icon is tapped for a student.
  final void Function(Map<String, dynamic> student) onDownloadPdf;

  const AdminReportCardBody({
    super.key,
    required this.classes,
    required this.selectedClass,
    required this.students,
    required this.isLoadingStudents,
    required this.primaryColor,
    required this.selectClassKey,
    required this.studentListKey,
    required this.onClassChanged,
    required this.onViewDetail,
    required this.onDownloadPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Class Selection — like a <select> in HTML / DropdownField in Vue
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Kelas',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                key: selectClassKey,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  color: Colors.grey[50],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    isExpanded: true,
                    value: selectedClass,
                    hint: Text(AppLocalizations.selectClass.tr),
                    items: classes.map((cls) {
                      return DropdownMenuItem<Map<String, dynamic>>(
                        value: cls,
                        child: Text(cls['name']?.toString() ?? 'Unknown'),
                      );
                    }).toList(),
                    // Fire callback up to parent — parent calls setState + _loadStudents
                    onChanged: onClassChanged,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Students list — shows spinner, empty states, or the actual list
        Expanded(
          child: isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
              : selectedClass == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.class_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Silakan pilih kelas terlebih dahulu',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : students.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada data siswa',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  key: studentListKey,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final status = student['raport_status'] ?? 'draft';

                    // Map status string → colour/text/icon — like a computed
                    // property in Vue: `statusBadge` computed from `student.status`
                    Color statusColor;
                    String statusText;
                    IconData statusIcon;

                    if (status == 'published') {
                      statusColor = Colors.green;
                      statusText = 'Terkirim';
                      statusIcon = Icons.check_circle;
                    } else if (status == 'final') {
                      statusColor = Colors.blue;
                      statusText = 'Final';
                      statusIcon = Icons.save;
                    } else {
                      statusColor = Colors.orange;
                      statusText = 'Draft';
                      statusIcon = Icons.edit_note;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        onTap: () => onViewDetail(student),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: [
                              // Avatar initial — like a Vue computed `initials`
                              CircleAvatar(
                                backgroundColor: primaryColor.withValues(
                                  alpha: 0.1,
                                ),
                                child: Text(
                                  (student['student_name'] ?? '?')[0]
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.lg),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      student['student_name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'NIS: ${student['student_number'] ?? '-'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Status badge chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      statusIcon,
                                      size: 14,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              IconButton(
                                icon: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),
                                onPressed: () => onDownloadPdf(student),
                                tooltip: 'Cetak PDF',
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(AppSpacing.xs),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
