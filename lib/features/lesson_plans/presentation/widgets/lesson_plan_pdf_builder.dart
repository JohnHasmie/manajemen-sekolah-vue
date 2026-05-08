// Builds a professional PDF document for an RPP (lesson plan).
//
// Layout (matches a real Kemdikbud-style RPP document):
//   • Header band — navy title bar with "RENCANA PELAKSANAAN
//     PEMBELAJARAN (RPP)" centered.
//   • Identitas grid — bordered 2-col PdfGrid with school info.
//   • Body sections — section headings (KOMPETENSI INTI, etc.) in
//     navy bold; paragraphs justified. The duplicate header info
//     LessonPlanContentFormatter prepends is stripped here so the
//     identitas grid isn't rendered twice.
//   • Signature block — 2-column "Mengetahui" / "Guru Mata Pelajaran"
//     with NIP placeholder lines.
//   • Footer — "Halaman X dari Y" on every page.
//
// Mixed-script rendering (Latin + Arabic)
// ---------------------------------------
// Syncfusion's PDF text engine doesn't run OpenType GSUB
// substitutions, doesn't apply Arabic kerning, and doesn't reverse
// glyph order for `PdfTextDirection.rightToLeft` — so Arabic comes
// out as a row of disjoint isolated forms regardless of which font
// or text direction we pick. Pre-shaping to Presentation Forms-B
// helps a little but still leaves visible gaps because the font's
// FE70-block glyphs aren't drawn with overlapping side-bearings.
//
// The robust fix used here: when a line contains Arabic, render it
// to a PNG using Flutter's own text engine (Skia + HarfBuzz, the
// same stack that draws Arabic correctly on screen) and embed the
// PNG in the PDF as an image. Latin-only lines still go through
// the regular PdfTextElement path so they remain selectable text.
// Identitas grid cells use [ArabicShaper.shapeRtl] as a best-effort
// fallback since PdfGrid doesn't accept image cells.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/arabic_shaper.dart';

class LessonPlanPdfBuilder {
  static final _navy = PdfColor(20, 48, 104);
  static final _slate900 = PdfColor(15, 23, 42);
  static final _slate500 = PdfColor(100, 116, 139);
  static final _slate200 = PdfColor(226, 232, 240);
  static final _slate50 = PdfColor(248, 250, 252);

  /// Header info that the identitas grid already renders — skip
  /// these lines when walking the formatted body.
  static const _headerLabels = [
    'Judul',
    'Mata Pelajaran',
    'Kelas',
    'Semester',
    'Tahun Ajaran',
    'Guru',
    'Status',
    'Satuan Pendidikan',
    'Tema',
    'Sub Tema',
    'Pembelajaran ke',
    'Alokasi waktu',
  ];

