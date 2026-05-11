import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/filter_sheet_reset.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_recap_screen.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

mixin GradeRecapDialogMixin {
  // Required from ConsumerState
  BuildContext get context;
  bool get mounted;
  WidgetRef get ref;
  void setState(VoidCallback fn);
  void openRecapTable(dynamic classData, dynamic subject) {
    final subj = Subject.fromJson(subject as Map<String, dynamic>);
    // [Brand 4.3] — promoted from a 0.95-height modal sheet to a
    // full-screen route. The recap matrix is the meaty surface of the
    // grade flow (frozen-name col + chapter columns + sticky save
    // bar); a full-screen page gives it the room it deserves and keeps
    // the BrandPageLayout assertions about KPI-overlap heights happy.
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => GradeRecapPage(
              teacher: teacherData,
              initialClass: {
                'id': classData['class_id'],
                'nama': classData['class_name'],
                'name': classData['class_name'],
              },
              initialSubject: {
                'id': subj.id,
                'nama': subj.name,
                'name': subj.name,
                'kode': subj.code,
              },
            ),
          ),
        )
        .then((_) {
          // When the recap screen pops, bypass both the server cache and the
          // on-device cache so any scores the teacher just saved show up in the
          // overview's "$recapCount/$totalStudents siswa" counter immediately.
          if (mounted) loadData(useCache: false);
        });
  }

  void showFilterDialog(LanguageProvider lp) {
    // Guard against accessing availableClasses before data is loaded.
    final classes = _safeAvailableClasses;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GradeRecapFilterSheet(
        availableClasses: classes,
        initialClassId: filterClassId,
        initialClassName: filterClassName,
        initialSubjectId: filterSubjectId,
        initialSubjectName: filterSubjectName,
        primaryColor: primaryColor,
        languageProvider: lp,
        teacherId: teacherData['id']?.toString() ?? '',
        onApply:
            ({
              String? classId,
              String? className,
              String? subjectId,
              String? subjectName,
            }) {
              setState(() {
                filterClassId = classId;
                filterClassName = className;
                filterSubjectId = subjectId;
                filterSubjectName = subjectName;
              });
              loadData();
            },
      ),
    );
  }

  /// Safely access availableClasses — returns empty list if data not loaded yet.
  List<Map<String, String>> get _safeAvailableClasses {
    try {
      return availableClasses;
    } catch (_) {
      return [];
    }
  }

  // Exposed state/methods needed
  late String? filterClassId;
  late String? filterClassName;
  late String? filterSubjectId;
  late String? filterSubjectName;
  // NOTE: this MUST be an abstract getter, not a `late` field. The real
  // implementation lives in `GradeRecapDataMixin` and computes the list
  // from `groupedData`. If we redeclare it as a field here, Dart's mixin
  // linearization picks up this (uninitialized) field instead of the getter,
  // `_safeAvailableClasses` swallows the LateInitializationError, and the
  // filter sheet renders with zero class chips. See filter_mixin for the
  // same pattern.
  List<Map<String, String>> get availableClasses;
  late Color primaryColor;
  Map<String, dynamic> get teacherData;
  Future<void> loadData({bool useCache = true});
  Widget filterSectionHeader(String title, IconData icon);
  Widget filterChip(String label, bool isSelected, VoidCallback onTap);
}

/// Stateful filter sheet for the grade recap screen.
class _GradeRecapFilterSheet extends StatefulWidget {
  final List<Map<String, String>> availableClasses;
  final String? initialClassId;
  final String? initialClassName;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final String teacherId;
  final void Function({
    String? classId,
    String? className,
    String? subjectId,
    String? subjectName,
  })
  onApply;

  const _GradeRecapFilterSheet({
    required this.availableClasses,
    required this.initialClassId,
    required this.initialClassName,
    required this.initialSubjectId,
    required this.initialSubjectName,
    required this.primaryColor,
    required this.languageProvider,
    required this.teacherId,
    required this.onApply,
  });

  @override
  State<_GradeRecapFilterSheet> createState() => _GradeRecapFilterSheetState();
}

class _GradeRecapFilterSheetState extends State<_GradeRecapFilterSheet> {
  late String? _classId;
  late String? _className;
  late String? _subjectId;
  late String? _subjectName;
  late List<dynamic> _subjectList;

  @override
  void initState() {
    super.initState();
    _classId = widget.initialClassId;
    _className = widget.initialClassName;
    _subjectId = widget.initialSubjectId;
    _subjectName = widget.initialSubjectName;
    _subjectList = [];
    // If a class is already selected, load its subjects
    if (_classId != null) {
      _fetchSubjects(_classId!);
    }
  }

  LanguageProvider get _lp => widget.languageProvider;

  /// Fetches only subjects the current teacher teaches for the given class.
  /// `/teacher/:id/subjects?class_id=` merges assignments + teaching
  /// schedule; see TeacherController@getSubjects.
  Future<void> _fetchSubjects(String classId) async {
    try {
      final r = await dioClient.get(
        '/teacher/${widget.teacherId}/subjects',
        queryParameters: {'class_id': classId},
      );
      final raw = r.data;
      final list = raw is List
          ? raw
          : (raw is Map && raw['data'] is List
                ? raw['data'] as List
                : <dynamic>[]);
      if (mounted) {
        setState(() => _subjectList = list);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppFilterBottomSheet(
      title: _lp.getTranslatedText({
        'en': 'Filter Recap',
        'id': 'Filter Rekap',
      }),
      primaryColor: widget.primaryColor,
      maxHeightFactor: 0.75,
      onApply: () {
        Navigator.pop(context);
        widget.onApply(
          classId: _classId,
          className: _className,
          subjectId: _subjectId,
          subjectName: _subjectName,
        );
      },
      onReset: () => FilterSheetHelpers.reset(
        context,
        () => widget.onApply(
          classId: null,
          className: null,
          subjectId: null,
          subjectName: null,
        ),
      ),
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
                options: widget.availableClasses.map((c) {
                  return FilterOption<String>(
                    value: c['id']!,
                    label: c['name']!,
                  );
                }).toList(),
                selectedValue: _classId,
                onSelected: (classId) async {
                  final isDeselect = classId == _classId;
                  final nextId = isDeselect ? null : classId;
                  setState(() {
                    _classId = nextId;
                    _className = FilterSheetHelpers.labelForId(
                      widget.availableClasses,
                      nextId,
                    );
                    _subjectId = null;
                    _subjectName = null;
                    _subjectList = [];
                  });
                  if (!isDeselect && classId != null) {
                    await _fetchSubjects(classId);
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
                    'id': 'Mapel',
                  }),
                  icon: Icons.book_outlined,
                  primaryColor: widget.primaryColor,
                ),
                FilterChipGrid<String>(
                  options: _subjectList.map((s) {
                    final sid = s['id']?.toString() ?? '';
                    final sname = (s['name'] ?? s['nama'] ?? '-').toString();
                    return FilterOption<String>(value: sid, label: sname);
                  }).toList(),
                  selectedValue: _subjectId,
                  onSelected: (subjectId) {
                    final isDeselect = subjectId == _subjectId;
                    final sname = _subjectList.firstWhere(
                      (s) => s['id']?.toString() == subjectId,
                      orElse: () => {'name': null, 'nama': null},
                    );
                    setState(() {
                      _subjectId = isDeselect ? null : subjectId;
                      _subjectName = isDeselect
                          ? null
                          : (sname['name'] ?? sname['nama'])?.toString();
                    });
                  },
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
