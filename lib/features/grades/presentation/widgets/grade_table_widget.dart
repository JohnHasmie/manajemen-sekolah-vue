import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

class GradeTableWidget extends StatefulWidget {
  final List<Student> filteredStudentList;
  final List<String> filteredGradeTypeList;
  final Map<String, List<Map<String, dynamic>>> assessmentHeaders;
  final List<Map<String, dynamic>> gradeList;
  final ScrollController horizontalScrollController;
  final bool canEdit;
  final bool isReadOnly;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final void Function(String type, Map<String, dynamic> header) onColumnTap;
  final void Function(Student student, String type, Map<String, dynamic> header) onCellTap;
  final void Function(String type) onAddAssessment;

  /// Called when user finishes inline editing a cell. Returns error message or null on success.
  final Future<String?> Function(Student student, String type, Map<String, dynamic> header, String value)? onInlineSave;

  const GradeTableWidget({
    super.key,
    required this.filteredStudentList, required this.filteredGradeTypeList,
    required this.assessmentHeaders, required this.gradeList,
    required this.horizontalScrollController,
    required this.canEdit, required this.isReadOnly,
    required this.primaryColor, required this.languageProvider,
    required this.onColumnTap, required this.onCellTap, required this.onAddAssessment,
    this.onInlineSave,
  });

  @override
  State<GradeTableWidget> createState() => _GradeTableWidgetState();
}

