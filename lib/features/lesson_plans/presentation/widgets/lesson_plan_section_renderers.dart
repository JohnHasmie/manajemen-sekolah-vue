// Format-specific section body renderers — Frame D / E / F polish.
//
// AiRppPreviewView calls [buildSectionBody] for each section card; if
// a custom layout exists for the given (format, fieldKey) pair we
// return a Widget, otherwise the caller falls back to the generic
// HtmlWidget renderer in LessonPlanFieldCard.
//
// The renderers are tolerant: they parse the AI-generated HTML with
// small regex extractors and fall through to null when the shape
// doesn't match (so unexpected AI output never crashes the page).

import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan_format.dart';

/// Returns a custom rendering for `(format, fieldKey)` or null.
///
/// The caller provides:
///   - `format` — the lesson plan's format (drives the dispatch)
///   - `fieldKey` — section key (e.g. "identitas", "langkah_kegiatan")
///   - `html` — section content as HTML string (from `format_data`)
///   - `lessonPlanData` — the full plan map, used by some renderers
///     to fill grid cells from columns when the HTML is empty.
Widget? buildSectionBody({
  required LessonPlanFormat format,
  required String fieldKey,
  required String html,
  required Map<String, dynamic> lessonPlanData,
}) {
  switch (format) {
    case LessonPlanFormat.k13:
      switch (fieldKey) {
        case 'identitas':
          return _buildIdentitasGrid(html, lessonPlanData);
        case 'langkah_kegiatan':
          return _buildStepRows(html, _k13StepAccent);
      }
      break;
    case LessonPlanFormat.modulAjar:
      switch (fieldKey) {
        case 'info_umum':
          return _buildIdentitasGrid(html, lessonPlanData);
        case 'tujuan':
          return _buildTpList(html);
        case 'kegiatan':
          return _buildPertemuanRows(html);
      }
      break;
    case LessonPlanFormat.rpp1Halaman:
    case LessonPlanFormat.file:
      // Single-page format keeps the generic HtmlWidget path — its
      // content is intentionally short and uninstrumented.
      break;
  }
  return null;
}

// ── K13 identitas / Modul Ajar info_umum → 2×2 id-grid ─────────

