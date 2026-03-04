import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/services/api_subject_services.dart';
import 'package:manajemensekolah/utils/color_utils.dart';
import 'package:manajemensekolah/utils/error_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
// Note: pastikan import AppLocalizations dan Provider jika diperlukan,
// namun di sini kita gunakan styling yang umum.

class RppAiResultScreen extends StatefulWidget {
  final Map<String, dynamic> rppData;
  final String teacherId;
  final VoidCallback onSaved;

  const RppAiResultScreen({
    super.key,
    required this.rppData,
    required this.teacherId,
    required this.onSaved,
  });

  @override
  State<RppAiResultScreen> createState() => _RppAiResultScreenState();
}

class _RppAiResultScreenState extends State<RppAiResultScreen> {
  bool _isSaving = false;
  bool _isRegenerating = false;

  late quill.QuillController _tujuanController;
  late quill.QuillController _kegiatanIntiController;
  late quill.QuillController _penilaianController;
  late quill.QuillController _kompetensiIntiController;
  late quill.QuillController _kompetensiDasarController;

  late TextEditingController _judulController;
  late TextEditingController _satuanPendidikanController;
  late TextEditingController _mataPelajaranController;
  late TextEditingController _babController;
  late TextEditingController _subBabController;
  late TextEditingController _pembelajaranKeController;
  late TextEditingController _kelasSemesterController;
  late TextEditingController _alokasiWaktuController;

