// Body widget for AdminReportCardScreen — class selector dropdown and student list.
// Replaces _buildBody() from admin_report_card_screen.dart.
// Like a Vue <template> section extracted into its own component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

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
    // When no class is selected yet, show a tappable grid of class cards.
    // Once a class is selected, show the dropdown + student list.
    if (selectedClass == null) {
      return _buildClassGrid();
    }

    return Column(
      children: [
        // Class selector — compact dropdown for switching after initial pick
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
                    onChanged: onClassChanged,
                  ),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Students list
        Expanded(
          child: isLoadingStudents
              ? const Center(child: CircularProgressIndicator())
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
                  itemBuilder: (context, index) =>
                      _buildStudentRow(students[index] as Map<String, dynamic>),
                ),
        ),
      ],
    );
  }

  Widget _buildClassGrid() {
    if (classes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Tidak ada kelas tersedia',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Pilih Kelas',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${classes.length} kelas tersedia',
          style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...classes.map((cls) => _buildClassCard(cls as Map<String, dynamic>)),
      ],
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls) {
    final name = cls['name']?.toString() ?? 'Unknown';
    final studentCount = cls['student_count'] ?? cls['students_count'] ?? 0;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          onTap: () => onClassChanged(cls),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 0.75,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.slate800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$studentCount siswa',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: ColorUtils.slate400,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> student) {
    final model = Student.fromJson(student);
    final status = student['raport_status'] ?? 'draft';

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
              CircleAvatar(
                backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: Text(
                  model.initials,
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
                      model.name.isNotEmpty ? model.name : 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'NIS: ${model.studentNumber.isNotEmpty ? model.studentNumber : '-'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
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
                    Icon(statusIcon, size: 14, color: statusColor),
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
                icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                onPressed: () => onDownloadPdf(student),
                tooltip: 'Cetak PDF',
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(AppSpacing.xs),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