/// Extract `<tr><td>label</td><td>value</td></tr>` pairs from an HTML
/// table. Returns empty when the HTML doesn't contain a table.
List<({String label, String value})> _extractTablePairs(String html) {
  final pairs = <({String label, String value})>[];
  final rowRegex = RegExp(
    r'<tr[^>]*>(.*?)</tr>',
    caseSensitive: false,
    dotAll: true,
  );
  final cellRegex = RegExp(
    r'<td[^>]*>(.*?)</td>',
    caseSensitive: false,
    dotAll: true,
  );
  for (final m in rowRegex.allMatches(html)) {
    final cells = cellRegex
        .allMatches(m.group(1) ?? '')
        .map((c) => _stripTags(c.group(1) ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (cells.length >= 2) {
      pairs.add((label: cells[0], value: cells[1]));
    }
  }
  return pairs;
}

Widget? _buildIdentitasGrid(String html, Map<String, dynamic> lp) {
  // Pass 1: try to parse the AI-generated <table>.
  var pairs = _extractTablePairs(html);

  // Pass 2: fall back to deriving from the lesson-plan map directly
  // when the AI returned a non-table format (or the section is
  // empty). This keeps the grid filled even on freshly-created
  // manual drafts that haven't run AI yet.
  if (pairs.isEmpty) {
    final m = _Map(lp);
    final fallback = <({String label, String value})>[];
    final mapel = m.firstNonEmpty(['subject_name', 'mata_pelajaran_nama']);
    final kelas = m.firstNonEmpty(['class_name', 'kelas_nama']);
    final semester = m.firstNonEmpty(['semester']);
    final ay = m.firstNonEmpty(['academic_year']);
    final alokasi = m.firstNonEmpty(['time_allocation', 'alokasi_waktu']);
    final materi = m.firstNonEmpty(['title', 'judul']);
    if (mapel != null) fallback.add((label: 'Mata pelajaran', value: mapel));
    if (kelas != null && semester != null) {
      fallback.add((label: 'Kelas / Smt', value: '$kelas / $semester'));
    } else if (kelas != null) {
      fallback.add((label: 'Kelas', value: kelas));
    } else if (semester != null) {
      fallback.add((label: 'Semester', value: semester));
    }
    if (materi != null) fallback.add((label: 'Materi pokok', value: materi));
    if (alokasi != null) fallback.add((label: 'Alokasi', value: alokasi));
    if (ay != null) fallback.add((label: 'Tahun ajaran', value: ay));
    pairs = fallback;
  }

  if (pairs.isEmpty) return null;

  return _IdGrid(pairs: pairs);
}

// ── K13 langkah_kegiatan → numbered step rows (Pendahuluan/Inti/Penutup) ──

const _k13StepAccent = Color(0xFF4338CA); // indigo-600

/// Parse `<h3>A. Pendahuluan (10 menit)</h3>` headings + the content
/// block that follows each, into ordered step rows. Returns null when
/// no `<h3>` heading was found so caller falls back to HtmlWidget.
Widget? _buildStepRows(String html, Color accent) {
  if (html.trim().isEmpty) return null;
  final headingRegex = RegExp(
    r'<h3[^>]*>(.*?)</h3>(.*?)(?=<h3[^>]*>|$)',
    caseSensitive: false,
    dotAll: true,
  );
  final matches = headingRegex.allMatches(html).toList();
  if (matches.isEmpty) return null;

  final rows = <_StepRow>[];
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final headingRaw = _stripTags(m.group(1) ?? '').trim();
    final body = m.group(2) ?? '';

    // "A. Pendahuluan (10 menit)" → splitter → label + minutes
    final letterMatch = RegExp(r'^([A-Z])\.\s*(.+)$').firstMatch(headingRaw);
    String label = headingRaw;
    String? badge;
    if (letterMatch != null) {
      label = letterMatch.group(2)!;
    }
    // Pluck "(NN menit)" from the heading and convert to "NN MENIT"
    final timeMatch = RegExp(
      r'\(\s*(\d+)\s*menit\s*\)',
      caseSensitive: false,
    ).firstMatch(label);
    if (timeMatch != null) {
      badge = '${timeMatch.group(1)} MENIT';
      label = label.replaceAll(timeMatch.group(0)!, '').trim();
    }

    rows.add(
      _StepRow(
        number: letterMatch?.group(1) ?? String.fromCharCode(65 + i),
        label: label,
        timeBadge: badge,
        body: _stripTags(body).trim(),
      ),
    );
  }
  if (rows.isEmpty) return null;
  return _StepRowsList(rows: rows, accent: accent);
}

// ── Modul Ajar tujuan → TP card list (TP 1, TP 2, ...) ─────────

Widget? _buildTpList(String html) {
  if (html.trim().isEmpty) return null;
  // The AI prompt asks for `<p><strong>TP 1.</strong> ...</p>` per
  // tujuan pembelajaran. Match those — fall back to HtmlWidget when
  // the shape doesn't match.
  final tpRegex = RegExp(
    r'<p[^>]*>\s*<strong[^>]*>\s*(TP\s*\d+(?:\.\d+)?)[\.\s]*</strong>\s*(.*?)</p>',
    caseSensitive: false,
    dotAll: true,
  );
  final tps = <({String num, String text})>[];
  for (final m in tpRegex.allMatches(html)) {
    final n = m.group(1) ?? '';
    final text = _stripTags(m.group(2) ?? '').trim();
    if (text.isEmpty) continue;
    tps.add((num: n.toUpperCase().replaceAll(RegExp(r'\s+'), ' '), text: text));
  }
  if (tps.length < 2) return null;
  return _TpList(items: tps);
}

// ── Modul Ajar kegiatan → per-pertemuan rows ───────────────────

Widget? _buildPertemuanRows(String html) {
  if (html.trim().isEmpty) return null;
  // Per the AI prompt: `<h3>Pertemuan 1 (X JP)</h3><ol><li>...</li></ol>`
  // Reuse the step-rows extractor but with violet accent, and rewrite
  // the badge to extract "X JP" instead of "NN menit".
  final headingRegex = RegExp(
    r'<h3[^>]*>(.*?)</h3>(.*?)(?=<h3[^>]*>|$)',
    caseSensitive: false,
    dotAll: true,
  );
  final matches = headingRegex.allMatches(html).toList();
  if (matches.isEmpty) return null;
  final rows = <_StepRow>[];
  for (var i = 0; i < matches.length; i++) {
    final m = matches[i];
    final raw = _stripTags(m.group(1) ?? '').trim();
    final body = _stripTags(m.group(2) ?? '').trim();
    final pertemuanMatch = RegExp(
      r'^Pertemuan\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(raw);
    final jpMatch = RegExp(
      r'\(\s*(\d+\s*JP)\s*\)',
      caseSensitive: false,
    ).firstMatch(raw);
    String label = raw;
    if (jpMatch != null) {
      label = label.replaceAll(jpMatch.group(0)!, '').trim();
    }
    rows.add(
      _StepRow(
        number: 'P${pertemuanMatch?.group(1) ?? (i + 1)}',
        label: label,
        timeBadge: jpMatch?.group(1)?.toUpperCase(),
        body: body,
      ),
    );
  }
  if (rows.isEmpty) return null;
  return _StepRowsList(rows: rows, accent: const Color(0xFF7C3AED));
}

// ── Helpers ────────────────────────────────────────────────────

String _stripTags(String html) {
  var t = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  t = t.replaceAll('&nbsp;', ' ');
  t = t.replaceAll('&amp;', '&');
  t = t.replaceAll('&lt;', '<');
  t = t.replaceAll('&gt;', '>');
  t = t.replaceAll('&quot;', '"');
  t = t.replaceAll('&#39;', "'");
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return t.trim();
}

class _Map {
  final Map<String, dynamic> _lp;
  _Map(this._lp);
  String? firstNonEmpty(List<String> keys) {
    for (final k in keys) {
      final v = _lp[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }
}

// ── Visual building blocks ─────────────────────────────────────

class _IdGrid extends StatelessWidget {
  const _IdGrid({required this.pairs});
  final List<({String label, String value})> pairs;

  @override
  Widget build(BuildContext context) {
    // Replaced the legacy `GridView.count(childAspectRatio: 3.4)` —
    // the fixed aspect ratio overflowed by ~15px when a value
    // wrapped to 3 lines (e.g. "Hiwar: Percakapan tentang Profesi
    // dan Cita-cita") and wasted vertical space when it was short
    // ("VII B / Genap"). Pairing rows under IntrinsicHeight lets
    // each row size itself to whichever cell is taller.
    final rows = <Widget>[];
    for (var i = 0; i < pairs.length; i += 2) {
      final left = _cell(pairs[i]);
      final right = i + 1 < pairs.length
          ? _cell(pairs[i + 1])
          : const SizedBox.shrink();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: 8),
              Expanded(child: right),
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  Widget _cell(({String label, String value}) p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            p.value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate800,
            ),
            // 3 lines — covers the longest "Materi pokok" titles
            // we've seen ("Hiwar: Percakapan tentang Profesi dan
            // Cita-cita") without truncating mid-word.
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StepRow {
  final String number;
  final String label;
  final String? timeBadge;
  final String body;
  const _StepRow({
    required this.number,
    required this.label,
    required this.timeBadge,
    required this.body,
  });
}

class _StepRowsList extends StatelessWidget {
  const _StepRowsList({required this.rows, required this.accent});
  final List<_StepRow> rows;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: i == 0
                  ? null
                  : Border(
                      top: BorderSide(
                        color: ColorUtils.slate200,
                        style: BorderStyle.solid,
                        width: 1,
                      ),
                    ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    rows[i].number,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              rows[i].label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: ColorUtils.slate900,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (rows[i].timeBadge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: ColorUtils.slate100,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                rows[i].timeBadge!,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: ColorUtils.slate600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (rows[i].body.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          rows[i].body,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: ColorUtils.slate600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TpList extends StatelessWidget {
  const _TpList({required this.items});
  final List<({String num, String text})> items;

  @override
  Widget build(BuildContext context) {
    const violet = Color(0xFF7C3AED);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: violet.withValues(alpha: 0.04),
                border: Border.all(color: violet.withValues(alpha: 0.18)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: violet,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      items[i].num,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      items[i].text,
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate800,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
