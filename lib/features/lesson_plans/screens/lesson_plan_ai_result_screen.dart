// AI-generated RPP (lesson plan) result screen with rich text editing.
// Like `pages/teacher/LessonPlan/AiResult.vue` in a Vue app.
//
// Displays and allows editing of AI-generated lesson plan content using
// Flutter Quill rich text editors. Supports polling for async AI job results,
// regeneration with custom prompts, saving to API, and PDF export.
// In Laravel terms: `AiLessonPlanController@show` + `@update`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/features/subjects/services/subject_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
// Note: ensure AppLocalizations and Provider are imported if needed,
// but here we use common styling.

/// AI-generated lesson plan viewer/editor with rich text editing.
///
/// Supports two modes:
/// 1. Direct mode -- [rppData] is provided, displays immediately
/// 2. Polling mode -- [pollUrl]/[jobId] provided, polls for AI job completion
///
/// Uses Flutter Quill for rich text editing (like Vue Quill / TinyMCE).
/// Props: [rppData], [teacherId], [onSaved] callback, polling fields.
class RppAiResultScreen extends StatefulWidget {
  final Map<String, dynamic>? rppData;
  final String teacherId;
  final VoidCallback onSaved;

  /// Polling mode fields - when set, the screen will poll for results
  final String? pollUrl;
  final String? jobId;
  final String? token;

  /// Metadata to build rppData after polling completes
  final Map<String, dynamic>? pollingMetadata;

  const RppAiResultScreen({
    super.key,
    this.rppData,
    required this.teacherId,
    required this.onSaved,
    this.pollUrl,
    this.jobId,
    this.token,
    this.pollingMetadata,
  });

  @override
  State<RppAiResultScreen> createState() => _RppAiResultScreenState();
}

/// State for [RppAiResultScreen].
///
/// Like a Vue component with `data() { return { isSaving, isPolling, ... } }`.
/// Manages multiple Quill controllers for each RPP section (tujuan, kegiatan
/// inti, penilaian, kompetensi) and text controllers for metadata fields.
class _RppAiResultScreenState extends State<RppAiResultScreen> {
  bool _isSaving = false;
  bool _isRegenerating = false;
  bool _isPolling = false;
  String _pollingStatus = '';
  String? _pollingError;

  late quill.QuillController _tujuanController;
  late quill.QuillController _kegiatanIntiController;
  late quill.QuillController _assessmentController;
  late quill.QuillController _kompetensiIntiController;
  late quill.QuillController _kompetensiDasarController;

  late TextEditingController _judulController;
  late TextEditingController _satuanPendidikanController;
  late TextEditingController _mataPelajaranController;
  late TextEditingController _chapterController;
  late TextEditingController _subChapterController;
  late TextEditingController _pembelajaranKeController;
  late TextEditingController _kelasSemesterController;
  late TextEditingController _alokasiWaktuController;

  final TextEditingController _promptController = TextEditingController();

  /// Like Vue's `mounted()` -- initializes controllers and starts polling
  /// if in polling mode, or displays data directly otherwise.
  @override
  void initState() {
    super.initState();
    if (widget.pollUrl != null || widget.jobId != null) {
      // Polling mode - init empty controllers and start polling
      _initControllers({});
      _isPolling = true;
      _pollingStatus = 'RPP sedang disusun oleh AI...';
      _startPolling();
    } else {
      _initControllers(widget.rppData ?? {});
    }
  }

