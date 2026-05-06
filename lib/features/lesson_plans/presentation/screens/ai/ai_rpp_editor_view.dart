// AI-RPP per-section editor.
//
// Owns one Quill controller per RPP field (Kompetensi Inti, Kompetensi
// Dasar, Indikator, …). Each controller subscribes to its document
// stream and forwards plain-text edits to `onFieldChanged` so the
// parent screen's `lessonPlanData` stays in sync — without that
// listener the controllers held the user's typing internally and the
// save handler PATCHed the original AI-generated content untouched.
//
// This file is intentionally AI-only: no "free text fallback" branch,
// no detection of whether the RPP is AI-generated. The dispatcher
// upstream (`RPPDetailPage`) decides that once and routes to the
// right screen; this widget just renders sections.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_quill_editor.dart';

class AiRppEditorView extends StatefulWidget {
  /// Brand colour for focus borders/shadows.
  final Color primaryColor;

  /// Structured field data from the lesson plan. Used to seed each
  /// section's Quill document with its existing content.
  final Map<String, dynamic> lessonPlanData;

  /// Field definitions: `[{ 'key', 'label', 'altKey' }]`. Drives the
  /// section list order and label text.
  final List<Map<String, String>> fieldDefinitions;

  /// Fired on every keystroke inside any section. The parent screen
  /// is expected to write the value back into its `lessonPlanData`
  /// map so subsequent saves carry the edits.
  final void Function(String fieldKey, String value) onFieldChanged;

  const AiRppEditorView({
    super.key,
    required this.primaryColor,
    required this.lessonPlanData,
    required this.fieldDefinitions,
    required this.onFieldChanged,
  });

  @override
  State<AiRppEditorView> createState() => _AiRppEditorViewState();
}

class _AiRppEditorViewState extends State<AiRppEditorView> {
  final Map<String, quill.QuillController> _controllers = {};
  final Set<String> _expandedSections = {};

  // Per-section accent icons.
  static const Map<String, IconData> _sectionIcons = {
    'core_competence': Icons.school_rounded,
    'basic_competence': Icons.assignment_rounded,
    'indicator': Icons.checklist_rounded,
    'learning_objective': Icons.track_changes_rounded,
    'main_material': Icons.menu_book_rounded,
    'learning_method': Icons.psychology_rounded,
    'media_tools': Icons.devices_rounded,
    'learning_source': Icons.source_rounded,
    'learning_activities': Icons.directions_run_rounded,
    'assessment': Icons.grading_rounded,
  };