  /// Builds the full PDF and returns its bytes.
  static Future<List<int>> build({
    required Map<String, dynamic> data,
    required String formattedBody,
  }) async {
    final regular = await _ttf('assets/fonts/Poppins-Regular.ttf', 11);
    final bold = await _ttf('assets/fonts/Poppins-Bold.ttf', 11);
    final heading = await _ttf('assets/fonts/Poppins-Bold.ttf', 12);
    final title = await _ttf('assets/fonts/Poppins-Bold.ttf', 18);
    final caption = await _ttf('assets/fonts/Poppins-Regular.ttf', 9);
    // Loaded for the identitas PdfGrid only — body Arabic lines go
    // through [_renderArabicPng] and don't use a Syncfusion font.
    final arabic = await _ttf(
      'assets/fonts/NotoSansArabic-Regular.ttf',
      11,
    );

    final document = PdfDocument();
    document.pageSettings.margins.all = 0;
    document.pageSettings.size = PdfPageSize.a4;

    final page = document.pages.add();
    final pageSize = page.size;
    const margin = 40.0;
    final contentWidth = pageSize.width - margin * 2;

    // ── Header band ──
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(_navy),
      bounds: Rect.fromLTWH(0, 0, pageSize.width, 70),
    );
    page.graphics.drawString(
      'RENCANA PELAKSANAAN PEMBELAJARAN',
      title,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(margin, 18, contentWidth, 24),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    page.graphics.drawString(
      '(RPP)',
      title,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(margin, 42, contentWidth, 22),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );

    var y = 90.0;

    // ── Identitas heading ──
    page.graphics.drawString(
      'IDENTITAS',
      heading,
      brush: PdfSolidBrush(_navy),
      bounds: Rect.fromLTWH(margin, y, contentWidth, 18),
    );
    y += 24;

    // ── Identitas grid ──
    final rows = <List<String>>[
      ['Judul', _str(data, ['title', 'judul'])],
      [
        'Mata Pelajaran',
        _str(data, ['subject_name', 'mata_pelajaran_nama']),
      ],
      ['Kelas', _str(data, ['class_name', 'kelas_nama'])],
      ['Semester', _str(data, ['semester'])],
      [
        'Tahun Ajaran',
        _str(data, ['academic_year', 'tahun_ajaran']),
      ],
      ['Guru', _str(data, ['teacher_name', 'guru_nama'])],
      ['Status', _str(data, ['status'])],
    ].where((r) => r[1].trim().isNotEmpty).toList();

    final grid = PdfGrid();
    grid.columns.add(count: 2);
    grid.columns[0].width = 140;
    grid.columns[1].width = contentWidth - 140;

    for (final row in rows) {
      final r = grid.rows.add();
      final value = row[1];
      final hasArabicValue = _hasArabic(value);
      r.cells[0].value = row[0];
      r.cells[1].value = hasArabicValue ? ArabicShaper.shapeRtl(value) : value;
      r.cells[0].style = PdfGridCellStyle(
        font: bold,
        textBrush: PdfSolidBrush(_slate900),
        backgroundBrush: PdfSolidBrush(_slate50),
        cellPadding: PdfPaddings(left: 10, right: 8, top: 6, bottom: 6),
      );
      r.cells[1].style = PdfGridCellStyle(
        font: hasArabicValue ? arabic : regular,
        textBrush: PdfSolidBrush(_slate900),
        cellPadding: PdfPaddings(left: 10, right: 8, top: 6, bottom: 6),
      );
    }
    grid.style = PdfGridStyle(
      borderOverlapStyle: PdfBorderOverlapStyle.inside,
      cellSpacing: 0,
    );
    final gridResult = grid.draw(
      page: page,
      bounds: Rect.fromLTWH(margin, y, contentWidth, 0),
    );
    y = (gridResult?.bounds.bottom ?? y) + 18;

    // ── Body sections ──
    final layout = PdfLayoutFormat(
      layoutType: PdfLayoutType.paginate,
      breakType: PdfLayoutBreakType.fitPage,
    );
    PdfLayoutResult? lastResult;

    for (final raw in formattedBody.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        y = (lastResult?.bounds.bottom ?? y) + 6;
        continue;
      }

      // Skip lines already rendered in identitas/header/signature.
      if (_isHeaderInfoLine(line)) continue;
      if (line.startsWith('RENCANA PELAKSANAAN PEMBELAJARAN') ||
          RegExp(r'^[=─-]{3,}$').hasMatch(line)) {
        continue;
      }
      if (line == 'Mengetahui' ||
          line.startsWith('Kepala Sekolah') ||
          line.startsWith('Guru Mata Pelajaran') ||
          RegExp(r'^NIP[\s.…]*$').hasMatch(line) ||
          line.trim() == '---' ||
          line.startsWith('*RPP ini digenerate')) {
        continue;
      }

      final isHeading = _looksLikeHeading(line);
      final hasArabic = _hasArabic(line);

      if (y > pageSize.height - margin - 80) {
        document.pages.add();
        y = margin + 10;
        lastResult = null;
      }

      // ── Arabic line → render as PNG via Flutter's text engine ──
      // This is the only reliable way to get correct Arabic shaping
      // and joining inside a Syncfusion PDF. Skia/HarfBuzz handles
      // GSUB substitution, kerning, and bidi automatically — we just
      // capture the result as a bitmap and stamp it onto the page.
      if (hasArabic) {
        final png = await _renderArabicPng(
          text: line,
          widthPt: contentWidth,
          fontSize: isHeading ? 12.0 : 11.0,
          weight: isHeading ? FontWeight.w700 : FontWeight.w400,
          color: isHeading
              ? const Color(0xFF143068)
              : const Color(0xFF0F172A),
        );

        if (y + png.heightPt > pageSize.height - margin - 80) {
          document.pages.add();
          y = margin + 10;
          lastResult = null;
        }

        document.pages[document.pages.count - 1].graphics.drawImage(
          PdfBitmap(png.bytes),
          Rect.fromLTWH(margin, y, contentWidth, png.heightPt),
        );
        y += png.heightPt + (isHeading ? 8 : 4);
        // Bypass lastResult for Arabic lines — we tracked y manually,
        // so the next iteration's empty-line spacing should fall back
        // to y rather than a stale text-element bound.
        lastResult = null;
        continue;
      }

      // ── Latin line → keep as selectable PDF text ──
      final elementFont = isHeading ? heading : regular;
      final element = PdfTextElement(
        text: line,
        font: elementFont,
        brush: PdfSolidBrush(isHeading ? _navy : _slate900),
        format: PdfStringFormat(
          alignment: isHeading
              ? PdfTextAlignment.left
              : PdfTextAlignment.justify,
          lineSpacing: 4,
        ),
      );

      lastResult = element.draw(
        page: document.pages[document.pages.count - 1],
        bounds: Rect.fromLTWH(
          margin,
          y,
          contentWidth,
          pageSize.height - y - margin - 50,
        ),
        format: layout,
      );
      y = (lastResult?.bounds.bottom ?? y) + (isHeading ? 8 : 4);
    }

