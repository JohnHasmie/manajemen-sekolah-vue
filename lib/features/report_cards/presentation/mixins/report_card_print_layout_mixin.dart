import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Mixin for report card print layout-building methods.
///
/// Used by inner StatefulWidget builders that hold reportCardData,
/// studentName, and className as widget properties.
mixin ReportCardPrintLayoutMixin {
  /// The report card data map.
  Map<String, dynamic> get reportCardData;

  /// The student's display name.
  String get studentName;

  /// The class name.
  String get className;
  Widget buildHeader() {
    return Column(
      children: [
        const Text(
          'PENCAPAIAN KOMPETENSI PESERTA DIDIK',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildHeaderRow('Nama Sekolah', 'SMA / SMK Bintang Bangsa'),
                  buildHeaderRow('Alamat', 'Jl. Pendidikan No. 1'),
                  buildHeaderRow('Nama', studentName),
                  buildHeaderRow('Nomor Induk / NISN', '-'),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildHeaderRow('Kelas', className),
                  buildHeaderRow('Semester', '1 (Ganjil)'),
                  buildHeaderRow('Tahun Pelajaran', '2023/2024'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildHeaderRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flexible so the label gets a hard cap when the row is rendered
          // inside a narrow Expanded(flex:1) (e.g. the E. KETIDAKHADIRAN
          // half-column), preventing 120px from eating the entire column
          // and forcing the value to wrap character-by-character.
          Flexible(
            flex: 5,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
              softWrap: true,
            ),
          ),
          const Text(' : '),
          Expanded(flex: 4, child: Text(value, softWrap: true)),
        ],
      ),
    );
  }

  /// Compact label-value row tuned for the attendance breakdown inside
  /// the narrow E. KETIDAKHADIRAN column. Drops the fixed 120px label
  /// width and lets both sides flex so "Tanpa Keterangan : 5 hari" fits
  /// without character-by-character wrapping.
  Widget buildCompactRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              softWrap: true,
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 11)),
          Expanded(
            flex: 4,
            child: Text(
              value,
              softWrap: true,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Container(
      color: Colors.grey.shade300,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget buildSikapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle('A. SIKAP'),
        const Text(
          '1. Sikap Spiritual',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Predikat: '
                '${reportCardData['spiritual_predicate'] ?? '-'}',
              ),
              Text(
                'Deskripsi: '
                '${reportCardData['spiritual_description'] ?? '-'}',
              ),
            ],
          ),
        ),
        const Text(
          '2. Sikap Sosial',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Predikat: '
                '${reportCardData['social_predicate'] ?? '-'}',
              ),
              Text(
                'Deskripsi: '
                '${reportCardData['social_description'] ?? '-'}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildGradeSection() {
    final List<dynamic> subjects = reportCardData['raport_subjects'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle('B. PENGETAHUAN DAN KETERAMPILAN'),
        Table(
          border: TableBorder.all(color: Colors.black87),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(4),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(2),
            4: FlexColumnWidth(2),
            5: FlexColumnWidth(2),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                buildTableCell('No', isHeader: true),
                buildTableCell('Mata Pelajaran', isHeader: true),
                buildTableCell('Pengetahuan\n(Nilai)', isHeader: true),
                buildTableCell('Pengetahuan\n(Predikat)', isHeader: true),
                buildTableCell('Keterampilan\n(Nilai)', isHeader: true),
                buildTableCell('Keterampilan\n(Predikat)', isHeader: true),
              ],
            ),
            for (int i = 0; i < subjects.length; i++)
              TableRow(
                children: [
                  buildTableCell((i + 1).toString(), center: true),
                  buildTableCell(subjects[i]['subject']?['name'] ?? '-'),
                  buildTableCell(
                    subjects[i]['knowledge_score']?.toString() ?? '-',
                    center: true,
                  ),
                  buildTableCell(
                    subjects[i]['knowledge_predicate'] ?? '-',
                    center: true,
                  ),
                  buildTableCell(
                    subjects[i]['skill_score']?.toString() ?? '-',
                    center: true,
                  ),
                  buildTableCell(
                    subjects[i]['skill_predicate'] ?? '-',
                    center: true,
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget buildEkstraSection() {
    final List<dynamic> extras = reportCardData['extracurriculars'] ?? [];
    if (extras.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle('C. EKSTRAKURIKULER'),
        Table(
          border: TableBorder.all(color: Colors.black87),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(4),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(4),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                buildTableCell('No', isHeader: true),
                buildTableCell('Kegiatan Ekstrakurikuler', isHeader: true),
                buildTableCell('Predikat', isHeader: true),
                buildTableCell('Keterangan', isHeader: true),
              ],
            ),
            for (int i = 0; i < extras.length; i++)
              TableRow(
                children: [
                  buildTableCell((i + 1).toString(), center: true),
                  buildTableCell(extras[i]['name'] ?? '-'),
                  buildTableCell(extras[i]['score'] ?? '-', center: true),
                  buildTableCell(extras[i]['description'] ?? '-'),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget buildPrestasiSection() {
    final List<dynamic> achievements = reportCardData['achievements'] ?? [];
    if (achievements.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSectionTitle('D. PRESTASI'),
        Table(
          border: TableBorder.all(color: Colors.black87),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(4),
            2: FlexColumnWidth(5),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                buildTableCell('No', isHeader: true),
                buildTableCell('Jenis Prestasi', isHeader: true),
                buildTableCell('Keterangan', isHeader: true),
              ],
            ),
            for (int i = 0; i < achievements.length; i++)
              TableRow(
                children: [
                  buildTableCell((i + 1).toString(), center: true),
                  buildTableCell(achievements[i]['type'] ?? '-'),
                  buildTableCell(achievements[i]['name'] ?? '-'),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildSectionTitle('E. KETIDAKHADIRAN'),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black87),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      children: [
                        buildCompactRow(
                          'Sakit',
                          '${reportCardData['attendance_sick'] ?? 0} hari',
                        ),
                        buildCompactRow(
                          'Izin',
                          '${reportCardData['attendance_permit'] ?? 0} hari',
                        ),
                        buildCompactRow(
                          'Tanpa Keterangan',
                          '${reportCardData['attendance_absent'] ?? 0} hari',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildSectionTitle('F. CATATAN WALI KELAS'),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black87),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Text(reportCardData['homeroom_notes'] ?? ''),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (reportCardData['promotion_decision'] != null &&
            reportCardData['promotion_decision'].toString().isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildSectionTitle('G. KEPUTUSAN'),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87),
                ),
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  'Berdasarkan pencapaian seluruh kompetensi, '
                  'peserta didik dinyatakan: '
                  '${reportCardData['promotion_decision']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget buildSignatures() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(
          child: _SignatureBlock(
            lineOne: 'Mengetahui,',
            lineTwo: 'Orang Tua/Wali',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _SignatureBlock(
            lineOne: 'Mengetahui,',
            lineTwo: 'Kepala Sekolah',
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: _SignatureBlock(
            lineOne: 'Kota, .. ........... 20..',
            lineTwo: 'Wali Kelas',
          ),
        ),
      ],
    );
  }

  Widget buildTableCell(
    String text, {
    bool isHeader = false,
    bool center = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: center || isHeader ? TextAlign.center : TextAlign.left,
        softWrap: true,
      ),
    );
  }
}

/// One column of the signatures footer (Orang Tua / Kepala Sekolah /
/// Wali Kelas). Wrapped in Expanded by the caller so the three blocks
/// share row width equally and don't overflow on narrow viewports.
class _SignatureBlock extends StatelessWidget {
  const _SignatureBlock({required this.lineOne, required this.lineTwo});

  final String lineOne;
  final String lineTwo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          lineOne,
          textAlign: TextAlign.center,
          softWrap: true,
          style: const TextStyle(fontSize: 12),
        ),
        Text(
          lineTwo,
          textAlign: TextAlign.center,
          softWrap: true,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 60),
        const Text(
          '(....................)',
          textAlign: TextAlign.center,
          softWrap: false,
          overflow: TextOverflow.fade,
          style: TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}
