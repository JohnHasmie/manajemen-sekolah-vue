import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_table_helpers_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_table_logic_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_table_editing_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_table_ui_mixin.dart';

// Re-export for convenience
export 'package:manajemensekolah/features/grades/presentation/mixins/grade_table_logic_mixin.dart'
    show ColDef;

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
  final void Function(Student student, String type, Map<String, dynamic> header)
  onCellTap;
  final void Function(String type) onAddAssessment;

  /// Called when user finishes inline editing a cell.
  /// Returns error message or null on success.
  final Future<String?> Function(
    Student student,
    String type,
    Map<String, dynamic> header,
    String value,
  )?
  onInlineSave;

  const GradeTableWidget({
    super.key,
    required this.filteredStudentList,
    required this.filteredGradeTypeList,
    required this.assessmentHeaders,
    required this.gradeList,
    required this.horizontalScrollController,
    required this.canEdit,
    required this.isReadOnly,
    required this.primaryColor,
    required this.languageProvider,
    required this.onColumnTap,
    required this.onCellTap,
    required this.onAddAssessment,
    this.onInlineSave,
  });

  @override
  State<GradeTableWidget> createState() => _GradeTableWidgetState();
}

class _GradeTableWidgetState extends State<GradeTableWidget>
    with
        GradeTableHelpersMixin,
        GradeTableLogicMixin,
        GradeTableEditingMixin,
        GradeTableUiMixin {
  // Active editing cell state
  String? _editingKey;
  int _editingStudentIdx = -1;
  int _editingColIdx = -1;
  final _editController = TextEditingController();
  final _editFocus = FocusNode();
  String? _errorMessage;
  bool _isSaving = false;

  @override
  String? get editingKey => _editingKey;

  @override
  int get editingStudentIdx => _editingStudentIdx;

  @override
  int get editingColIdx => _editingColIdx;

  @override
  TextEditingController get editController => _editController;

  @override
  FocusNode get editFocus => _editFocus;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get isSaving => _isSaving;

  @override
  void setEditingState({
    String? editingKey,
    int? editingStudentIdx,
    int? editingColIdx,
    String? errorMessage,
    bool? isSaving,
  }) {
    setState(() {
      if (editingKey != null) _editingKey = editingKey;
      if (editingStudentIdx != null) _editingStudentIdx = editingStudentIdx;
      if (editingColIdx != null) _editingColIdx = editingColIdx;
      if (errorMessage != null) _errorMessage = errorMessage;
      if (isSaving != null) _isSaving = isSaving;
    });
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - nameW;
        final cols = buildColumns(availableWidth);
        final contentWidth = _calculateContentWidth(cols, availableWidth);
        return buildTableLayout(cols, contentWidth);
      },
    );
  }

  double _calculateContentWidth(List<ColDef> cols, double availableWidth) {
    final totalWidth = cols.length * cellW;
    return totalWidth < availableWidth ? availableWidth : totalWidth;
  }

  Widget buildTableLayout(List<ColDef> cols, double contentWidth) {
    return GestureDetector(
      onTap: cancelEditing,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            nameColumn(),
            Expanded(child: buildScrollableTable(cols, contentWidth)),
          ],
        ),
      ),
    );
  }

  Widget buildScrollableTable(List<ColDef> cols, double contentWidth) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: widget.horizontalScrollController,
      child: SizedBox(
        width: contentWidth,
        child: Column(
          children: [
            headerRow(cols, contentWidth),
            ...buildStudentRows(cols, contentWidth),
          ],
        ),
      ),
    );
  }

  Iterable<Widget> buildStudentRows(List<ColDef> cols, double contentWidth) {
    return widget.filteredStudentList.asMap().entries.map(
      (e) => dataRow(e.key, e.value, cols, contentWidth),
    );
  }
}