class _GradeTableWidgetState extends State<GradeTableWidget> {
  // Active editing cell
  String? _editingKey;
  int _editingStudentIdx = -1;
  int _editingColIdx = -1;
  final _editController = TextEditingController();
  final _editFocus = FocusNode();
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void dispose() {
    _editController.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  // ── Constants ──
  static const double _nameW = 120;
  static const double _cellW = 54;
  static const double _headerH = 48;
  static const double _rowH = 42;

  // ── Helpers ──
  String _short(String type) {
    const m = {'uh': 'UH', 'tugas': 'Tgs', 'uts': 'UTS', 'uas': 'UAS', 'pts': 'PTS', 'pas': 'PAS'};
    return m[type] ?? type.toUpperCase();
  }

  Color _scoreColor(double s) {
    if (s >= 80) return ColorUtils.success600;
    if (s >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  Map<String, dynamic>? _getGrade(Student student, String type, Map<String, dynamic> header) {
    try {
      final sid = student.id.toString();
      final scid = student.studentClassId?.toString();
      final result = widget.gradeList.firstWhere((g) {
        final gSid = g['siswa_id']?.toString();
        final gScid = g['student_class_id']?.toString();
        bool match = gSid == sid;
        if (!match && (scid != null || gScid != null)) {
          match = gScid == scid || gSid == scid;
        }
        if (!match) return false;
        final hId = header['id']?.toString();
        final aId = g['assessment_id']?.toString();
        if (hId != null && aId != null) {
          if (hId != aId) return false;
        } else if (hId != null || aId != null) {
          return false;
        }
        return (g['jenis']?.toString().toLowerCase() == type.toLowerCase()) &&
               (g['tanggal']?.toString().split('T')[0] == header['date']) &&
               ((g['title'] ?? '').toString().trim() == (header['title'] ?? '').toString().trim());
      }, orElse: () => <String, dynamic>{});
      return result.isEmpty ? null : result;
    } catch (_) { return null; }
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    final d = double.tryParse(v.toString());
    if (d == null) return v.toString();
    return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(1);
  }

  String _cellKey(Student s, String type, int idx) => '${s.id}__${type}__$idx';

  List<_ColDef> _buildColumns(double availableWidth) {
    final cols = <_ColDef>[];

    // 1. Add all real data columns
    for (final type in widget.filteredGradeTypeList) {
      final headers = widget.assessmentHeaders[type] ?? [];
      for (int i = 0; i < headers.length; i++) {
        cols.add(_ColDef(type: type, index: i, header: headers[i], isPlaceholder: false));
      }
    }

    // 2. Add placeholder columns for empty types (so table looks complete)
    for (final type in widget.filteredGradeTypeList) {
      final headers = widget.assessmentHeaders[type] ?? [];
      if (headers.isEmpty) {
        cols.add(_ColDef(type: type, index: 0, header: const {}, isPlaceholder: true));
      }
    }

    // 3. Fill remaining screen width with empty spacer columns
    final usedWidth = cols.length * _cellW;
    final remaining = availableWidth - usedWidth;
    if (remaining > _cellW) {
      final extraCols = (remaining / _cellW).floor();
      for (int i = 0; i < extraCols; i++) {
        cols.add(_ColDef(type: '', index: i, header: const {}, isPlaceholder: true));
      }
    }

    return cols;
  }

  void _startEditingAt(int studentIdx, int colIdx, List<_ColDef> cols) {
    if (!widget.canEdit || widget.isReadOnly) return;
    if (studentIdx < 0 || studentIdx >= widget.filteredStudentList.length) return;
    if (colIdx < 0 || colIdx >= cols.length) return;

    final col = cols[colIdx];
    if (col.isPlaceholder) return;

    final student = widget.filteredStudentList[studentIdx];

    if (widget.onInlineSave == null) {
      widget.onCellTap(student, col.type, col.header);
      return;
    }

    final rec = _getGrade(student, col.type, col.header);
    final currentValue = rec?.isNotEmpty == true ? _fmt(rec!['score']) : '';

    setState(() {
      _editingKey = _cellKey(student, col.type, col.index);
      _editingStudentIdx = studentIdx;
      _editingColIdx = colIdx;
      _editController.text = currentValue;
      _errorMessage = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocus.requestFocus();
      _editController.selection = TextSelection(baseOffset: 0, extentOffset: _editController.text.length);
    });
  }

  void _startEditing(Student student, _ColDef col, List<_ColDef> cols) {
    final studentIdx = widget.filteredStudentList.indexOf(student);
    final colIdx = cols.indexOf(col);
    _startEditingAt(studentIdx, colIdx, cols);
  }

  Future<void> _finishAndMove(int nextStudentIdx, int nextColIdx, List<_ColDef> cols) async {
    if (_isSaving) return;
    final value = _editController.text.trim();
    final studentIdx = _editingStudentIdx;
    final colIdx = _editingColIdx;

    if (studentIdx < 0 || colIdx < 0) return;

    final student = widget.filteredStudentList[studentIdx];
    final col = cols[colIdx];

    setState(() => _isSaving = true);

    if (widget.onInlineSave != null && value.isNotEmpty) {
      final error = await widget.onInlineSave!(student, col.type, col.header, value);
      if (!mounted) return;
      if (error != null) {
        setState(() { _errorMessage = error; _isSaving = false; });
        _editFocus.requestFocus();
        return;
      }
    }

    setState(() { _isSaving = false; _errorMessage = null; _editingKey = null; });

    // Move to next cell
    if (nextStudentIdx >= 0 && nextColIdx >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startEditingAt(nextStudentIdx, nextColIdx, cols);
      });
    }
  }

  void _cancelEditing() {
    setState(() { _editingKey = null; _errorMessage = null; _editingStudentIdx = -1; _editingColIdx = -1; });
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final availableWidth = constraints.maxWidth - _nameW;
      final cols = _buildColumns(availableWidth);
      final totalWidth = cols.length * _cellW;
      // Use max of calculated width or available width so table fills the screen
      final contentWidth = totalWidth < availableWidth ? availableWidth : totalWidth;

      return GestureDetector(
        onTap: _cancelEditing,
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _nameColumn(),
            Expanded(child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: widget.horizontalScrollController,
              child: SizedBox(
                width: contentWidth,
                child: Column(children: [
                  _headerRow(cols, contentWidth),
                  ...widget.filteredStudentList.asMap().entries.map((e) => _dataRow(e.key, e.value, cols, contentWidth)),
                ]),
              ),
            )),
          ]),
        ),
      );
    });
  }

  // ── Name column ──

  Widget _nameColumn() {
    return Container(
      width: _nameW,
      decoration: BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: ColorUtils.slate200))),
      child: Column(children: [
        Container(
          height: _headerH, width: _nameW,
          padding: const EdgeInsets.only(left: 10),
          alignment: Alignment.centerLeft,
          color: widget.primaryColor,
          child: const Text('Siswa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        ...widget.filteredStudentList.asMap().entries.map((e) {
          final i = e.key;
          return Container(
            height: _rowH, width: _nameW,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: i.isEven ? Colors.white : ColorUtils.slate50,
              border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
            ),
            child: Row(children: [
              SizedBox(width: 18, child: Text('${i + 1}', style: TextStyle(fontSize: 10, color: ColorUtils.slate400, fontWeight: FontWeight.w600))),
              Expanded(child: Text(e.value.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: ColorUtils.slate800), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          );
        }),
      ]),
    );
  }

  // ── Header row ──

  Widget _headerRow(List<_ColDef> cols, double contentWidth) {
    return Container(
      height: _headerH,
      color: widget.primaryColor,
      child: Row(children: cols.map((c) {
        if (c.isPlaceholder) {
          // Empty placeholder header
          final label = c.type.isNotEmpty ? _short(c.type) : '';
          return Container(
            width: _cellW,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.06)))),
            child: label.isNotEmpty
                ? Center(child: Text(label, style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.3)), textAlign: TextAlign.center))
                : null,
          );
        }

        final date = c.header['date'] as String;
        final parts = date.split('-');
        final dFmt = parts.length == 3 ? '${parts[2]}/${parts[1]}' : date;
        final label = '${_short(c.type)} ${c.index + 1}';

        return InkWell(
          onTap: () => widget.onColumnTap(c.type, c.header),
          child: Container(
            width: _cellW,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.12)))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white), textAlign: TextAlign.center, maxLines: 1),
              const SizedBox(height: 1),
              Text(dFmt, style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.6)), textAlign: TextAlign.center),
            ]),
          ),
        );
      }).toList()),
    );
  }

  // ── Data row with inline edit ──

  Widget _dataRow(int index, Student student, List<_ColDef> cols, double contentWidth) {
    return Container(
      height: _rowH,
      decoration: BoxDecoration(
        color: index.isEven ? Colors.white : ColorUtils.slate50,
        border: Border(bottom: BorderSide(color: ColorUtils.slate100)),
      ),
      child: Row(children: cols.map((c) {
        if (c.isPlaceholder) {
          return Container(
            width: _cellW,
            decoration: BoxDecoration(
              color: ColorUtils.slate50.withValues(alpha: 0.3),
              border: Border(right: BorderSide(color: ColorUtils.slate100.withValues(alpha: 0.3))),
            ),
          );
        }

        final key = _cellKey(student, c.type, c.index);
        final isEditing = _editingKey == key;

        if (isEditing) {
          return _editCell(cols);
        }

        final rec = _getGrade(student, c.type, c.header);
        final hasVal = rec?.isNotEmpty == true;
        final score = hasVal ? (rec!['score'] as num?)?.toDouble() : null;
        final txt = hasVal ? _fmt(rec!['score']) : '-';

        return GestureDetector(
          onTap: () => _startEditing(student, c, cols),
          child: Container(
            width: _cellW,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border(right: BorderSide(color: ColorUtils.slate100.withValues(alpha: 0.5)))),
            child: Text(txt, style: TextStyle(
              fontSize: hasVal ? 13 : 10,
              fontWeight: hasVal ? FontWeight.w700 : FontWeight.w400,
              color: score != null ? _scoreColor(score) : ColorUtils.slate300,
            )),
          ),
        );
      }).toList()),
    );
  }

  // ── Inline edit cell with keyboard navigation ──

  Widget _editCell(List<_ColDef> cols) {
    final hasError = _errorMessage != null;
    final borderColor = hasError ? ColorUtils.error600 : widget.primaryColor;

    return Container(
      width: _cellW,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      decoration: BoxDecoration(
        color: hasError ? ColorUtils.error600.withValues(alpha: 0.06) : widget.primaryColor.withValues(alpha: 0.06),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          height: hasError ? 22 : 30,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (event is! KeyDownEvent) return;
              final key = event.logicalKey;
              if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.tab) {
                // Move down (next student, same column)
                _finishAndMove(_editingStudentIdx + 1, _editingColIdx, cols);
              } else if (key == LogicalKeyboardKey.arrowUp) {
                // Move up (prev student, same column)
                _finishAndMove(_editingStudentIdx - 1, _editingColIdx, cols);
              } else if (key == LogicalKeyboardKey.arrowRight) {
                // Move right (same student, next column)
                final nextCol = cols.indexWhere((c) => !c.isPlaceholder, _editingColIdx + 1);
                if (nextCol >= 0) _finishAndMove(_editingStudentIdx, nextCol, cols);
              } else if (key == LogicalKeyboardKey.arrowLeft) {
                // Move left (same student, prev column)
                for (int i = _editingColIdx - 1; i >= 0; i--) {
                  if (!cols[i].isPlaceholder) { _finishAndMove(_editingStudentIdx, i, cols); break; }
                }
              } else if (key == LogicalKeyboardKey.escape) {
                _cancelEditing();
              }
            },
            child: TextField(
              controller: _editController,
              focusNode: _editFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: hasError ? ColorUtils.error600 : widget.primaryColor),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4), border: InputBorder.none),
              onSubmitted: (_) => _finishAndMove(_editingStudentIdx + 1, _editingColIdx, cols),
              onTapOutside: (_) => _finishAndMove(-1, -1, cols),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(_errorMessage!, style: TextStyle(fontSize: 6, color: ColorUtils.error600, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ]),
    );
  }
}

class _ColDef {
  final String type;
  final int index;
  final Map<String, dynamic> header;
  final bool isPlaceholder;
  const _ColDef({required this.type, required this.index, required this.header, this.isPlaceholder = false});
}
