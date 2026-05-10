// Builds a professional PDF document for an RPP (lesson plan).
//
// Layout (Kemdikbud-style RPP, polished for the 2026 redesign):
//   • Masthead — navy band with the format chip ("K13 / RPP 1 HAL /
//     MODUL AJAR / FILE"), the lesson title, and class · subject
//     · semester strip below.
//   • Identitas table — bordered 2-col PdfGrid with alternating
//     row tints and stronger label cells.
//   • Body sections — each major section ("A. KOMPETENSI INTI",
//     "B. KOMPETENSI DASAR", …) opens with a navy-banded heading
//     row that carries a white circular letter badge + the section
//     title in white, then the prose underneath. Sub-sections
//     ("Kegiatan Pendahuluan", "Sikap", "Pengetahuan", "Keterampilan",
//     etc.) render as left-bordered slate labels. "(NN menit)"
//     trailing on a heading is plucked into a navy pill on the
//     right side of the bar so the duration reads at a glance.
//   • Signature block — clean two-column "Mengetahui" / "Guru
//     Mata Pelajaran" with thin horizontal lines (no dotted
//     ellipses) for the name + NIP placeholders.
//   • Footer — format pill on the left, "Halaman X dari Y" on the
//     right.
//
// The duplicate header info LessonPlanContentFormatter prepends is
// stripped here so the identitas grid isn't rendered twice. The
// per-line walk approach is kept because it works for both the
// legacy column-based payloads and the new format_data JSON path —
// both flow through `LessonPlanContentFormatter.format()`.
//
// Mixed-script rendering (Latin + Arabic)
// ---------------------------------------
// Syncfusion's PDF text engine doesn't run OpenType GSUB
// substitutions, doesn't apply Arabic kerning, and doesn't reverse
// glyph order for `PdfTextDirection.rightToLeft` — so Arabic comes
// out as a row of disjoint isolated forms regardless of which font
// or text direction we pick. The robust fix used here: when a line
// contains Arabic, render it to a PNG using Flutter's own text
// engine (Skia + HarfBuzz, the same stack that draws Arabic
// correctly on screen) and embed the PNG in the PDF as an image.
// Latin-only lines still go through the regular PdfTextElement path
// so they remain selectable text. Identitas grid cells use
// [ArabicShaper.shapeRtl] as a best-effort fallback since PdfGrid
// doesn't accept image cells.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:manajemensekolah/features/lesson_plans/presentation/widgets/arabic_shaper.dart';

class LessonPlanPdfBuilder {
  static final _navy = PdfColor(20, 48, 104);
  static final _navyLight = PdfColor(37, 80, 156);
  static final _slate900 = PdfColor(15, 23, 42);
  static final _slate700 = PdfColor(51, 65, 85);
  static final _slate500 = PdfColor(100, 116, 139);
  static final _slate200 = PdfColor(226, 232, 240);
  static final _slate100 = PdfColor(241, 245, 249);
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

  /// Sub-section labels that should render as a left-bordered slate
  /// label rather than as another full section bar. Matched
  /// case-insensitively against the trimmed line.
  static const _subSectionLabels = [
    'kegiatan pendahuluan',
    'kegiatan inti',
    'kegiatan penutup',
    'pendahuluan',
    'inti',
    'penutup',
    'sikap',
    'pengetahuan',
    'keterampilan',
    'asesmen formatif',
    'asesmen sumatif',
    'pemahaman bermakna',
    'pertanyaan pemantik',
    'profil pelajar pancasila',
  ];