  /// Polls the AI job endpoint until completion or failure.
  /// Like checking a Laravel Queue job status via `GET /api/ai-jobs/{id}`
  /// every few seconds until it returns 'completed' or 'failed'.
  Future<void> _startPolling() async {
    // Validate we have a poll URL or job ID
    if (widget.pollUrl == null && widget.jobId == null) {
      AppLogger.error('lesson_plan', 'No poll_url or job_id available');
      if (mounted) {
        setState(() {
          _isPolling = false;
          _pollingError =
              'Server tidak mengembalikan informasi polling (poll_url/job_id null). '
              'Silakan coba lagi.';
        });
      }
      return;
    }

    // Per docs Section 2.2: GET /api/ai-jobs/{id}
    // Extract the job ID for polling via getIt<ApiSubjectService>().pollAiJob
    final jobIdForPoll = widget.jobId ??
        (widget.pollUrl != null ? widget.pollUrl!.split('/').last : null);

    if (jobIdForPoll == null) {
      if (mounted) {
        setState(() {
          _isPolling = false;
          _pollingError = 'Tidak dapat menentukan job ID untuk polling.';
        });
      }
      return;
    }

    AppLogger.debug('lesson_plan', 'Starting polling for job: $jobIdForPoll');

    int attempts = 0;
    const maxAttempts = 60; // 5 minutes (60 * 5s)

    while (attempts < maxAttempts) {
      if (!mounted) return;
      attempts++;

      try {
        AppLogger.debug('lesson_plan', 'Poll attempt #$attempts');

        final response = await getIt<ApiSubjectService>().pollAiJob(
          jobIdForPoll,
          widget.token ?? '',
        );

        if (!mounted) return;

        AppLogger.debug('lesson_plan', 'Poll response status: ${response.statusCode}');
        AppLogger.debug('lesson_plan', 'Poll response data: ${response.data}');

        if (response.statusCode == 200) {
          final resultBody = response.data is Map<String, dynamic>
              ? response.data as Map<String, dynamic>
              : <String, dynamic>{};
          // Per docs: response is { success, data: { status, result, error_message } }
          final jobData = resultBody['data'] ?? resultBody;
          final status = jobData['status'] ?? resultBody['status'];

          if (status == 'completed' || status == 'success') {
            // Per docs Section 2.2: result is inside data.result
            final rppResponse = jobData['result'] ??
                jobData['data'] ??
                resultBody['result'] ??
                resultBody;
            _applyPollingResult(rppResponse);
            return;
          } else if (status == 'failed' || status == 'error') {
            setState(() {
              _isPolling = false;
              _pollingError = jobData['error_message'] ??
                  jobData['error'] ??
                  resultBody['message'] ??
                  'AI generation failed';
            });
            return;
          } else {
            // Still processing (pending, processing)
            final statusLabel = status == 'processing'
                ? 'AI sedang memproses'
                : 'Menunggu antrian AI';
            setState(() {
              _pollingStatus =
                  '$statusLabel... (${attempts * 5}s)';
            });
          }
        } else if (response.statusCode == 202) {
          // Still processing
          setState(() {
            _pollingStatus =
                'AI masih memproses... (${attempts * 5}s)';
          });
        }
      } catch (e) {
        AppLogger.error('lesson_plan', e);
        // Don't fail immediately on network errors, keep retrying
      }

      await Future.delayed(const Duration(seconds: 5));
    }

    if (mounted) {
      setState(() {
        _isPolling = false;
        _pollingError = 'Waktu tunggu AI habis (5 menit). Silakan coba lagi.';
      });
    }
  }

  void _applyPollingResult(dynamic rppResponse) {
    final metadata = widget.pollingMetadata ?? {};

    final mappedData = {
      'judul': rppResponse['title'] ?? metadata['title'] ?? 'RPP AI',
      'mata_pelajaran_id': metadata['mata_pelajaran_id'],
      'mata_pelajaran_nama': metadata['mata_pelajaran_nama'] ?? '',
      'satuan_pendidikan': metadata['satuan_pendidikan'] ?? 'SD/MI',
      'bab_nama': metadata['bab_nama'] ?? '',
      'sub_bab_nama': metadata['sub_bab_nama'] ?? '',
      'kelas_semester': metadata['kelas_semester'] ?? '',
      'tema': rppResponse['title'],
      'sub_tema': '',
      'pembelajaran_ke': '',
      'alokasi_waktu': metadata['alokasi_waktu'] ?? '',
      'kompetensi_inti': _stripHtml(rppResponse['core_competence'] as String? ?? ''),
      'kompetensi_dasar': _stripHtml(rppResponse['basic_competence'] as String? ?? ''),
      'tujuan_pembelajaran': _stripHtml(rppResponse['learning_objective'] as String? ?? ''),
      'kegiatan_inti': _stripHtml(rppResponse['learning_activities'] as String? ?? ''),
      'penilaian': _stripHtml(rppResponse['assessment'] as String? ?? ''),
      'is_ai_generated': true,
    };

    setState(() {
      _isPolling = false;
      _pollingError = null;
    });
    _initControllers(mappedData);
    setState(() {});
  }

