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
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_polling_skeleton_body.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_polling_error_body.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_meta_row.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_plain_text_field.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_rich_text_field.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_dialog_field.dart';

/// AI-generated lesson plan viewer/editor with rich text editing.
///
/// Supports two modes:
/// 1. Direct mode -- [lessonPlanData] is provided, displays immediately
/// 2. Polling mode -- [pollUrl]/[jobId] provided, polls for AI job completion
///
/// Uses Flutter Quill for rich text editing (like Vue Quill / TinyMCE).
/// Props: [lessonPlanData], [teacherId], [onSaved] callback, polling fields.
class LessonPlanAiResultScreen extends StatefulWidget {
  final Map<String, dynamic>? lessonPlanData;
  final String teacherId;
  final VoidCallback onSaved;

  /// Polling mode fields - when set, the screen will poll for results
  final String? pollUrl;
  final String? jobId;
  final String? token;

  /// Metadata to build lessonPlanData after polling completes
  final Map<String, dynamic>? pollingMetadata;

  const LessonPlanAiResultScreen({
    super.key,
    this.lessonPlanData,
    required this.teacherId,
    required this.onSaved,
    this.pollUrl,
    this.jobId,
    this.token,
    this.pollingMetadata,
  });

  @override
  State<LessonPlanAiResultScreen> createState() =>
      _LessonPlanAiResultScreenState();
}

/// State for [LessonPlanAiResultScreen].
///
/// Like a Vue component with `data() { return { isSaving, isPolling, ... } }`.
/// Manages multiple Quill controllers for each lesson plan section (tujuan, kegiatan
/// inti, penilaian, kompetensi) and text controllers for metadata fields.
class _LessonPlanAiResultScreenState extends State<LessonPlanAiResultScreen> {
  bool _isSaving = false;
  bool _isRegenerating = false;
  bool _isPolling = false;
  String _pollingStatus = '';
  String? _pollingError;

  late quill.QuillController _objectivesController;
  late quill.QuillController _coreActivityController;
  late quill.QuillController _assessmentController;
  late quill.QuillController _coreCompetencyController;
  late quill.QuillController _basicCompetencyController;