  /// Builds the full PDF and returns its bytes.
  static Future<List<int>> build({
    required Map<String, dynamic> data,
    required String formattedBody,
  }) async {
    final regular = await _ttf('assets/fonts/Poppins-Regular.ttf', 11);
    final bold = await _ttf('assets/fonts/Poppins-Bold.ttf', 11);
    final boldSmall = await _ttf('assets/fonts/Poppins-Bold.ttf', 10);
    final heading = await _ttf('assets/fonts/Poppins-Bold.ttf', 12);
    final sectionTitle = await _ttf('assets/fonts/Poppins-Bold.ttf', 12.5);
    final sectionLetter = await _ttf('assets/fonts/Poppins-Bold.ttf', 11);
    final mastheadKicker = await _ttf('assets/fonts/Poppins-Bold.ttf', 9);
    final mastheadTitle = await _ttf('assets/fonts/Poppins-Bold.ttf', 18);
    final mastheadStrip = await _ttf('assets/fonts/Poppins-Regular.ttf', 10);
    final caption = await _ttf('assets/fonts/Poppins-Regular.ttf', 8.5);
    final captionBold = await _ttf('assets/fonts/Poppins-Bold.ttf', 8.5);
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

    // ── Masthead ──
    final formatLabel = _resolveFormatLabel(data);
    _drawMasthead(
      page: page,
      pageWidth: pageSize.width,
      contentWidth: contentWidth,
      margin: margin,
      data: data,
      formatLabel: formatLabel,
      mastheadKicker: mastheadKicker,
      mastheadTitle: mastheadTitle,
      mastheadStrip: mastheadStrip,
    );

    var y = 110.0;

    // ── Identitas heading + grid ──
    _drawSectionBar(
      page: page,
      x: margin,
      y: y,
      width: contentWidth,
      letter: '•',
      title: 'IDENTITAS',
      sectionLetterFont: sectionLetter,
      sectionTitleFont: sectionTitle,
    );
    y += 32;

    final identitasRows = <List<String>>[
      ['Judul', _str(data, ['title', 'judul'])],
      ['Mata Pelajaran', _str(data, ['subject_name', 'mata_pelajaran_nama'])],
      ['Kelas', _str(data, ['class_name', 'kelas_nama'])],
      ['Semester', _str(data, ['semester'])],
      ['Tahun Ajaran', _str(data, ['academic_year', 'tahun_ajaran'])],
      ['Alokasi Waktu', _str(data, ['time_allocation', 'alokasi_waktu'])],
      ['Guru', _str(data, ['teacher_name', 'guru_nama'])],
      ['Status', _str(data, ['status'])],
    ].where((r) => r[1].trim().isNotEmpty).toList();

    final grid = PdfGrid();
    grid.columns.add(count: 2);
    grid.columns[0].width = 140;
    grid.columns[1].width = contentWidth - 140;

    for (var i = 0; i < identitasRows.length; i++) {
      final row = identitasRows[i];
      final r = grid.rows.add();
      final value = row[1];
      final hasArabicValue = _hasArabic(value);
      final altRow = i.isOdd;
      r.cells[0].value = row[0];
      r.cells[1].value = hasArabicValue ? ArabicShaper.shapeRtl(value) : value;
      r.cells[0].style = PdfGridCellStyle(
        font: bold,
        textBrush: PdfSolidBrush(_navy),
        backgroundBrush: PdfSolidBrush(_slate100),
        cellPadding: PdfPaddings(left: 12, right: 8, top: 7, bottom: 7),
      );
      r.cells[1].style = PdfGridCellStyle(
        font: hasArabicValue ? arabic : regular,
        textBrush: PdfSolidBrush(_slate900),
        backgroundBrush: PdfSolidBrush(altRow ? _slate50 : PdfColor(255, 255, 255)),
        cellPadding: PdfPaddings(left: 12, right: 8, top: 7, bottom: 7),
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
    y = (gridResult?.bounds.bottom ?? y) + 20;

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

      // Skip lines already rendered in identitas / masthead /
      // signature footer.
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

      final hasArabic = _hasArabic(line);

      // ── Section detector — "A. KOMPETENSI INTI" / "B. KOMPETENSI DASAR" / …
      final sectionMatch = RegExp(
        r'^([A-Z])\.\s+(.+)$',
      ).firstMatch(line);
      if (sectionMatch != null && _looksLikeSectionTitle(sectionMatch.group(2)!)) {
        // Pluck "(NN menit)" trailing on a section title into a
        // pill so the duration is callout-styled instead of just
        // running into the heading text. Common on K13 langkah_kegiatan
        // sub-sections like "Pendahuluan (10 menit)".
        var titleRaw = sectionMatch.group(2)!.trim();
        String? timeBadge;
        final timeMatch = RegExp(
          r'\(\s*(\d+)\s*menit\s*\)',
          caseSensitive: false,
        ).firstMatch(titleRaw);
        if (timeMatch != null) {
          timeBadge = '${timeMatch.group(1)} MENIT';
          titleRaw = titleRaw.replaceAll(timeMatch.group(0)!, '').trim();
        }

        if (y > pageSize.height - margin - 100) {
          document.pages.add();
          y = margin + 10;
          lastResult = null;
        }

        _drawSectionBar(
          page: document.pages[document.pages.count - 1],
          x: margin,
          y: y,
          width: contentWidth,
          letter: sectionMatch.group(1)!,
          title: titleRaw.toUpperCase(),
          sectionLetterFont: sectionLetter,
          sectionTitleFont: sectionTitle,
          timeBadge: timeBadge,
          timeBadgeFont: captionBold,
        );
        y += 32;
        lastResult = null;
        continue;
      }

      // ── Sub-section label — "Kegiatan Pendahuluan", "Sikap", …
      if (_isSubSectionLabel(line)) {
        if (y > pageSize.height - margin - 80) {
          document.pages.add();
          y = margin + 10;
          lastResult = null;
        }

        var titleRaw = line;
        String? timeBadge;
        final timeMatch = RegExp(
          r'\(\s*(\d+)\s*menit\s*\)',
          caseSensitive: false,
        ).firstMatch(titleRaw);
        if (timeMatch != null) {
          timeBadge = '${timeMatch.group(1)} MENIT';
          titleRaw = titleRaw.replaceAll(timeMatch.group(0)!, '').trim();
        }

        _drawSubSectionLabel(
          page: document.pages[document.pages.count - 1],
          x: margin,
          y: y,
          width: contentWidth,
          title: titleRaw,
          font: heading,
          timeBadge: timeBadge,
          timeBadgeFont: captionBold,
        );
        y += 26;
        lastResult = null;
        continue;
      }

      if (y > pageSize.height - margin - 80) {
        document.pages.add();
        y = margin + 10;
        lastResult = null;
      }

      // ── Arabic line → render as PNG via Flutter's text engine ──
      if (hasArabic) {
        final png = await _renderArabicPng(
          text: line,
          widthPt: contentWidth,
          fontSize: 11.0,
          weight: FontWeight.w400,
          color: const Color(0xFF0F172A),
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
        y += png.heightPt + 4;
        lastResult = null;
        continue;
      }

      // ── Latin paragraph → keep as selectable PDF text ──
      // Detect numbered / bulleted lines and indent them so the
      // markers visually align rather than running flush with the
      // section bar's left edge.
      final isList = RegExp(r'^(\d+\.\s|•\s|-\s)').hasMatch(line);
      final element = PdfTextElement(
        text: line,
        font: regular,
        brush: PdfSolidBrush(_slate900),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.left,
          lineSpacing: 4,
        ),
      );

      lastResult = element.draw(
        page: document.pages[document.pages.count - 1],
        bounds: Rect.fromLTWH(
          margin + (isList ? 8 : 0),
          y,
          contentWidth - (isList ? 8 : 0),
          pageSize.height - y - margin - 50,
        ),
        format: layout,
      );
      y = (lastResult?.bounds.bottom ?? y) + 4;
    }

    // ── Signature block (last page) ──
    final lastPage = document.pages[document.pages.count - 1];
    final signY = (lastResult?.bounds.bottom ?? y) + 32;

    if (signY > lastPage.size.height - margin - 130) {
      final next = document.pages.add();
      _drawSignature(
        page: next,
        startY: margin + 20,
        margin: margin,
        contentWidth: contentWidth,
        regular: regular,
        bold: bold,
        boldSmall: boldSmall,
      );
    } else {
      _drawSignature(
        page: lastPage,
        startY: signY,
        margin: margin,
        contentWidth: contentWidth,
        regular: regular,
        bold: bold,
        boldSmall: boldSmall,
      );
    }

    // ── Footer (format pill + page number) ──
    for (int i = 0; i < document.pages.count; i++) {
      _drawFooter(
        page: document.pages[i],
        pageIndex: i,
        pageCount: document.pages.count,
        margin: margin,
        formatLabel: formatLabel,
        caption: caption,
        captionBold: captionBold,
      );
    }

    final bytes = await document.save();
    document.dispose();
    return bytes;
  }

  // ── Masthead ────────────────────────────────────────────────────

  static void _drawMasthead({
    required PdfPage page,
    required double pageWidth,
    required double contentWidth,
    required double margin,
    required Map<String, dynamic> data,
    required String formatLabel,
    required PdfFont mastheadKicker,
    required PdfFont mastheadTitle,
    required PdfFont mastheadStrip,
  }) {
    // Navy band fills the full width — flush with the page edge so
    // the masthead reads as a definitive page header rather than a
    // floating box.
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(_navy),
      bounds: Rect.fromLTWH(0, 0, pageWidth, 84),
    );
    // Subtle accent stripe at the bottom of the band — visually
    // separates the title area from the stripe row underneath.
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(_navyLight),
      bounds: Rect.fromLTWH(0, 80, pageWidth, 4),
    );

