// Filter bottom sheet for material screen — lets user pick class + subject.
//
// Extracted from teacher_material_screen.dart `_showFilterDialog()`.
// Now uses shared filter components for consistent UI.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';

/// Result returned by [MaterialFilterDialog] when the user taps Apply.
class MaterialFilterResult {
  final String? classId;
  final String? subjectId;
  final List<dynamic> subjectList;

  const MaterialFilterResult({
    required this.classId,
    required this.subjectId,
    required this.subjectList,
  });
}

/// Bottom sheet for filtering materials by class and subject.
class MaterialFilterDialog extends StatefulWidget {
  final List<dynamic> classList;
  final List<dynamic> initialSubjectList;
  final String? initialClassId;
  final String? initialSubjectId;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final Future<List<dynamic>> Function(String classId) onLoadSubjects;

  const MaterialFilterDialog({
    super.key,
    required this.classList,
    required this.initialSubjectList,
    this.initialClassId,
    this.initialSubjectId,
    required this.primaryColor,
    required this.languageProvider,
    required this.onLoadSubjects,
  });

  /// Shows this dialog and returns a [MaterialFilterResult]
  /// when the user taps Apply, or null if dismissed.
  static Future<MaterialFilterResult?> show({
    required BuildContext context,
    required List<dynamic> classList,
    required List<dynamic> initialSubjectList,
    String? initialClassId,
    String? initialSubjectId,
    required Color primaryColor,
    required LanguageProvider languageProvider,
    required Future<List<dynamic>> Function(String) onLoadSubjects,
  }) {
    return showModalBottomSheet<MaterialFilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MaterialFilterDialog(
        classList: classList,
        initialSubjectList: initialSubjectList,
        initialClassId: initialClassId,
        initialSubjectId: initialSubjectId,
        primaryColor: primaryColor,
        languageProvider: languageProvider,
        onLoadSubjects: onLoadSubjects,
      ),
    );
  }

  @override
  State<MaterialFilterDialog> createState() => _MaterialFilterDialogState();
}

class _MaterialFilterDialogState extends State<MaterialFilterDialog> {
  late String? _classId;
  late String? _subjectId;
  late List<dynamic> _subjectList;

  @override
  void initState() {
    super.initState();
    _classId = widget.initialClassId;
    _subjectId = widget.initialSubjectId;
    _subjectList = List.from(widget.initialSubjectList);
  }

  LanguageProvider get _lp => widget.languageProvider;

  @override
  Widget build(BuildContext context) {
    return AppFilterBottomSheet(
      title: _lp.getTranslatedText({
        'en': 'Filter Materials',
        'id': 'Filter Materi',
      }),
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.75,
      onApply: () {
        Navigator.pop(
          context,
          MaterialFilterResult(
            classId: _classId,
            subjectId: _subjectId,
            subjectList: _subjectList,
          ),
        );
      },
      onReset: () => setState(() {
        _classId = null;
        _subjectId = null;
        _subjectList = [];
      }),
      content: TeacherFilterContent(
        sections: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilterSectionHeader(
                title: _lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
                icon: Icons.class_outlined,
                primaryColor: widget.primaryColor,
              ),
              FilterChipGrid<String>(
                options: widget.classList.map((c) {
                  final id = c['id']?.toString() ?? '';
                  final name = (c['name'] ?? c['nama'] ?? '-').toString();
                  return FilterOption(value: id, label: name);
                }).toList(),
                selectedValue: _classId,
                onSelected: (val) async {
                  final newId = val == _classId ? null : val;
                  setState(() {
                    _classId = newId;
                    _subjectId = null;
                    _subjectList = [];
                  });
                  if (newId != null) {
                    final subjects = await widget.onLoadSubjects(newId);
                    if (mounted) {
                      setState(() => _subjectList = subjects);
                    }
                  }
                },
                selectedColor: widget.primaryColor,
              ),
            ],
          ),
          if (_classId != null && _subjectList.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilterSectionHeader(
                  title: _lp.getTranslatedText({
                    'en': 'Subject',
                    'id': 'Mata Pelajaran',
                  }),
                  icon: Icons.book_outlined,
                  primaryColor: widget.primaryColor,
                ),
                FilterChipGrid<String>(
                  options: _subjectList.map((s) {
                    final id =
                        (s['id'] ?? s['mata_pelajaran_id'])?.toString() ?? '';
                    final name = (s['nama'] ?? s['name'] ?? '-').toString();
                    return FilterOption(value: id, label: name);
                  }).toList(),
                  selectedValue: _subjectId,
                  onSelected: (val) => setState(() => _subjectId = val),
                  selectedColor: widget.primaryColor,
                ),
              ],
            ),
          if (_classId != null && _subjectList.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                _lp.getTranslatedText({
                  'en': 'Loading subjects...',
                  'id': 'Memuat mapel...',
                }),
                style: TextStyle(color: ColorUtils.slate500, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
