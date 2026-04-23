import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_ai_result_screen.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/mixins/lesson_plan_ai_result_data_mixin.dart';

mixin LessonPlanAiResultExportMixin
    on State<LessonPlanAiResultScreen>, LessonPlanAiResultDataMixin {
  Future<void> previewPDF() async {
    try {
      final (document, page, graphics) = _createPdfDocument();
      final double yPosition = _renderPdfContent(document, page, graphics);
      await _savePdfFile(document);
    } catch (e) {
      _handlePdfError(e);
    }
  }

  (PdfDocument, PdfPage, PdfGraphics) _createPdfDocument() {
    final document = PdfDocument();
    final page = document.pages.add();
    return (document, page, page.graphics);
  }

  double _renderPdfContent(
    PdfDocument document,
    PdfPage page,
    PdfGraphics graphics,
  ) {
    _drawPdfHeader(graphics, page);
    double yPosition = _drawPdfMetadata(graphics, page, 40);
    yPosition += 20;

    yPosition = _drawPdfSectionGroup(page, graphics, yPosition);
    return yPosition;
  }

  double _drawPdfSectionGroup(
    PdfPage page,
    PdfGraphics graphics,
    double yPosition,
  ) {
    yPosition = _drawSection1(page, graphics, yPosition);
    yPosition = _drawSection2(page, graphics, yPosition);
    yPosition = _drawSection3(page, graphics, yPosition);
    yPosition = _drawSection4(page, graphics, yPosition);
    return _drawSection5(page, graphics, yPosition);
  }

  double _drawSection1(PdfPage page, PdfGraphics graphics, double y) =>
      _drawPdfSection(
        'A. Kompetensi Inti (KI)',
        coreCompetencyController.document.toPlainText(),
        page,
        graphics,
        y,
      );

  double _drawSection2(PdfPage page, PdfGraphics graphics, double y) =>
      _drawPdfSection(
        'B. Kompetensi Dasar (KD) dan Indikator (IPK)',
        basicCompetencyController.document.toPlainText(),
        page,
        graphics,
        y,
      );

  double _drawSection3(PdfPage page, PdfGraphics graphics, double y) =>
      _drawPdfSection(
        'C. Tujuan Pembelajaran',
        objectivesController.document.toPlainText(),
        page,
        graphics,
        y,
      );

  double _drawSection4(PdfPage page, PdfGraphics graphics, double y) =>
      _drawPdfSection(
        'D. Kegiatan Pembelajaran',
        coreActivityController.document.toPlainText(),
        page,
        graphics,
        y,
      );

  double _drawSection5(PdfPage page, PdfGraphics graphics, double y) =>
      _drawPdfSection(
        'E. Penilaian (Asesmen)',
        assessmentController.document.toPlainText(),
        page,
        graphics,
        y,
      );

  void _drawPdfHeader(PdfGraphics graphics, PdfPage page) {
    final titleFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      14,
      style: PdfFontStyle.bold,
    );
    _drawCenteredString(
      graphics,
      page,
      titleFont,
      0,
      'RENCANA PELAKSANAAN PEMBELAJARAN (RPP)',
    );
    _drawCenteredString(
      graphics,
      page,
      titleFont,
      30,
      titleController.text.toUpperCase(),
    );
  }

  void _drawCenteredString(
    PdfGraphics graphics,
    PdfPage page,
    PdfFont font,
    double yPos,
    String text,
  ) {
    graphics.drawString(
      text,
      font,
      bounds: Rect.fromLTWH(0, yPos, page.size.width, 30),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
  }

  double _drawPdfMetadata(PdfGraphics graphics, PdfPage page, double startY) {
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);
    final metaData = [
      'Satuan Pendidikan : ${educationUnitController.text}',
      'Mata Pelajaran    : ${subjectNameController.text}',
      'Bab               : ${chapterController.text}',
      'Sub Bab           : ${subChapterController.text}',
      'Kelas/Semester    : ${classSemesterController.text}',
      'Pembelajaran Ke   : ${lessonNumberController.text}',
      'Alokasi Waktu     : ${timeAllocationController.text}',
    ];

    double yPosition = startY;
    for (final meta in metaData) {
      if (yPosition > page.size.height - 30) {
        yPosition = 40;
      }
      graphics.drawString(
        meta,
        font,
        bounds: Rect.fromLTWH(0, yPosition, page.size.width - 20, 15),
      );
      yPosition += 18;
    }
    return yPosition;
  }

  double _drawPdfSection(
    String title,
    String content,
    PdfPage page,
    PdfGraphics graphics,
    double startY,
  ) {
    final headerFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      12,
      style: PdfFontStyle.bold,
    );
    final font = PdfStandardFont(PdfFontFamily.helvetica, 12);

    double currentY = startY;
    if (currentY > page.size.height - 50) currentY = 40;

    graphics.drawString(
      title,
      headerFont,
      bounds: Rect.fromLTWH(0, currentY, page.size.width, 20),
    );
    currentY += 20;

    if (content.trim().isEmpty) return currentY + 10;

    final textElement = PdfTextElement(text: content, font: font);
    final result = textElement.draw(
      page: page,
      bounds: Rect.fromLTWH(20, currentY, page.size.width - 40, 0),
    );

    if (result != null) {
      return result.bounds.bottom + 20;
    }
    return currentY + 10;
  }

  Future<void> _savePdfFile(PdfDocument document) async {
    final bytes = await document.save();
    document.dispose();

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/Preview_RPP_'
      '${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(bytes, flush: true);
    await OpenFile.open(file.path);
  }

  void _handlePdfError(dynamic e) {
    AppLogger.error('lesson_plan', e);
    if (mounted) {
      SnackBarUtils.showInfo(
        context,
        '${AppLocalizations.failedToCreatePdfPreview.tr}: $e',
      );
    }
  }
}
