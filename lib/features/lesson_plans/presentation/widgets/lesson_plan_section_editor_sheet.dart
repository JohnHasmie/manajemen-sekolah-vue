// Per-section RPP editor — near-full-page draggable sheet.
//
// Replaces the legacy "global edit toggle" pattern: instead of
// flipping the whole detail screen into an edit mode with N Quill
// editors at once, each section gets its own scoped sheet with one
// Quill editor and a single Save action. Save → PATCH only that key
// in `format_data` (the backend's UpdateLessonPlanAction merges
// partial JSONB so other sections are untouched).
//
// Sheet sizing — opens at 96% so it covers the bottom nav and feels
// like a focused editor, but stays a sheet (status bar peeks above)
// so the user knows it's overlay context, not a separate page. The
// shared `AppDraggableSheet` drives the chrome.
//
// AI regen lives in this same sheet's footer as a violet ✦ mini
// button — replaces the separate regen sheet for the per-section
// case. The multi-section regen sheet (Frame J in the original
// mockup) remains for bulk regen and is a separate widget.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:manajemensekolah/core/config/ai_config.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/services/preferences_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/core/widgets/app_quill_editor.dart';
import 'package:manajemensekolah/features/lesson_plans/data/lesson_plan_service.dart';

/// Result returned to the parent screen after the sheet closes.
///
/// `newHtml` carries the rich HTML that was saved (or null if the
/// user dismissed). Parent should replace `format_data[fieldKey]` in
/// its local lesson-plan map with this value so the detail card
/// re-renders with the edit.
class SectionEditResult {
  final String fieldKey;
  final String newHtml;
  const SectionEditResult({required this.fieldKey, required this.newHtml});
}

/// Open the section editor sheet for one [fieldKey] of [lessonPlanId].
///
/// `currentHtml` seeds the Quill document with the existing content.
/// `regenInfo` (when present) drives the violet "Generate ulang"
/// affordance — pass `{remaining: int, max: int, can_regenerate: bool}`
/// matching the backend's `regen_limits` shape.
Future<SectionEditResult?> showLessonPlanSectionEditorSheet({
  required BuildContext context,
  required String lessonPlanId,
  required String fieldKey,
  required String fieldLabel,
  required String currentHtml,
  Map<String, dynamic>? regenInfo,
  String? formatLabel,
}) {
  return AppDraggableSheet.show<SectionEditResult>(
    context: context,
    // Open and stay near-full-page (96% caps under the system status
    // bar) so Quill has the entire viewport to work with — the
    // bottom nav bar is fully covered. The user can still drag to
    // collapse if they want to peek at the underlying detail.
    initialSize: 0.96,
    minSize: 0.6,
    maxSize: 0.96,
    builder: (sheetCtx, scrollController) => _SectionEditorSheet(
      lessonPlanId: lessonPlanId,
      fieldKey: fieldKey,
      fieldLabel: fieldLabel,
      currentHtml: currentHtml,
      regenInfo: regenInfo,
      formatLabel: formatLabel,
    ),
  );
}

class _SectionEditorSheet extends StatefulWidget {
  const _SectionEditorSheet({
    required this.lessonPlanId,
    required this.fieldKey,
    required this.fieldLabel,
    required this.currentHtml,
    required this.regenInfo,
    required this.formatLabel,
  });

  final String lessonPlanId;
  final String fieldKey;
  final String fieldLabel;
  final String currentHtml;
  final Map<String, dynamic>? regenInfo;
  final String? formatLabel;

  @override
  State<_SectionEditorSheet> createState() => _SectionEditorSheetState();
}

class _SectionEditorSheetState extends State<_SectionEditorSheet> {
  late final quill.QuillController _controller;

  /// Initial plain-text snapshot — used to disable Simpan when
  /// nothing has changed.
  late final String _initialText;

  bool _isDirty = false;
  bool _isSaving = false;
  bool _isRegenerating = false;

