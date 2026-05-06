// Manually-uploaded RPP detail bottom sheet.
//
// Owns the lifecycle for non-AI lesson plans: a teacher uploads a
// file (PDF/DOCX/image) and fills in the metadata via a form. There
// is no per-field structured editor and no AI regeneration — edits
// happen in [LessonPlanFormDialog], which already handles file
// re-upload + metadata save against the core /rpp endpoint.
//
// AI-generated RPPs go through [AiRppDetailScreen] instead. The
// dispatcher in `lesson_plan_detail_screen.dart` decides which to
// show once at entry — neither screen re-checks the kind.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/manual/manual_rpp_preview_view.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_content_formatter.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_detail_header.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/lesson_plan_form_dialog.dart';

class ManualRppDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lessonPlanData;
  final bool isNew;

  const ManualRppDetailScreen({
    super.key,
    required this.lessonPlanData,
    this.isNew = false,
  });

  static Future<void> show({
    required BuildContext context,
    required Map<String, dynamic> lessonPlanData,
    bool isNew = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => ManualRppDetailScreen(
        lessonPlanData: lessonPlanData,
        isNew: isNew,
      ),
    );
  }

  @override
  State<ManualRppDetailScreen> createState() => _ManualRppDetailScreenState();
}

class _ManualRppDetailScreenState extends State<ManualRppDetailScreen> {
  late Map<String, dynamic> _lessonPlanData;
  bool _isDownloading = false;

  Color get _primary => ColorUtils.getRoleColor('guru');

  @override
  void initState() {
    super.initState();
    _lessonPlanData = Map<String, dynamic>.from(widget.lessonPlanData);
  }

  String? get _lessonPlanId {
    final id = _lessonPlanData['id'] ??
        _lessonPlanData['rpp_id'] ??
        _lessonPlanData['lesson_plan_id'];
    final s = id?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }

  String? get _filePath {
    final url = _lessonPlanData['file_url'];
    if (url != null && url.toString().trim().isNotEmpty) {
      return url.toString().trim();
    }
    final fp = _lessonPlanData['file_path'];
    if (fp != null && fp.toString().trim().isNotEmpty) {
      return fp.toString().trim();
    }
    return null;
  }

  String _displayTitle() {
    final title = LessonPlan.fromJson(_lessonPlanData).title;
    return title.isNotEmpty ? title : 'RPP';
  }

  String _formattedContent() =>
      LessonPlanContentFormatter.format(_lessonPlanData);

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final mediaHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: mediaHeight * 0.95),
        decoration: BoxDecoration(
          color: ColorUtils.lightGray,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LessonPlanDetailHeader(
                  title: 'Detail RPP',
                  subtitle: _displayTitle(),
                  // Manual uploads have no inline editor — the edit
                  // button opens the upload form dialog directly.
                  isEditing: false,
                  isSaving: false,
                  primaryColor: _primary,
                  onEditTap: _openEditForm,
                  // No-op: the header still renders Save in some
                  // states, but it's never reached because isEditing
                  // is always false here.
                  onSaveTap: () {},
                  onExportTap: _showExportMenu,
                  onCopyTap: _copyToClipboard,
                ),
                Expanded(
                  child: ManualRppPreviewView(
                    lessonPlanData: _lessonPlanData,
                    formattedContent: _formattedContent(),
                    primaryColor: _primary,
                    filePath: _filePath,
                    isDownloading: _isDownloading,
                    onFileDownloadTap: _downloadAndOpenFile,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Edit (opens existing form dialog) ─────────────────────────

  void _openEditForm() {
    if (_lessonPlanId == null) return;
    final teacherId = (_lessonPlanData['teacher_id'] ??
            _lessonPlanData['teacher']?['id'] ??
            '')
        .toString();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
        ),
        child: LessonPlanFormDialog(
          teacherId: teacherId,
          lessonPlanData: _lessonPlanData,
          onSaved: () {
            // Pop the manual detail sheet so the list-screen
            // refresh drives the new content into view.
            AppNavigator.pop(context);
          },
        ),
      ),
    );
  }

  // ── Export menu (PDF / text) ──────────────────────────────────

  void _showExportMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export ke PDF'),
              onTap: () {
                AppNavigator.pop(sheetCtx);
                _exportToPdf();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description, color: Colors.blue),
              title: const Text('Export ke Text'),
              onTap: () {
                AppNavigator.pop(sheetCtx);
                _exportToText();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _formattedContent()));
    if (mounted) {
      SnackBarUtils.showInfo(
        context,
        AppLocalizations.lessonPlanCopiedToClipboard.tr,
      );
    }
  }

  Future<void> _exportToPdf() async {
    try {
      final document = PdfDocument();
      final page = document.pages.add();
      final graphics = page.graphics;
      final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      final titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );

      graphics.drawString(
        'RENCANA PELAKSANAAN PEMBELAJARAN (RPP)',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.size.width, 30),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      final lines = _formattedContent().split('\n');
      var y = 40.0;
      for (final line in lines) {
        if (line.trim().isEmpty) {
          y += 10;
          continue;
        }
        graphics.drawString(
          line,
          font,
          bounds: Rect.fromLTWH(50, y, page.size.width - 100, 15),
        );
        y += 18;
        if (y > page.size.height - 50) {
          document.pages.add();
          y = 40;
        }
      }

      final bytes = await document.save();
      document.dispose();

      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/RPP_${LessonPlan.fromJson(_lessonPlanData).title}_'
        '${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
      await OpenFile.open(file.path);
      if (mounted) {
        SnackBarUtils.showInfo(context, 'RPP berhasil diexport ke PDF');
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> _exportToText() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/RPP_${LessonPlan.fromJson(_lessonPlanData).title}_'
        '${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(_formattedContent(), flush: true);
      await OpenFile.open(file.path);
      if (mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.lessonPlanExportedToText.tr,
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  // ── Attachment download ───────────────────────────────────────

  Future<void> _downloadAndOpenFile() async {
    final fp = _filePath;
    final id = _lessonPlanId;
    if (fp == null || id == null) return;

    setState(() => _isDownloading = true);
    try {
      // Use the backend download proxy — works with
      // both local storage and S3/Minio. The mobile
      // client cannot resolve the internal Docker
      // hostname (e.g. minio:9000) in file_url.
      final bytes = await ApiService.downloadFile(
        '/rpp/$id/download',
      );
      final dir = await getTemporaryDirectory();
      final fileName = Uri.parse(fp).pathSegments.last;
      final localFile = File('${dir.path}/$fileName');
      await localFile.writeAsBytes(bytes, flush: true);
      await OpenFile.open(localFile.path);
      if (mounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.fileSavedSuccessfully.tr,
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          ErrorUtils.getFriendlyMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }
}
