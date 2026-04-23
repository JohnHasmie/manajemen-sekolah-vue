import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _titleController.dispose();
    for (final c in _scoreControllers.values) {
      c.dispose();
    }
    for (final f in _scoreFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
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