  Color get _accent => ColorUtils.getRoleColor('guru');
  Color get _aiAccent => const Color(0xFF7C3AED);

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController(
      document: _htmlToQuillDocument(widget.currentHtml),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _initialText = _controller.document.toPlainText().trimRight();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final current = _controller.document.toPlainText().trimRight();
    final dirty = current != _initialText;
    if (dirty != _isDirty) {
      setState(() => _isDirty = dirty);
    }
  }

  bool get _canRegen {
    final info = widget.regenInfo;
    if (info == null) return true;
    final v = info['can_regenerate'];
    if (v is bool) return v;
    final remaining = info['remaining'];
    return remaining is int ? remaining > 0 : true;
  }

  int? get _regenRemaining {
    final v = widget.regenInfo?['remaining'];
    return v is int ? v : null;
  }

  int? get _regenMax {
    final v =
        widget.regenInfo?['max_regenerations'] ?? widget.regenInfo?['max'];
    return v is int ? v : null;
  }

  // ── Save (PATCH only this section) ─────────────────────────────

  Future<void> _save() async {
    if (!_isDirty || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final newHtml = _quillDocumentToHtml(_controller.document);
      // The backend's UpdateLessonPlanAction merges partial format_data
      // JSONB, so sending only this key is safe — sibling sections
      // are preserved untouched.
      await LessonPlanService.updateLessonPlan(widget.lessonPlanId, {
        'format_data': {widget.fieldKey: newHtml},
      });
      if (!mounted) return;
      AppNavigator.pop(
        context,
        SectionEditResult(fieldKey: widget.fieldKey, newHtml: newHtml),
      );
    } catch (e) {
      AppLogger.error('lesson_plan', 'section save failed: $e');
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal menyimpan ${widget.fieldLabel}: $e',
        );
        setState(() => _isSaving = false);
      }
    }
  }

  // ── Regenerate (inline replace) ───────────────────────────────

  Future<void> _regenerate() async {
    if (_isRegenerating || _isSaving || !_canRegen) return;
    setState(() => _isRegenerating = true);
    try {
      final token = PreferencesService().getString('token') ?? '';
      final aiDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 90),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          validateStatus: (_) => true,
        ),
      );

      final response = await aiDio.post(
        '${AiConfig.baseUrl}/lesson-plans/${widget.lessonPlanId}/regen/${widget.fieldKey}',
      );

      if (!mounted) return;

      final data = response.data;
      final body = data is Map<String, dynamic>
          ? data
          : <String, dynamic>{'raw': data};

      if (response.statusCode == 429) {
        SnackBarUtils.showError(
          context,
          body['message']?.toString() ??
              'Batas regenerasi untuk ${widget.fieldLabel} telah tercapai.',
        );
        return;
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        SnackBarUtils.showError(
          context,
          body['message']?.toString() ?? 'Regenerasi gagal',
        );
        return;
      }

      final inner = body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : body;
      final newContent =
          (inner['content'] ?? inner[widget.fieldKey] ?? body['content'] ?? '')
              .toString();

      if (newContent.isEmpty) {
        SnackBarUtils.showError(
          context,
          'AI mengembalikan konten kosong. Coba lagi.',
        );
        return;
      }

      final doc = _htmlToQuillDocument(newContent);
      _controller
        ..document = doc
        ..updateSelection(
          const TextSelection.collapsed(offset: 0),
          quill.ChangeSource.local,
        );
      // Force the dirty flag so Simpan lights up — even if the
      // regenerated text happens to match the initial.
      setState(() => _isDirty = true);

      SnackBarUtils.showInfo(
        context,
        '${widget.fieldLabel} di-generate ulang oleh AI',
      );
    } catch (e) {
      AppLogger.error('lesson_plan', 'regen failed: $e');
      if (mounted) SnackBarUtils.showError(context, 'Regenerasi gagal: $e');
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Sheet shell — rounded top, white surface. AppDraggableSheet
    // already constrains height to 96% of viewport, so this Column
    // stretches to fill that envelope.
    //
    // Layout note (handle placement): the drag handle is rendered
    // INSIDE the gradient header rather than above it on the white
    // surface, otherwise the modal sheet shows a white 16px strip
    // between the rounded top corners and the cobalt gradient. Same
    // pattern used by `lesson_plan_setup_sheet.dart`.
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            _buildBrandHeader(),
            if (_canRegen && _regenRemaining != null && _regenRemaining! > 0)
              _buildRegenHint(),
            // LayoutBuilder gives the editor an exact maxHeight from
            // the Expanded slot. Without it, AppQuillEditor's inner
            // `Column(mainAxisSize.min)` ignores Expanded's bounded
            // constraints and overflows when its document grows past
            // the screen — that's the "BOTTOM OVERFLOWED BY N PIXELS"
            // banner we used to see on rich docs.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: AbsorbPointer(
                  absorbing: _isRegenerating,
                  child: Opacity(
                    opacity: _isRegenerating ? 0.55 : 1,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return AppQuillEditor(
                          controller: _controller,
                          accentColor: _accent,
                          placeholder: 'Tulis isi ${widget.fieldLabel}…',
                          minHeight: 200,
                          // Subtract a small buffer for the toolbar
                          // strip baked into AppQuillEditor (~46px)
                          // so the document area never pokes past the
                          // available slot.
                          maxHeight: (constraints.maxHeight - 48)
                              .clamp(200.0, double.infinity)
                              .toDouble(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  /// Compact cobalt brand header — same look as `BrandPageHeader` but
  /// inlined here so it doesn't fight the sheet's rounded top corners.
  /// Shows kicker + title + close button + dirty/AI status row.
  Widget _buildBrandHeader() {
    final kicker = [
      'RPP',
      if (widget.formatLabel != null && widget.formatLabel!.isNotEmpty)
        widget.formatLabel!.toUpperCase(),
      'EDIT BAGIAN',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _accent,
            Color.lerp(_accent, Colors.lightBlueAccent, 0.35) ?? _accent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle, inlined into the gradient so the cobalt
          // reaches all the way to the rounded top edge. Moving it
          // out of the white DecoratedBox killed the white strip
          // that used to sit between the sheet's top and the header.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kicker,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 0.6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Edit ${widget.fieldLabel}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSaving ? null : () => _attemptClose(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStatusRow(),
        ],
      ),
    );
  }

  /// Pill row inside the header — section label + dirty/AI state +
  /// optional "Regen N/M" quota badge. Same visual language as the
  /// file detail page's ctx-strip.
  Widget _buildStatusRow() {
    final remaining = _regenRemaining;
    final max = _regenMax;
    final dirtyLabel = _isRegenerating
        ? 'AI sedang menulis ulang…'
        : (_isDirty ? 'Perubahan belum disimpan' : 'Belum diubah');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _isRegenerating ? Icons.auto_awesome_rounded : Icons.edit_rounded,
              size: 16,
              color: _isRegenerating ? _aiAccent : _accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.fieldLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  dirtyLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (remaining != null && max != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Regen $remaining/$max',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegenHint() {
    final remaining = _regenRemaining;
    final max = _regenMax;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _aiAccent.withValues(alpha: 0.06),
            const Color(0xFF4338CA).withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: _aiAccent.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _aiAccent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 11,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Mau AI tulis ulang section ini?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _aiAccent,
                  ),
                ),
                if (remaining != null && max != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Sisa kuota regenerasi: $remaining/$max',
                      style: TextStyle(
                        fontSize: 10,
                        color: ColorUtils.slate600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Footer pinned to the bottom of the sheet — Batal · violet ✦
  /// regen · Simpan. SafeArea bottom: true so the system home
  /// indicator doesn't collide with Simpan on iPhones.
  Widget _buildFooter() {
    final canSave = _isDirty && !_isSaving && !_isRegenerating;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: ColorUtils.slate100)),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _isSaving ? null : _attemptClose,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ColorUtils.slate700,
                  side: BorderSide(color: ColorUtils.slate200),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _RegenButton(
              isLoading: _isRegenerating,
              isEnabled: _canRegen && !_isSaving,
              color: _aiAccent,
              onTap: _regenerate,
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: canSave ? _save : null,
                icon: _isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text(
                  _isSaving ? 'Menyimpan…' : 'Simpan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: ColorUtils.slate200,
                  disabledForegroundColor: ColorUtils.slate400,
                  minimumSize: const Size.fromHeight(44),
                  elevation: canSave ? 6 : 0,
                  shadowColor: _accent.withValues(alpha: 0.28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _attemptClose() async {
    if (!_isDirty) {
      AppNavigator.pop(context);
      return;
    }
    final discard = await _confirmDiscard();
    if (discard == true && mounted) AppNavigator.pop(context);
  }

  Future<bool?> _confirmDiscard() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan perubahan?'),
        content: Text(
          'Perubahan pada ${widget.fieldLabel} belum disimpan dan akan hilang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Lanjut edit'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ColorUtils.error600),
            child: const Text('Buang'),
          ),
        ],
      ),
    );
  }
}