  final TextEditingController _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initControllers(widget.rppData);
  }

  quill.Document _convertHtmlToQuill(String html) {
    if (html.isEmpty) return quill.Document();

    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
    int counter = 1;
    while (text.contains('<li>')) {
      if (text.contains('<ol>')) {
        text = text.replaceFirst('<li>', '$counter. ');
        counter++;
      } else {
        text = text.replaceFirst('<li>', '• ');
      }
    }
    text = text.replaceAll('</li>', '\n');
    text = text.replaceAll(RegExp(r'<br\s*/?>'), '\n');
    text = text.replaceAll(RegExp(r'<h3>'), '\n');
    text = text.replaceAll(RegExp(r'</h3>|<p>|</p>'), '\n');
    text = text.replaceAll(RegExp(r'<[^>]*>'), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.trim();

    final doc = quill.Document()..insert(0, text);
    return doc;
  }

  void _initControllers(Map<String, dynamic> data) {
    _judulController = TextEditingController(
      text: data['judul'] ?? data['title'] ?? 'RPP AI',
    );
    _satuanPendidikanController = TextEditingController(
      text: data['satuan_pendidikan'] ?? 'SD/MI',
    );
    _mataPelajaranController = TextEditingController(
      text: data['mata_pelajaran_nama'] ?? '',
    );
    _babController = TextEditingController(text: data['bab_nama'] ?? '');
    _subBabController = TextEditingController(text: data['sub_bab_nama'] ?? '');
    _pembelajaranKeController = TextEditingController(
      text: data['pembelajaran_ke'] ?? '',
    );
    _kelasSemesterController = TextEditingController(
      text: data['kelas_semester'] ?? '',
    );
    _alokasiWaktuController = TextEditingController(
      text: data['alokasi_waktu'] ?? '',
    );

    _kompetensiIntiController = quill.QuillController(
      document: _convertHtmlToQuill(data['kompetensi_inti'] ?? ''),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _kompetensiDasarController = quill.QuillController(
      document: _convertHtmlToQuill(data['kompetensi_dasar'] ?? ''),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _tujuanController = quill.QuillController(
      document: _convertHtmlToQuill(
        data['tujuan_pembelajaran'] ?? data['learning_objective'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _kegiatanIntiController = quill.QuillController(
      document: _convertHtmlToQuill(
        data['kegiatan_inti'] ?? data['learning_activities'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _penilaianController = quill.QuillController(
      document: _convertHtmlToQuill(
        data['penilaian'] ?? data['assessment'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  // stripHtml dihapus karena digunakan html2md

  @override
  void dispose() {
    _kompetensiIntiController.dispose();
    _kompetensiDasarController.dispose();
    _tujuanController.dispose();
    _kegiatanIntiController.dispose();
    _penilaianController.dispose();
    _judulController.dispose();
    _satuanPendidikanController.dispose();
    _mataPelajaranController.dispose();
    _babController.dispose();
    _subBabController.dispose();
    _pembelajaranKeController.dispose();
    _kelasSemesterController.dispose();
    _alokasiWaktuController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _showRegenerateDialog() {
    _promptController.clear();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: ColorUtils.primary),
              SizedBox(width: 8),
              Text(
                'Generate Ulang AI',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistem akan menyusun ulang konten RPP berdasarkan data saat ini. Anda dapat menambahkan instruksi spesifik di bawah.',
                  style: TextStyle(color: ColorUtils.slate600, fontSize: 14),
                ),
                SizedBox(height: 16),
                _buildDialogField(
                  'Mata Pelajaran',
                  _mataPelajaranController.text,
                ),
                SizedBox(height: 12),
                _buildDialogField('Bab', _babController.text),
                SizedBox(height: 16),
                Text(
                  'Instruksi / Prompt Tambahan (Opsional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate800,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _promptController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        'Contoh: Buat kegiatan inti menggunakan metode diskusi kelompok dan studi kasus...',
                    hintStyle: TextStyle(
                      color: ColorUtils.slate400,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ColorUtils.slate300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ColorUtils.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: TextStyle(color: ColorUtils.slate500),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _regenerateRPP(prompt: _promptController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Generate'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: ColorUtils.slate500, fontSize: 12)),
        SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            value.isEmpty ? '-' : value,
            style: TextStyle(
              color: ColorUtils.slate800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _regenerateRPP({String prompt = ''}) async {
    setState(() {
      _isRegenerating = true;
    });

    try {
      // Mock API regenerate response sesuai KamillLabs documentation
      await Future.delayed(const Duration(seconds: 2));

      final regeneratedData = {
        'title': _judulController.text, // Pertahankan judul
        'learning_objective':
            '<ol><li>[Regenerated] Melalui diskusi, siswa dapat memahami konsep dengan lebih mendalam.</li><li>Diberikan studi kasus, siswa mampu memecahkan masalah dengan akurat.</li></ol>',
        'learning_activities':
            '<h3>Pendahuluan (15 menit)</h3><p>[Regenerated] Guru membuka kelas dengan cerita inspiratif terkait materi.</p><h3>Kegiatan Inti (60 menit)</h3><ul><li>Siswa melakukan debat aktif mengenai topik.</li><li>Siswa menyusun mind-map bersama kelompok.</li></ul><h3>Penutup (15 menit)</h3><p>Evaluasi singkat dan refleksi bersama.</p>',
        'assessment':
            '<h3>1. Penilaian Kinerja</h3><p>[Regenerated] Observasi terhadap keaktifan siswa dalam berdebat.</p><h3>2. Penilaian Produk</h3><p>Penilaian kreativitas mind-map yang dihasilkan kelompok.</p>',
      };

      setState(() {
        _tujuanController.document = _convertHtmlToQuill(
          regeneratedData['learning_objective']!,
        );
        _kegiatanIntiController.document = _convertHtmlToQuill(
          regeneratedData['learning_activities']!,
        );
        _penilaianController.document = _convertHtmlToQuill(
          regeneratedData['assessment']!,
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('RPP berhasil di-generate ulang!'),
            backgroundColor: ColorUtils.success600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal regenerate RPP: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRegenerating = false;
        });
      }
    }
  }

  Future<void> _previewPDF() async {
    try {
      // Create a new PDF document
      final PdfDocument document = PdfDocument();
      PdfPage page = document.pages.add();
      PdfGraphics graphics = page.graphics;

      // Create PDF fonts
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        14,
        style: PdfFontStyle.bold,
      );
      final PdfFont headerFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        12,
        style: PdfFontStyle.bold,
      );

      double yPosition = 0;

      // Draw title
      graphics.drawString(
        'RENCANA PELAKSANAAN PEMBELAJARAN (RPP)',
        titleFont,
        bounds: Rect.fromLTWH(0, yPosition, page.size.width, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      yPosition += 30;

      graphics.drawString(
        _judulController.text.toUpperCase(),
        titleFont,
        bounds: Rect.fromLTWH(0, yPosition, page.size.width, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      yPosition += 40;

      // Draw meta info
      final metaData = [
        'Satuan Pendidikan : ${_satuanPendidikanController.text}',
        'Mata Pelajaran    : ${_mataPelajaranController.text}',
        'Bab               : ${_babController.text}',
        'Sub Bab           : ${_subBabController.text}',
        'Kelas/Semester    : ${_kelasSemesterController.text}',
        'Pembelajaran Ke   : ${_pembelajaranKeController.text}',
        'Alokasi Waktu     : ${_alokasiWaktuController.text}',
      ];

      for (var meta in metaData) {
        if (yPosition > page.size.height - 30) {
          page = document.pages.add();
          graphics = page.graphics;
          yPosition = 40;
        }
        graphics.drawString(
          meta,
          font,
          bounds: Rect.fromLTWH(0, yPosition, page.size.width - 20, 15),
        );
        yPosition += 18;
      }
      yPosition += 20;

      // Helper function to draw section
      double drawSection(String title, String content, double startY) {
        double currentY = startY;

        // Check page break for header
        if (currentY > page.size.height - 50) {
          page = document.pages.add();
          graphics = page.graphics;
          currentY = 40;
        }

        graphics.drawString(
          title,
          headerFont,
          bounds: Rect.fromLTWH(0, currentY, page.size.width, 20),
        );
        currentY += 20;

        if (content.trim().isEmpty) {
          return currentY + 10;
        }

        final PdfTextElement textElement = PdfTextElement(
          text: content,
          font: font,
        );

        final PdfLayoutResult? result = textElement.draw(
          page: page,
          bounds: Rect.fromLTWH(20, currentY, page.size.width - 40, 0),
        );

        if (result != null) {
          page = result.page;
          graphics = page.graphics;
          currentY = result.bounds.bottom + 20;
        } else {
          currentY += 10;
        }

        return currentY;
      }

      yPosition = drawSection(
        'A. Kompetensi Inti (KI)',
        _kompetensiIntiController.document.toPlainText(),
        yPosition,
      );
      yPosition = drawSection(
        'B. Kompetensi Dasar (KD) dan Indikator (IPK)',
        _kompetensiDasarController.document.toPlainText(),
        yPosition,
      );
      yPosition = drawSection(
        'C. Tujuan Pembelajaran',
        _tujuanController.document.toPlainText(),
        yPosition,
      );
      yPosition = drawSection(
        'D. Kegiatan Pembelajaran',
        _kegiatanIntiController.document.toPlainText(),
        yPosition,
      );
      yPosition = drawSection(
        'E. Penilaian (Asesmen)',
        _penilaianController.document.toPlainText(),
        yPosition,
      );

      // Save the document
      final List<int> bytes = await document.save();
      document.dispose();

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/Preview_RPP_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);

      // Open the file
      await OpenFile.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat preview PDF: $e')),
        );
      }
    }
  }

  Future<void> _saveRPP() async {
    if (_judulController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Judul RPP wajib diisi.')));
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Map data untuk Backend K-13 (3 komponen manual + metadata)
      // Waktu dan default lainnya diatur static untuk AI bypass saat ini
      final payloadData = {
        'guru_id': widget.teacherId,
        'mata_pelajaran_id':
            widget.rppData['mata_pelajaran_id'] ?? widget.rppData['subject_id'],
        'judul': _judulController.text,
        'kompetensi_inti': _kompetensiIntiController.document.toPlainText(),
        'kompetensi_dasar': _kompetensiDasarController.document.toPlainText(),
        'tujuan_pembelajaran': _tujuanController.document.toPlainText(),
        'kegiatan_pendahuluan':
            '• Melakukan Pembukaan dengan Salam dan Membaca Doa\n• Mengaitkan Materi Sebelumnya',
        'kegiatan_inti': _kegiatanIntiController.document.toPlainText(),
        'kegiatan_penutup':
            '• Siswa membuat resume dengan bimbingan guru\n• Guru memeriksa pekerjaan siswa',
        'penilaian': _penilaianController.document.toPlainText(),
        'satuan_pendidikan': _satuanPendidikanController.text,
        'kelas_semester': _kelasSemesterController.text,
        'tema': _babController.text, // Bab sebagai tema
        'sub_tema': _subBabController.text,
        'pembelajaran_ke': _pembelajaranKeController.text,
        'alokasi_waktu': _alokasiWaktuController.text,
        'waktu_pendahuluan': '15',
        'waktu_inti': '140',
        'waktu_penutup': '15',
        'is_ai_generated': true, // Flaging backend untuk AI
      };

      if (kDebugMode) {
        print("Menyimpan RPP Payload: \$payloadData");
      }

      await ApiSubjectService.saveRPP(payloadData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('RPP AI berhasil disimpan!'),
            backgroundColor: ColorUtils.success600,
          ),
        );
        widget.onSaved();
        Navigator.pop(context); // Kembali ke list RPP
      }
    } catch (e) {
      if (kDebugMode) print('Save AI RPP error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorUtils.getFriendlyMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Hasil RPP AI (K-13)'),
        backgroundColor: Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: _previewPDF,
            tooltip: 'Preview PDF',
          ),
          IconButton(
            icon: _isRegenerating
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.refresh),
            onPressed: _isRegenerating ? null : _showRegenerateDialog,
            tooltip: 'Generate Ulang',
          ),
          IconButton(
            icon: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(Icons.save),
            onPressed: _isSaving ? null : _saveRPP,
            tooltip: 'Simpan RPP',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'RPP berhasil di-generate menggunakan format 10 Komponen AI dan telah dipetakan ke 3 Komponen K-13. Anda bisa menyesuaikan teks di bawah ini sebelum menyimpan.',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            _buildSectionHeader('Judul RPP'),
            _buildTextField(_judulController, maxLines: 1),
            SizedBox(height: 20),
            _buildSectionHeader('Informasi Umum'),
            _buildMetaInfoPanel(),
            SizedBox(height: 20),
            _buildSectionHeader('A. Kompetensi Inti (KI)'),
            _buildRichTextField(_kompetensiIntiController),
            SizedBox(height: 20),
            _buildSectionHeader('B. Kompetensi Dasar (KD) dan Indikator (IPK)'),
            _buildRichTextField(_kompetensiDasarController),
            SizedBox(height: 20),
            _buildSectionHeader('C. Tujuan Pembelajaran'),
            _buildRichTextField(_tujuanController),
            SizedBox(height: 20),
            _buildSectionHeader(
              'D. Kegiatan Pembelajaran (Pendahuluan, Inti, Penutup)',
            ),
            _buildRichTextField(_kegiatanIntiController),
            SizedBox(height: 20),
            _buildSectionHeader('E. Penilaian (Asesmen)'),
            _buildRichTextField(_penilaianController),
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRPP,
                icon: _isSaving
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.save),
                label: Text(
                  'Simpan ke Database',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.success600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: ColorUtils.slate800,
        ),
      ),
    );
  }

  Widget _buildMetaInfoPanel() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        children: [
          _buildMetaRow('Satuan Pendidikan', _satuanPendidikanController),
          _buildMetaRow('Mata Pelajaran', _mataPelajaranController),
          _buildMetaRow('Bab', _babController),
          _buildMetaRow('Sub Bab', _subBabController),
          _buildMetaRow('Kelas/Semester', _kelasSemesterController),
          _buildMetaRow('Pembelajaran Ke', _pembelajaranKeController),
          _buildMetaRow('Alokasi Waktu', _alokasiWaktuController),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(' : ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 13, color: ColorUtils.slate900),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: ColorUtils.slate300),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {int maxLines = 4}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14, height: 1.6, color: ColorUtils.slate800),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildRichTextField(quill.QuillController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            child: quill.QuillSimpleToolbar(
              controller: controller,
              config: const quill.QuillSimpleToolbarConfig(
                showFontFamily: false,
                showFontSize: false,
                showInlineCode: false,
                showListCheck: false,
                showCodeBlock: false,
                showQuote: false,
                showUndo: false,
                showRedo: false,
                showSearchButton: false,
                showSubscript: false,
                showSuperscript: false,
              ),
            ),
          ),
          Divider(height: 1, color: ColorUtils.slate200),
          Container(
            height: 200,
            padding: EdgeInsets.all(16),
            child: quill.QuillEditor.basic(
              controller: controller,
              config: const quill.QuillEditorConfig(),
            ),
          ),
        ],
      ),
    );
  }
}
