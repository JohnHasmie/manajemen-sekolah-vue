// Parent view of a student's report card detail.
// Like `pages/parent/Raport/Detail.vue` in a Vue app.
//
// Read-only view of a finalized report card showing grades, extracurriculars,
// character assessment, and attendance. Supports Excel download.
// This is a StatelessWidget -- all data is passed via constructor.
// In Laravel terms: `RaportController@parentShow`.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/report_cards/exports/report_card_export_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Read-only report card detail view for parents.
///
/// StatelessWidget -- no local state needed. All data comes via props.
/// Like a Vue presentational component that only renders data.
/// Props: [reportCardData], [studentName], [studentData], [userRole].
class ParentReportCardDetailScreen extends StatelessWidget {
  final Map<String, dynamic> reportCardData;
  final String studentName;
  final Map<String, dynamic> studentData;
  final String userRole;

  const ParentReportCardDetailScreen({
    super.key,
    required this.reportCardData,
    required this.studentName,
    required this.studentData,
    this.userRole = 'wali', // Default to wali
  });

  Color _getPrimaryColor() {
    return ColorUtils.getRoleColor(userRole);
  }

  LinearGradient _getCardGradient() {
    final primaryColor = _getPrimaryColor();
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Header - Pattern #7 gradient header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              gradient: _getCardGradient(),
              boxShadow: [
                BoxShadow(
                  color: _getPrimaryColor().withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => AppNavigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Raport: $studentName',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Detail E-Raport Siswa',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Student Info Card
                  _buildInfoCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // Sikap (Attitude) Card
                  _buildSikapCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // Pengetahuan & Keterampilan (Grades)
                  _buildGradesCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // Ekstrakurikuler
                  _buildExtracurricularCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // Prestasi
                  _buildAchievementCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // Kehadiran (Attendance)
                  _buildAttendanceCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // Catatan Wali Kelas
                  _buildNotesCard(),
                  const SizedBox(height: AppSpacing.lg),

                  // Keputusan
                  _buildDecisionCard(),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _downloadPdf(context),
        backgroundColor: ColorUtils.corporateBlue600,
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: const Text('Cetak PDF', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  void _downloadPdf(BuildContext context) async {
    // Show loading
    SnackBarUtils.showInfo(context, 'Menyiapkan file PDF...');

    try {
      if (userRole == 'wali') {
        await ExcelReportCardService.exportCertificateRaportPdf(
          studentClassId: reportCardData['student_class_id'].toString(),
          academicYearId: reportCardData['academic_year_id'].toString(),
          semesterId: reportCardData['semester_id'].toString(),
          studentName: studentName,
          context: context,
        );
      } else {
        await ExcelReportCardService.exportSingleRaportPdf(
          studentClassId: reportCardData['student_class_id'].toString(),
          academicYearId: reportCardData['academic_year_id'].toString(),
          semesterId: reportCardData['semester_id'].toString(),
          studentName: studentName,
          context: context,
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
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

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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
              'NIS: ${studentData['nis'] ?? '-'} | NISN: ${studentData['nisn'] ?? '-'}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSikapCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Sikap', Icons.accessibility_new_rounded),
            _buildDetailRow(
              'Spiritual',
              '${reportCardData['spiritual_predicate'] ?? '-'} : ${reportCardData['spiritual_description'] ?? '-'}',
            ),
            const Divider(),
            _buildDetailRow(
              'Sosial',
              '${reportCardData['social_predicate'] ?? '-'} : ${reportCardData['social_description'] ?? '-'}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradesCard() {
    final subjects = reportCardData['raport_subjects'] as List<dynamic>? ?? [];

    if (subjects.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Nilai Mata Pelajaran', Icons.menu_book),
              const Center(child: Text('Belum ada data nilai mata pelajaran.')),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Nilai Mata Pelajaran', Icons.menu_book),
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
                          '${sub['knowledge_score'] ?? 0} (${sub['knowledge_predicate'] ?? '-'})',
                        ),
                      ),
                      DataCell(
                        Text(
                          '${sub['skill_score'] ?? 0} (${sub['skill_predicate'] ?? '-'})',
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

  Widget _buildExtracurricularCard() {
    final extras = reportCardData['extracurriculars'] as List<dynamic>? ?? [];
    if (extras.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Ekstrakurikuler', Icons.sports_basketball),
            ...extras.map(
              (ex) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildDetailRow(
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

  Widget _buildAchievementCard() {
    final achievements = reportCardData['achievements'] as List<dynamic>? ?? [];
    if (achievements.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Prestasi', Icons.emoji_events),
            ...achievements.map(
              (ach) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: _buildDetailRow(
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

  Widget _buildAttendanceCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Kehadiran', Icons.event_available),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttendanceBadge(
                  'Sakit',
                  reportCardData['attendance_sick'] ?? 0,
                  Colors.orange,
                ),
                _buildAttendanceBadge(
                  'Izin',
                  reportCardData['attendance_permit'] ?? 0,
                  Colors.blue,
                ),
                _buildAttendanceBadge(
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

  Widget _buildAttendanceBadge(String label, int count, Color color) {
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

  Widget _buildNotesCard() {
    final notes = reportCardData['homeroom_notes']?.toString() ?? '';
    if (notes.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Catatan Wali Kelas', Icons.edit_note),
            Text(notes, style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionCard() {
    final decision = reportCardData['promotion_decision']?.toString() ?? '';
    if (decision.isEmpty) return const SizedBox.shrink();

    return Card(
      color: ColorUtils.corporateBlue600.withValues(alpha: 0.05),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Keputusan', Icons.gavel),
            Text(
              decision,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
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
