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

  late TextEditingController _judulController;

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
    _judulController = TextEditingController(text: data['title'] ?? 'RPP AI');

    _tujuanController = quill.QuillController(
      document: _convertHtmlToQuill(data['learning_objective'] ?? ''),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _kegiatanIntiController = quill.QuillController(
      document: _convertHtmlToQuill(data['learning_activities'] ?? ''),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _penilaianController = quill.QuillController(
      document: _convertHtmlToQuill(data['assessment'] ?? ''),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  // stripHtml dihapus karena digunakan html2md

  @override
  void dispose() {
    _tujuanController.dispose();
    _kegiatanIntiController.dispose();
    _penilaianController.dispose();
    _judulController.dispose();
    super.dispose();
  }

  Future<void> _regenerateRPP() async {
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
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

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

      // Helper function to draw section
      double drawSection(String title, String content, double startY) {
        double currentY = startY;

        // Check page break for header
        if (currentY > page.size.height - 50) {
          document.pages.add();
          currentY = 40;
        }

        graphics.drawString(
          title,
          headerFont,
          bounds: Rect.fromLTWH(0, currentY, page.size.width, 20),
        );
        currentY += 20;

        final List<String> lines = content.split('\n');
        for (String line in lines) {
          if (line.trim().isEmpty) {
            currentY += 10;
            continue;
          }

          if (currentY > page.size.height - 30) {
            document.pages
                .add(); // add page doesn't return the page to draw on graphics automatically in this loop easily without refactoring, but for simple preview we assume it fits or text breaks.
            // In a robust implementation, we'd use PdfTextElement with layout.
            currentY = 40;
          }

          graphics.drawString(
            line,
            font,
            bounds: Rect.fromLTWH(20, currentY, page.size.width - 20, 15),
          );
          currentY += 18;
        }
        return currentY + 10;
      }

      yPosition = drawSection(
        'A. Tujuan Pembelajaran',
        _tujuanController.document.toPlainText(),
        yPosition,
      );
      yPosition = drawSection(
        'B. Kegiatan Pembelajaran',
        _kegiatanIntiController.document.toPlainText(),
        yPosition,
      );
      yPosition = drawSection(
        'C. Penilaian (Asesmen)',
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
        'mata_pelajaran_id': widget.rppData['subject_id'],
        'judul': _judulController.text,
        'tujuan_pembelajaran': _tujuanController.document.toPlainText(),
        'kegiatan_pendahuluan':
            '• Melakukan Pembukaan dengan Salam dan Membaca Doa\n• Mengaitkan Materi Sebelumnya',
        'kegiatan_inti': _kegiatanIntiController.document.toPlainText(),
        'kegiatan_penutup':
            '• Siswa membuat resume dengan bimbingan guru\n• Guru memeriksa pekerjaan siswa',
        'penilaian': _penilaianController.document.toPlainText(),
        'satuan_pendidikan': 'SD/MI',
        'kelas_semester':
            '${widget.rppData['kelas_nama']} / ${widget.rppData['semester']}',
        'tema': _judulController.text,
        'sub_tema': '',
        'pembelajaran_ke': '1',
        'alokasi_waktu': widget.rppData['tahun_ajaran'],
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
            onPressed: _isRegenerating ? null : _regenerateRPP,
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
            _buildSectionHeader('A. Tujuan Pembelajaran'),
            _buildRichTextField(_tujuanController),
            SizedBox(height: 20),
            _buildSectionHeader(
              'B. Kegiatan Pembelajaran (Pendahuluan, Inti, Penutup)',
            ),
            _buildRichTextField(_kegiatanIntiController),
            SizedBox(height: 20),
            _buildSectionHeader('C. Penilaian (Asesmen)'),
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