/// Compact violet "✦" mini-button for the footer regen action.
class _RegenButton extends StatelessWidget {
  const _RegenButton({
    required this.isLoading,
    required this.isEnabled,
    required this.color,
    required this.onTap,
  });

  final bool isLoading;
  final bool isEnabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = !isEnabled || isLoading;
    return Tooltip(
      message: 'Generate ulang dengan AI',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: color.withValues(alpha: disabled ? 0.10 : 0.22),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: color,
                    ),
                  )
                : Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: color.withValues(alpha: disabled ? 0.40 : 1),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── HTML <-> Quill helpers ──────────────────────────────────────

/// Tolerant HTML → plain-Quill conversion. Borrowed from the editor
/// view so the two stay in sync. Quill doesn't have a built-in HTML
/// import; this strips tags and keeps list/heading line breaks.
quill.Document _htmlToQuillDocument(String html) {
  if (html.trim().isEmpty) return quill.Document();

  var text = html.replaceAll(RegExp(r'<ul>|<ol>'), '\n');
  text = text.replaceAll(RegExp(r'</ul>|</ol>'), '\n');
  var counter = 1;
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
  text = text.replaceAll(RegExp(r'<h[1-6]>'), '\n');
  text = text.replaceAll(RegExp(r'</h[1-6]>|<p>|</p>'), '\n');
  text = text.replaceAll(RegExp(r'<[^>]*>'), '');
  text = text.replaceAll('&nbsp;', ' ');
  text = text.replaceAll('&amp;', '&');
  text = text.replaceAll('&lt;', '<');
  text = text.replaceAll('&gt;', '>');
  text = text.replaceAll('&quot;', '"');
  text = text.replaceAll('&#39;', "'");
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  text = text.trim();
  if (text.isEmpty) return quill.Document();
  return quill.Document()..insert(0, text);
}

