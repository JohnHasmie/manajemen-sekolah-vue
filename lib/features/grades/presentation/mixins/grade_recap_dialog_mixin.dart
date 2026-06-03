import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
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
        ref: ref,
        availableClasses: classes,
        hideClassSection: isHomeroomView,
        isHomeroomView: isHomeroomView,
        initialClassId: filterClassId,
        initialClassName: filterClassName,
        initialSubjectId: filterSubjectId,
        initialSubjectName: filterSubjectName,
        primaryColor: primaryColor,
        languageProvider: lp,
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

  /// Safely access availableClasses — returns empty list if data not loaded
  /// yet.
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

  /// Wali kelas vs mengajar — drives whether the Kelas section
  /// renders in the filter sheet. Satisfied by `GradeRecapDataMixin`.
  bool get isHomeroomView;
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
///
/// Sources its chip set from `filterRosterRiverpod` (the
/// pre-fetched roster — see filter_sheet_reset.dart for the brand
/// rule). The legacy `_fetchSubjects` per-tap network call is gone.
class _GradeRecapFilterSheet extends StatefulWidget {
  final WidgetRef ref;

  /// Legacy: still passed for the wali-kelas fallback when the
  /// roster provider hasn't hydrated yet (cold open). Once the
  /// provider populates this is unused.
  final List<Map<String, String>> availableClasses;

  /// True when the host page is in wali kelas mode. Hides the Kelas
  /// section since the role toggle in the page header has already
  /// locked the class.
  final bool hideClassSection;

  /// Drives `roster.classesForView(...)` / `classesForSubject(...)`.
  final bool isHomeroomView;

  final String? initialClassId;
  final String? initialClassName;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final void Function({
    String? classId,
    String? className,
    String? subjectId,
    String? subjectName,
  })
  onApply;

  const _GradeRecapFilterSheet({
    required this.ref,
    required this.availableClasses,
    required this.hideClassSection,
    required this.isHomeroomView,
    required this.initialClassId,
    required this.initialClassName,
    required this.initialSubjectId,
    required this.initialSubjectName,
    required this.primaryColor,
    required this.languageProvider,
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

  @override
  void initState() {
    super.initState();
    _classId = widget.initialClassId;
    _className = widget.initialClassName;
    _subjectId = widget.initialSubjectId;
    _subjectName = widget.initialSubjectName;
  }

  LanguageProvider get _lp => widget.languageProvider;

  @override
  Widget build(BuildContext context) {
    // Brand filter rule: source chips from the pre-fetched roster +
    // cross-axis maps. No on-tap network round-trips.
    final roster = widget.ref.watch(filterRosterRiverpod);
    final rosterClasses = roster.classesForSubject(
      _subjectId,
      isHomeroomView: widget.isHomeroomView,
    );
    final rosterSubjects = roster.subjectsForClass(
      _classId,
      isHomeroomView: widget.isHomeroomView,
    );
    // Cold-open fallback: provider hasn't hydrated yet.
    final fallbackClasses = rosterClasses.isNotEmpty
        ? rosterClasses
        : widget.availableClasses;
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
          // Kelas section hides in wali kelas mode — the role toggle
          // in the page header has already locked the class.
          if (!widget.hideClassSection)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FilterSectionHeader(
                  title: _lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
                  icon: Icons.class_outlined,
                  primaryColor: widget.primaryColor,
                ),
                FilterChipGrid<String>(
                  options: fallbackClasses.map((c) {
                    final id = (c is Map ? c['id'] : null)?.toString() ?? '';
                    final name = c is Map
                        ? ((c['name'] ?? c['nama'] ?? '-').toString())
                        : '-';
                    return FilterOption<String>(value: id, label: name);
                  }).toList(),
                  selectedValue: _classId,
                  onSelected: (classId) {
                    final isDeselect = classId == _classId;
                    final nextId = isDeselect ? null : classId;
                    setState(() {
                      _classId = nextId;
                      _className = FilterSheetHelpers.labelForId(
                        fallbackClasses,
                        nextId,
                      );
                      // Cross-axis: drop subject if the new class
                      // doesn't teach it.
                      if (_subjectId != null && nextId != null) {
                        final allowed = roster
                            .subjectsForClass(
                              nextId,
                              isHomeroomView: widget.isHomeroomView,
                            )
                            .map((s) => (s as Map)['id']?.toString());
                        if (!allowed.contains(_subjectId)) {
                          _subjectId = null;
                          _subjectName = null;
                        }
                      }
                      // Auto-select-on-single.
                      if (nextId != null && _subjectId == null) {
                        final only = roster.subjectsForClass(
                          nextId,
                          isHomeroomView: widget.isHomeroomView,
                        );
                        if (only.length == 1 && only.first is Map) {
                          _subjectId = (only.first as Map)['id']?.toString();
                          _subjectName =
                              ((only.first as Map)['name'] ??
                                      (only.first as Map)['nama'])
                                  ?.toString();
                        }
                      }
                    });
                  },
                  selectedColor: widget.primaryColor,
                ),
              ],
            ),
          if (rosterSubjects.isNotEmpty)
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
                  options: rosterSubjects.map((s) {
                    final sid = (s is Map ? s['id'] : null)?.toString() ?? '';
                    final sname = s is Map
                        ? ((s['name'] ?? s['nama'] ?? '-').toString())
                        : '-';
                    return FilterOption<String>(value: sid, label: sname);
                  }).toList(),
                  selectedValue: _subjectId,
                  onSelected: (subjectId) {
                    final isDeselect = subjectId == _subjectId;
                    final nextId = isDeselect ? null : subjectId;
                    setState(() {
                      _subjectId = nextId;
                      _subjectName = FilterSheetHelpers.labelForId(
                        rosterSubjects,
                        nextId,
                      );
                      // Cross-axis inverse: auto-select sole class.
                      if (nextId != null && _classId == null) {
                        final only = roster.classesForSubject(
                          nextId,
                          isHomeroomView: widget.isHomeroomView,
                        );
                        if (only.length == 1 && only.first is Map) {
                          _classId = (only.first as Map)['id']?.toString();
                          _className =
                              ((only.first as Map)['name'] ??
                                      (only.first as Map)['nama'])
                                  ?.toString();
                        }
                      }
                    });
                  },
                  selectedColor: widget.primaryColor,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
