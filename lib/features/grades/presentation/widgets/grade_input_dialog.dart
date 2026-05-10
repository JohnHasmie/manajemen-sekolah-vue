import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_input_form_mixin.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/grade_input_ui_builder_mixin.dart';

/// Grade Input Dialog — DraggableScrollableSheet for adding new grades.
class GradeInputDialog extends StatefulWidget {
  final Map<String, dynamic> teacher;
  final Map<String, dynamic> subject;
  final List<Student> studentList;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onSaved;

  const GradeInputDialog({
    super.key,
    required this.teacher,
    required this.subject,
    required this.studentList,
    required this.primaryColor,
    required this.languageProvider,
    required this.onSaved,
  });

  @override
  State<GradeInputDialog> createState() => GradeInputDialogState();
}

class GradeInputDialogState extends State<GradeInputDialog>
    with GradeInputFormMixin, GradeInputUiBuilderMixin {
  String _selectedType = 'uh';
  DateTime _selectedDate = DateTime.now();
  final _titleController = TextEditingController();
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, FocusNode> _scoreFocusNodes = {};
  bool _isSaving = false;

  final _types = ['uh', 'tugas', 'uts', 'uas', 'pts', 'pas'];
  final _typeLabels = {
    'uh': 'UH',
    'tugas': 'Tugas',
    'uts': 'UTS',
    'uas': 'UAS',
    'pts': 'PTS',
    'pas': 'PAS',
  };

  @override
  String get selectedType => _selectedType;
  @override
  DateTime get selectedDate => _selectedDate;
  @override
  TextEditingController get titleController => _titleController;
  @override
  Map<String, TextEditingController> get scoreControllers => _scoreControllers;
  @override
  Map<String, FocusNode> get scoreFocusNodes => _scoreFocusNodes;
  @override
  bool get isSaving => _isSaving;
  @override
  List<String> get types => _types;
  @override
  Map<String, String> get typeLabels => _typeLabels;

  @override
  void setSelectedType(String type) => setState(() => _selectedType = type);
  @override
  void setSelectedDate(DateTime date) => setState(() => _selectedDate = date);
  @override
  void setIsSaving(bool value) => setState(() => _isSaving = value);

  @override
  void initState() {
    super.initState();
    for (final s in widget.studentList) {
      _scoreControllers[s.id] = TextEditingController();
      _scoreFocusNodes[s.id] = FocusNode();
    }
  }

  /// Set up listeners on every score controller so the KPI strip and
  /// bottom-bar progress recompute as soon as the teacher types.
  /// Without this they'd only update on the per-row `setState({})`
  /// call from the UI mixin's `onChanged`, which doesn't reach the
  /// dialog state — the KPI numbers would lag behind.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final c in _scoreControllers.values) {
      c.removeListener(_onAnyScoreChanged);
      c.addListener(_onAnyScoreChanged);
    }
  }

  void _onAnyScoreChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _scoreControllers.values) {
      c.removeListener(_onAnyScoreChanged);
      c.dispose();
    }
    for (final f in _scoreFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  // ── KPI strip ─────────────────────────────────────────────────
  // Live counts so the teacher sees their progress as they type.

  ({int filled, int total, int overKkm, int underKkm}) _kpiStats() {
    var filled = 0;
    var overKkm = 0;
    var underKkm = 0;
    for (final c in _scoreControllers.values) {
      final raw = c.text.trim();
      if (raw.isEmpty) continue;
      filled++;
      final v = double.tryParse(raw);
      if (v == null) continue;
      if (v >= 75) {
        overKkm++;
      } else {
        underKkm++;
      }
    }
    return (
      filled: filled,
      total: widget.studentList.length,
      overKkm: overKkm,
      underKkm: underKkm,
    );
  }

  Widget _buildKpiStrip(Color primary) {
    final s = _kpiStats();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _kpiCell(value: '${s.filled}', label: 'DIISI', color: primary),
          _kpiDivider(),
          _kpiCell(
            value: '${s.total}',
            label: 'TOTAL',
            color: ColorUtils.slate700,
          ),
          _kpiDivider(),
          _kpiCell(
            value: '${s.overKkm}',
            label: '≥ KKM',
            color: ColorUtils.success600,
          ),
          _kpiDivider(),
          _kpiCell(
            value: '${s.underKkm}',
            label: '< KKM',
            color: ColorUtils.error600,
          ),
        ],
      ),
    );
  }

  Widget _kpiCell({
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() {
    return Container(width: 1, height: 22, color: ColorUtils.slate100);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            buildFormHeader(widget.primaryColor),
            // KPI overlap strip — Diisi / Total / ≥ KKM / < KKM.
            // Pulled out of the config section so it sits between
            // the cobalt header and the form (Frame B mockup).
            _buildKpiStrip(widget.primaryColor),
            buildConfigSection(widget.primaryColor),
            const Divider(height: 1, color: Color.fromARGB(255, 241, 245, 249)),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: EdgeInsets.only(
                  bottom: bottomInset > 0
                      ? bottomInset
                      : MediaQuery.of(context).padding.bottom + 60,
                ),
                itemCount: widget.studentList.length,
                itemBuilder: (ctx, i) =>
                    buildStudentListItem(i, widget.primaryColor),
              ),
            ),
            if (bottomInset == 0) buildBottomBar(widget.primaryColor),
          ],
        ),
      ),
    );
  }
}