/// Quill plain-text → HTML round-trip for the save payload.
String _quillDocumentToHtml(quill.Document doc) {
  final raw = doc.toPlainText();
  final lines = raw.split('\n');

  final buffer = StringBuffer();
  String? listMode;

  void flushList() {
    if (listMode != null) {
      buffer.write('</$listMode>');
      listMode = null;
    }
  }

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      flushList();
      continue;
    }

    final bulletMatch = RegExp(r'^[•\-]\s*(.+)$').firstMatch(trimmed);
    final orderedMatch = RegExp(r'^\d+\.\s*(.+)$').firstMatch(trimmed);

    if (bulletMatch != null) {
      if (listMode != 'ul') {
        flushList();
        buffer.write('<ul>');
        listMode = 'ul';
      }
      buffer.write('<li>${_escape(bulletMatch.group(1)!)}</li>');
    } else if (orderedMatch != null) {
      if (listMode != 'ol') {
        flushList();
        buffer.write('<ol>');
        listMode = 'ol';
      }
      buffer.write('<li>${_escape(orderedMatch.group(1)!)}</li>');
    } else {
      flushList();
      buffer.write('<p>${_escape(trimmed)}</p>');
    }
  }
  flushList();

  final html = buffer.toString();
  return html.isEmpty ? '<p></p>' : html;
}

String _escape(String s) {
  return s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