    // ── Signature block (last page) ──
    final lastPage = document.pages[document.pages.count - 1];
    final signY = (lastResult?.bounds.bottom ?? y) + 30;

    if (signY > lastPage.size.height - margin - 130) {
      final next = document.pages.add();
      _drawSignature(
        page: next,
        startY: margin + 10,
        margin: margin,
        contentWidth: contentWidth,
        regular: regular,
        bold: bold,
      );
    } else {
      _drawSignature(
        page: lastPage,
        startY: signY,
        margin: margin,
        contentWidth: contentWidth,
        regular: regular,
        bold: bold,
      );
    }

    // ── Footer ──
    for (int i = 0; i < document.pages.count; i++) {
      final p = document.pages[i];
      p.graphics.drawString(
        'Halaman ${i + 1} dari ${document.pages.count}',
        caption,
        brush: PdfSolidBrush(_slate500),
        bounds: Rect.fromLTWH(
          margin,
          p.size.height - 25,
          p.size.width - margin * 2,
          15,
        ),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
    }

    final bytes = await document.save();
    document.dispose();
    return bytes;
  }

  // ── Script detection ──

  static bool _hasArabic(String s) {
    for (final r in s.runes) {
      if (_isArabicRune(r)) return true;
    }
    return false;
  }

  static bool _isArabicRune(int rune) {
    // Arabic block: U+0600–U+06FF
    // Arabic Supplement: U+0750–U+077F
    // Arabic Extended-A: U+08A0–U+08FF
    // Arabic Presentation Forms-A: U+FB50–U+FDFF
    // Arabic Presentation Forms-B: U+FE70–U+FEFF
    return (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x08A0 && rune <= 0x08FF) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
  }

