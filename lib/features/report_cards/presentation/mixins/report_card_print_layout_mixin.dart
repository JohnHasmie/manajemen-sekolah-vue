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
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(' : '),
          Expanded(child: Text(value)),
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
                        buildHeaderRow(
                          'Sakit',
                          '${reportCardData['attendance_sick'] ?? 0} hari',
                        ),
                        buildHeaderRow(
                          'Izin',
                          '${reportCardData['attendance_permit'] ?? 0} hari',
                        ),
                        buildHeaderRow(
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
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            Text('Mengetahui,'),
            Text('Orang Tua/Wali'),
            SizedBox(height: 60),
            Text('...........................'),
          ],
        ),
        Column(
          children: [
            Text('Mengetahui,'),
            Text('Kepala Sekolah'),
            SizedBox(height: 60),
            Text('...........................'),
          ],
        ),
        Column(
          children: [
            Text('Kota, .. ............. 20..'),
            Text('Wali Kelas'),
            SizedBox(height: 60),
            Text('...........................'),
          ],
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
      ),
    );
  }
}
