// RPP section-based editor view. Replaces the single-text-field editor.
// Shows all RPP sections as expandable cards with Quill rich-text editors.
// Each section can be expanded/collapsed independently.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_quill_editor.dart';

/// Section-based RPP editor with expandable Quill editors per field.
///
/// Each section (Kompetensi Inti, Tujuan Pembelajaran, etc.) gets its own
/// collapsible card with a rich-text Quill editor inside.
class LessonPlanEditorView extends StatefulWidget {
  /// The current RPP text content (full formatted text for backward compat).
  final String content;

  /// Brand colour for focus borders/shadows.
  final Color primaryColor;

  /// Callback fired whenever the text changes.
  final ValueChanged<String> onChanged;

  /// Structured field data from lesson plan.
  /// If provided, shows section-based editing instead of single text field.
  final Map<String, dynamic>? lessonPlanData;

  /// Field definitions list: [{ 'key': '...', 'label': '...', 'altKey': '...' }]
  final List<Map<String, String>>? fieldDefinitions;

  /// Callback fired when a specific field changes.
  final void Function(String fieldKey, String value)? onFieldChanged;

  const LessonPlanEditorView({
    super.key,
    required this.content,
    required this.primaryColor,
    required this.onChanged,
    this.lessonPlanData,
    this.fieldDefinitions,
    this.onFieldChanged,
  });

  @override
  State<LessonPlanEditorView> createState() => _LessonPlanEditorViewState();
}

class _LessonPlanEditorViewState extends State<LessonPlanEditorView> {
  final Map<String, quill.QuillController> _controllers = {};
  final Set<String> _expandedSections = {};

  // Section icons for visual variety
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

  // Section colors for left accent
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

  bool get _hasSections =>
      widget.fieldDefinitions != null &&
      widget.fieldDefinitions!.isNotEmpty &&
      widget.lessonPlanData != null;

  @override
  void initState() {
    super.initState();
    if (_hasSections) {
      _initSectionControllers();
      // Expand the first section by default
      if (widget.fieldDefinitions!.isNotEmpty) {
        _expandedSections.add(widget.fieldDefinitions!.first['key']!);
      }
    }
  }

  void _initSectionControllers() {
    final data = widget.lessonPlanData!;
    for (final field in widget.fieldDefinitions!) {
      final key = field['key']!;
      final altKey = field['altKey'] ?? '';
      final value = _getFieldValue(data, key, altKey);
      _controllers[key] = quill.QuillController(
        document: _htmlToQuill(value),
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  String _getFieldValue(Map<String, dynamic> data, String key, String altKey) {
    final val = data[key];
    if (val != null && val.toString().trim().isNotEmpty) {
      return val.toString().trim();
    }
    if (altKey.isNotEmpty) {
      final altVal = data[altKey];
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

    return quill.Document()..insert(0, text);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSections) {
      return _buildSectionEditor();
    }
    return _buildFallbackEditor();
  }

  // ── Section-based editor ──

  Widget _buildSectionEditor() {
    final fields = widget.fieldDefinitions!;
    final nonEmptyFields = fields.where((f) {
      final key = f['key']!;
      final controller = _controllers[key];
      if (controller == null) return false;
      return controller.document.toPlainText().trim().isNotEmpty;
    }).toList();

    // Also include empty fields at the end for adding content
    final emptyFields = fields.where((f) {
      final key = f['key']!;
      final controller = _controllers[key];
      if (controller == null) return true;
      return controller.document.toPlainText().trim().isEmpty;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Header info
        _buildEditorHeader(nonEmptyFields.length, fields.length),
        const SizedBox(height: 10),

        // Section cards with content
        ...nonEmptyFields.asMap().entries.map(
          (entry) => _buildSectionCard(entry.value, entry.key),
        ),

        // Empty sections (collapsed, for adding new content)
        if (emptyFields.isNotEmpty) ...[
          _buildEmptySectionsHeader(emptyFields.length),
          ...emptyFields.asMap().entries.map(
            (entry) => _buildSectionCard(
              entry.value,
              nonEmptyFields.length + entry.key,
              isEmpty: true,
            ),
          ),
        ],
      ],
    );
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
          // Expand all / collapse all
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (_expandedSections.length ==
                      widget.fieldDefinitions!.length) {
                    _expandedSections.clear();
                  } else {
                    _expandedSections.clear();
                    for (final f in widget.fieldDefinitions!) {
                      _expandedSections.add(f['key']!);
                    }
                  }
                });
              },
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _expandedSections.length == widget.fieldDefinitions!.length
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
          // Section header (always visible, tappable)
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
                    // Left accent strip
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

          // Expanded editor content
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

  // ── Fallback single text editor (when no sections provided) ──

  Widget _buildFallbackEditor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Formatting toolbar (stubs)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(10)),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _formatButton(Icons.format_bold),
                _formatButton(Icons.format_italic),
                _formatButton(Icons.format_underlined),
                _formatButton(Icons.title),
                _formatButton(Icons.table_chart),
                _formatButton(Icons.list),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: ColorUtils.slate200),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: TextField(
                controller: TextEditingController(text: widget.content),
                onChanged: widget.onChanged,
                maxLines: null,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  hintText: 'Ketik RPP disini...',
                  hintStyle: TextStyle(color: ColorUtils.slate400),
                ),
                style: TextStyle(
                  fontSize: 13.5,
                  fontFamily: 'Courier',
                  height: 1.6,
                  color: ColorUtils.slate800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatButton(IconData icon) {
    return IconButton(
      icon: Icon(icon, size: 18, color: ColorUtils.slate500),
      onPressed: () {},
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