  // ── Arabic line rendering ──
  //
  // Lays out [text] using Flutter's own paragraph engine (Skia +
  // HarfBuzz) at 3× the target resolution, captures the result as
  // a PNG, and returns the bytes alongside the natural height in
  // PDF points so callers can position the image precisely.
  //
  // The 3× pixel ratio keeps the bitmap sharp when scaled back to
  // the requested PDF point box. NotoSansArabic is the primary
  // family with Poppins as fallback for any incidental Latin runs;
  // both are already declared in pubspec.yaml so they're available
  // to the runtime font registry.
  static Future<({Uint8List bytes, double heightPt})> _renderArabicPng({
    required String text,
    required double widthPt,
    required double fontSize,
    required FontWeight weight,
    required Color color,
  }) async {
    const pixelRatio = 3.0;
    final widthPx = widthPt * pixelRatio;

    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.right,
        textDirection: ui.TextDirection.rtl,
        fontSize: fontSize * pixelRatio,
        fontWeight: weight,
        fontFamily: 'NotoSansArabic',
        height: 1.4,
      ),
    )
      ..pushStyle(
        ui.TextStyle(
          color: color,
          fontFamily: 'NotoSansArabic',
          fontFamilyFallback: const ['Poppins'],
        ),
      )
      ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: widthPx));

    final heightPx = paragraph.height.ceil() + 2;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawParagraph(paragraph, Offset.zero);
    final image = await recorder
        .endRecording()
        .toImage(widthPx.ceil(), heightPx);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    return (
      bytes: byteData!.buffer.asUint8List(),
      heightPt: heightPx / pixelRatio,
    );
  }

  // ── Signature block ──

  static void _drawSignature({
    required PdfPage page,
    required double startY,
    required double margin,
    required double contentWidth,
    required PdfFont regular,
    required PdfFont bold,
  }) {
    final colWidth = (contentWidth - 40) / 2;
    final leftX = margin;
    final rightX = margin + colWidth + 40;

    page.graphics.drawString(
      'Mengetahui,',
      regular,
      brush: PdfSolidBrush(_slate900),
      bounds: Rect.fromLTWH(leftX, startY, colWidth, 14),
    );

    page.graphics.drawString(
      'Kepala Sekolah',
      bold,
      brush: PdfSolidBrush(_slate900),
      bounds: Rect.fromLTWH(leftX, startY + 18, colWidth, 14),
    );
    page.graphics.drawString(
      'Guru Mata Pelajaran',
      bold,
      brush: PdfSolidBrush(_slate900),
      bounds: Rect.fromLTWH(rightX, startY + 18, colWidth, 14),
    );

    final lineY = startY + 18 + 70;
    page.graphics.drawLine(
      PdfPen(_slate200, width: 1),
      Offset(leftX, lineY),
      Offset(leftX + colWidth - 30, lineY),
    );
    page.graphics.drawLine(
      PdfPen(_slate200, width: 1),
      Offset(rightX, lineY),
      Offset(rightX + colWidth - 30, lineY),
    );

    page.graphics.drawString(
      '( ____________________ )',
      regular,
      brush: PdfSolidBrush(_slate500),
      bounds: Rect.fromLTWH(leftX, lineY + 4, colWidth, 14),
    );
    page.graphics.drawString(
      '( ____________________ )',
      regular,
      brush: PdfSolidBrush(_slate500),
      bounds: Rect.fromLTWH(rightX, lineY + 4, colWidth, 14),
    );

    page.graphics.drawString(
      'NIP. ........................',
      regular,
      brush: PdfSolidBrush(_slate900),
      bounds: Rect.fromLTWH(leftX, lineY + 22, colWidth, 14),
    );
    page.graphics.drawString(
      'NIP. ........................',
      regular,
      brush: PdfSolidBrush(_slate900),
      bounds: Rect.fromLTWH(rightX, lineY + 22, colWidth, 14),
    );
  }

  // ── Helpers ──

  static Future<PdfFont> _ttf(String asset, double size) async {
    final byteData = await rootBundle.load(asset);
    return PdfTrueTypeFont(byteData.buffer.asUint8List(), size);
  }

  static String _str(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  static bool _isHeaderInfoLine(String line) {
    final colon = line.indexOf(':');
    if (colon < 0) return false;
    final label = line.substring(0, colon).trim();
    return _headerLabels.contains(label);
  }

  static bool _looksLikeHeading(String line) {
    if (line.length > 80) return false;
    if (line.endsWith(':') &&
        !line.toLowerCase().startsWith('contoh')) {
      return true;
    }
    final upper = line.toUpperCase() == line;
    final hasLetters =
        line.replaceAll(RegExp(r'[^A-Za-z]'), '').length >= 3;
    return upper && hasLetters;
  }
}