  // Per-section accent colours (cycles for any extras).
  static const List<Color> _sectionColors = [
    Color(0xFF3B82F6), // blue
    Color(0xFF8B5CF6), // violet
    Color(0xFF10B981), // emerald
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFF06B6D4), // cyan
    Color(0xFFEC4899), // pink
    Color(0xFF14B8A6), // teal
    Color(0xFF6366F1), // indigo
    Color(0xFFF97316), // orange
  ];

  @override
  void initState() {
    super.initState();
    _initSectionControllers();
    if (widget.fieldDefinitions.isNotEmpty) {
      _expandedSections.add(widget.fieldDefinitions.first['key']!);
    }
  }

  void _initSectionControllers() {
    for (final field in widget.fieldDefinitions) {
      final key = field['key']!;
      final altKey = field['altKey'] ?? '';
      final value = _getFieldValue(key, altKey);
      final controller = quill.QuillController(
        document: _htmlToQuill(value),
        selection: const TextSelection.collapsed(offset: 0),
      );
      // Forward Quill edits up to the parent so `lessonPlanData`
      // stays in sync. The listener subscribes AFTER the document is
      // built so the initial-content insert doesn't fire spuriously.
      controller.document.changes.listen((_) {
        final text = controller.document.toPlainText().trimRight();
        widget.onFieldChanged(key, text);
      });
      _controllers[key] = controller;
    }
  }

  String _getFieldValue(String key, String altKey) {
    final val = widget.lessonPlanData[key];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString().trim();
    }
    if (altKey.isNotEmpty) {
      final altVal = widget.lessonPlanData[altKey];
      if (altVal != null && altVal.toString().trim().isNotEmpty) {
        return altVal.toString().trim();
      }
    }
    return '';
  }

  quill.Document _htmlToQuill(String html) {
    if (html.isEmpty) return quill.Document();

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

    return quill.Document()..insert(0, text);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.fieldDefinitions;
    final nonEmpty = fields
        .where((f) => _isFieldNonEmpty(f['key']!))
        .toList();
    final empty = fields
        .where((f) => !_isFieldNonEmpty(f['key']!))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        _buildEditorHeader(nonEmpty.length, fields.length),
        const SizedBox(height: 10),
        ...nonEmpty.asMap().entries.map(
              (e) => _buildSectionCard(e.value, e.key),
            ),
        if (empty.isNotEmpty) ...[
          _buildEmptySectionsHeader(empty.length),
          ...empty.asMap().entries.map(
                (e) => _buildSectionCard(
                  e.value,
                  nonEmpty.length + e.key,
                  isEmpty: true,
                ),
              ),
        ],
      ],
    );
  }

  bool _isFieldNonEmpty(String key) {
    final c = _controllers[key];
    if (c == null) return false;
    return c.document.toPlainText().trim().isNotEmpty;
  }

  Widget _buildEditorHeader(int filledCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.primaryColor.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded, size: 18, color: widget.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Per Bagian',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: widget.primaryColor,
                  ),
                ),
                Text(
                  '$filledCount dari $totalCount bagian terisi • Ketuk bagian untuk mengedit',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: widget.primaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_expandedSections.length ==
                      widget.fieldDefinitions.length) {
                    _expandedSections.clear();
                  } else {
                    _expandedSections
                      ..clear()
                      ..addAll(
                        widget.fieldDefinitions.map((f) => f['key']!),
                      );
                  }
                });
              },
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _expandedSections.length == widget.fieldDefinitions.length
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 18,
                  color: widget.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySectionsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6, left: 4),
      child: Row(
        children: [
          Icon(
            Icons.add_circle_outline_rounded,
            size: 13,
            color: ColorUtils.slate400,
          ),
          const SizedBox(width: 4),
          Text(
            '$count bagian belum terisi',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ColorUtils.slate400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    Map<String, String> field,
    int index, {
    bool isEmpty = false,
  }) {
    final key = field['key']!;
    final label = field['label']!;
    final isExpanded = _expandedSections.contains(key);
    final sectionColor = _sectionColors[index % _sectionColors.length];
    final sectionIcon = _sectionIcons[key] ?? Icons.article_rounded;
    final controller = _controllers[key];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(
          color: isExpanded
              ? sectionColor.withValues(alpha: 0.2)
              : ColorUtils.slate100,
        ),
        boxShadow: [
          if (isExpanded)
            BoxShadow(
              color: sectionColor.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSections.remove(key);
                  } else {
                    _expandedSections.add(key);
                  }
                });
              },
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? sectionColor
                            : isEmpty
                                ? ColorUtils.slate200
                                : sectionColor.withValues(alpha: 0.4),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: isExpanded
                                    ? sectionColor.withValues(alpha: 0.12)
                                    : ColorUtils.slate50,
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              child: Icon(
                                sectionIcon,
                                size: 15,
                                color: isExpanded
                                    ? sectionColor
                                    : ColorUtils.slate400,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isExpanded
                                          ? sectionColor
                                          : ColorUtils.slate700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (!isExpanded && !isEmpty) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      _getPreviewText(controller),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: ColorUtils.slate400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  if (isEmpty && !isExpanded) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      'Ketuk untuk menambahkan konten',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: ColorUtils.slate400,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 20,
                                color: isExpanded
                                    ? sectionColor
                                    : ColorUtils.slate400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: controller != null
                ? _buildSectionQuillEditor(controller, sectionColor)
                : const SizedBox.shrink(),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  String _getPreviewText(quill.QuillController? controller) {
    if (controller == null) return '';
    final text = controller.document.toPlainText().trim();
    if (text.isEmpty) return 'Belum ada konten';
    return text.length > 60 ? '${text.substring(0, 60)}...' : text;
  }

  Widget _buildSectionQuillEditor(
    quill.QuillController controller,
    Color accentColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AppQuillEditor(
          controller: controller,
          accentColor: accentColor,
          placeholder: 'Tulis konten bagian ini...',
          minHeight: 150,
          maxHeight: 300,
        ),
      ),
    );
  }
}
