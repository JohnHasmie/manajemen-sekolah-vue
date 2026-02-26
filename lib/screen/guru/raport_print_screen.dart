import 'package:flutter/material.dart';
import 'package:manajemensekolah/utils/color_utils.dart';

class RaportPrintScreen extends StatelessWidget {
  final Map<String, dynamic> raportData;
  final String studentName;
  final String className;

  const RaportPrintScreen({
    super.key,
    required this.raportData,
    required this.studentName,
    required this.className,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preview Raport',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: ColorUtils.corporateBlue600,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print to PDF',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Fungsi cetak PDF menggunakan Syncfusion akan segera diimplementasikan.',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildSikapSection(),
                const SizedBox(height: 16),
                _buildNilaiSection(),
                const SizedBox(height: 16),
                _buildEkstraSection(),
                const SizedBox(height: 16),
                _buildPrestasiSection(),
                const SizedBox(height: 16),
                _buildInfoSection(),
                const SizedBox(height: 32),
                _buildSignatures(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Text(
          'PENCAPAIAN KOMPETENSI PESERTA DIDIK',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow(
                    'Nama Sekolah',
                    'SMA / SMK Bintang Bangsa',
                  ), // Default/Placeholder
                  _buildHeaderRow('Alamat', 'Jl. Pendidikan No. 1'),
                  _buildHeaderRow('Nama', studentName),
                  _buildHeaderRow('Nomor Induk / NISN', '-'),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderRow('Kelas', className),
                  _buildHeaderRow(
                    'Semester',
                    '1 (Ganjil)',
                  ), // Hardcoded assuming semester 1
                  _buildHeaderRow(
                    'Tahun Pelajaran',
                    '2023/2024',
                  ), // Hardcoded placeholder
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderRow(String label, String value) {
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

  Widget _buildSectionTitle(String title) {
    return Container(
      color: Colors.grey.shade300,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSikapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('A. SIKAP'),
        // Spiritual
        const Text(
          '1. Sikap Spiritual',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Predikat: ${raportData['spiritual_predicate'] ?? '-'}'),
              Text('Deskripsi: ${raportData['spiritual_description'] ?? '-'}'),
            ],
          ),
        ),
        // Social
        const Text(
          '2. Sikap Sosial',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Predikat: ${raportData['social_predicate'] ?? '-'}'),
              Text('Deskripsi: ${raportData['social_description'] ?? '-'}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNilaiSection() {
    final List<dynamic> subjects = raportData['raport_subjects'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('B. PENGETAHUAN DAN KETERAMPILAN'),
        Table(
          border: TableBorder.all(color: Colors.black87),
          columnWidths: const {
            0: FlexColumnWidth(1), // No
            1: FlexColumnWidth(4), // Mata Pelajaran
            2: FlexColumnWidth(2), // Pengetahuan Nilai
            3: FlexColumnWidth(2), // Pengetahuan Predikat
            4: FlexColumnWidth(2), // Keterampilan Nilai
            5: FlexColumnWidth(2), // Keterampilan Predikat
          },
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade200),
              children: [
                _buildTableCell('No', isHeader: true),
                _buildTableCell('Mata Pelajaran', isHeader: true),
                _buildTableCell('Pengetahuan\n(Nilai)', isHeader: true),
                _buildTableCell('Pengetahuan\n(Predikat)', isHeader: true),
                _buildTableCell('Keterampilan\n(Nilai)', isHeader: true),
                _buildTableCell('Keterampilan\n(Predikat)', isHeader: true),
              ],
            ),
            for (int i = 0; i < subjects.length; i++)
              TableRow(
                children: [
                  _buildTableCell((i + 1).toString(), center: true),
                  _buildTableCell(subjects[i]['subject']?['name'] ?? '-'),
                  _buildTableCell(
                    subjects[i]['knowledge_score']?.toString() ?? '-',
                    center: true,
                  ),
                  _buildTableCell(
                    subjects[i]['knowledge_predicate'] ?? '-',
                    center: true,
                  ),
                  _buildTableCell(
                    subjects[i]['skill_score']?.toString() ?? '-',
                    center: true,
                  ),
                  _buildTableCell(
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

  Widget _buildEkstraSection() {
    final List<dynamic> extras = raportData['extracurriculars'] ?? [];
    if (extras.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('C. EKSTRAKURIKULER'),
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
                _buildTableCell('No', isHeader: true),
                _buildTableCell('Kegiatan Ekstrakurikuler', isHeader: true),
                _buildTableCell('Predikat', isHeader: true),
                _buildTableCell('Keterangan', isHeader: true),
              ],
            ),
            for (int i = 0; i < extras.length; i++)
              TableRow(
                children: [
                  _buildTableCell((i + 1).toString(), center: true),
                  _buildTableCell(extras[i]['name'] ?? '-'),
                  _buildTableCell(extras[i]['score'] ?? '-', center: true),
                  _buildTableCell(extras[i]['description'] ?? '-'),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrestasiSection() {
    final List<dynamic> achievements = raportData['achievements'] ?? [];
    if (achievements.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('D. PRESTASI'),
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
                _buildTableCell('No', isHeader: true),
                _buildTableCell('Jenis Prestasi', isHeader: true),
                _buildTableCell('Keterangan', isHeader: true),
              ],
            ),
            for (int i = 0; i < achievements.length; i++)
              TableRow(
                children: [
                  _buildTableCell((i + 1).toString(), center: true),
                  _buildTableCell(achievements[i]['type'] ?? '-'),
                  _buildTableCell(achievements[i]['name'] ?? '-'),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
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
                  _buildSectionTitle('E. KETIDAKHADIRAN'),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black87),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        _buildHeaderRow(
                          'Sakit',
                          '${raportData['attendance_sick'] ?? 0} hari',
                        ),
                        _buildHeaderRow(
                          'Izin',
                          '${raportData['attendance_permit'] ?? 0} hari',
                        ),
                        _buildHeaderRow(
                          'Tanpa Keterangan',
                          '${raportData['attendance_absent'] ?? 0} hari',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionTitle('F. CATATAN WALI KELAS'),
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black87),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Text(raportData['homeroom_notes'] ?? ''),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (raportData['promotion_decision'] != null &&
            raportData['promotion_decision'].toString().isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('G. KEPUTUSAN'),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black87),
                ),
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Berdasarkan pencapaian seluruh kompetensi, peserta didik dinyatakan: ${raportData['promotion_decision']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSignatures() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            const Text('Mengetahui,'),
            const Text('Orang Tua/Wali'),
            const SizedBox(height: 60),
            const Text('...........................'),
          ],
        ),
        Column(
          children: [
            const Text('Mengetahui,'),
            const Text('Kepala Sekolah'),
            const SizedBox(height: 60),
            const Text('...........................'),
          ],
        ),
        Column(
          children: [
            const Text('Kota, .. ............. 20..'),
            const Text('Wali Kelas'),
            const SizedBox(height: 60),
            const Text('...........................'),
          ],
        ),
      ],
    );
  }

  Widget _buildTableCell(
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