    final title = _str(data, ['title', 'judul']);
    final kicker = [
      'RPP',
      formatLabel.toUpperCase(),
    ].where((s) => s.isNotEmpty).join(' · ');

    page.graphics.drawString(
      kicker,
      mastheadKicker,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(margin, 14, contentWidth, 12),
    );

    page.graphics.drawString(
      title.isNotEmpty ? title : 'Rencana Pelaksanaan Pembelajaran',
      mastheadTitle,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(margin, 28, contentWidth, 24),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.left,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );

    final stripParts = <String>[
      _str(data, ['subject_name', 'mata_pelajaran_nama']),
      _str(data, ['class_name', 'kelas_nama']),
      [
        _str(data, ['semester']),
        _str(data, ['academic_year', 'tahun_ajaran']),
      ].where((s) => s.isNotEmpty).join(' '),
    ].where((s) => s.isNotEmpty).toList();

    if (stripParts.isNotEmpty) {
      page.graphics.drawString(
        stripParts.join('  ·  '),
        mastheadStrip,
        brush: PdfSolidBrush(PdfColor(207, 219, 240)),
        bounds: Rect.fromLTWH(margin, 56, contentWidth, 14),
      );
    }
  }

  // ── Section bar (full-width navy with letter badge) ────────────

  static void _drawSectionBar({
    required PdfPage page,
    required double x,
    required double y,
    required double width,
    required String letter,
    required String title,
    required PdfFont sectionLetterFont,
    required PdfFont sectionTitleFont,
    String? timeBadge,
    PdfFont? timeBadgeFont,
  }) {
    const barHeight = 26.0;
    // Bar background.
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(_navy),
      bounds: Rect.fromLTWH(x, y, width, barHeight),
    );

    // Letter badge — circular ring on the left.
    page.graphics.drawEllipse(
      Rect.fromLTWH(x + 6, y + 4, 18, 18),
      brush: PdfSolidBrush(PdfColor(255, 255, 255)),
    );
    page.graphics.drawString(
      letter,
      sectionLetterFont,
      brush: PdfSolidBrush(_navy),
      bounds: Rect.fromLTWH(x + 6, y + 4, 18, 18),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );

    // Time pill on the far right (when supplied).
    var titleEnd = x + width - 8;
    if (timeBadge != null && timeBadgeFont != null) {
      const pillWidth = 60.0;
      const pillHeight = 16.0;
      final pillX = x + width - pillWidth - 8;
      final pillY = y + (barHeight - pillHeight) / 2;
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(255, 255, 255, 35)),
        bounds: Rect.fromLTWH(pillX, pillY, pillWidth, pillHeight),
      );
      page.graphics.drawString(
        timeBadge,
        timeBadgeFont,
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(pillX, pillY, pillWidth, pillHeight),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
      titleEnd = pillX - 4;
    }

    // Title.
    page.graphics.drawString(
      title,
      sectionTitleFont,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(
        x + 30,
        y,
        titleEnd - x - 30,
        barHeight,
      ),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.left,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
  }

  // ── Sub-section label (left-bordered slate row) ────────────────

  static void _drawSubSectionLabel({
    required PdfPage page,
    required double x,
    required double y,
    required double width,
    required String title,
    required PdfFont font,
    String? timeBadge,
    PdfFont? timeBadgeFont,
  }) {
    const labelHeight = 22.0;
    // Left navy accent stripe — 3pt wide.
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(_navyLight),
      bounds: Rect.fromLTWH(x, y, 3, labelHeight),
    );
    // Slate100 background fill.
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(_slate100),
      bounds: Rect.fromLTWH(x + 3, y, width - 3, labelHeight),
    );

    var titleEnd = x + width - 8;
    if (timeBadge != null && timeBadgeFont != null) {
      const pillWidth = 56.0;
      const pillHeight = 14.0;
      final pillX = x + width - pillWidth - 8;
      final pillY = y + (labelHeight - pillHeight) / 2;
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(_navy),
        bounds: Rect.fromLTWH(pillX, pillY, pillWidth, pillHeight),
      );
      page.graphics.drawString(
        timeBadge,
        timeBadgeFont,
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(pillX, pillY, pillWidth, pillHeight),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
      titleEnd = pillX - 4;
    }

    page.graphics.drawString(
      title,
      font,
      brush: PdfSolidBrush(_navy),
      bounds: Rect.fromLTWH(
        x + 12,
        y,
        titleEnd - x - 12,
        labelHeight,
      ),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.left,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
  }

  // ── Signature block ────────────────────────────────────────────

  static void _drawSignature({
    required PdfPage page,
    required double startY,
    required double margin,
    required double contentWidth,
    required PdfFont regular,
    required PdfFont bold,
    required PdfFont boldSmall,
  }) {
    final colWidth = (contentWidth - 40) / 2;
    final leftX = margin;
    final rightX = margin + colWidth + 40;

    page.graphics.drawString(
      'Mengetahui,',
      regular,
      brush: PdfSolidBrush(_slate700),
      bounds: Rect.fromLTWH(leftX, startY, colWidth, 14),
    );

    page.graphics.drawString(
      'Kepala Sekolah',
      bold,
      brush: PdfSolidBrush(_navy),
      bounds: Rect.fromLTWH(leftX, startY + 18, colWidth, 14),
    );
    page.graphics.drawString(
      'Guru Mata Pelajaran',
      bold,
      brush: PdfSolidBrush(_navy),
      bounds: Rect.fromLTWH(rightX, startY + 18, colWidth, 14),
    );

    // Signature space — clean horizontal lines, no dotted ellipses.
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
      'Nama & Tanda Tangan',
      boldSmall,
      brush: PdfSolidBrush(_slate500),
      bounds: Rect.fromLTWH(leftX, lineY + 4, colWidth, 12),
    );
    page.graphics.drawString(
      'Nama & Tanda Tangan',
      boldSmall,
      brush: PdfSolidBrush(_slate500),
      bounds: Rect.fromLTWH(rightX, lineY + 4, colWidth, 12),
    );

    page.graphics.drawString(
      'NIP.',
      regular,
      brush: PdfSolidBrush(_slate900),
      bounds: Rect.fromLTWH(leftX, lineY + 22, colWidth, 14),
    );
    page.graphics.drawString(
      'NIP.',
      regular,
      brush: PdfSolidBrush(_slate900),
      bounds: Rect.fromLTWH(rightX, lineY + 22, colWidth, 14),
    );
  }

  // ── Footer ──────────────────────────────────────────────────────

  static void _drawFooter({
    required PdfPage page,
    required int pageIndex,
    required int pageCount,
    required double margin,
    required String formatLabel,
    required PdfFont caption,
    required PdfFont captionBold,
  }) {
    final pageSize = page.size;
    final footerY = pageSize.height - 28;
    // Thin top hairline so the footer reads as a defined band even
    // on long content pages.
    page.graphics.drawLine(
      PdfPen(_slate200, width: 0.6),
      Offset(margin, footerY),
      Offset(pageSize.width - margin, footerY),
    );

    if (formatLabel.isNotEmpty) {
      // Format pill on the left.
      const pillHeight = 14.0;
      final pillWidth =
          (formatLabel.length * 5.5 + 16).clamp(48.0, 110.0).toDouble();
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(_navy),
        bounds: Rect.fromLTWH(margin, footerY + 5, pillWidth, pillHeight),
      );
      page.graphics.drawString(
        formatLabel.toUpperCase(),
        captionBold,
        brush: PdfBrushes.white,
        bounds:
            Rect.fromLTWH(margin, footerY + 5, pillWidth, pillHeight),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );
    }

    // Page X of Y on the right.
    page.graphics.drawString(
      'Halaman ${pageIndex + 1} dari $pageCount',
      caption,
      brush: PdfSolidBrush(_slate500),
      bounds: Rect.fromLTWH(
        margin,
        footerY + 5,
        pageSize.width - margin * 2,
        14,
      ),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.right,
        lineAlignment: PdfVerticalAlignment.middle,
      ),
    );
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

  /// Read the lesson plan format and return a short uppercase pill
  /// label ("K13", "RPP 1 HAL", "MODUL AJAR", "FILE"). Falls through
  /// to an empty string when the column is missing — masthead/footer
  /// silently skip the pill in that case.
  static String _resolveFormatLabel(Map<String, dynamic> data) {
    final raw = (data['format'] ?? '').toString().trim().toLowerCase();
    switch (raw) {
      case 'k13':
        return 'K13';
      case 'rpp_1_halaman':
      case 'rpp_1hal':
      case 'rpp1halaman':
        return 'RPP 1 HAL';
      case 'modul_ajar':
      case 'modulajar':
        return 'MODUL AJAR';
      case 'file':
        return 'FILE';
    }
    return '';
  }

  static bool _isHeaderInfoLine(String line) {
    final colon = line.indexOf(':');
    if (colon < 0) return false;
    final label = line.substring(0, colon).trim();
    return _headerLabels.contains(label);
  }

  /// Heuristic for whether a line is the body of a section title
  /// (e.g. "KOMPETENSI INTI (KI)") vs an inline "A. Pendahuluan".
  /// We only render the navy section bar for genuinely uppercase
  /// section titles — inline activity headings still flow as
  /// sub-section labels via [_isSubSectionLabel].
  static bool _looksLikeSectionTitle(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return false;
    // Must be mostly uppercase to qualify — rules out "A. Pendahuluan"
    // (mixed case) which should render as a sub-section label, not a
    // full section bar.
    final letters = trimmed.replaceAll(RegExp(r'[^A-Za-z]'), '');
    if (letters.length < 3) return false;
    return letters.toUpperCase() == letters;
  }

  static bool _isSubSectionLabel(String line) {
    final lower = line.trim().toLowerCase();
    if (lower.isEmpty) return false;
    // Strip a trailing "(NN menit)" before matching so
    // "Kegiatan Pendahuluan (10 menit)" still triggers.
    final stripped = lower
        .replaceAll(RegExp(r'\(\s*\d+\s*menit\s*\)'), '')
        .trim();
    for (final label in _subSectionLabels) {
      if (stripped == label) return true;
    }
    return false;
  }
}
