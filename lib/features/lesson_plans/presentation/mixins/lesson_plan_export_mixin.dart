import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_detail_screen.dart';

/// Mixin for exporting and downloading lesson plan files.
/// Handles PDF/text export and file download operations.
mixin LessonPlanExportMixin on State<RPPDetailPage> {
  // Abstract getters/setters
  Map<String, dynamic> get lessonPlanData;
  String get editedContent;
  bool get isMounted;

  bool get isDownloading;
  set isDownloading(bool v);

  String? get filePath;
  Future<void> exportToWord() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 12);
      final PdfFont titleFont = PdfStandardFont(
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

      final List<String> lines = editedContent.split('\n');
      double yPosition = 40;

      for (final String line in lines) {
        if (line.trim().isEmpty) {
          yPosition += 10;
          continue;
        }

        graphics.drawString(
          line,
          font,
          bounds: Rect.fromLTWH(50, yPosition, page.size.width - 100, 15),
        );
        yPosition += 18;

        if (yPosition > page.size.height - 50) {
          document.pages.add();
          yPosition = 40;
        }
      }

      final List<int> bytes = await document.save();
      document.dispose();

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${LessonPlan.fromJson(lessonPlanData).title}_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);

      await OpenFile.open(file.path);

      if (isMounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              languageProvider.getTranslatedText({
                'en': 'Lesson plan exported to PDF successfully',
                'id': 'RPP berhasil diexport ke PDF',
              }),
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (isMounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> exportToText() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/RPP_${LessonPlan.fromJson(lessonPlanData).title}_${DateTime.now().millisecondsSinceEpoch}.txt',
      );
      await file.writeAsString(editedContent, flush: true);

      await OpenFile.open(file.path);

      if (isMounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.lessonPlanExportedToText.tr,
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (isMounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  String _getFileName(String filePath) {
    return Uri.parse(filePath).pathSegments.last;
  }

  Future<void> downloadAndOpenFile() async {
    final fp = filePath;
    if (fp == null) return;

    setState(() => isDownloading = true);

    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        fp,
        options: Options(responseType: ResponseType.bytes),
      );

      final directory = await getTemporaryDirectory();
      final fileName = _getFileName(fp);
      final localFile = File('${directory.path}/$fileName');
      await localFile.writeAsBytes(response.data ?? [], flush: true);

      await OpenFile.open(localFile.path);

      if (isMounted) {
        SnackBarUtils.showInfo(
          context,
          AppLocalizations.fileSavedSuccessfully.tr,
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (isMounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (isMounted) {
        setState(() => isDownloading = false);
      }
    }
  }

  Future<void> copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: editedContent));
    if (isMounted) {
      SnackBarUtils.showInfo(
        context,
        AppLocalizations.lessonPlanCopiedToClipboard.tr,
      );
    }
  }
}