  String _stripHtml(String html) {
    if (html.isEmpty) return '';
    var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
    text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
    int counter = 1;
    while (text.contains('<li>')) {
      if (html.contains('<ol>')) {
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
    return text.trim();
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
    _chapterController = TextEditingController(text: data['bab_nama'] ?? '');
    _subChapterController = TextEditingController(text: data['sub_bab_nama'] ?? '');
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

    _assessmentController = quill.QuillController(
      document: _convertHtmlToQuill(
        data['penilaian'] ?? data['assessment'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  // stripHtml removed because html2md is used instead

  @override
  void dispose() {
    _kompetensiIntiController.dispose();
    _kompetensiDasarController.dispose();
    _tujuanController.dispose();
    _kegiatanIntiController.dispose();
    _assessmentController.dispose();
    _judulController.dispose();
    _satuanPendidikanController.dispose();
    _mataPelajaranController.dispose();
    _chapterController.dispose();
    _subChapterController.dispose();
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
              SizedBox(width: AppSpacing.sm),
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
                SizedBox(height: AppSpacing.lg),
                _buildDialogField(
                  'Mata Pelajaran',
                  _mataPelajaranController.text,
                ),
                SizedBox(height: AppSpacing.md),
                _buildDialogField('Bab', _chapterController.text),
                SizedBox(height: AppSpacing.lg),
                Text(
                  'Instruksi / Prompt Tambahan (Opsional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate800,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
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
              onPressed: () => AppNavigator.pop(context),
              child: Text(
                AppLocalizations.cancel.tr,
                style: TextStyle(color: ColorUtils.slate500),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                AppNavigator.pop(context);
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
        SizedBox(height: AppSpacing.xs),
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
        _assessmentController.document = _convertHtmlToQuill(
          regeneratedData['assessment']!,
        );
      });

      if (mounted) {
                SnackBarUtils.showSuccess(context, 'RPP berhasil di-generate ulang!');
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
        'Bab               : ${_chapterController.text}',
        'Sub Bab           : ${_subChapterController.text}',
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
        _assessmentController.document.toPlainText(),
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
                SnackBarUtils.showInfo(context, 'Gagal membuat preview PDF: $e');
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
      // Map data for Backend K-13 (3 manual components + metadata)
      // Duration and other defaults are set statically for AI bypass currently
      final payloadData = {
        'guru_id': widget.teacherId,
        'mata_pelajaran_id':
            widget.rppData?['mata_pelajaran_id'] ?? widget.rppData?['subject_id'],
        'judul': _judulController.text,
        'kompetensi_inti': _kompetensiIntiController.document.toPlainText(),
        'kompetensi_dasar': _kompetensiDasarController.document.toPlainText(),
        'tujuan_pembelajaran': _tujuanController.document.toPlainText(),
        'kegiatan_pendahuluan':
            '• Melakukan Pembukaan dengan Salam dan Membaca Doa\n• Mengaitkan Materi Sebelumnya',
        'kegiatan_inti': _kegiatanIntiController.document.toPlainText(),
        'kegiatan_penutup':
            '• Siswa membuat resume dengan bimbingan guru\n• Guru memeriksa pekerjaan siswa',
        'penilaian': _assessmentController.document.toPlainText(),
        'satuan_pendidikan': _satuanPendidikanController.text,
        'kelas_semester': _kelasSemesterController.text,
        'tema': _chapterController.text, // Chapter as theme
        'sub_tema': _subChapterController.text,
        'pembelajaran_ke': _pembelajaranKeController.text,
        'alokasi_waktu': _alokasiWaktuController.text,
        'waktu_pendahuluan': '15',
        'waktu_inti': '140',
        'waktu_penutup': '15',
        'is_ai_generated': true, // Backend flag for AI-generated content
      };

      AppLogger.debug('lesson_plan', "Menyimpan RPP Payload: \$payloadData");

      await getIt<ApiSubjectService>().saveRPP(payloadData);

      if (mounted) {
                SnackBarUtils.showSuccess(context, 'RPP AI berhasil disimpan!');
        AppNavigator.pop(context); // Return to RPP list (PopScope triggers onSaved)
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
                SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildPollingSkeletonBody() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.getRoleColor('guru').withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: ColorUtils.getRoleColor('guru'),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI sedang menyusun RPP...',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: ColorUtils.getRoleColor('guru'),
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        _pollingStatus,
                        style: TextStyle(
                          color: ColorUtils.slate500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.xxl),
          // Skeleton sections
          _buildSkeletonSection('Judul RPP', height: 48),
          SizedBox(height: AppSpacing.xl),
          _buildSkeletonSection('Informasi Umum', height: 200),
          SizedBox(height: AppSpacing.xl),
          _buildSkeletonSection('A. Kompetensi Inti (KI)', height: 120),
          SizedBox(height: AppSpacing.xl),
          _buildSkeletonSection('B. Kompetensi Dasar (KD)', height: 120),
          SizedBox(height: AppSpacing.xl),
          _buildSkeletonSection('C. Tujuan Pembelajaran', height: 120),
          SizedBox(height: AppSpacing.xl),
          _buildSkeletonSection('D. Kegiatan Pembelajaran', height: 150),
          SizedBox(height: AppSpacing.xl),
          _buildSkeletonSection('E. Penilaian (Asesmen)', height: 120),
        ],
      ),
    );
  }

  Widget _buildSkeletonSection(String title, {double height = 120}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ColorUtils.slate800,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Shimmer.fromColors(
          baseColor: ColorUtils.shimmerBaseColor,
          highlightColor: ColorUtils.shimmerHighlightColor,
          child: Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPollingErrorBody() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ColorUtils.error600.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: ColorUtils.error600,
              ),
            ),
            SizedBox(height: AppSpacing.xl),
            Text(
              'Gagal Generate RPP',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              _pollingError ?? '',
              style: TextStyle(fontSize: 13, color: ColorUtils.slate500),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: () => AppNavigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ColorUtils.getRoleColor('guru'),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          widget.onSaved(); // Refresh RPP list when navigating back
        }
      },
      child: Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_isPolling ? 'Generating RPP AI...' : 'Hasil RPP AI (K-13)'),
        backgroundColor: ColorUtils.getRoleColor('guru'),
        foregroundColor: Colors.white,
        actions: _isPolling || _pollingError != null
            ? []
            : [
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
      body: _isPolling
          ? _buildPollingSkeletonBody()
          : _pollingError != null
              ? _buildPollingErrorBody()
              : SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                  SizedBox(width: AppSpacing.md),
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
            SizedBox(height: AppSpacing.xl),
            _buildSectionHeader('Judul RPP'),
            _buildTextField(_judulController, maxLines: 1),
            SizedBox(height: AppSpacing.xl),
            _buildSectionHeader('Informasi Umum'),
            _buildMetaInfoPanel(),
            SizedBox(height: AppSpacing.xl),
            _buildSectionHeader('A. Kompetensi Inti (KI)'),
            _buildRichTextField(_kompetensiIntiController),
            SizedBox(height: AppSpacing.xl),
            _buildSectionHeader('B. Kompetensi Dasar (KD) dan Indikator (IPK)'),
            _buildRichTextField(_kompetensiDasarController),
            SizedBox(height: AppSpacing.xl),
            _buildSectionHeader('C. Tujuan Pembelajaran'),
            _buildRichTextField(_tujuanController),
            SizedBox(height: AppSpacing.xl),
            _buildSectionHeader(
              'D. Kegiatan Pembelajaran (Pendahuluan, Inti, Penutup)',
            ),
            _buildRichTextField(_kegiatanIntiController),
            SizedBox(height: AppSpacing.xl),
            _buildSectionHeader('E. Penilaian (Asesmen)'),
            _buildRichTextField(_assessmentController),
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
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        children: [
          _buildMetaRow('Satuan Pendidikan', _satuanPendidikanController),
          _buildMetaRow('Mata Pelajaran', _mataPelajaranController),
          _buildMetaRow('Bab', _chapterController),
          _buildMetaRow('Sub Bab', _subChapterController),
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
            color: Colors.black.withValues(alpha: 0.02),
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
          contentPadding: EdgeInsets.all(AppSpacing.lg),
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
            color: Colors.black.withValues(alpha: 0.02),
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
            padding: EdgeInsets.all(AppSpacing.lg),
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
