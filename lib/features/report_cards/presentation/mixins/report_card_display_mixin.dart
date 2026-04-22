import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Mixin for report card card-building methods (parent view).
///
/// Used by inner StatefulWidget builders that hold reportCardData,
/// studentName, and studentData as widget properties.
mixin ReportCardDisplayMixin {
  /// The report card data map.
  Map<String, dynamic> get reportCardData;

  /// The student's display name.
  String get studentName;

  /// The student data map.
  Map<String, dynamic> get studentData;
  Widget buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: ColorUtils.corporateBlue600, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ColorUtils.corporateBlue600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: ColorUtils.corporateBlue600.withValues(
                alpha: 0.1,
              ),
              child: Text(
                studentName.isNotEmpty ? studentName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.corporateBlue600,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              studentName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'NIS: '
              '${studentData['nis'] ?? '-'}'
              ' | NISN: '
              '${studentData['nisn'] ?? '-'}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSikapCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionHeader('Sikap', Icons.accessibility_new_rounded),
            buildDetailRow(
              'Spiritual',
              '${reportCardData['spiritual_predicate'] ?? '-'}'
                  ' : '
                  '${reportCardData['spiritual_description'] ?? '-'}',
            ),
            const Divider(),
            buildDetailRow(
              'Sosial',
              '${reportCardData['social_predicate'] ?? '-'}'
                  ' : '
                  '${reportCardData['social_description'] ?? '-'}',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildGradesCard() {
    final subjects = reportCardData['raport_subjects'] as List<dynamic>? ?? [];
    if (subjects.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSectionHeader('Nilai Mata Pelajaran', Icons.menu_book),
              const Center(child: Text('Belum ada data nilai.')),
            ],
          ),
        ),
      );
    }
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionHeader('Nilai Mata Pelajaran', Icons.menu_book),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                columns: const [
                  DataColumn(label: Text('Mata Pelajaran')),
                  DataColumn(label: Text('Pengetahuan')),
                  DataColumn(label: Text('Keterampilan')),
                ],
                rows: subjects.map((sub) {
                  return DataRow(
                    cells: [
                      DataCell(Text(sub['subject']?['name'] ?? 'Unknown')),
                      DataCell(
                        Text(
                          '${sub['knowledge_score'] ?? 0} '
                          '(${sub['knowledge_predicate'] ?? '-'})',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${sub['skill_score'] ?? 0} '
                          '(${sub['skill_predicate'] ?? '-'})',
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildExtracurricularCard() {
    final extras = reportCardData['extracurriculars'] as List<dynamic>? ?? [];
    if (extras.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionHeader('Ekstrakurikuler', Icons.sports_basketball),
            ...extras.map(
              (ex) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: buildDetailRow(
                  ex['name'] ?? '-',
                  '${ex['score'] ?? '-'} - ${ex['description'] ?? '-'}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAchievementCard() {
    final achievements = reportCardData['achievements'] as List<dynamic>? ?? [];
    if (achievements.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionHeader('Prestasi', Icons.emoji_events),
            ...achievements.map(
              (ach) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: buildDetailRow(
                  ach['type'] ?? 'Lainnya',
                  '${ach['name'] ?? '-'} - ${ach['description'] ?? '-'}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAttendanceCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionHeader('Kehadiran', Icons.event_available),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                buildAttendanceBadge(
                  'Sakit',
                  reportCardData['attendance_sick'] ?? 0,
                  Colors.orange,
                ),
                buildAttendanceBadge(
                  'Izin',
                  reportCardData['attendance_permit'] ?? 0,
                  Colors.blue,
                ),
                buildAttendanceBadge(
                  'Alpa',
                  reportCardData['attendance_absent'] ?? 0,
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAttendanceBadge(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget buildNotesCard() {
    final notes = reportCardData['homeroom_notes']?.toString() ?? '';
    if (notes.isEmpty) return const SizedBox.shrink();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionHeader('Catatan Wali Kelas', Icons.edit_note),
            Text(notes, style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget buildDecisionCard() {
    final decision = reportCardData['promotion_decision']?.toString() ?? '';
    if (decision.isEmpty) return const SizedBox.shrink();
    return Card(
      color: ColorUtils.corporateBlue600.withValues(alpha: 0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(
          color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildSectionHeader('Keputusan', Icons.gavel),
            Text(
              decision,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const Text(' : '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