  late TextEditingController _titleController;
  late TextEditingController _educationUnitController;
  late TextEditingController _subjectNameController;
  late TextEditingController _chapterController;
  late TextEditingController _subChapterController;
  late TextEditingController _lessonNumberController;
  late TextEditingController _classSemesterController;
  late TextEditingController _timeAllocationController;

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
      _pollingStatus = 'AI is generating lesson plan...';
      _startPolling();
    } else {
      _initControllers(widget.lessonPlanData ?? {});
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
    final jobIdForPoll = widget.jobId ?? (widget.pollUrl?.split('/').last);

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

        AppLogger.debug(
          'lesson_plan',
          'Poll response status: ${response.statusCode}',
        );
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
            final lessonPlanResponse =
                jobData['result'] ??
                jobData['data'] ??
                resultBody['result'] ??
                resultBody;
            _applyPollingResult(lessonPlanResponse);
            return;
          } else if (status == 'failed' || status == 'error') {
            setState(() {
              _isPolling = false;
              _pollingError =
                  jobData['error_message'] ??
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
              _pollingStatus = '$statusLabel... (${attempts * 5}s)';
            });
          }
        } else if (response.statusCode == 202) {
          // Still processing
          setState(() {
            _pollingStatus = 'AI masih memproses... (${attempts * 5}s)';
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

  void _applyPollingResult(dynamic lessonPlanResponse) {
    final metadata = widget.pollingMetadata ?? {};

    final mappedData = {
      'title':
          lessonPlanResponse['title'] ?? metadata['title'] ?? 'Lesson Plan AI',
      'subject_id': metadata['mata_pelajaran_id'],
      'subject_name': metadata['mata_pelajaran_nama'] ?? '',
      'education_unit': metadata['satuan_pendidikan'] ?? 'SD/MI',
      'chapter_name': metadata['bab_nama'] ?? '',
      'sub_chapter_name': metadata['sub_bab_nama'] ?? '',
      'class_semester': metadata['kelas_semester'] ?? '',
      'theme': lessonPlanResponse['title'],
      'sub_theme': '',
      'lesson_number': '',
      'time_allocation': metadata['alokasi_waktu'] ?? '',
      'core_competency': _stripHtml(
        lessonPlanResponse['core_competence'] as String? ?? '',
      ),
      'basic_competency': _stripHtml(
        lessonPlanResponse['basic_competence'] as String? ?? '',
      ),
      'learning_objectives': _stripHtml(
        lessonPlanResponse['learning_objective'] as String? ?? '',
      ),
      'core_activity': _stripHtml(
        lessonPlanResponse['learning_activities'] as String? ?? '',
      ),
      'assessment': _stripHtml(
        lessonPlanResponse['assessment'] as String? ?? '',
      ),
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
    // English keys first, fallback to Indonesian API keys
    _titleController = TextEditingController(
      text: data['title'] ?? data['judul'] ?? 'Lesson Plan AI',
    );
    _educationUnitController = TextEditingController(
      text: data['education_unit'] ?? data['satuan_pendidikan'] ?? 'SD/MI',
    );
    _subjectNameController = TextEditingController(
      text: data['subject_name'] ?? data['mata_pelajaran_nama'] ?? '',
    );
    _chapterController = TextEditingController(
      text: data['chapter_name'] ?? data['bab_nama'] ?? '',
    );
    _subChapterController = TextEditingController(
      text: data['sub_chapter_name'] ?? data['sub_bab_nama'] ?? '',
    );
    _lessonNumberController = TextEditingController(
      text: data['lesson_number'] ?? data['pembelajaran_ke'] ?? '',
    );
    _classSemesterController = TextEditingController(
      text: data['class_semester'] ?? data['kelas_semester'] ?? '',
    );
    _timeAllocationController = TextEditingController(
      text: data['time_allocation'] ?? data['alokasi_waktu'] ?? '',
    );

    _coreCompetencyController = quill.QuillController(
      document: _convertHtmlToQuill(
        data['core_competency'] ?? data['kompetensi_inti'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _basicCompetencyController = quill.QuillController(
      document: _convertHtmlToQuill(
        data['basic_competency'] ?? data['kompetensi_dasar'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _objectivesController = quill.QuillController(
      document: _convertHtmlToQuill(
        data['learning_objectives'] ??
            data['tujuan_pembelajaran'] ??
            data['learning_objective'] ??
            '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _coreActivityController = quill.QuillController(
      document: _convertHtmlToQuill(
        data['core_activity'] ??
            data['kegiatan_inti'] ??
            data['learning_activities'] ??
            '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );

    _assessmentController = quill.QuillController(
      document: _convertHtmlToQuill(
        data['assessment'] ?? data['penilaian'] ?? '',
      ),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  // stripHtml removed because html2md is used instead

  @override
  void dispose() {
    _coreCompetencyController.dispose();
    _basicCompetencyController.dispose();
    _objectivesController.dispose();
    _coreActivityController.dispose();
    _assessmentController.dispose();
    _titleController.dispose();
    _educationUnitController.dispose();
    _subjectNameController.dispose();
    _chapterController.dispose();
    _subChapterController.dispose();
    _lessonNumberController.dispose();
    _classSemesterController.dispose();
    _timeAllocationController.dispose();
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
                LessonPlanDialogField(
                  label: 'Mata Pelajaran',
                  value: _subjectNameController.text,
                ),
                SizedBox(height: AppSpacing.md),
                LessonPlanDialogField(label: 'Bab', value: _chapterController.text),
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
                _regenerateLessonPlan(prompt: _promptController.text);
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


  Future<void> _regenerateLessonPlan({String prompt = ''}) async {
    setState(() {
      _isRegenerating = true;
    });

    try {
      // Mock API regenerate response sesuai KamillLabs documentation
      await Future.delayed(const Duration(seconds: 2));

      final regeneratedData = {
        'title': _titleController.text, // Pertahankan judul
        'learning_objective':
            '<ol><li>[Regenerated] Melalui diskusi, siswa dapat memahami konsep dengan lebih mendalam.</li><li>Diberikan studi kasus, siswa mampu memecahkan masalah dengan akurat.</li></ol>',
        'learning_activities':
            '<h3>Pendahuluan (15 menit)</h3><p>[Regenerated] Guru membuka kelas dengan cerita inspiratif terkait materi.</p><h3>Kegiatan Inti (60 menit)</h3><ul><li>Siswa melakukan debat aktif mengenai topik.</li><li>Siswa menyusun mind-map bersama kelompok.</li></ul><h3>Penutup (15 menit)</h3><p>Evaluasi singkat dan refleksi bersama.</p>',
        'assessment':
            '<h3>1. Penilaian Kinerja</h3><p>[Regenerated] Observasi terhadap keaktifan siswa dalam berdebat.</p><h3>2. Penilaian Produk</h3><p>Penilaian kreativitas mind-map yang dihasilkan kelompok.</p>',
      };

      setState(() {
        _objectivesController.document = _convertHtmlToQuill(
          regeneratedData['learning_objective']!,
        );
        _coreActivityController.document = _convertHtmlToQuill(
          regeneratedData['learning_activities']!,
        );
        _assessmentController.document = _convertHtmlToQuill(
          regeneratedData['assessment']!,
        );
      });

      if (mounted) {
        SnackBarUtils.showSuccess(context, AppLocalizations.rppRegeneratedSuccessfully.tr);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${AppLocalizations.failedToRegenerateRpp.tr}: $e')));
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
        _titleController.text.toUpperCase(),
        titleFont,
        bounds: Rect.fromLTWH(0, yPosition, page.size.width, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      yPosition += 40;

      // Draw meta info
      final metaData = [
        'Satuan Pendidikan : ${_educationUnitController.text}',
        'Mata Pelajaran    : ${_subjectNameController.text}',
        'Bab               : ${_chapterController.text}',
        'Sub Bab           : ${_subChapterController.text}',
        'Kelas/Semester    : ${_classSemesterController.text}',
        'Pembelajaran Ke   : ${_lessonNumberController.text}',
        'Alokasi Waktu     : ${_timeAllocationController.text}',
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
        _coreCompetencyController.document.toPlainText(),
        yPosition,
      );
      yPosition = drawSection(
        'B. Kompetensi Dasar (KD) dan Indikator (IPK)',
        _basicCompetencyController.document.toPlainText(),
        yPosition,
      );
      yPosition = drawSection(
        'C. Tujuan Pembelajaran',
        _objectivesController.document.toPlainText(),
        yPosition,
      );
      yPosition = drawSection(
        'D. Kegiatan Pembelajaran',
        _coreActivityController.document.toPlainText(),
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
        SnackBarUtils.showInfo(context, '${AppLocalizations.failedToCreatePdfPreview.tr}: $e');
      }
    }
  }

  Future<void> _saveLessonPlan() async {
    if (_titleController.text.isEmpty) {
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
            widget.lessonPlanData?['mata_pelajaran_id'] ??
            widget.lessonPlanData?['subject_id'],
        'judul': _titleController.text,
        'kompetensi_inti': _coreCompetencyController.document.toPlainText(),
        'kompetensi_dasar': _basicCompetencyController.document.toPlainText(),
        'tujuan_pembelajaran': _objectivesController.document.toPlainText(),
        'kegiatan_pendahuluan':
            '• Melakukan Pembukaan dengan Salam dan Membaca Doa\n• Mengaitkan Materi Sebelumnya',
        'kegiatan_inti': _coreActivityController.document.toPlainText(),
        'kegiatan_penutup':
            '• Siswa membuat resume dengan bimbingan guru\n• Guru memeriksa pekerjaan siswa',
        'penilaian': _assessmentController.document.toPlainText(),
        'satuan_pendidikan': _educationUnitController.text,
        'kelas_semester': _classSemesterController.text,
        'tema': _chapterController.text, // Chapter as theme
        'sub_tema': _subChapterController.text,
        'pembelajaran_ke': _lessonNumberController.text,
        'alokasi_waktu': _timeAllocationController.text,
        'waktu_pendahuluan': '15',
        'waktu_inti': '140',
        'waktu_penutup': '15',
        'is_ai_generated': true, // Backend flag for AI-generated content
      };

      AppLogger.debug('lesson_plan', "Menyimpan RPP Payload: \$payloadData");

      await getIt<ApiSubjectService>().saveRPP(payloadData);

      if (mounted) {
        SnackBarUtils.showSuccess(context, AppLocalizations.rppSavedSuccessfully.tr);
        AppNavigator.pop(
          context,
        ); // Return to RPP list (PopScope triggers onSaved)
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
          title: Text(
            _isPolling ? 'Generating RPP AI...' : 'Hasil RPP AI (K-13)',
          ),
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
                    onPressed: _isSaving ? null : _saveLessonPlan,
                    tooltip: 'Simpan RPP',
                  ),
                ],
        ),
        body: _isPolling
            ? LessonPlanPollingSkeletonBody(pollingStatus: _pollingStatus)
            : _pollingError != null
            ? LessonPlanPollingErrorBody(
                pollingError: _pollingError,
                onBack: () => AppNavigator.pop(context),
              )
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
                              AppLocalizations.rppAiGeneratedDescription.tr,
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
                    LessonPlanPlainTextField(controller: _titleController, maxLines: 1),
                    SizedBox(height: AppSpacing.xl),
                    _buildSectionHeader('Informasi Umum'),
                    _buildMetaInfoPanel(),
                    SizedBox(height: AppSpacing.xl),
                    _buildSectionHeader('A. Kompetensi Inti (KI)'),
                    LessonPlanRichTextField(controller:_coreCompetencyController),
                    SizedBox(height: AppSpacing.xl),
                    _buildSectionHeader(
                      'B. Kompetensi Dasar (KD) dan Indikator (IPK)',
                    ),
                    LessonPlanRichTextField(controller:_basicCompetencyController),
                    SizedBox(height: AppSpacing.xl),
                    _buildSectionHeader('C. Tujuan Pembelajaran'),
                    LessonPlanRichTextField(controller:_objectivesController),
                    SizedBox(height: AppSpacing.xl),
                    _buildSectionHeader(
                      'D. Kegiatan Pembelajaran (Pendahuluan, Inti, Penutup)',
                    ),
                    LessonPlanRichTextField(controller:_coreActivityController),
                    SizedBox(height: AppSpacing.xl),
                    _buildSectionHeader('E. Penilaian (Asesmen)'),
                    LessonPlanRichTextField(controller:_assessmentController),
                    SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveLessonPlan,
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
          LessonPlanMetaRow(label: 'Satuan Pendidikan', controller: _educationUnitController),
          LessonPlanMetaRow(label: 'Mata Pelajaran', controller: _subjectNameController),
          LessonPlanMetaRow(label: 'Bab', controller: _chapterController),
          LessonPlanMetaRow(label: 'Sub Bab', controller: _subChapterController),
          LessonPlanMetaRow(label: 'Kelas/Semester', controller: _classSemesterController),
          LessonPlanMetaRow(label: 'Pembelajaran Ke', controller: _lessonNumberController),
          LessonPlanMetaRow(label: 'Alokasi Waktu', controller: _timeAllocationController),
        ],
      ),
    );
  }

}
